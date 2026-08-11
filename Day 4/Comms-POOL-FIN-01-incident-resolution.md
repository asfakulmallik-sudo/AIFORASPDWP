# Incident Communication Pack - POOL-FIN-01 Black Screen

## Audience 1 - Non-Technical Executive
Your access is restored and your data is safe. From about 7:00 AM to 10:00 AM, around 40% of users on POOL-FIN-01 saw a blank screen after sign-in; POOL-FIN-02 was not affected. The issue followed a 2:00 AM update applied only to POOL-FIN-01. We applied the fix, and by 10:00 AM logins were verified as normal with no further reports. No action is needed unless the issue returns.

## Audience 2 - Affected End-User Team (10 People)
Your access is restored and your data is safe. Between about 7:00 AM and 10:00 AM, a 2:00 AM update applied only to POOL-FIN-01 caused a blank screen after sign-in for about 40% of POOL-FIN-01 users, while POOL-FIN-02 stayed unaffected; we fixed it and by 10:00 AM logins were verified as normal with no further reports. If you see this again, sign out and sign in once; if it continues, contact the DWWP Service Desk.

## Audience 3 - Engineer-to-Engineer Internal Note
Access is restored and user data remained safe; issue was display-path only.

Fact set (same incident facts):
- Incident window: approximately 07:00 to 10:00 local.
- Impact: approximately 40% of users in POOL-FIN-01.
- Control pool: POOL-FIN-02 unaffected.
- Change correlation: 02:00 overnight image update was applied only to POOL-FIN-01; POOL-FIN-02 was not updated.
- Root cause: graphics stack regression in updated FIN-01 image, with DWM crash path (dwm.exe faulting in igdumd64.dll), leading to black screen/disconnect behavior.
- Exact action taken: applied the recommended graphics-path remediation for the updated POOL-FIN-01 image/host path, after targeted validation of the crash sequence.
- Verification step: by 10:00 AM, users were verified logging into POOL-FIN-01 hosts successfully, with no further issue reports.

Config detail to retain for recurrence handling:
- Fault signature observed during incident: Application Error Event 1000 (dwm.exe -> igdumd64.dll), plus DWM exit/disconnect sequence on affected host(s).
- Comparator in unaffected pool showed normal DWM startup and no matching app crash events in the same window.

Preventive action needed (carry forward from RCA):
1. Canary-first image rollout with explicit hold points.
2. Automated rollback trigger on DWM crash pattern post-deploy.
3. Pre-release graphics driver inventory diff against last known-good image.
4. Mandatory sign-off for graphics driver changes.
5. Synthetic login/reconnect render-readiness checks (not auth-only).
6. Alert correlation for Event 1000 (dwm.exe/igdumd64.dll), Event 9009 spikes, and Event 40 spikes after Event 21.
