# DWP Triage Analysis: User Login Failure (cthompson)

Date: 2026-08-07
Method: Scope facts only (no additional telemetry)

## Scope Facts
- Symptom: user cthompson not able to login.
- Who: cthompson only (single-user impact).
- Since: approximately 08:40 this morning.
- Change: nil reported.

## Ranked Likely Causes (Most Probable First)

1. Account lockout or credential issue specific to cthompson
- Why this fits scope facts:
  - Single-user impact strongly points to user-specific identity/authentication failure rather than platform or pool-wide fault.
  - No reported change reduces likelihood of infrastructure regression and increases likelihood of normal auth-path issues (bad password, stale saved credential, lockout after retries).
- Single fastest check:
  - Check directory sign-in/identity logs for cthompson at and after ~08:40 for lockout, bad password, or invalid credential result.

2. Conditional Access / MFA challenge failure for cthompson
- Why this fits scope facts:
  - A login can fail for one user if MFA prompt approval, authenticator registration, device compliance, or policy condition is not met for that identity/session.
  - No environmental change and one-user scope align with user-context policy enforcement issues.
- Single fastest check:
  - Review cthompson sign-in trace at ~08:40 for policy decision details (MFA required/failed, CA block reason).

3. cthompson account state issue (disabled, expired password, expired account, risk block)
- Why this fits scope facts:
  - User-only failure with no broader impact is consistent with account status transitions or security controls applied to one identity.
  - Sudden onset at a specific time can match password expiry enforcement or security/risk action.
- Single fastest check:
  - Inspect cthompson account properties and security status for disabled/expired/blocked state.

4. User profile/session artifact problem tied to cthompson (stale/corrupt profile/session token)
- Why this fits scope facts:
  - Can affect only one user while others continue normally.
  - No change context still allows per-user profile/session corruption to appear suddenly.
- Single fastest check:
  - Attempt a fresh login path for cthompson (new session/client profile) and check host/session logs for profile load or session-init errors.

5. Licensing or entitlement assignment issue for cthompson
- Why this fits scope facts:
  - Missing or changed license/app assignment can block one user while others are unaffected.
  - No platform change plus single-user impact keeps entitlement drift plausible.
- Single fastest check:
  - Verify cthompson has required license/resource assignment and compare to a known-working peer user.

## Positioning Statement
Do not commit to one cause yet. Current weighting favors identity and policy path issues first because the impact is limited to one user and no infrastructure change is reported.

## Event Evidence Addendum (2026-08-07 08:44-09:12)

Source: Security Event Log on DESKTOP-FB022

- 08:44:01 - Security Event 4776 (Audit Failure)
  - FINBRIDGE\\cthompson credential validation failed.
  - Error code 0xC000006A (wrong password).
- 08:44:03 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
  - Logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:28 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
- 08:44:55 - Security Event 4625 (Audit Failure)
  - Failure reason: unknown user name or bad password.
- 08:44:56 - Security Event 4740 (Audit Failure)
  - FINBRIDGE\\cthompson account locked out.
  - Caller computer: DESKTOP-FB022.
- 08:45:10 - Security Event 4625 (Audit Failure)
  - Failure reason: account locked out.
  - Logon type 7 (unlock attempt), source DESKTOP-FB022.
- 08:45:44 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed.
  - Failure code 0x18 (wrong password).
  - Source IP 10.10.8.112.
- 08:46:01 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed (wrong password), source IP 10.10.8.112.
- 08:46:33 - Security Event 4771 (Audit Failure)
  - Kerberos pre-authentication failed (wrong password), source IP 10.10.8.112.

## Hypothesis Review Against Evidence

1. Account lockout or credential issue specific to cthompson
- Verdict: Support.
- Determining evidence:
  - Event 4776 at 08:44:01 (wrong password, 0xC000006A).
  - Event 4740 at 08:44:56 (account locked out).
  - Event 4625 at 08:45:10 (account locked out).

2. Conditional Access / MFA challenge failure for cthompson
- Verdict: Contradicts.
- Determining evidence:
  - Event 4776 at 08:44:01 and Event 4625 at 08:44:03/08:44:28/08:44:55 show credential failures before any successful authentication stage.

3. cthompson account state issue (disabled, expired password, expired account, risk block)
- Verdict: Support for lockout subtype; neutral for disabled/expired/risk subtypes.
- Determining evidence:
  - Event 4740 at 08:44:56 (account lockout confirmed).
  - Event 4625 at 08:45:10 (failure reason account locked out).

4. User profile/session artifact problem tied to cthompson (stale/corrupt profile/session token)
- Verdict: Contradicts.
- Determining evidence:
  - Event 4776 at 08:44:01 and Event 4771 at 08:45:44/08:46:01/08:46:33 indicate authentication failures prior to profile/session initialization.

5. Licensing or entitlement assignment issue for cthompson
- Verdict: Contradicts.
- Determining evidence:
  - Event 4776 at 08:44:01 (wrong password) and Event 4740 at 08:44:56 (lockout) show identity-path failure, not entitlement denial.

## Surviving Hypothesis

Account lockout caused by repeated bad credentials for FINBRIDGE\\cthompson, including continued wrong-password attempts from a second source (10.10.8.112), resulting in login failure.

## Resolution Steps Addendum

1. Contain lockout triggers
- Identify and isolate source 10.10.8.112 from further authentication attempts until credential source is remediated.
- Check for stale credentials in scheduled tasks, mapped resources, services, mail profiles, and saved credentials.

2. Restore access
- Unlock FINBRIDGE\\cthompson in Active Directory.
- Reset password to a temporary strong value and require password change at next sign-in.
- Perform first test sign-in from a known-clean endpoint.

3. Remove stale credentials
- Clear stored domain credentials on DESKTOP-FB022.
- Re-authenticate business apps and endpoints with the new password.
- Update/remove cached credentials on secondary devices tied to the user.

4. Validate resolution
- Confirm successful sign-in event sequence after unlock/reset.
- Confirm no new Event 4625, 4771, 4776, or 4740 entries for the user during observation window.
- Obtain user confirmation that interactive login is working.

5. Prevent recurrence
- Add standard lockout triage step to trace secondary source IP when lockout persists.
- Add quick event-correlation check between Event 4740 and recent Event 4771/4625 source systems.

## Additional Investigation Addendum

### Expanded Event Detail Interpretation
- 08:44:01 Event 4776 (0xC000006A) establishes initial bad-password credential validation failure for FINBRIDGE\\cthompson.
- 08:44:03, 08:44:28, and 08:44:55 Event 4625 (interactive logon type 2) show repeated local sign-in attempts failing with bad password from DESKTOP-FB022.
- 08:44:56 Event 4740 confirms transition from bad-password attempts to account lockout state.
- 08:45:10 Event 4625 (logon type 7) confirms post-lockout login failure due to lockout, not a new failure mode.
- 08:45:44, 08:46:01, and 08:46:33 Event 4771 (0x18 wrong password) from source IP 10.10.8.112 indicate continued incorrect credential attempts from a second source after lockout occurred.

### Surviving Hypothesis (Restated)
The evidence supports a user-specific credential failure sequence culminating in account lockout for FINBRIDGE\\cthompson, with ongoing bad-password retries from at least one additional source (10.10.8.112) sustaining login failure.

### Resolution Execution Detail
1. Stop all active bad-credential retries:
- Identify process/device mapped to 10.10.8.112 and suppress authentication attempts until credentials are corrected.
- Confirm DESKTOP-FB022 has no stale stored domain credentials continuing retries.

2. Recover account access:
- Unlock account and reset password.
- Enforce password change at next interactive sign-in.

3. Credential hygiene cleanup:
- Remove/update cached credentials across workstation and secondary clients.
- Re-authenticate domain-connected applications with the new credential.

4. Closure verification criteria:
- Successful user sign-in event present.
- No new Event 4740 lockout.
- No new Event 4776/4625/4771 wrong-password failures during observation window.
