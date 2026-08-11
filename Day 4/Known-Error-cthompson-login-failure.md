Symptom: FINBRIDGE\cthompson could not log in from approximately 08:40, with repeated failed interactive sign-in attempts. The user experience was login failure until account recovery was completed.

Cause: Repeated wrong-password authentication attempts triggered account lockout for FINBRIDGE\cthompson. Continued wrong-password Kerberos pre-authentication attempts from source IP 10.10.8.112 sustained the failure condition until remediation.

Scope: The impact was limited to one user account, FINBRIDGE\cthompson. Evidence in the incident log references DESKTOP-FB022 as the interactive source endpoint.

Workaround: Restore account access by applying account recovery action and then validating interactive sign-in from DESKTOP-FB022. The issue was resolved when recovery actions were applied and a successful login was recorded.

Permanent fix: Correct the credential retry condition and complete credential hygiene so stale or incorrect stored credentials are removed and re-authenticated. The RCA preventive controls require lockout-source correlation and post-recovery observation to prevent recurrence.

How to spot it: Look for Event 4776 with error 0xC000006A (wrong password), Event 4625 with bad-password/locked-out reasons, Event 4740 account lockout, and Event 4771 with failure code 0x18 from retry sources such as 10.10.8.112. Confirm recovery with Event 4722 (account enabled) followed by Event 4624 successful interactive logon.
