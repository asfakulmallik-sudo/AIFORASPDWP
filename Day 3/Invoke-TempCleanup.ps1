#Requires -Version 5.1

<#
.SYNOPSIS
    Safely cleans temporary files from Windows endpoint temp folders for DWP engineers.

.DESCRIPTION
    Moves qualifying temp files to a timestamped backup folder instead of deleting them
    permanently, enabling full rollback. Supports dry-run mode, age filtering, locked-file
    detection, per-file error handling, and session logging. Safe to run repeatedly.

.PARAMETER DryRun
    Lists files that would be processed without making any changes to the file system.

.PARAMETER OlderThanDays
    Only target files last modified more than this many days ago. Default: 0 (all files).

.PARAMETER Rollback
    Restores all files from the most recent backup session to their original locations.

.PARAMETER BackupRoot
    Root folder for backup sessions. Each run creates a timestamped subfolder here.
    Default: $env:TEMP\_CleanupBackup

.PARAMETER LogRoot
    Folder where date-timestamped log files are written. Default: <script folder>\Logs

.PARAMETER TargetFolders
    Array of folders to scan and clean. Defaults to the user and system temp folders.

.EXAMPLE
    .\Invoke-TempCleanup.ps1 -DryRun
    Lists files that would be moved; no changes made.

.EXAMPLE
    .\Invoke-TempCleanup.ps1 -OlderThanDays 30
    Moves files last modified more than 30 days ago to the backup folder.

.EXAMPLE
    .\Invoke-TempCleanup.ps1 -Rollback
    Restores all files from the most recent backup session.

.NOTES
    Requires PowerShell 5.1. Admin rights required for the system Temp folder.
    Files are MOVED not deleted; use -Rollback to undo.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,

    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    [switch]$Rollback,

    [string]$BackupRoot = (Join-Path $env:TEMP '_CleanupBackup'),

    [string]$LogRoot = (Join-Path $PSScriptRoot 'Logs'),

    [string[]]$TargetFolders = @(
        $env:TEMP,
        (Join-Path $env:SystemRoot 'Temp')
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# INITIALISATION
# Create the log folder and open a date-timestamped log file for this session.
# ---------------------------------------------------------------------------
$sessionStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

if (-not (Test-Path $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}
$logFile = Join-Path $LogRoot "cleanup_$sessionStamp.log"

# ---------------------------------------------------------------------------
# WRITE-LOG FUNCTION
# Writes a timestamped entry to the log file and echoes it to the console.
# Levels: INFO, WARN, ERROR, DRY
# ---------------------------------------------------------------------------
function Write-Log {
    param(
        [ValidateSet('INFO','WARN','ERROR','DRY')]
        [string]$Level,
        [string]$Message
    )
    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $entry -Encoding UTF8

    switch ($Level) {
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        'ERROR' { Write-Host $entry -ForegroundColor Red }
        'DRY'   { Write-Host $entry -ForegroundColor Cyan }
        default { Write-Host $entry }
    }
}

# ---------------------------------------------------------------------------
# TEST-FILELOCKED FUNCTION
# Tries to open the file with exclusive write access to detect a lock.
# Returns $true if the file is held by another process.
# ---------------------------------------------------------------------------
function Test-FileLocked {
    param([System.IO.FileInfo]$File)
    try {
        $stream = [System.IO.File]::Open(
            $File.FullName,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $stream.Close()
        $stream.Dispose()
        return $false
    }
    catch {
        # Any exception here means we cannot get exclusive access
        return $true
    }
}

# ---------------------------------------------------------------------------
# BACKUP SESSION SETUP
# Each run uses a timestamped subfolder; a manifest CSV maps backup->original paths.
# Files are flattened using a GUID filename to avoid path-length and collision issues.
# ---------------------------------------------------------------------------
$backupSession = Join-Path $BackupRoot $sessionStamp
$manifestPath  = Join-Path $backupSession 'manifest.csv'

function Backup-FileToSession {
    param([System.IO.FileInfo]$File)

    if (-not (Test-Path $backupSession)) {
        New-Item -ItemType Directory -Path $backupSession -Force | Out-Null
    }

    # Use a GUID filename so files from different folders never collide in backup
    $backupName = '{0}{1}' -f [System.Guid]::NewGuid().ToString('N'), $File.Extension
    $backupPath = Join-Path $backupSession $backupName

    Move-Item -LiteralPath $File.FullName -Destination $backupPath -Force -ErrorAction Stop

    # Append one row to the manifest so rollback can reconstruct the original path
    [PSCustomObject]@{
        OriginalPath  = $File.FullName
        BackupPath    = $backupPath
        Session       = $sessionStamp
        SizeBytes     = $File.Length
        LastWriteTime = $File.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    } | Export-Csv -Path $manifestPath -Append -NoTypeInformation -Encoding UTF8

    return $backupPath
}

# ---------------------------------------------------------------------------
# ROLLBACK BRANCH
# Reads the most recent session manifest and moves each file back to its
# original location. Skips files whose original path already exists (idempotent).
# Exits after completing rollback; the rest of the script does not run.
# ---------------------------------------------------------------------------
if ($Rollback) {
    Write-Log INFO '=== ROLLBACK MODE ==='

    $sessions = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending

    if (-not $sessions) {
        Write-Log WARN "No backup sessions found under: $BackupRoot"
        exit 0
    }

    $lastSession  = $sessions | Select-Object -First 1
    $lastManifest = Join-Path $lastSession.FullName 'manifest.csv'

    if (-not (Test-Path $lastManifest)) {
        Write-Log WARN "Manifest not found in most recent session: $($lastSession.FullName)"
        exit 0
    }

    Write-Log INFO "Restoring from session: $($lastSession.Name)"
    $entries       = Import-Csv -Path $lastManifest -Encoding UTF8
    $rbRestored    = 0
    $rbSkipped     = 0
    $rbErrors      = 0

    foreach ($entry in $entries) {
        try {
            # Skip restore if the file already exists at the original path (idempotent)
            if (Test-Path -LiteralPath $entry.OriginalPath) {
                Write-Log WARN "Already exists, skipped: $($entry.OriginalPath)"
                $rbSkipped++
                continue
            }

            $parentDir = Split-Path $entry.OriginalPath -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }

            Move-Item -LiteralPath $entry.BackupPath -Destination $entry.OriginalPath -Force -ErrorAction Stop
            Write-Log INFO "Restored: $($entry.OriginalPath)"
            $rbRestored++
        }
        catch {
            Write-Log ERROR "Failed to restore '$($entry.OriginalPath)': $($_.Exception.Message)"
            $rbErrors++
        }
    }

    Write-Log INFO "Rollback complete. Restored: $rbRestored | Skipped: $rbSkipped | Errors: $rbErrors"
    exit 0
}

# ---------------------------------------------------------------------------
# MAIN CLEANUP LOOP
# Iterates over target folders, selects files older than the cutoff date,
# checks each file for locks, then moves (or dry-run reports) each one.
# ---------------------------------------------------------------------------
$cutoff = (Get-Date).AddDays(-$OlderThanDays)

# Counters used to build the summary report
$stats = [PSCustomObject]@{
    Found   = 0
    Moved   = 0
    DryRun  = 0
    Locked  = 0
    Errors  = 0
}

Write-Log INFO '================================================================='
Write-Log INFO "DWP Temp Cleanup - Session: $sessionStamp"
Write-Log INFO ('Mode       : {0}' -f $(if ($DryRun) { 'DRY RUN (no changes will be made)' } else { 'LIVE' }))
Write-Log INFO ('Cutoff     : files older than {0} day(s) (before {1})' -f $OlderThanDays, $cutoff.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Log INFO ('Targets    : {0}' -f ($TargetFolders -join ', '))
Write-Log INFO '================================================================='

foreach ($folder in $TargetFolders) {

    # Skip folders that do not exist on this endpoint
    if (-not (Test-Path $folder)) {
        Write-Log WARN "Folder not found, skipping: $folder"
        continue
    }

    Write-Log INFO "--- Scanning: $folder ---"

    # Collect files recursively; suppress access-denied errors for subfolders silently
    # Force array output so .Count is always available in strict mode.
    $files = @(
        Get-ChildItem -Path $folder -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    )

    Write-Log INFO "Files matching criteria: $($files.Count)"
    $stats.Found += $files.Count

    foreach ($file in $files) {
        try {
            # Check for a file lock before attempting any move
            if (Test-FileLocked -File $file) {
                Write-Log WARN "Locked, skipped: $($file.FullName)"
                $stats.Locked++
                continue
            }

            if ($DryRun) {
                Write-Log DRY ('Would move: {0}  [{1} KB, modified {2}]' -f
                    $file.FullName,
                    [math]::Round($file.Length / 1KB, 1),
                    $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
                $stats.DryRun++
            }
            else {
                $dest = Backup-FileToSession -File $file
                Write-Log INFO "Moved: $($file.FullName) -> $dest"
                $stats.Moved++
            }
        }
        catch {
            # Log the error and continue; a single file failure does not stop the run
            Write-Log ERROR "Error on '$($file.FullName)': $($_.Exception.Message)"
            $stats.Errors++
        }
    }
}

# ---------------------------------------------------------------------------
# SUMMARY REPORT
# Prints and logs a final count of all actions taken during this session.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host " Cleanup Summary  -  $sessionStamp"                               -ForegroundColor Cyan
Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host ('  Files found      : {0}' -f $stats.Found)

if ($DryRun) {
    Write-Host ('  Would move       : {0}' -f $stats.DryRun) -ForegroundColor Cyan
}
else {
    Write-Host ('  Moved to backup  : {0}' -f $stats.Moved)  -ForegroundColor Green
    if ($stats.Moved -gt 0) {
        Write-Host ('  Backup location  : {0}' -f $backupSession)
    }
}

Write-Host ('  Locked / skipped : {0}' -f $stats.Locked) -ForegroundColor Yellow
Write-Host ('  Errors           : {0}' -f $stats.Errors) -ForegroundColor $(if ($stats.Errors -gt 0) { 'Red' } else { 'Green' })
Write-Host ('  Log file         : {0}' -f $logFile)
Write-Host '=================================================================' -ForegroundColor Cyan

Write-Log INFO ('Summary - Found:{0} Moved:{1} DryRun:{2} Locked:{3} Errors:{4}' -f
    $stats.Found, $stats.Moved, $stats.DryRun, $stats.Locked, $stats.Errors)
Write-Log INFO '=== Cleanup complete ==='
