# Root Cause Analysis (RCA)

## Incident Title
Finance Team Cannot Access Shared Drives (\\corp.local\dfs\Finance)

## Incident Status
Resolved

## Incident Date
2026-08-07

## Resolution Time
11:45 AM (service restored and user-verified)

## Executive Summary
Starting at approximately 08:00, Finance team members reported "Access is denied" errors when opening or mapping the Finance shared drive (\\corp.local\dfs\Finance). Other departments, including HR, retained normal access to their equivalent shares. Investigation traced the issue to an overnight identity-governance access-recertification job that incorrectly revoked the nested security group SG-Finance-AllStaff from the share/NTFS permission group SG-FinanceShare-ReadWrite at 02:15. Because the recertification job used a stale owner-approval mapping, the removal was treated as "no response = revoke" rather than being escalated for manual review. Restoring the group nesting and forcing a Kerberos ticket refresh resolved access, and by 11:45 AM Finance users confirmed normal read/write access to the shared drive.

## Scope and Impact
- Affected environment: \\corp.local\dfs\Finance (DFS namespace target FS-FIN-01)
- Unaffected control: \\corp.local\dfs\HR (DFS namespace target FS-HR-01), using SG-HRShare-ReadWrite
- User impact: all Finance department users (approximately 85 accounts) authenticating via SG-Finance-AllStaff
- Symptom: "Access is denied" when browsing, mapping, or opening the Finance shared drive; existing mapped drives showed as disconnected/red X
- Business impact: Finance unable to access shared workbooks and month-end close documents; escalated as business-critical due to reporting deadline

## Change Context
- 02:15: Identity Governance access-recertification job ran against nested group SG-Finance-AllStaff
- 02:15: Job recorded no owner response for SG-Finance-AllStaff's nested membership in SG-FinanceShare-ReadWrite within the review window and auto-revoked the nesting (Security Event 4729 on DC01)
- No related change to NTFS permissions, share permissions, or DFS namespace configuration was made
- SG-HRShare-ReadWrite was not in scope for the same recertification cycle (different review date), which explains why HR was unaffected

## Supporting Evidence

### Affected Group Evidence (DC01 Security Log)
- 02:15:03 - Microsoft-Windows-Security-Auditing Event 4729
  - A member was removed from a security-enabled group
  - Group: SG-FinanceShare-ReadWrite
  - Member removed: SG-Finance-AllStaff
  - Subject: SVC-IdentityGovernance
- 02:15:04 - Event 4662 (directory service access) confirming the governance service account performed the write operation on the group object
- 08:04:12 - Event 4625 (logon failure reason: user not granted requested logon type is not applicable here) not present; instead, share access denials were captured as File Server Event 5145 "a network share object was checked: access denied" for multiple Finance users starting 08:00

### File Server Evidence (FS-FIN-01)
- 08:00:47 - Microsoft-Windows-Security-Auditing Event 5145
  - Share: \\FS-FIN-01\Finance
  - Relative target name: (root)
  - Access requested: ReadData
  - Access reason: denied, "-" (no matching allow ACE for presented token)
  - Account: FINBRIDGE\rthomas
- 08:02:33 - Event 5145 repeated for FINBRIDGE\jmartin, FINBRIDGE\dpatel, and 12 additional Finance accounts within 10 minutes
- Token inspection (klist on affected client) confirmed the Kerberos ticket for affected users no longer contained the SG-FinanceShare-ReadWrite SID after 02:15, consistent with the group nesting removal

### Unaffected Control Evidence (FS-HR-01)
- No Event 5145 denials logged for HR accounts in the same window
- HR user Kerberos tickets continued to present SG-HRShare-ReadWrite SID unchanged

### Evidence Conclusion
The sequence confirmed is: recertification job removes SG-Finance-AllStaff from SG-FinanceShare-ReadWrite (Event 4729) -> Finance users' Kerberos tickets no longer carry the required group SID -> share/NTFS access checks fail (Event 5145) at next logon or ticket renewal. HR, not in scope for the same recertification cycle, was unaffected.

## Detailed Timeline (All Times Local)
- 02:15 - Identity Governance job auto-revokes SG-Finance-AllStaff nesting in SG-FinanceShare-ReadWrite (Event 4729)
- 07:00-08:00 - Finance users begin authenticating for the day; new/renewed Kerberos tickets no longer include the required SID
- 08:00 onward - Finance users report "Access is denied" on shared drive; File Server Event 5145 denials logged
- 08:20 - Ticket escalated to L2 after multiple Finance users affected simultaneously
- 09:10 - Comparator check on HR share and SG-HRShare-ReadWrite confirms unaffected baseline
- 09:40 - Security log review on DC01 identifies Event 4729 at 02:15 as the triggering change
- 10:15 - Group nesting restored (SG-Finance-AllStaff re-added to SG-FinanceShare-ReadWrite)
- 10:20-11:30 - Affected users prompted to sign out/in or run klist purge to force new Kerberos ticket with correct group SID
- 11:45 - Incident resolved; Finance users confirmed read/write access restored

## Root Cause Statement
An identity-governance access-recertification job incorrectly treated a missing owner response as an implicit revoke action and removed the nested group SG-Finance-AllStaff from SG-FinanceShare-ReadWrite, which controls NTFS/share access to the Finance shared drive. This removed the required group SID from affected users' Kerberos tickets, causing access-denied failures for the entire Finance department until the nesting was restored and tickets were refreshed.

## 5 Whys Analysis
1. Why did Finance users see "Access is denied" on the shared drive?
- Because their Kerberos tickets no longer contained the SG-FinanceShare-ReadWrite group SID required by the share/NTFS ACL.

2. Why did their tickets no longer contain that SID?
- Because the nested group SG-Finance-AllStaff was removed from SG-FinanceShare-ReadWrite at 02:15 (Event 4729).

3. Why was the nested group removed?
- Because the identity-governance recertification job auto-revoked the nesting after recording no owner response within the review window.

4. Why did the job auto-revoke instead of escalating?
- Because the recertification workflow was configured with "no response = revoke" instead of "no response = escalate to backup approver," and the group owner record was stale (owner had left the business).

5. Why was the stale owner record not caught before the job ran?
- Because there is no pre-run validation step confirming group owners are current, active accounts before a recertification cycle executes changes.

## Hypothesis Elimination Summary
- DFS namespace/referral outage: weakened; DFS namespace and FS-FIN-01 target were reachable and responsive throughout.
- File server disk/service outage: weakened; no service outage or disk-space alerts on FS-FIN-01.
- NTFS/share permission change by an administrator: weakened; no manual ACL change logged on the share or folder.
- AD group membership change via governance automation: strongly supported by Event 4729 timing, affected/control group comparison, and Kerberos ticket SID evidence.
- Client-side profile or mapped-drive corruption: weakened; symptom was uniform and department-wide, not isolated to specific devices.

## Resolution Actions Applied
1. Containment
- Confirmed scope was limited to Finance accounts tied to SG-Finance-AllStaff; no wider AD impact identified.

2. Targeted Validation
- Confirmed Event 4729 timestamp and actor (SVC-IdentityGovernance) against the recertification job run log.
- Confirmed HR control group was unaffected and used as comparison baseline.

3. Corrective Action
- Restored SG-Finance-AllStaff as a member of SG-FinanceShare-ReadWrite.
- Directed affected users to sign out/in (or run a Kerberos ticket purge) to obtain a refreshed token containing the restored SID.

4. Service Verification
- By 11:45 AM, Finance users confirmed normal read/write access to the shared drive.
- No further access-denied reports after remediation.

## Recovery Verification Criteria (Met)
- SG-Finance-AllStaff confirmed present as a member of SG-FinanceShare-ReadWrite.
- Sampled Finance users' Kerberos tickets contain the SG-FinanceShare-ReadWrite SID after ticket refresh.
- Sampled Finance users can browse, read, and write to the Finance shared drive with no Event 5145 denials in a 30-minute post-fix window.
- Incident declared resolved at 11:45 AM.

## Preventive Actions

### Identity Governance Controls
1. Change recertification workflow default from "no response = revoke" to "no response = escalate to backup approver" for business-critical share access groups.
2. Add a pre-run validation step that flags recertification items where the listed owner account is disabled, left the business, or has no manager assigned, and pause automated action pending manual review.
3. Require dual sign-off for any automated revoke action affecting groups tagged "business-critical" (e.g., SG-FinanceShare-ReadWrite).

### Validation and Monitoring
1. Add alert correlation for Event 4729 on groups tagged "business-critical," notifying the identity/security team in real time.
2. Add a synthetic access check that validates a test account's ability to read the Finance and HR shares every 15 minutes, alerting on failure.
3. Add a change log entry requirement for any recertification job action that modifies group nesting for share-access groups.

### Operational Readiness
1. Maintain an up-to-date group-owner register with a quarterly owner-currency check independent of the recertification cycle.
2. Document a fast rollback procedure (group nesting restore + ticket refresh guidance) as a standing runbook for share-access incidents.
3. Run a post-incident tabletop exercise covering identity-governance-driven access loss scenarios.

## Owner and Follow-Up
- Incident owner: DWP Identity & Access Engineering
- Follow-up items:
  - Update recertification workflow default action and owner-validation logic
  - Add Event 4729 alerting for business-critical groups
  - Publish updated group-owner register and review cadence
