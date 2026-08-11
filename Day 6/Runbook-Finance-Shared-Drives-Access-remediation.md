# Runbook: Finance Team Cannot Access Shared Drives (AD Group Nesting Removal)

Title: Finance Shared Drive Access Loss Remediation Runbook
Version: 1.0
Date: 10/08/2026
Author: Sathishbabu
Reviewed: self
Status: draft
Change: initial version from RCA

## 1) Prerequisites

Complete every prerequisite before starting the procedure.

1. Confirm this is the same incident pattern.
Expected result: The ticket states Finance users get "Access is denied" on \\corp.local\dfs\Finance, and HR/other departments are unaffected.

2. Confirm you are working from an approved incident and change record.
Expected result: Incident ID and change ID are open and ready for timestamps and evidence.

3. Verify you have delegated permissions to modify membership of SG-FinanceShare-ReadWrite in Active Directory.
Expected result: You can add/remove members of the group in Active Directory Users and Computers (ADUC) or via PowerShell.

4. Verify you have Read access to the Security event log on the domain controller (DC01) holding the PDC emulator role.
Expected result: You can query Event ID 4729 and 4728 for the affected group.

5. Verify you have Read access to the Security event log on the file server FS-FIN-01.
Expected result: You can query Event ID 5145 for the Finance share.

6. Verify you have at least Reader access to the HR share configuration (FS-HR-01) for comparison.
Expected result: You can confirm HR remains unaffected as a control.

7. Sign in to a management workstation with RSAT / Active Directory PowerShell module installed.
Expected result: `Get-ADGroupMember` and `Add-ADGroupMember` cmdlets are available.

8. Confirm restart/ticket-refresh approval is not required (this fix does not require host reboots).
Expected result: No additional change approval is needed for the group-membership restore step.

9. Notify Service Desk and Finance stakeholders that remediation is starting.
Expected result: Stakeholders are aware some users may need to sign out/in once during remediation.

## 2) Procedure

Follow steps in order. Each step is one action.

1. Confirm current membership of SG-FinanceShare-ReadWrite.
Expected result: SG-Finance-AllStaff is absent from the member list, confirming the suspected cause.

```powershell
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName
```

2. [Elevated permissions required] Query the domain controller Security log for the removal event.
Expected result: Event ID 4729 is found showing SG-Finance-AllStaff removed from SG-FinanceShare-ReadWrite, with the actor and timestamp recorded.

```powershell
Get-WinEvent -ComputerName "DC01" -FilterHashtable @{LogName='Security'; Id=4729; StartTime=(Get-Date).AddHours(-24)} |
  Where-Object { $_.Message -match 'SG-FinanceShare-ReadWrite' } |
  Select-Object TimeCreated, Id, Message
```

3. Record the Event 4729 timestamp and actor (expected: SVC-IdentityGovernance) in the incident ticket.
Expected result: Ticket contains reproducible proof of the triggering change.

4. Check the file server Security log for corresponding access-denied events.
Expected result: Event ID 5145 entries confirm multiple Finance accounts denied access to the Finance share starting the same morning.

```powershell
Get-WinEvent -ComputerName "FS-FIN-01" -FilterHashtable @{LogName='Security'; Id=5145; StartTime=(Get-Date).AddHours(-6)} |
  Where-Object { $_.Message -match 'Finance' } |
  Select-Object -First 20 TimeCreated, Id, Message
```

5. Confirm HR share is unaffected as a control comparison.
Expected result: No matching Event 5145 denials for HR accounts against \\FS-HR-01\HR in the same window.

6. [Elevated permissions required] Restore SG-Finance-AllStaff as a member of SG-FinanceShare-ReadWrite.
Expected result: Command completes successfully with no errors.

```powershell
Add-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" -Members "SG-Finance-AllStaff"
```

7. Verify the membership restore.
Expected result: SG-Finance-AllStaff is listed as a member of SG-FinanceShare-ReadWrite.

```powershell
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName
```

8. Notify affected Finance users to sign out and sign back in, or to purge Kerberos tickets, to obtain a refreshed token containing the restored group SID.
Expected result: Users have a clear, simple instruction to refresh their access.

9. For any user who cannot sign out immediately, have them run a Kerberos ticket purge on their device.
Expected result: The client requests a new ticket including the restored SID on next authentication.

```powershell
klist purge
```

10. Run a controlled access test as one affected Finance user (or with the user on a call) against the Finance shared drive.
Expected result: The user can browse, open, and save a test file without an access-denied error.

11. Repeat step 10 for at least two additional affected Finance users in different teams within Finance.
Expected result: Consistent successful access confirms the fix is not isolated to one account.

12. Update the incident timeline with remediation start, group-restore completion time, and service restoration confirmation time.
Expected result: Incident record contains a complete operational timeline.

## 3) Verification

Complete all verification checks before closure.

1. Confirm SG-Finance-AllStaff membership in SG-FinanceShare-ReadWrite is present and stable.
Expected result: Command output lists SG-Finance-AllStaff as a current member.

```powershell
Get-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" | Select-Object Name, SamAccountName
```

2. Sample at least three affected users and confirm their Kerberos ticket contains the SG-FinanceShare-ReadWrite SID after refresh.
Expected result: `klist` output for each sampled user shows the restored group in the ticket's group list (or `whoami /groups` shows the group as present).

```powershell
whoami /groups | findstr "SG-FinanceShare-ReadWrite"
```

3. Query the file server Security log for the last 30 minutes.
Expected result: No new Event ID 5145 access-denied entries for the Finance share.

```powershell
Get-WinEvent -ComputerName "FS-FIN-01" -FilterHashtable @{LogName='Security'; Id=5145; StartTime=(Get-Date).AddMinutes(-30)} |
  Where-Object { $_.Message -match 'Finance' } |
  Select-Object TimeCreated, Id, Message
```

4. Confirm three fresh user logins/reconnects can read and write a test file on the Finance shared drive.
Expected result: All three tests succeed with no access-denied error.

5. Confirm the HR share and SG-HRShare-ReadWrite remain unchanged and unaffected.
Expected result: Control group membership and HR access are unchanged from baseline.

6. Add command output, Event 4729/5145 evidence, and successful user test results to the incident ticket.
Expected result: Closure evidence is complete and auditable.

7. Close the incident only after all verification steps pass.
Expected result: Incident is resolved with objective proof attached.

## 4) Rollback

Use this rollback only if restoring the group nesting causes an unexpected access issue (for example, unintended access granted to a sub-group that should not have Finance share access).

### Immediate containment (target: under 3 minutes)

1. Remove SG-Finance-AllStaff from SG-FinanceShare-ReadWrite to return to the prior (incident) state while the unexpected issue is investigated.
Expected result: Membership reverts to the state before remediation.

```powershell
Remove-ADGroupMember -Identity "SG-FinanceShare-ReadWrite" -Members "SG-Finance-AllStaff" -Confirm:$false
```

2. Notify Service Desk and Finance stakeholders that the fix has been paused pending investigation.
Expected result: Stakeholders are aware of the temporary reversal and expected next update time.

### Stabilization actions after containment

3. Identify the specific sub-group or account causing the unexpected access issue.
Expected result: You have a precise scope of the secondary problem before re-applying the fix.

```powershell
Get-ADGroupMember -Identity "SG-Finance-AllStaff" -Recursive | Select-Object Name, SamAccountName
```

4. If the issue is a single unwanted nested account or sub-group, remove only that nested object from SG-Finance-AllStaff rather than blocking the whole fix.
Expected result: The unwanted access path is closed while preserving the ability to restore the main fix.

5. Re-apply step 6 from the Procedure (restore SG-Finance-AllStaff to SG-FinanceShare-ReadWrite) once the secondary issue is resolved.
Expected result: Finance access is restored without the unintended side effect.

6. If the issue cannot be isolated quickly, escalate to DWP Identity & Access Engineering with the Event 4729 evidence, group membership snapshots, and description of the unexpected access observed.
Expected result: Engineering receives complete context for deeper investigation while Finance users remain informed of status.

## 5) Notes

- Elevated permissions are required to modify AD group membership and to query Security event logs on DC01 and FS-FIN-01.
- The signature for this incident is Event 4729 (member removed from SG-FinanceShare-ReadWrite) followed by Event 5145 (share access denied) for Finance accounts.
- A user's Kerberos ticket does not update automatically after a group membership change; the user must sign out/in or purge tickets to see the fix.
- SG-HRShare-ReadWrite and the HR share are the control comparison and should remain unchanged during incident handling.
- Related documents:
  - RCA-Finance-Shared-Drives-Access-final.md
  - KB-L1-Self-Service-Shared-Drive-Access.md
  - KB-L2L3-Finance-Shared-Drives-Diagnosis-and-Remediation.md
