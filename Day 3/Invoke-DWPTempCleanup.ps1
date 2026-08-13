#Requires -Version 5.1
<#
.SYNOPSIS
    Safe, idempotent temp-file cleanup utility for DWP Windows endpoints.

.DESCRIPTION
    Scans defined temp locations and removes files older than today's date.
    Before any file is removed it is moved to a timestamped backup staging
    folder, which enables a full rollback if needed.
    Every action is written to a time-stamped log file, and a summary is
    printed at the end of each run.

    WHAT IT CLEANS
    --------------
    1. User Temp      : $env:TEMP  (and $env:LOCALAPPDATA\Temp if different)
    2. System Temp    : $env:SystemRoot\Temp

    WHAT IT DOES NOT TOUCH
    ----------------------
    - Files created or modified today
    - Files that are locked / in use by another process
    - The root target folders themselves
    - Anything outside the defined target list

    ROLLBACK
    --------
    Files are moved (not deleted) into a timestamped backup folder before
    removal. Running -Rollback restores them from the most recent session.
    The backup folder can be deleted manually once satisfied with the cleanup.

    IDEMPOTENCY
    -----------
    Safe to re-run. Files already removed in a previous run are silently
    skipped. Rollback is also idempotent -- already-restored files are skipped.

.PARAMETER DryRun
    Lists every file that would be removed and total space to be freed.
    No files are moved or deleted.

.PARAMETER Rollback
    Restores all files from the most recent backup session to their original
    locations. Skips files that are already present (idempotent).

.PARAMETER BackupRoot
    Root folder for backup staging.
    Default: C:\DWPTempCleanupBackup
    Each run creates a sub-folder named with a timestamp.
    Ensure this drive has free space comparable to your temp folder size.

.PARAMETER LogRoot
    Folder where log files are written.
    Default: C:\Logs\DWPTempCleanup

.EXAMPLE
    .\Invoke-DWPTempCleanup.ps1 -DryRun
    Preview only -- lists what would be removed. No changes made.

.EXAMPLE
    .\Invoke-DWPTempCleanup.ps1
    Live run -- moves eligible temp files to backup, then removes them.

.EXAMPLE
    .\Invoke-DWPTempCleanup.ps1 -Rollback
    Restores all files from the most recent backup session.

.EXAMPLE
    .\Invoke-DWPTempCleanup.ps1 -BackupRoot D:\Backups -LogRoot D:\Logs
    Uses custom paths for backup staging and log output.

.NOTES
    +---------------------------------------------------------------------------+
    |  PRE-RUN CHECKLIST                                                        |
    +---------------------------------------------------------------------------+
    |  [REQUIRED]                                                               |
    |  1. Run PowerShell as Administrator.                                      |
    |     The system temp folder (C:\Windows\Temp) requires elevation to       |
    |     read and move files.                                                  |
    |  2. Verify the BackupRoot drive has enough free space.                   |
    |     Worst case: equal to the total size of all temp folders.             |
    |                                                                           |
    |  [STRONGLY RECOMMENDED]                                                   |
    |  3. Run with -DryRun first to review the file list before going live.    |
    |  4. Test on a non-production endpoint before broad deployment.           |
    |                                                                           |
    |  [ENVIRONMENT]                                                            |
    |  5. Execution policy must allow script execution.                        |
    |     Check with: Get-ExecutionPolicy                                       |
    +---------------------------------------------------------------------------+

    Author  : DWP Engineer (AI-drafted -- review before production use)
    Version : 1.0
    Date    : 2026-08-12
    PSver   : 5.1
#>

param(
    [switch]$DryRun,
    [switch]$Rollback,
    [string]$BackupRoot = 'C:\DWPTempCleanupBackup',
    [string]$LogRoot    = 'C:\Logs\DWPTempCleanup'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

#region -- Constants -----------------------------------------------------------
$ScriptVersion = '1.0'
$RunStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
$TodayMidnight = (Get-Date).Date        # target: LastWriteTime strictly before this
$ManifestName  = 'manifest.json'
$BackupSession = Join-Path $BackupRoot $RunStamp
$LogFile       = Join-Path $LogRoot "DWPTempCleanup_${RunStamp}.log"

# Build deduplicated list of target folders that actually exist
$rawTargets = @(
    $env:TEMP,
    (Join-Path $env:SystemRoot 'Temp'),
    (Join-Path $env:LOCALAPPDATA 'Temp')
)
$TargetPaths = $rawTargets |
               Where-Object { $_ -ne $null -and $_.Trim() -ne '' } |
               ForEach-Object { $_.TrimEnd('\') } |
               Select-Object -Unique |
               Where-Object { Test-Path $_ }
#endregion

#region -- Logging -------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SKIP','ACTION','SUMMARY')]
        [string]$Level = 'INFO'
    )
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level   ] $Message"

    $colour = switch ($Level) {
        'WARN'    { 'Yellow'   }
        'ERROR'   { 'Red'      }
        'SKIP'    { 'DarkGray' }
        'ACTION'  { 'Cyan'     }
        'SUMMARY' { 'Green'    }
        default   { 'White'    }
    }
    Write-Host $line -ForegroundColor $colour

    try {
        Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        # Silently ignore log write failures so they do not stop the cleanup
    }
}
#endregion

#region -- Helpers -------------------------------------------------------------
function Initialize-Folder {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# Returns $true if the file cannot be opened exclusively (i.e. it is locked)
function Test-FileLocked {
    param([string]$Path)
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $stream.Close()
        $stream.Dispose()
        return $false
    } catch {
        return $true
    }
}

function Get-HumanSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

# Returns the path to the manifest.json of the most recent backup session
function Get-MostRecentManifest {
    if (-not (Test-Path $BackupRoot)) { return $null }
    $found = Get-ChildItem -Path $BackupRoot -Recurse -Filter $ManifestName `
                           -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending |
             Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}
#endregion

#region -- Startup banner ------------------------------------------------------
Initialize-Folder $LogRoot

$modeLabel = if ($DryRun) { 'DRY RUN' } elseif ($Rollback) { 'ROLLBACK' } else { 'LIVE' }

Write-Host ''
Write-Host ('=' * 70) -ForegroundColor Yellow
Write-Host "  DWP TEMP CLEANUP UTILITY  v$ScriptVersion  --  MODE: $modeLabel" -ForegroundColor Yellow
Write-Host "  $(Get-Date -Format 'dd-MMM-yyyy HH:mm:ss')  |  Host: $env:COMPUTERNAME" -ForegroundColor Yellow
Write-Host ('=' * 70) -ForegroundColor Yellow
Write-Host ''

Write-Log "Script started. Version=$ScriptVersion  RunStamp=$RunStamp  Mode=$modeLabel"
Write-Log "Log file     : $LogFile"
Write-Log "Backup root  : $BackupRoot"
Write-Log "Cutoff date  : $($TodayMidnight.ToString('yyyy-MM-dd')) (files with LastWriteTime before this are targeted)"
Write-Log "Target paths : $($TargetPaths -join ' | ')"
#endregion

###############################################################################
# ROLLBACK MODE
###############################################################################
if ($Rollback) {
    Write-Log '--------------------------------------------------------------' -Level INFO
    Write-Log 'ROLLBACK: Locating most recent backup manifest...' -Level ACTION

    $manifestPath = Get-MostRecentManifest
    if (-not $manifestPath) {
        Write-Log "No backup manifest found under '$BackupRoot'. Nothing to restore." -Level WARN
        exit 0
    }
    Write-Log "Manifest : $manifestPath"

    $entries = $null
    try {
        $entries = Get-Content -Path $manifestPath -Raw -ErrorAction Stop |
                   ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Log "FATAL: Cannot read manifest file: $_" -Level ERROR
        exit 1
    }

    if (-not $entries) {
        Write-Log 'Manifest is empty. Nothing to restore.' -Level WARN
        exit 0
    }

    $restoredCount  = 0
    $skippedCount   = 0
    $rbErrorCount   = 0

    foreach ($entry in $entries) {

        # Idempotent: original file already back in place
        if (Test-Path $entry.OriginalPath) {
            Write-Log "SKIP (already present): $($entry.OriginalPath)" -Level SKIP
            $skippedCount++
            continue
        }

        if (-not (Test-Path $entry.BackupPath)) {
            Write-Log "SKIP (backup file missing): $($entry.BackupPath)" -Level SKIP
            $skippedCount++
            continue
        }

        try {
            $destDir = Split-Path $entry.OriginalPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Move-Item -Path $entry.BackupPath -Destination $entry.OriginalPath `
                      -Force -ErrorAction Stop
            Write-Log "RESTORED: $($entry.OriginalPath)" -Level ACTION
            $restoredCount++
        } catch {
            Write-Log "ERROR restoring '$($entry.OriginalPath)': $_" -Level ERROR
            $rbErrorCount++
        }
    }

    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Green
    Write-Host '  ROLLBACK SUMMARY' -ForegroundColor Green
    Write-Host ('=' * 70) -ForegroundColor Green
    Write-Log "Restored : $restoredCount  |  Skipped : $skippedCount  |  Errors : $rbErrorCount" -Level SUMMARY
    Write-Log 'Rollback complete.' -Level INFO
    exit 0
}

###############################################################################
# CLEANUP MODE  (DryRun or Live)
###############################################################################

#region -- STEP 1: Enumerate eligible files ------------------------------------
Write-Log '--------------------------------------------------------------' -Level INFO
Write-Log 'STEP 1/5 -- Enumerating eligible temp files' -Level ACTION

$allFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($folder in $TargetPaths) {
    Write-Log "Scanning: $folder"
    try {
        $found = Get-ChildItem -Path $folder -Recurse -File -Force `
                               -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -lt $TodayMidnight }

        if ($found) {
            # Wrap single result in array so Count is always available
            $foundArr = @($found)
            foreach ($f in $foundArr) { $allFiles.Add($f) }
            Write-Log "  $($foundArr.Count) eligible file(s) found in $folder"
        } else {
            Write-Log "  No eligible files in $folder"
        }
    } catch {
        Write-Log "ERROR scanning '$folder': $_" -Level ERROR
    }
}

$totalBytes = 0
if ($allFiles.Count -gt 0) {
    $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $totalBytes) { $totalBytes = 0 }
}
Write-Log "Enumeration complete -- $($allFiles.Count) file(s) / $(Get-HumanSize $totalBytes) eligible for removal"
#endregion

#region -- DRY RUN output ------------------------------------------------------
if ($DryRun) {
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Cyan
    Write-Host '  DRY RUN -- FILES THAT WOULD BE REMOVED' -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Cyan

    if ($allFiles.Count -eq 0) {
        Write-Host '  No eligible files found.' -ForegroundColor Green
    } else {
        foreach ($f in $allFiles) {
            $display = $f.FullName
            if ($display.Length -gt 58) { $display = '...' + $display.Substring($display.Length - 55) }
            Write-Host ('  {0,-60}  {1,9}  Modified: {2}' -f
                $display,
                (Get-HumanSize $f.Length),
                $f.LastWriteTime.ToString('dd-MMM-yyyy'))
        }
    }

    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Cyan
    Write-Host "  Total : $($allFiles.Count) file(s)  |  $(Get-HumanSize $totalBytes) to be freed" -ForegroundColor Cyan
    Write-Host '  Re-run without -DryRun to execute the cleanup.' -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Cyan

    Write-Log "DryRun summary -- $($allFiles.Count) file(s) / $(Get-HumanSize $totalBytes) would be removed." -Level SUMMARY
    Write-Log 'No changes were made.' -Level INFO
    exit 0
}
#endregion

#region -- STEP 2: Create backup staging folder --------------------------------
Write-Log '--------------------------------------------------------------' -Level INFO
Write-Log 'STEP 2/5 -- Creating backup staging folder' -Level ACTION
Write-Log "Backup session folder: $BackupSession"

if (Test-Path $BackupSession) {
    # Already exists -- prior interrupted run; resume idempotently
    Write-Log 'Backup folder already exists (resuming from interrupted run).' -Level WARN
} else {
    try {
        New-Item -ItemType Directory -Path $BackupSession -Force | Out-Null
        Write-Log "Backup folder created: $BackupSession"
    } catch {
        Write-Log "FATAL: Cannot create backup folder '$BackupSession': $_" -Level ERROR
        exit 1
    }
}

if ($allFiles.Count -eq 0) {
    Write-Log 'No eligible files to process. Exiting.' -Level INFO
    exit 0
}
#endregion

#region -- STEP 3: Move files to backup staging --------------------------------
Write-Log '--------------------------------------------------------------' -Level INFO
Write-Log 'STEP 3/5 -- Moving eligible files to backup staging' -Level ACTION

$manifest       = [System.Collections.Generic.List[hashtable]]::new()
$movedCount     = 0
$skippedLocked  = 0
$skippedGone    = 0
$moveErrors     = 0

foreach ($file in $allFiles) {

    # Idempotent: file was already removed (e.g. by a previous interrupted run)
    if (-not (Test-Path $file.FullName)) {
        Write-Log "SKIP (already removed): $($file.FullName)" -Level SKIP
        $skippedGone++
        continue
    }

    # Skip files locked by another process
    if (Test-FileLocked -Path $file.FullName) {
        Write-Log "SKIP (file locked): $($file.FullName)" -Level SKIP
        $skippedLocked++
        continue
    }

    # Use a GUID filename in the backup folder to avoid any path-length or
    # collision issues when files from different folders share a name
    $backupFileName = "$([System.Guid]::NewGuid().ToString('N')).bak"
    $backupPath     = Join-Path $BackupSession $backupFileName

    try {
        Move-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
        Write-Log "MOVED: '$($file.FullName)' -> '$backupPath'" -Level ACTION
        $manifest.Add(@{
            OriginalPath  = $file.FullName
            BackupPath    = $backupPath
            FileName      = $file.Name
            SizeBytes     = [long]$file.Length
            LastWriteTime = $file.LastWriteTime.ToString('o')
        })
        $movedCount++
    } catch {
        Write-Log "ERROR moving '$($file.FullName)': $_" -Level ERROR
        $moveErrors++
    }
}
#endregion

#region -- STEP 4: Write rollback manifest -------------------------------------
Write-Log '--------------------------------------------------------------' -Level INFO
Write-Log 'STEP 4/5 -- Writing rollback manifest' -Level ACTION

$manifestPath = Join-Path $BackupSession $ManifestName
try {
    $manifest | ConvertTo-Json -Depth 3 |
        Out-File -FilePath $manifestPath -Encoding UTF8 -Force -ErrorAction Stop
    Write-Log "Manifest written: $manifestPath  ($($manifest.Count) entries)"
} catch {
    Write-Log "ERROR writing manifest (rollback will not be available): $_" -Level ERROR
}
#endregion

#region -- STEP 5: Remove empty sub-folders ------------------------------------
Write-Log '--------------------------------------------------------------' -Level INFO
Write-Log 'STEP 5/5 -- Removing empty sub-folders from target paths' -Level ACTION

foreach ($folder in $TargetPaths) {
    try {
        # Sort by descending path length so deepest child dirs are processed first
        $emptyDirs = Get-ChildItem -Path $folder -Recurse -Directory -Force `
                                   -ErrorAction SilentlyContinue |
                     Where-Object {
                         $_.FullName -ne $folder -and
                         (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue |
                          Measure-Object).Count -eq 0
                     } |
                     Sort-Object { $_.FullName.Length } -Descending

        foreach ($dir in $emptyDirs) {
            try {
                Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
                Write-Log "REMOVED empty dir: $($dir.FullName)" -Level ACTION
            } catch {
                Write-Log "SKIP (cannot remove dir '$($dir.FullName)'): $_" -Level SKIP
            }
        }
    } catch {
        Write-Log "ERROR processing directories in '$folder': $_" -Level ERROR
    }
}
#endregion

#region -- Summary -------------------------------------------------------------
$reclaimedBytes = 0
if ($manifest.Count -gt 0) {
    $sum = ($manifest | Measure-Object -Property SizeBytes -Sum).Sum
    if ($sum) { $reclaimedBytes = $sum }
}

Write-Host ''
Write-Host ('=' * 70) -ForegroundColor Green
Write-Host '  CLEANUP SUMMARY' -ForegroundColor Green
Write-Host ('=' * 70) -ForegroundColor Green
Write-Log '-- SUMMARY ---------------------------------------------------------' -Level SUMMARY
Write-Log "Files removed         : $movedCount" -Level SUMMARY
Write-Log "Space freed           : $(Get-HumanSize $reclaimedBytes)" -Level SUMMARY
Write-Log "Skipped (locked)      : $skippedLocked" -Level SUMMARY
Write-Log "Skipped (already gone): $skippedGone" -Level SUMMARY
Write-Log "Errors                : $moveErrors" -Level SUMMARY
Write-Log "Backup location       : $BackupSession" -Level SUMMARY
Write-Log "Log file              : $LogFile" -Level SUMMARY
Write-Log "To rollback, run      : .\Invoke-DWPTempCleanup.ps1 -Rollback" -Level SUMMARY
Write-Log '--------------------------------------------------------------------' -Level SUMMARY

if ($moveErrors -gt 0) {
    Write-Host "  [ADVISORY] $moveErrors error(s) occurred. Review the log file." -ForegroundColor Yellow
}
Write-Log 'Script completed successfully.' -Level INFO
Write-Host ''
#endregion
