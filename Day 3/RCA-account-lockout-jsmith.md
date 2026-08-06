# Root Cause Analysis (RCA): User Account Lockout (jsmith)

## Incident Summary
- User: jsmith
- System: DESKTOP-FB001
- Incident window reviewed: 08:02:14 to 08:23:44 (30-minute sample provided)
- Symptom: User was locked out of their machine/account during logon and unlock attempts

## Event ID Reference: What Each Event Records

### Event ID 4625 (Audit Failure) - Failed Logon
Records a failed authentication attempt. It includes:
- Account name used in the attempt
- Failure reason (for example, bad password or account locked)
- Source workstation/computer making the attempt
- Logon type (how logon was attempted)

In this incident:
- Two 4625 events show "Unknown username or bad password" with Logon Type 2 (Interactive logon at console).
- One later 4625 shows "Account locked out" with Logon Type 7 (Unlock workstation).

### Event ID 4740 (Audit Failure) - Account Locked Out
Records when an account is locked due to lockout policy threshold being met (too many bad password attempts). It includes the account locked and caller/source computer.

In this incident:
- jsmith was locked out at 08:06:01.
- Lockout source/caller: DESKTOP-FB001.

### Event ID 4722 (Audit Success) - Account Enabled
Records that an account was enabled by an administrator or authorized operator.

In this incident:
- Account jsmith was enabled/unlocked at 08:22:10.
- Action performed by: FINBRIDGE\helpdesk-admin.

### Event ID 4624 (Audit Success) - Successful Logon
Records a successful authentication/logon.

In this incident:
- jsmith successfully logged on at 08:23:44 after administrative intervention.

## Reconstructed Sequence of Events (Plain English)
1. At 08:02:14, someone at DESKTOP-FB001 tried to sign in interactively as jsmith and entered incorrect credentials (bad password or wrong username format).
2. At 08:04:22, a second interactive sign-in attempt for jsmith from the same desktop failed for the same reason.
3. At 08:06:01, the account lockout threshold was reached, and jsmith was locked out (event 4740), with DESKTOP-FB001 identified as the source.
4. At 08:07:45, an attempt to unlock/sign in to the locked workstation using jsmith failed because the account was already locked (4625, Logon Type 7).
5. At 08:22:10, helpdesk-admin enabled/unlocked the account (4722).
6. At 08:23:44, jsmith successfully logged in (4624), confirming recovery.

## Most Likely Cause of Lockout
Most likely cause: repeated local interactive bad-password attempts on DESKTOP-FB001 triggered account lockout policy.

### Evidence from Events
- Multiple failed interactive logons (4625 at 08:02:14 and 08:04:22) from DESKTOP-FB001.
- Explicit lockout event (4740 at 08:06:01) naming DESKTOP-FB001 as caller.
- Subsequent unlock attempt failure (4625 at 08:07:45, Logon Type 7) with reason "Account locked out," showing the lockout state persisted.
- Administrative account enable/unlock (4722) followed by successful logon (4624), confirming lockout was the blocking condition.

## 5-Whys Analysis

### Problem Statement
User jsmith became locked out and could not unlock/login until helpdesk intervention.

1. Why was jsmith unable to access the machine?
- Because the account was locked (4625 with "Account locked out" and 4740 lockout event).

2. Why was the account locked?
- Because failed authentication attempts reached the configured lockout threshold (4740 follows repeated 4625 bad-password failures).

3. Why were there repeated failed authentication attempts?
- Because interactive sign-in attempts from DESKTOP-FB001 used invalid credentials for jsmith (4625 with "Unknown username or bad password," Logon Type 2).

4. Why were invalid credentials entered repeatedly?
- Most likely user error (mistyped password / stale remembered password) during console sign-in attempts. The dataset does not show evidence of remote service-driven attempts; all listed failures are local to DESKTOP-FB001 and interactive/unlock types.

5. Why did this lead to a user-impacting incident instead of self-recovery?
- Because account lockout policy correctly enforced security controls, but there was no immediate self-service unlock path for the user, requiring helpdesk-admin to re-enable/unlock account (4722).

## Root Cause
Primary root cause:
- Repeated invalid interactive credential entry for jsmith on DESKTOP-FB001 triggered domain/local account lockout policy.

Contributing factors:
- Lack of immediate self-service unlock/reset flow for locked users.
- Potential credential confusion (cached/old password or typing errors) at endpoint sign-in.

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
- Helpdesk re-enabled/unlocked the account (completed at 08:22:10).
- User successfully authenticated afterward (08:23:44).

### Preventive Actions
- User guidance:
  - Verify username format at sign-in (UPN vs SAM where applicable).
  - Use "show password" option before submit when available.
- Policy and monitoring:
  - Review lockout threshold and observation window for balance between security and usability.
  - Alert on clustered 4625 failures from a single endpoint before threshold is reached.
- Service desk readiness:
  - Provide a rapid unlock runbook and SLA for lockout events.
  - If environment supports it, enable secure self-service unlock/password reset.
- Endpoint checks:
  - Confirm no local scripts, scheduled tasks, or credential managers repeatedly replay old credentials on DESKTOP-FB001.

## Confidence and Limitations
- Confidence: High for immediate cause (bad password attempts leading to lockout), supported directly by 4625 and 4740 chronology.
- Limitation: The sample contains only six events. Additional security logs (preceding/following window, DC logs, and workstation credential provider logs) would improve attribution between user typo vs stale cached credentials vs automated process.

## Final Determination
The lockout was most likely caused by consecutive incorrect interactive sign-in attempts for jsmith at DESKTOP-FB001, which triggered lockout policy enforcement. Administrative account re-enable/unlock restored access, after which login succeeded.
