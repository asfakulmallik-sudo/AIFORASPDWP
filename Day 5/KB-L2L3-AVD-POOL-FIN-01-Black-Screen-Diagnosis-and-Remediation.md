# KB: AVD POOL-FIN-01 Black Screen Post Login (L2/L3)

Version: v1.0  
Date: 2026-08-07  
Status: Draft

## Background
POOL-FIN-01 and POOL-FIN-02 deliver Azure Virtual Desktop access for finance users. This service is business-critical because users depend on it for line-of-business apps at start of day. A black-screen condition after login causes immediate productivity loss, repeated reconnect attempts, and increased Service Desk load. Fast diagnosis is required to separate user-side issues from platform-side rendering failures.

## Symptom
### What users report
- "I can log in but only see a black screen."
- "Sometimes it comes back after about 30 seconds."
- "Sometimes I get disconnected and have to reconnect."

### What the engineer observes
- Concentrated impact in POOL-FIN-01, with POOL-FIN-02 stable.
- Login success events occur, then desktop rendering fails and/or sessions disconnect.
- Repeating event pattern on affected hosts during the same timeframe.

## Root Cause
A graphics stack regression introduced by the overnight 02:00 update to POOL-FIN-01 caused `dwm.exe` to fault in `igdumd64.dll` (exception `0xc0000005`). This created a loop of successful logon followed by rendering failure/disconnect.

### Evidence that confirms root cause
- Affected host (example SHFIN-01-A):
  - Event ID 21 (logon success)
  - Event ID 1000 (Application Error: faulting app `dwm.exe`, module `igdumd64.dll`, exception `0xc0000005`)
  - Event ID 9009 (Desktop Window Manager exit, exit code `0x40010004`)
  - Event ID 40 (session disconnect)
- Control host (example SHFIN-02-A):
  - Event ID 21 present
  - Event ID 9011 (Desktop Window Manager started)
  - No matching Event ID 1000 for `dwm.exe`/`igdumd64.dll` in the same window

## Detection
Run these steps before remediation. Use the PowerShell path first to confirm in under 3 minutes.

1. Identify one affected host in POOL-FIN-01 and one control host in POOL-FIN-02.
Expected result: You have host names ready (example: SHFIN-01-A affected, SHFIN-02-A control).

2. Open Windows PowerShell as admin from a management jump box with remote event log access.
Expected result: You can query both hosts with `Get-WinEvent`.

3. Run the following commands exactly.
Expected result: Output shows affected-host crash signatures and control-host healthy baseline.

```powershell
$affected = "SHFIN-01-A"
$control  = "SHFIN-02-A"
$since = (Get-Date).AddHours(-4)

# Affected host: Application log, Event ID 1000, confirm dwm.exe + igdumd64.dll
Get-WinEvent -ComputerName $affected -FilterHashtable @{
  LogName='Application'; Id=1000; StartTime=$since
} | Where-Object {
  $_.Message -match 'Faulting application name:\s*dwm.exe' -and
  $_.Message -match 'Faulting module name:\s*igdumd64.dll'
} | Select-Object -First 5 TimeCreated, Id, ProviderName, Message

# Affected host: DWM Operational log, Event ID 9009
Get-WinEvent -ComputerName $affected -FilterHashtable @{
  LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9009; StartTime=$since
} | Select-Object -First 5 TimeCreated, Id, Message

# Affected host: LocalSessionManager Operational log, Event IDs 21 and 40
Get-WinEvent -ComputerName $affected -FilterHashtable @{
  LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; Id=21,40; StartTime=$since
} | Select-Object -First 20 TimeCreated, Id, Message

# Control host baseline: DWM Operational Event ID 9011 should exist
Get-WinEvent -ComputerName $control -FilterHashtable @{
  LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9011; StartTime=$since
} | Select-Object -First 5 TimeCreated, Id, Message

# Control host should not show affected crash signature in Application Event ID 1000
Get-WinEvent -ComputerName $control -FilterHashtable @{
  LogName='Application'; Id=1000; StartTime=$since
} | Where-Object {
  $_.Message -match 'Faulting application name:\s*dwm.exe' -and
  $_.Message -match 'Faulting module name:\s*igdumd64.dll'
} | Select-Object -First 5 TimeCreated, Id, ProviderName, Message
```

4. If command access is unavailable, use Event Viewer with exact log locations below.
Expected result: Manual checks produce the same conclusion.

5. On affected host, open Event Viewer > Windows Logs > Application.
Expected result: Application log is open.

6. In Application log, filter Event ID 1000 for Last 4 hours and open newest matching event.
Expected result: Field values show faulting app `dwm.exe`, faulting module `igdumd64.dll`, exception `0xc0000005`.

7. On affected host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational and filter Event ID 9009 for Last 4 hours.
Expected result: Event 9009 exists in the same incident window.

8. On affected host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > TerminalServices-LocalSessionManager > Operational and filter Event IDs 21,40 for Last 4 hours.
Expected result: Repeated sequence Event 21 then Event 40 is present for impacted users.

9. On control host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational and filter Event ID 9011 for Last 4 hours.
Expected result: Event 9011 (DWM started) is present and acts as healthy baseline.

10. On control host, open Event Viewer > Windows Logs > Application and filter Event ID 1000 for Last 4 hours.
Expected result: No matching `dwm.exe` + `igdumd64.dll` crash pattern is present.

11. Confirm this incident type only if all conditions are true.
Expected result: High-confidence diagnosis before action.

- Affected host has Application log Event ID 1000 with `dwm.exe` and `igdumd64.dll`.
- Affected host has DWM Operational Event ID 9009 in same time window.
- Affected host has LocalSessionManager Event 21 followed by Event 40 pattern.
- Control host in POOL-FIN-02 shows DWM Operational Event ID 9011 baseline and no matching Application Event ID 1000 crash signature.

## Resolution
Use one affected host at a time. Follow command path first, then confirm in portal.

1. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts and copy the exact `Session host` value and VM name.
Expected result: You have exact target names for command execution.

2. Open PowerShell and load Azure context.
Expected result: You can run AVD and VM commands in the correct subscription.

```powershell
$subId = "<subscription-id>"
$rg = "<resource-group-containing-POOL-FIN-01>"
$hostPool = "POOL-FIN-01"
$sessionHost = "SHFIN-01-A.domain.local"
$vmName = "SHFIN-01-A"

Connect-AzAccount
Set-AzContext -SubscriptionId $subId
```

3. Set drain mode on the target host.
Expected result: `Allow new sessions` becomes `No` for the target host.

```powershell
Update-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hostPool -Name $sessionHost -AllowNewSession:$false
```

4. Confirm in portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > target host > Properties that option `Allow new sessions` shows `No`.
Expected result: New user placement to target host is blocked.

5. Notify and sign out active users on target host via command path.
Expected result: Target host has zero active sessions.

```powershell
$sessions = Get-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hostPool | Where-Object { $_.SessionHostName -eq $sessionHost }
foreach ($s in $sessions) {
  Send-AzWvdUserSessionMessage -ResourceGroupName $rg -HostPoolName $hostPool -SessionHostName $sessionHost -UserSessionId $s.Name.Split('/')[-1] -MessageTitle "AVD maintenance" -MessageBody "Please save your work. You will be signed out."
  Remove-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hostPool -SessionHostName $sessionHost -Id $s.Name.Split('/')[-1] -Force
}
```

6. Open Azure Portal path Virtual machines > SHFIN-01-A > Connect and run the approved DWP graphics-path remediation package in admin session.
Expected result: Remediation package completes successfully.

7. Restart the VM.
Expected result: VM reboots and returns online.

```powershell
Restart-AzVM -ResourceGroupName $rg -Name $vmName
```

8. Confirm host health in portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts and verify options `Status = Available` and `Agent status = Available` on target host.
Expected result: Host is healthy and registered.

9. Re-enable target host session acceptance.
Expected result: `Allow new sessions` returns to `Yes`.

```powershell
Update-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hostPool -Name $sessionHost -AllowNewSession:$true
```

10. Repeat steps 1 to 9 for each affected host listed under Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Expected result: All affected hosts are remediated and back in rotation.

## Verification
1. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Expected result: For each remediated host, options show `Status = Available`, `Agent status = Available`, `Allow new sessions = Yes`.

2. Run quick host-state command.
Expected result: Every remediated host returns healthy state in output.

```powershell
Get-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hostPool |
  Select-Object Name,Status,AllowNewSession,AgentVersion
```

3. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions and verify three fresh user logins are distributed across remediated hosts.
Expected result: Three successful sessions without black screen or immediate disconnect.

4. Run 30-minute crash-signature checks on remediated host(s).
Expected result: No new `dwm.exe` + `igdumd64.dll` Event 1000, no Event 9009 spike, and no repeating 21->40 sequence.

```powershell
$since = (Get-Date).AddMinutes(-30)
$checkHost = "SHFIN-01-A"

Get-WinEvent -ComputerName $checkHost -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$since} |
  Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } |
  Select-Object TimeCreated,Id,Message

Get-WinEvent -ComputerName $checkHost -FilterHashtable @{LogName='Microsoft-Windows-Desktop Window Manager/Operational'; Id=9009; StartTime=$since} |
  Select-Object TimeCreated,Id,Message

Get-WinEvent -ComputerName $checkHost -FilterHashtable @{LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; Id=21,40; StartTime=$since} |
  Select-Object TimeCreated,Id,Message
```

5. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts and confirm control baseline remains healthy.
Expected result: POOL-FIN-02 hosts remain stable and unaffected.

## Rollback
Trigger rollback immediately if black-screen rate or disconnect loop increases after remediation.

### Immediate containment (target: under 3 minutes)
1. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > failing host > Properties and set `Allow new sessions = No`, then click Save.
Expected result: New sessions stop landing on failing host.

2. Execute emergency sign-out command path.
Expected result: All active sessions are removed from failing host quickly.

```powershell
$failHost = "SHFIN-01-A.domain.local"
Update-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hostPool -Name $failHost -AllowNewSession:$false
$badSessions = Get-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hostPool | Where-Object { $_.SessionHostName -eq $failHost }
foreach ($s in $badSessions) {
  Remove-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hostPool -SessionHostName $failHost -Id $s.Name.Split('/')[-1] -Force
}
```

3. Open Azure Portal path Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts and verify at least one host has options `Status = Available` and `Allow new sessions = Yes`.
Expected result: Immediate healthy capacity exists for reconnect.

### Recovery rollback
4. Open Azure Portal path Virtual machines > failing VM > Overview and note `Resource group`, `Image`, `OS disk`, and `Boot diagnostics` time.
Expected result: Recovery context and baseline are documented.

5. Run quick platform redeploy.
Expected result: Host is re-provisioned on new hardware without changing image version.

```powershell
Redeploy-AzVM -ResourceGroupName $rg -Name $vmName
```

6. If fault persists, rebuild from known-good image using portal path Virtual machines > Create > Image and select the exact pre-incident gallery image version.
Expected result: Host image is rolled back to known-good build.

7. Register rebuilt host back to POOL-FIN-01 with portal path Azure Virtual Desktop > Host pools > POOL-FIN-01 > Registration key > Generate new key, then run registration command on rebuilt VM.
Expected result: Rebuilt host appears under Session hosts for POOL-FIN-01.

8. Keep rebuilt host option `Allow new sessions = No` in Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > host > Properties, and run one admin and one user validation login.
Expected result: Host validates clean before user exposure.

9. Re-enable host option `Allow new sessions = Yes` only if both validations pass.
Expected result: Host safely re-enters rotation.

10. If validation fails, keep `Allow new sessions = No`, remove host from active rotation, and route users to POOL-FIN-02.
Expected result: Unstable host remains isolated while service continues.

## Preventive
Implement these process/tooling controls to prevent recurrence.

1. Add release gate in image pipeline: block promotion if synthetic AVD login test detects any Event ID 1000 with `dwm.exe` + `igdumd64.dll` within 15 minutes post-boot.

2. Add automated post-deploy canary policy: first rollout to one-host canary ring in POOL-FIN-01; require 30-minute soak with zero Event IDs 1000/9009 spikes before wider rollout.

3. Add Azure Monitor + Log Analytics alert rule:
- Signal A: Windows Application Event ID 1000 where faulting app = `dwm.exe` and module = `igdumd64.dll`
- Signal B: Desktop Window Manager Operational Event ID 9009 rate above baseline
- Signal C: TerminalServices LocalSessionManager Event ID 40 spike within 1 minute of Event ID 21
- Action: auto-open incident + notify DWP Engineering channel + pause deployment stage.

4. Add driver-change control in release checklist: mandatory diff of graphics component versions versus last known-good release; require explicit sign-off from DWP engineering approver.

5. Add one-click rollback automation runbook in Azure Automation that executes:
- set Allow new sessions = Off
- sign out sessions on selected host
- place host in quarantine tag
- notify Service Desk template message
This removes manual delay during incident containment.

## Related
- `Day 5/Runbook-POOL-FIN-01-blackscreen-remediation.md`
- `Day 5/KB-L1-Self-Service-Black-Screen-After-Sign-In.md`
- `Day 4/Known-Error-POOL-FIN-01-blackscreen.md`
- `Day 4/Triage-POOL-FIN-01-blackscreen-ranked-causes.md`
- `Day 4/Closure-POOL-FIN-01-blackscreen.md`
- `Day 4/Comms-POOL-FIN-01-incident-resolution.md`
- `Day 4/RCA-AVD-POOL-FIN-01-blackscreen-final.md`
