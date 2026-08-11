# Root Cause Analysis (RCA)

## Incident Title
Single-User Login Failure - FINBRIDGE\\cthompson

## Incident Status
Resolved

## Incident Date
2024-03-15

## Resolution Time
09:09 AM (access restored and user-verified)

## Executive Summary
From approximately 08:40 AM, user FINBRIDGE\\cthompson was unable to log in. Investigation showed repeated bad-password attempts, account lockout, and continued wrong-password Kerberos pre-authentication attempts from a second source IP. Corrective actions were applied to restore account access and stop credential retry conditions. At 09:09 AM, successful interactive login was recorded, and the user confirmed no further issue.

## Scope and Impact
- Affected identity: FINBRIDGE\\cthompson only.
- Affected endpoint in evidence: DESKTOP-FB022.
- Business impact: one user unable to perform login until resolution.

## Supporting Evidence

### Failure Evidence (08:44-08:46)
- 08:44:01 - Security Event 4776 (Audit Failure)
  - Credential validation failed for FINBRIDGE\\cthompson.
  - Error code: 0xC000006A (wrong password).
- 08:44:03 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
  - Logon type: 2 (Interactive), source: DESKTOP-FB022.
- 08:44:28 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
- 08:44:55 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
- 08:44:56 - Security Event 4740 (Audit Failure)
  - Account locked out: FINBRIDGE\\cthompson.
  - Caller computer: DESKTOP-FB022.
- 08:45:10 - Security Event 4625 (Audit Failure)
  - Failure reason: account locked out.
  - Logon type: 7 (Unlock attempt), source: DESKTOP-FB022.
- 08:45:44 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed.
  - Failure code: 0x18 (wrong password).
  - Source IP: 10.10.8.112.
- 08:46:01 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed, failure code 0x18, source IP 10.10.8.112.
- 08:46:33 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed, failure code 0x18, source IP 10.10.8.112.

### Recovery Evidence (09:08-09:09)
- 09:08:14 - Security Event 4722 (Audit Success)
  - User account enabled: FINBRIDGE\\cthompson.
  - Action performed by: FINBRIDGE\\helpdesk-admin.
- 09:09:01 - Security Event 4624 (Audit Success)
  - Successful interactive logon for FINBRIDGE\\cthompson.
  - Logon type: 2 (Interactive), source: DESKTOP-FB022.

## Evidence Conclusion
The event chain shows repeated wrong-password attempts leading to account lockout, then continued wrong-password pre-authentication attempts from an additional source. After account recovery action, successful interactive logon occurred and user access was restored.

## Detailed Timeline (Local Time)
- ~08:40 - User reports inability to log in.
- 08:44:01 - Event 4776 wrong password (0xC000006A).
- 08:44:03, 08:44:28, 08:44:55 - Event 4625 repeated interactive bad-password failures.
- 08:44:56 - Event 4740 account lockout recorded.
- 08:45:10 - Event 4625 shows account locked out.
- 08:45:44, 08:46:01, 08:46:33 - Event 4771 wrong-password Kerberos pre-auth failures from 10.10.8.112.
- 09:08:14 - Event 4722 account enabled by helpdesk-admin.
- 09:09:01 - Event 4624 successful interactive logon from DESKTOP-FB022.
- 09:09 - User verified working and no issues reported.

## Root Cause Statement
User login failure was caused by repeated bad credentials for FINBRIDGE\\cthompson, which triggered account lockout, with additional continued wrong-password attempts from source IP 10.10.8.112 sustaining the failure condition until account recovery and credential correction steps were applied.

## 5 Whys Analysis
1. Why could the user not log in?
- Because authentication attempts were failing and the account entered a locked state.

2. Why were authentication attempts failing?
- Because wrong passwords were repeatedly submitted, shown by Event 4776 and multiple Event 4625 entries.

3. Why did access remain blocked after initial failures?
- Because account lockout occurred (Event 4740), and post-lockout attempts continued to fail (Event 4625 lockout reason).

4. Why did wrong-password attempts continue after lockout?
- Because additional Kerberos pre-authentication failures continued from source IP 10.10.8.112 (Event 4771 with code 0x18).

5. Why was resolution only achieved after intervention?
- Because account state had to be recovered and credential retry sources had to be corrected before successful logon could occur, confirmed by Event 4722 followed by Event 4624.

## Resolution Actions Applied
1. Account recovery action was executed (account enabled by helpdesk-admin).
2. Credential-path remediation steps were applied to stop continued wrong-password retry conditions.
3. Successful interactive login was validated from DESKTOP-FB022.
4. User confirmed access was restored with no further issues.

## Verification of Recovery
- Event 4722 at 09:08:14 confirms account recovery action.
- Event 4624 at 09:09:01 confirms successful interactive logon.
- User confirmation at 09:09 confirms service restored.

## Preventive Actions
1. Add lockout triage runbook step to immediately correlate Event 4740 with preceding Event 4776/4625 and concurrent Event 4771 sources.
2. Add standard check for secondary source IP retry behavior when wrong-password failures persist.
3. Require credential cache review on primary workstation and any secondary clients whenever lockout events occur.
4. Capture a short post-recovery observation window to confirm no recurring Event 4776, 4625, 4771, or 4740 entries for the affected user.

## Ownership
- Incident owner: DWP Engineering
- Recovery operator in evidence: FINBRIDGE\\helpdesk-admin
