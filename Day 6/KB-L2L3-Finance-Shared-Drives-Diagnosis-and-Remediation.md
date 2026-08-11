# KB: Finance Team Cannot Access Shared Drives (L2/L3)

Version: v1.0
Date: 10/08/2026
Status: Draft

## Background
The Finance team accesses shared files via the DFS namespace path \\corp.local\dfs\Finance, targeting the file server FS-FIN-01. Access is controlled by NTFS/share permissions granted to the security group SG-FinanceShare-ReadWrite, which normally contains the nested group SG-Finance-AllStaff. This service is business-critical, particularly around month-end close, and any department-wide loss of access causes immediate escalation.

## Symptom
### What users report
- "I get 'Access is denied' when I try to open the Finance drive."
- "My mapped drive shows a red X."
- "It was working yesterday, now the whole team can't get in."

### What the engineer observes
- Impact is concentrated across the entire Finance department, not isolated devices.
- Other departments (for example HR) retain normal access to their equivalent share.
- File server Security log shows repeated Event ID 5145 (share access denied) for Finance accounts starting the same morning.
- Domain controller Security log shows an Event ID 4729 (group member removed) against SG-FinanceShare-ReadWrite overnight.

## Root Cause
An identity-governance access-recertification job auto-revoked the nested group SG-Finance-AllStaff from SG-FinanceShare-ReadWrite after recording no owner response within the review window ("no response = revoke"). This removed the group SID from affected users' Kerberos tickets, causing share/NTFS access checks to fail for the whole Finance department until the nesting was restored and tickets were refreshed.

### Evidence that confirms root cause
- Domain controller (DC01) Security log:
  - Event ID 4729 at 02:15: member SG-Finance-AllStaff removed from group SG-FinanceShare-ReadWrite, actor SVC-IdentityGovernance
- File server (FS-FIN-01) Security log:
  - Event ID 5145 starting 08:00: share access denied for multiple FINBRIDGE Finance accounts against \\FS-FIN-01\Finance
- Control comparison:
  - HR share (\\FS-HR-01\HR) and SG-HRShare-ReadWrite showed no matching Event 4729/5145 pattern in the same window

## Detection
Run these steps before remediation. Use the PowerShell path first to confirm in under 3 minutes.

1. Identify the affected group (SG-FinanceShare-ReadWrite) and the expected nested member (SG-Finance-AllStaff).
Expected result: You have the exact group names ready for verification.

2. Open Windows PowerShell as admin from a management workstation with the Active Directory module and remote event log access.
Expected result: You can run `Get-ADGroupMember` and `Get-WinEvent` against DC01 and FS-FIN-01.

3. Run the following commands exactly.
Expected result: Output confirms the missing nested group, the triggering Event 4729, and the resulting Event 5145 denials.

```powershell
$dc = "DC01"
$fileServer = "FS-FIN-01"
$since = (Get-Date).AddHours(-24)

# Confirm current membership is missing the expected nested group
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName

# Domain controller: confirm removal event for the group
Get-WinEvent -ComputerName $dc -FilterHashtable @{LogName='Security'; Id=4729; StartTime=$since} |
  Where-Object { $_.Message -match 'SG-FinanceShare-ReadWrite' } |
  Select-Object -First 5 TimeCreated, Id, Message

# File server: confirm access-denied events for the Finance share
Get-WinEvent -ComputerName $fileServer -FilterHashtable @{LogName='Security'; Id=5145; StartTime=$since} |
  Where-Object { $_.Message -match 'Finance' } |
  Select-Object -First 20 TimeCreated, Id, Message

# Control comparison: HR share should show no matching denial pattern
Get-WinEvent -ComputerName "FS-HR-01" -FilterHashtable @{LogName='Security'; Id=5145; StartTime=$since} |
  Where-Object { $_.Message -match 'HR' } |
  Select-Object -First 5 TimeCreated, Id, Message
```

4. If command access is unavailable, use Event Viewer with exact log locations below.
Expected result: Manual checks produce the same conclusion.

5. On DC01, open Event Viewer > Windows Logs > Security and filter Event ID 4729 for Last 24 hours.
Expected result: An entry shows SG-Finance-AllStaff removed from SG-FinanceShare-ReadWrite, with actor SVC-IdentityGovernance.

6. On FS-FIN-01, open Event Viewer > Windows Logs > Security and filter Event ID 5145 for Last 24 hours.
Expected result: Multiple entries show access denied against the Finance share for FINBRIDGE Finance accounts, starting around the time users began reporting the issue.

7. On FS-HR-01, open Event Viewer > Windows Logs > Security and filter Event ID 5145 for Last 24 hours.
Expected result: No matching denial pattern exists for the HR share in the same window.

8. Confirm this incident type only if all conditions are true.
Expected result: High-confidence diagnosis before action.

- SG-FinanceShare-ReadWrite is missing SG-Finance-AllStaff as a member.
- DC01 Security log has Event ID 4729 for this removal within the last 24 hours.
- FS-FIN-01 Security log has Event ID 5145 denials for Finance accounts correlating with the user reports.
- The HR (or another department) control share shows no matching denial pattern in the same window.

## Resolution
Restore the nested group membership, then have affected users refresh their Kerberos ticket.

1. Restore SG-Finance-AllStaff as a member of SG-FinanceShare-ReadWrite.
Expected result: Command completes successfully with no errors.

```powershell
Add-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" -Members "SG-Finance-AllStaff"
```

2. Confirm the membership restore.
Expected result: SG-Finance-AllStaff appears in the member list.

```powershell
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName
```

3. Direct affected users to sign out and sign back in (or reconnect their remote/VPN session) to force a refreshed Kerberos ticket.
Expected result: Users obtain a new ticket containing the restored SG-FinanceShare-ReadWrite SID.

4. For users who cannot sign out immediately, have them purge Kerberos tickets locally.
Expected result: The next authentication request generates a new ticket including the restored SID.

```powershell
klist purge
```

5. Confirm ticket refresh for a sampled user.
Expected result: The group appears in the user's current token.

```powershell
whoami /groups | findstr "SG-FinanceShare-ReadWrite"
```

6. Run a controlled access test as one affected Finance user against the shared drive (browse, open, and save a test file).
Expected result: Access succeeds with no denial.

7. Repeat the access test for at least two more affected Finance users in different teams.
Expected result: Consistent successful access confirms the fix is department-wide, not account-specific.

## Verification
1. Confirm SG-Finance-AllStaff membership in SG-FinanceShare-ReadWrite is present and stable.
Expected result: Command output lists SG-Finance-AllStaff as a current member.

```powershell
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName
```

2. Query the file server Security log for the last 30 minutes.
Expected result: No new Event ID 5145 access-denied entries for the Finance share.

```powershell
Get-WinEvent -ComputerName "FS-FIN-01" -FilterHashtable @{LogName='Security'; Id=5145; StartTime=(Get-Date).AddMinutes(-30)} |
  Where-Object { $_.Message -match 'Finance' } |
  Select-Object TimeCreated, Id, Message
```

3. Confirm at least three fresh user sessions can read and write a test file on the Finance shared drive with no access-denied error.
Expected result: All three tests succeed.

4. Confirm the HR share and SG-HRShare-ReadWrite control group remain unchanged from baseline.
Expected result: No unintended changes were introduced by the fix.

5. Add command output, Event 4729/5145 evidence, and successful user test results to the incident ticket.
Expected result: Closure evidence is complete and auditable.

## Rollback
Trigger rollback only if restoring the nesting causes an unexpected access issue (for example, unintended access reaching a sub-group that should not have Finance share access).

### Immediate containment (target: under 3 minutes)
1. Remove SG-Finance-AllStaff from SG-FinanceShare-ReadWrite to return to the prior state while the unexpected issue is investigated.
Expected result: Membership reverts to the pre-remediation state.

```powershell
Remove-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" -Members "SG-Finance-AllStaff" -Confirm:$false
```

2. Notify Service Desk and Finance stakeholders that the fix has been paused pending investigation.
Expected result: Stakeholders are aware of the temporary reversal and next update time.

### Recovery rollback
3. Identify the specific sub-group or account causing the unexpected access issue.
Expected result: You have a precise scope of the secondary problem before re-applying the fix.

```powershell
Get-ADGroupMember -Identity "SG-Finance-AllStaff" -Recursive | Select-Object Name, SamAccountName
```

4. Remove only the specific nested object causing the unwanted access, rather than blocking the entire fix.
Expected result: The unwanted access path is closed while preserving the ability to restore the main fix.

5. Re-apply the group nesting restore (`Add-ADGroupMember`) once the secondary issue is resolved.
Expected result: Finance access is restored without the unintended side effect.

6. If the issue cannot be isolated quickly, escalate to DWP Identity & Access Engineering with the Event 4729 evidence, group membership snapshots, and a description of the unexpected access observed.
Expected result: Engineering receives complete context for deeper investigation while Finance users remain informed of status.

## Preventive
Implement these process/tooling controls to prevent recurrence.

1. Change the identity-governance recertification workflow default from "no response = revoke" to "no response = escalate to backup approver" for groups tagged "business-critical."

2. Add a pre-run validation step in the recertification job that flags reviews where the listed group owner is disabled, has left the business, or has no manager assigned, and pauses automated action pending manual review.

3. Add an Azure Monitor / SIEM alert rule:
- Signal: Security Event ID 4729 on groups tagged "business-critical" (for example SG-FinanceShare-ReadWrite)
- Action: notify Identity & Access Engineering in real time and log to the incident channel.

4. Add a synthetic access check that validates a test account's ability to read the Finance and HR shares every 15 minutes, alerting on failure.

5. Maintain an up-to-date group-owner register with a quarterly owner-currency check independent of the recertification cycle, so stale owners are caught before a recertification job acts on them.

## Related
- `Day 6/RCA-Finance-Shared-Drives-Access-final.md`
- `Day 6/Runbook-Finance-Shared-Drives-Access-remediation.md`
- `Day 6/KB-L1-Self-Service-Shared-Drive-Access.md`
