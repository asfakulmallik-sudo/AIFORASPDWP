Symptom: Users on POOL-FIN-01 see a black or blank screen after login. For some users it clears after about 30 seconds; for others the session disconnects or remains unusable.

Cause: A graphics stack regression introduced by the updated POOL-FIN-01 image caused Desktop Window Manager (dwm.exe) to crash in Intel graphics module igdumd64.dll. This crash pattern produced the black-screen and disconnect behavior.

Scope: Approximately 40% of users on POOL-FIN-01 were affected between about 07:00 and 10:00. POOL-FIN-02 was unaffected and was not updated.

Workaround: Immediately limit exposure on affected POOL-FIN-01 hosts and route users to unaffected capacity (POOL-FIN-02) while remediation is applied. Continue service using healthy hosts until stable login behavior is verified.

Permanent fix: Apply the recommended graphics-path remediation for the updated POOL-FIN-01 image/host path and restore stable logons. Longer term, enforce canary-first image rollout with rollback triggers and graphics-driver validation gates.

How to spot it: Look for the sequence of Event 21 logon success followed by Application Error Event 1000 for dwm.exe faulting in igdumd64.dll (exception 0xc0000005), then DWM Event 9009 and/or Session disconnect Event 40. On unaffected hosts, DWM Event 9011 appears with no matching Event 1000 in the same window.
