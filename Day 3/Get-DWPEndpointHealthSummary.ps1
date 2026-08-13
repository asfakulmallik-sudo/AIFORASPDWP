<#
.SYNOPSIS
    Read-only endpoint health summary script for DWP Engineers (PowerShell 5.1).

.DESCRIPTION
    Produces a structured health report for an endpoint covering:
      1.  System uptime
      2.  Windows Update pending status
      3.  HP driver currency (WMI Win32_PnPSignedDriver — flags drivers older
          than 365 days)
      4.  Disk space (all fixed drives)
      5.  Last 5 System event log errors
      6.  Company Portal / Intune last sync time
      7.  Windows version and build
      8.  Top 3 processes by memory (Working Set)
      9.  Top 3 processes by CPU time

    READ-ONLY GUARANTEE
    -------------------
    This script makes no changes to the system. Every section uses only:
      - CIM/WMI queries          (read-only by design)
      - Get-EventLog             (read-only)
      - Registry reads via       Get-ItemProperty (read-only)
      - COM object queries via   Microsoft.Update.Session (read-only)
      - Process inspection via   Get-Process (read-only)
    No registry keys, files, services, or configurations are modified.

.NOTES
    ┌─────────────────────────────────────────────────────────────────────────┐
    │  PRE-RUN CHECKLIST — action required BEFORE executing this script       │
    ├─────────────────────────────────────────────────────────────────────────┤
    │  [REQUIRED]                                                              │
    │  1. Run PowerShell as Administrator.                                     │
    │     - Get-EventLog (Section 5) requires elevation to read the System     │
    │       log on some machines.                                              │
    │     - The Windows Update COM object (Section 2) may return 0 results    │
    │       without elevation.                                                 │
    │     - Company Portal / Intune registry keys (Section 6) live under      │
    │       HKLM and require elevation to read reliably.                       │
    │                                                                          │
    │  [ENVIRONMENT CHECKS]                                                    │
    │  2. Confirm execution policy allows running scripts:                     │
    │       Get-ExecutionPolicy                                                │
    │     If it returns 'Restricted', ask your administrator to set it to     │
    │     RemoteSigned or Bypass for this session only.                        │
    │  3. Machine must have internet access for the Windows Update COM query   │
    │     (Section 2) to reach Microsoft update servers. Offline / air-gapped  │
    │     machines will show "No pending updates found" regardless.            │
    │  4. This script is intended for managed DWP endpoints running            │
    │     Windows 10/11 with Intune enrolment. Results on unmanaged or        │
    │     non-Intune devices will be partial.                                  │
    └─────────────────────────────────────────────────────────────────────────┘

    Author  : DWP Engineer (AI-drafted — review before production use)
    Version : 1.0
    Date    : 2026-08-12
    PSver   : 5.1
#>

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

#──────────────────────────────────────────────────────────────────────────────
# Helper: section banner
#──────────────────────────────────────────────────────────────────────────────
function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

#──────────────────────────────────────────────────────────────────────────────
# Report header
#──────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "███████████████████████████████████████████████████████████████████" -ForegroundColor Yellow
Write-Host "  DWP ENDPOINT HEALTH SUMMARY" -ForegroundColor Yellow
Write-Host "  Generated : $(Get-Date -Format 'dd-MMM-yyyy  HH:mm:ss')" -ForegroundColor Yellow
Write-Host "  Hostname  : $($env:COMPUTERNAME)" -ForegroundColor Yellow
Write-Host "  Run as    : $($env:USERDOMAIN)\$($env:USERNAME)" -ForegroundColor Yellow
Write-Host "███████████████████████████████████████████████████████████████████" -ForegroundColor Yellow

#──────────────────────────────────────────────────────────────────────────────
# SECTION 1 — SYSTEM UPTIME
# Reads: Win32_OperatingSystem (CIM, read-only)
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "1 / 9  |  SYSTEM UPTIME"

$os = Get-CimInstance -ClassName Win32_OperatingSystem
if ($os) {
    $uptime   = (Get-Date) - $os.LastBootUpTime
    $bootTime = $os.LastBootUpTime

    Write-Host "  Last Boot  : $($bootTime.ToString('dd-MMM-yyyy  HH:mm:ss'))"
    Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"

    if ($uptime.Days -ge 14) {
        Write-Host "  [ADVISORY]   Machine has been up for $($uptime.Days) days." `
                   "Consider scheduling a reboot." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK]         Uptime within acceptable range." -ForegroundColor Green
    }
} else {
    Write-Host "  [ERROR] Could not retrieve OS uptime." -ForegroundColor Red
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 2 — WINDOWS UPDATE PENDING
# Reads: Microsoft.Update.Session COM object (read-only search, no install)
# NOTE: Requires elevation and internet access for accurate results.
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "2 / 9  |  WINDOWS UPDATE PENDING"

try {
    $updateSession    = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher   = $updateSession.CreateUpdateSearcher()

    # IsInstalled=0 restricts to updates not yet applied — read-only search only
    $searchResult     = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

    if ($searchResult.Updates.Count -eq 0) {
        Write-Host "  [OK]  No pending Windows Updates found." -ForegroundColor Green
    } else {
        Write-Host "  [ALERT]  $($searchResult.Updates.Count) pending update(s) detected:" `
                   -ForegroundColor Yellow
        foreach ($update in $searchResult.Updates) {
            $kb = if ($update.KBArticleIDs.Count -gt 0) { "(KB$($update.KBArticleIDs[0]))" } else { "" }
            Write-Host "    - $($update.Title) $kb"
        }
    }
} catch {
    Write-Host "  [WARN]  Windows Update COM query failed. Run as Administrator and" `
               "ensure internet access." -ForegroundColor Yellow
    Write-Host "          Error: $_" -ForegroundColor DarkGray

    # Fallback: check registry for last successful update install date
    $wuReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' `
                              -ErrorAction SilentlyContinue
    if ($wuReg -and $wuReg.LastSuccessTime) {
        Write-Host "  [INFO]  Last successful Windows Update install (registry): $($wuReg.LastSuccessTime)"
    }
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 3 — HP DRIVER UPDATE STATUS
# Reads: Win32_PnPSignedDriver (CIM, read-only) — flags drivers older than 365 days
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "3 / 9  |  HP DRIVER UPDATE STATUS"

$cutoff    = (Get-Date).AddDays(-365)
$hpDrivers = Get-CimInstance -ClassName Win32_PnPSignedDriver |
             Where-Object { $_.Manufacturer -like '*HP*' -or $_.Manufacturer -like '*Hewlett*' } |
             Where-Object { $_.DriverDate -ne $null } |
             Select-Object DeviceName, DriverVersion,
                           @{N='DriverDate'; E={ $_.DriverDate.ToString('dd-MMM-yyyy') }},
                           @{N='AgeFlag';    E={ if ($_.DriverDate -lt $cutoff) { 'OLD' } else { 'OK' } }}

if (-not $hpDrivers) {
    Write-Host "  [INFO]  No HP-signed drivers found via WMI."
} else {
    Write-Host ""
    $hpDrivers | Format-Table -AutoSize
    $oldCount = ($hpDrivers | Where-Object { $_.AgeFlag -eq 'OLD' }).Count
    if ($oldCount -gt 0) {
        Write-Host "  [ADVISORY]  $oldCount HP driver(s) are over 365 days old." `
                   "Verify with HP Support Assistant." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK]  All detected HP drivers are less than 365 days old." -ForegroundColor Green
    }
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 4 — DISK SPACE
# Reads: Win32_LogicalDisk (CIM, read-only)
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "4 / 9  |  DISK SPACE"

$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
if ($drives) {
    foreach ($drive in $drives) {
        $totalGB = [math]::Round($drive.Size / 1GB, 2)
        $freeGB  = [math]::Round($drive.FreeSpace / 1GB, 2)
        $usedGB  = [math]::Round($totalGB - $freeGB, 2)
        $freePct = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

        $colour = if ($freePct -lt 10)  { 'Red'    }
                  elseif ($freePct -lt 20) { 'Yellow' }
                  else                     { 'Green'  }
        $flag   = if ($freePct -lt 10)  { '[CRITICAL]' }
                  elseif ($freePct -lt 20) { '[ADVISORY]' }
                  else                     { '[OK]      ' }

        Write-Host ("  $flag  Drive $($drive.DeviceID)  " +
                    "Total: ${totalGB} GB  |  Used: ${usedGB} GB  |  " +
                    "Free: ${freeGB} GB  ($freePct % free)") -ForegroundColor $colour
    }
} else {
    Write-Host "  [ERROR]  Could not retrieve disk information." -ForegroundColor Red
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 5 — LAST 5 SYSTEM EVENT LOG ERRORS
# Reads: Windows System event log (read-only Get-EventLog)
# NOTE: Requires elevation on some machines.
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "5 / 9  |  LAST 5 SYSTEM EVENT LOG ERRORS"

try {
    $sysErrors = Get-EventLog -LogName System -EntryType Error -Newest 5 -ErrorAction Stop
    if ($sysErrors) {
        $sysErrors | ForEach-Object {
            Write-Host ("  [{0}]  Source: {1,-30}  EventID: {2,-6}  Msg: {3}" -f `
                $_.TimeGenerated.ToString('dd-MMM-yyyy HH:mm'),
                $_.Source,
                $_.EventID,
                ($_.Message -split "`n")[0].Trim().Substring(0, [Math]::Min(80, ($_.Message -split "`n")[0].Trim().Length))
            )
        }
    } else {
        Write-Host "  [OK]  No System log errors found." -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN]  Could not read System event log. Run as Administrator." `
               -ForegroundColor Yellow
    Write-Host "          Error: $_" -ForegroundColor DarkGray
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 6 — COMPANY PORTAL / INTUNE LAST SYNC
# Reads: HKLM registry (Intune enrollment keys) + Intune Management Extension
#        log path check. Read-only. Requires elevation for HKLM access.
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "6 / 9  |  COMPANY PORTAL / INTUNE LAST SYNC"

$synced = $false

# Method A: Intune Management Extension registry key
$imeKey = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension'
if (Test-Path $imeKey) {
    Write-Host "  [INFO]  Intune Management Extension registry key found."
}

# Method B: MDM enrollment keys — look for LastSuccessfulSyncTime across enrolments
$enrollRoot = 'HKLM:\SOFTWARE\Microsoft\Enrollments'
if (Test-Path $enrollRoot) {
    $enrollKeys = Get-ChildItem -Path $enrollRoot -ErrorAction SilentlyContinue
    foreach ($key in $enrollKeys) {
        $syncTime = (Get-ItemProperty -Path $key.PSPath `
                                      -Name LastSuccessfulSyncTime `
                                      -ErrorAction SilentlyContinue).LastSuccessfulSyncTime
        if ($syncTime) {
            $syncDate = [datetime]::FromFileTime($syncTime)
            $age      = (Get-Date) - $syncDate
            $colour   = if ($age.TotalHours -gt 24) { 'Yellow' } else { 'Green' }
            $flag     = if ($age.TotalHours -gt 24) { '[ADVISORY]' } else { '[OK]      ' }
            Write-Host ("  $flag  Enrolment: $($key.PSChildName.Substring(0,[Math]::Min(8,$key.PSChildName.Length)))...  " +
                        "Last Sync: $($syncDate.ToString('dd-MMM-yyyy HH:mm'))  ($([math]::Round($age.TotalHours,1)) hours ago)") `
                       -ForegroundColor $colour
            $synced = $true
        }
    }
}

# Method C: check device join status via dsregcmd output (read-only tool)
$dsreg = & dsregcmd /status 2>$null
if ($dsreg) {
    $mdmUrl  = ($dsreg | Select-String 'MdmUrl\s*:').ToString().Trim()
    $aadJoin = ($dsreg | Select-String 'AzureAdJoined\s*:').ToString().Trim()
    if ($mdmUrl)  { Write-Host "  [INFO]  $mdmUrl" }
    if ($aadJoin) { Write-Host "  [INFO]  $aadJoin" }
}

if (-not $synced) {
    Write-Host "  [WARN]  No Intune sync timestamp found. Device may not be enrolled," `
               "or elevation is needed." -ForegroundColor Yellow
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 7 — WINDOWS VERSION AND BUILD
# Reads: Win32_OperatingSystem (CIM) + registry CurrentVersion (read-only)
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "7 / 9  |  WINDOWS VERSION"

$winReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' `
                           -ErrorAction SilentlyContinue

if ($os -and $winReg) {
    $displayVersion = $winReg.DisplayVersion   # e.g. 22H2
    $currentBuild   = $winReg.CurrentBuild
    $ubr            = $winReg.UBR             # Update Build Revision
    $edition        = $os.Caption

    Write-Host "  OS Edition     : $edition"
    Write-Host "  Feature Update : $displayVersion"
    Write-Host "  Build          : $currentBuild.$ubr"
    Write-Host "  Architecture   : $($os.OSArchitecture)"
    Write-Host "  Install Date   : $($os.InstallDate.ToString('dd-MMM-yyyy'))"

    # Flag known end-of-support builds (Win10 21H2 = 19044, Win10 22H2 = 19045 supported to Oct 2025)
    $buildNum = [int]$currentBuild
    if ($buildNum -lt 19045) {
        Write-Host "  [ADVISORY]  This build may be approaching or past end of support." `
                   "Verify with DWP release guidance." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK]  Build number within current supported range." -ForegroundColor Green
    }
} else {
    Write-Host "  [ERROR]  Could not retrieve Windows version information." -ForegroundColor Red
}

#──────────────────────────────────────────────────────────────────────────────
# SECTION 8 — TOP 3 PROCESSES BY MEMORY (Working Set)
# Reads: Get-Process (read-only)
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "8 / 9  |  TOP 3 PROCESSES BY MEMORY (Working Set)"

Get-Process -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 3 |
    ForEach-Object {
        $memMB = [math]::Round($_.WorkingSet64 / 1MB, 1)
        Write-Host ("  {0,-8}  {1,-35}  Memory: {2,8} MB" -f $_.Id, $_.ProcessName, $memMB)
    }

#──────────────────────────────────────────────────────────────────────────────
# SECTION 9 — TOP 3 PROCESSES BY CPU TIME
# Reads: Get-Process (read-only)
# Note: CPU property = total processor time (seconds) consumed since start,
#       not current % utilisation. High values indicate sustained CPU use.
#──────────────────────────────────────────────────────────────────────────────
Write-SectionHeader "9 / 9  |  TOP 3 PROCESSES BY CPU TIME"

Write-Host "  (CPU column = total CPU seconds consumed since process start)"
Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 3 |
    ForEach-Object {
        $cpuSec = [math]::Round($_.CPU, 1)
        Write-Host ("  {0,-8}  {1,-35}  CPU Time: {2,10} sec" -f $_.Id, $_.ProcessName, $cpuSec)
    }

#──────────────────────────────────────────────────────────────────────────────
# Report footer
#──────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  REPORT COMPLETE  --  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "  No changes were made to this system." -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
