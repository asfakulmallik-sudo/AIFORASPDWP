<#
.SYNOPSIS
     Collects and displays basic computer health information.

.DESCRIPTION
     Reports the computer name and installed memory, free space on drive C:,
     the five processes using the most working-set memory, recent System log
     errors, and the count of non-special user profiles unused for 90 days.
     This script reads information only and does not modify system settings.

.AUTHOR
     Original author not specified.

.HOW TO RUN
     Run from a PowerShell session:
     .\inherited.ps1

.NOTES
     Reading the System event log and user-profile information may require
     an elevated PowerShell session, depending on local permissions.
#>

# Get the computer system details, such as the device name and installed memory.
$computerSystem = Get-CimInstance Win32_ComputerSystem

# Get the number of free bytes available on the C: drive.
$freeSpaceBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Find the five running processes with the largest working-set memory usage.
$topMemoryProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Get the 10 newest System event log entries and keep only error-level events.
$recentSystemErrors = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Get local user profiles and start filtering for profiles that may be stale.
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
     # Keep non-special profiles that have not been used within the last 90 days.
     -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# Display a heading before the diagnostic report details.
Write-Host 'Computer Health Report'

# Display the computer name and total installed physical memory in bytes.
Write-Host $computerSystem.Name $computerSystem.TotalPhysicalMemory

# Convert free bytes to gigabytes, round to two decimal places, and display the result.
Write-Host ([math]::Round($freeSpaceBytes / 1GB, 2)) 'GB free'

# Display the name and working-set memory usage for each top memory-consuming process.
$topMemoryProcesses | ForEach-Object {
     # Display the current process name and working-set memory in bytes.
     Write-Host $_.Name $_.WS
}

# Display the time and message for each recent System event log error.
$recentSystemErrors | ForEach-Object {
     # Display the current event's timestamp and message.
     Write-Host $_.TimeCreated $_.Message
}

# Check whether any stale user profiles were found.
if ($staleUserProfiles.Count -gt 0) {
     # Display the number of stale user profiles when at least one exists.
     Write-Host 'Stale profiles:' $staleUserProfiles.Count
}