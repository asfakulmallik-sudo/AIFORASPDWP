<#
.SYNOPSIS
    Read-only endpoint triage script for DWP engineers (PowerShell 5.1).

.DESCRIPTION
    Triage context: use this script as a first-pass health check before escalating
    a desktop or endpoint issue. Run it to quickly establish baseline state without
    making any changes to the system.

    Collects and displays: system uptime, free disk space, pending reboot status,
    top 5 processes by memory, top 5 processes by CPU, last 5 System log errors,
    approximate internet speed, Microsoft Defender service state, logged-in user
    count, and last Windows Update install date.

    This script is READ-ONLY: it does not modify the registry, services, files,
    or any other system state. It only queries information.

.NOTES
    ITEMS TO VERIFY BEFORE RUNNING (flagged again inline at the relevant section):
    1. Internet speed test (Section 7) downloads a small test file from a public
       Microsoft URL into MEMORY ONLY (no file is written to disk). Confirm your
       proxy/firewall policy allows outbound HTTPS to this URL before running,
       and that this is acceptable on the target network.
    2. Last Windows Update (Section 10) uses Get-HotFix, which reflects installed
       hotfixes/patches and may not always show the very latest cumulative update
       date on every build. Treat the result as indicative, not authoritative.
    3. System log read (Section 6) requires the local "Event Log Readers" /
       standard user permission to read the System log; on locked-down builds
       this may require elevated rights - confirm access if it errors out.
    4. Execution policy: this script must be allowed to run (e.g. RemoteSigned).
       Confirm your local policy permits running signed/local scripts.
#>

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " DWP Endpoint Health Report - $(Get-Date)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. System uptime
#    Reads OS LastBootUpTime via CIM and calculates elapsed time since boot.
#    Read-only: queries WMI/CIM class Win32_OperatingSystem only.
# ---------------------------------------------------------------------------
Write-Host "`n--- 1. System Uptime ---" -ForegroundColor Yellow
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    [PSCustomObject]@{
        LastBootTime = $os.LastBootUpTime
        Uptime       = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    } | Format-List
}
catch {
    Write-Warning "Could not read system uptime: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 2. Free disk space
#    Reads free/total space for each local fixed disk via CIM. No changes made.
# ---------------------------------------------------------------------------
Write-Host "`n--- 2. Free Disk Space ---" -ForegroundColor Yellow
try {
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N='SizeGB';E={[math]::Round($_.Size / 1GB, 2)}},
            @{N='FreeGB';E={[math]::Round($_.FreeSpace / 1GB, 2)}},
            @{N='FreePercent';E={ if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 } }} |
        Format-Table -AutoSize
}
catch {
    Write-Warning "Could not read disk space: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 3. Whether a reboot is pending
#    Checks well-known registry indicators only (read access, no writes):
#      - Component Based Servicing\RebootPending
#      - WindowsUpdate\Auto Update\RebootRequired
#      - PendingFileRenameOperations value
# ---------------------------------------------------------------------------
Write-Host "`n--- 3. Reboot Pending Check ---" -ForegroundColor Yellow
try {
    $rebootPending = $false
    $reasons = @()

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $rebootPending = $true
        $reasons += 'Component Based Servicing\RebootPending key present'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $rebootPending = $true
        $reasons += 'WindowsUpdate\Auto Update\RebootRequired key present'
    }
    $pfro = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($pfro) {
        $rebootPending = $true
        $reasons += 'PendingFileRenameOperations value present'
    }

    [PSCustomObject]@{
        RebootPending = $rebootPending
        Reasons       = if ($reasons.Count -gt 0) { $reasons -join '; ' } else { 'None found' }
    } | Format-List
}
catch {
    Write-Warning "Could not check reboot-pending registry keys: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 4. Top 5 processes by memory (working set)
#    Reads process info only; no processes are stopped or modified.
# ---------------------------------------------------------------------------
Write-Host "`n--- 4. Top 5 Processes by Memory (Working Set) ---" -ForegroundColor Yellow
try {
    Get-Process | Sort-Object WS -Descending | Select-Object -First 5 |
        Select-Object Name, Id, @{N='WorkingSetMB';E={[math]::Round($_.WS / 1MB, 1)}} |
        Format-Table -AutoSize
}
catch {
    Write-Warning "Could not read process memory usage: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 5. Top 5 processes by CPU
#    Reads cumulative CPU time per process; read-only, no changes made.
# ---------------------------------------------------------------------------
Write-Host "`n--- 5. Top 5 Processes by CPU ---" -ForegroundColor Yellow
try {
    Get-Process | Where-Object { $_.CPU } | Sort-Object CPU -Descending | Select-Object -First 5 |
        Select-Object Name, Id, @{N='CPU_Seconds';E={[math]::Round($_.CPU, 1)}} |
        Format-Table -AutoSize
}
catch {
    Write-Warning "Could not read process CPU usage: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 6. Last 5 system log errors
#    Reads the System event log only; no logs are cleared or modified.
#    VERIFY: requires permission to read the System event log (see notes above).
# ---------------------------------------------------------------------------
Write-Host "`n--- 6. Last 5 System Log Errors ---" -ForegroundColor Yellow
try {
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2 } -MaxEvents 5 -ErrorAction Stop |
        Select-Object TimeCreated, Id, ProviderName, @{N='Message';E={ ($_.Message -split "`n")[0] }} |
        Format-Table -Wrap -AutoSize
}
catch {
    Write-Warning "Could not read System event log errors: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 7. Internet connectivity check
#    TCP connection to Microsoft's connectivity endpoint; no TLS validation or data download.
#    This confirms DNS resolution and outbound port 443 reachability only.
# ---------------------------------------------------------------------------
Write-Host "`n--- 7. Internet Connectivity Check ---" -ForegroundColor Yellow
try {
    $testHost = 'www.msftconnecttest.com'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $connection = Test-NetConnection -ComputerName $testHost -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
    $sw.Stop()
    if (-not $connection.TcpTestSucceeded) {
        throw "TCP connection to $testHost on port 443 was unsuccessful."
    }
    [PSCustomObject]@{
        Host          = $testHost
        RemoteAddress = $connection.RemoteAddress
        Port          = 443
        ConnectMs     = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
        Result        = 'Reachable'
    } | Format-List
}
catch {
    Write-Warning "Connectivity check failed (check DNS, proxy, or firewall): $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 8. Microsoft Defender service status
#    Queries the WinDefend service state only; service is not started/stopped.
# ---------------------------------------------------------------------------
Write-Host "`n--- 8. Microsoft Defender Service Status ---" -ForegroundColor Yellow
try {
    $svc = Get-Service -Name WinDefend -ErrorAction Stop
    [PSCustomObject]@{
        Name   = $svc.Name
        Status = $svc.Status
    } | Format-List
}
catch {
    Write-Warning "Could not query WinDefend service (it may not exist on this build): $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 9. How many users logged in
#    Uses the built-in 'query user' command to list active sessions; read-only.
# ---------------------------------------------------------------------------
Write-Host "`n--- 9. Logged-In Users ---" -ForegroundColor Yellow
try {
    $quserOutput = query user 2>$null
    if ($quserOutput) {
        $sessions = $quserOutput | Select-Object -Skip 1
        Write-Host "Logged-in session count: $($sessions.Count)"
        $quserOutput | Format-Table -Wrap
    }
    else {
        Write-Host "No interactive user sessions found (or 'query user' unavailable)."
    }
}
catch {
    Write-Warning "Could not enumerate logged-in users: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 10. When was the last Windows Update
#     Reads installed hotfix records via Get-HotFix, sorted by install date.
#     Read-only. See NOTES above re: accuracy caveat.
# ---------------------------------------------------------------------------
Write-Host "`n--- 10. Last Windows Update ---" -ForegroundColor Yellow
try {
    $lastUpdate = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($lastUpdate) {
        $lastUpdate | Select-Object HotFixID, Description, InstalledOn | Format-List
    }
    else {
        Write-Host "No hotfix records found."
    }
}
catch {
    Write-Warning "Could not read Windows Update history: $($_.Exception.Message)"
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " Report complete." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
