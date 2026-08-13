# Root Cause Analysis (RCA): Print Spooler Service Recurring Crash and Restart Failure

## Incident Summary
- Service affected: Print Spooler (Spooler)
- Source: Service Control Manager
- Incident window reviewed: 2024-03-15 10:01:14 to 10:03:50 (approx. 2 minutes 36 seconds)
- Symptom: Print Spooler service crashed repeatedly, triggering automatic recovery, then failed to restart and remained down

## Event ID Reference: What Each Event Records

### Event ID 7034 (Error, Source: Service Control Manager) - Service Terminated Unexpectedly
Records that a service process stopped without being told to do so (i.e., it crashed rather than being stopped cleanly). It includes:
- The name of the service that crashed
- A running count of how many times this same service has crashed ("It has done this N time(s)")

In this incident:
- Logged three times at 10:01:14, 10:01:45, and 10:02:16, showing occurrence counts 1, 2, and 3.
- The roughly 30-second gap between each occurrence is consistent with Service Control Manager (SCM) automatically restarting the service after each crash, per its configured recovery options, only for the service to crash again almost immediately.

### Event ID 7031 (Error, Source: Service Control Manager) - Service Terminated, Corrective Action Scheduled
Records the same "terminated unexpectedly" condition as 7034, but is used when SCM's recovery configuration has a corrective action defined and about to be taken. It includes:
- The occurrence count
- The specific corrective action and the delay before it is applied

In this incident:
- Logged at 10:02:47 as the 4th occurrence.
- States the corrective action is to **restart the service in 60,000 milliseconds (60 seconds)** — meaning SCM had exhausted its faster restart attempts and moved to a longer recovery delay, and this is the last recovery attempt before the incident escalates.

### Event ID 7023 (Error, Source: Service Control Manager) - Service Terminated With a Specific Error
Records that a service process ended and specifies the exact Win32 error that was returned when it stopped or failed to start. Unlike 7034, this event carries the actual error text rather than just "terminated unexpectedly."

In this incident:
- Logged at 10:03:49, roughly 62 seconds after the 7031 event — consistent with the 60-second recovery delay elapsing and SCM attempting to restart the service.
- The error text is **"The specified module could not be found."** This maps to Win32 error 126 (`ERROR_MOD_NOT_FOUND`) and indicates that when Windows tried to load/start the spooler process (or a component it depends on, such as a print processor or driver DLL), a required module could not be located on disk.

### Event ID 7038 (Error, Source: Service Control Manager) - Service Failed to Log On
Records that a service could not start because the account it runs under could not be logged on. It includes:
- The account the service is configured to run as
- The specific logon failure reason returned by the security subsystem

In this incident:
- Logged at 10:03:50, one second after the 7023 event, as part of the same restart attempt.
- Records that the Print Spooler was unable to log on as **NT AUTHORITY\SYSTEM**, with the reason: **"Logon failure: the user has not been granted the requested logon type at this computer."** This is the classic text for Win32 error 1385 (`ERROR_LOGON_TYPE_NOT_GRANTED`), which occurs when the account lacks the **"Log on as a service"** user right (or that right has been explicitly restricted/denied) for the requested logon type.

## Reconstructed Sequence of Events (Plain English)
1. At 10:01:14, the Print Spooler service crashed unexpectedly for the first time. SCM's default recovery behavior restarted it.
2. At 10:01:45 (31 seconds later), it crashed again (2nd time) and was restarted again.
3. At 10:02:16 (31 seconds later), it crashed a 3rd time — the same short interval each time, suggesting the service was hitting the same fault immediately after each restart rather than failing randomly.
4. At 10:02:47, the 4th crash was logged, and this time SCM logged that it was moving to its next configured recovery action: **restart the service after a 60-second delay** — a sign SCM had cycled through faster automatic restarts and was now applying a longer back-off before trying again.
5. At 10:03:49 (~62 seconds later, matching the scheduled 60-second delay), SCM attempted the restart, but the service process terminated immediately with the error **"The specified module could not be found,"** meaning a required file/component the service (or its startup path) depends on was missing or inaccessible.
6. At 10:03:50, one second later, SCM logged that the same restart attempt also failed because the Print Spooler could not log on as **NT AUTHORITY\SYSTEM** — the account was denied the requested logon type. This is a security/permissions failure, separate from the missing-module error, and it means the service process could not even be created properly.
7. After 10:03:50, no further recovery events are provided, indicating the service did not recover on its own and remained down, requiring manual/administrative intervention.

## Most Likely Cause of the Service Crashing
**Most likely cause:** The Print Spooler was already unstable and crashing repeatedly (likely due to a corrupted, missing, or incompatible print driver/processor component), and when the service's automatic recovery tried to restart it after the 60-second delay, it could not restart at all because the **"Log on as a service" logon right for the SYSTEM account had been restricted or removed** (most likely via a recent security policy / Group Policy change to User Rights Assignment). This logon restriction — not the original crash — is what turned a recoverable crash loop into a full, unrecovered outage.

### Evidence from Events
- **Repeated, rapid, identical-pattern crashes (7034 x3 + 7031):** Four crashes in under 2 minutes, each roughly 30 seconds apart, is consistent with SCM's default recovery cadence (restart, then a slightly longer delay) repeatedly hitting the same fault — indicating a deterministic, reproducible problem rather than a one-off glitch.
- **"Specified module could not be found" (7023) at the exact moment the scheduled 60-second restart was due:** This shows that the restart attempt itself failed because a component the spooler needs to start (a DLL, print processor, or driver file) was missing or unreachable — a strong indicator of the original instability's technical cause (e.g., a corrupted/removed driver or print processor file).
- **Logon failure for NT AUTHORITY\SYSTEM (7038), logged one second after 7023, during the same restart attempt:** This is a distinct, security-related failure. `ERROR_LOGON_TYPE_NOT_GRANTED` specifically means the account was not permitted to log on with the requested logon type (i.e., "Log on as a service"). SYSTEM does not normally require explicit assignment of this right, so seeing this error strongly implies a recent change to security policy (e.g., User Rights Assignment, a security baseline/GPO push, or a "Deny log on as a service" setting) is now blocking it.
- **Both failures occurring on the same restart attempt (10:03:49–10:03:50):** This shows the service was blocked from two directions at once — a missing/corrupt dependency and a logon rights restriction — which explains why the service did not recover on its own even after SCM's built-in retry logic executed correctly.

## 5-Whys Analysis

### Problem Statement
The Print Spooler service crashed four times within about 90 seconds and then failed to restart entirely, leaving the service down.

1. **Why did the Print Spooler service stop working?**
   - Because it crashed repeatedly (Event 7034 x3, Event 7031), and then its scheduled automatic restart also failed (Event 7023, Event 7038), leaving no successful recovery.

2. **Why did the scheduled automatic restart fail?**
   - Because two separate problems occurred during the same restart attempt: the service process could not find a required module/component (7023, "The specified module could not be found") and it could not log on as NT AUTHORITY\SYSTEM (7038, "the user has not been granted the requested logon type").

3. **Why could the service not log on as NT AUTHORITY\SYSTEM?**
   - Because the account's permission to log on with the "Log on as a service" logon type was not present or had been restricted at the time of the restart attempt — normally a default right that does not need to be manually configured for SYSTEM.

4. **Why was the SYSTEM account's "Log on as a service" right missing or restricted?**
   - Most likely because a security hardening change (e.g., a Group Policy Object update to User Rights Assignment, or an explicit "Deny log on as a service" entry) was applied to the machine and did not correctly account for built-in service accounts required by default Windows services like the Print Spooler.

5. **Why was a policy change that broke a core Windows service not caught before it impacted the Print Spooler?**
   - Because there is no pre-deployment validation, staged rollout, or automated post-change health check for security policy/GPO changes that verifies critical built-in services (such as Print Spooler) can still start and log on successfully before/after the policy is applied fleet-wide.

## Root Cause
**Primary root cause:** A security policy change restricting or removing the "Log on as a service" logon right for the account the Print Spooler runs under (NT AUTHORITY\SYSTEM) prevented the service from restarting after it entered a crash loop, converting a recoverable fault into a full service outage.

**Contributing factor (initial instability):** A missing, corrupted, or incompatible print driver/print processor module (evidenced by the repeated 7034/7031 crashes and the "specified module could not be found" error in 7023) was already causing the spooler to crash before the logon restriction blocked its recovery.

**Contributing factors (process gaps):**
- No validation step to confirm default Windows service accounts retain required logon rights after a security/GPO policy change.
- No automated alerting on repeated Event ID 7034/7031 crash-loop patterns that would allow proactive intervention before the service became fully unrecoverable.
- No routine integrity check of print driver/print processor components that could catch a missing/corrupted module before it caused service instability.

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
- Review and correct the "Log on as a service" User Rights Assignment (locally via `secpol.msc` or via the applicable GPO) to ensure NT AUTHORITY\SYSTEM (and any other required service accounts) are permitted the required logon type, and remove any inadvertent "Deny log on as a service" entries affecting it.
- After correcting the logon right, manually restart the Print Spooler service and confirm it starts and remains stable (no further 7034 events).
- Identify the missing/corrupted module referenced in the 7023 event (check installed print drivers and print processors, e.g., via `Print Management` or `pnputil`), and reinstall or repair the affected driver/print processor.
- Check recent change history (GPO deployment logs, security baseline update records) around 2024-03-15 to confirm which policy change altered the logon right, and identify all other machines that received the same policy.

### Preventive Actions
- Add a pre-deployment validation step for any User Rights Assignment / security baseline changes that explicitly tests whether default Windows services (Print Spooler, and other SYSTEM/LocalService/NetworkService-dependent services) can still start after the policy is applied in a test ring.
- Implement staged/phased rollout for GPO security policy changes rather than fleet-wide deployment, with a health-check gate between rings.
- Add monitoring/alerting for Event ID 7031/7034 crash-loop patterns (e.g., 3+ crashes of the same service within 5 minutes) so responders can intervene before the service becomes fully unrecoverable.
- Add monitoring/alerting for Event ID 7038 logon failures on core services, since this event type almost always indicates a security/policy misconfiguration rather than a transient fault.
- Periodically validate integrity of print driver and print processor files on print servers/shared endpoints to catch corruption or accidental removal before it causes spooler instability.

## Confidence and Limitations
- **Confidence:** High that the immediate blocking cause of the failed recovery is the logon-type restriction, based on the explicit, unambiguous text of Event 7038. High confidence that repeated crashes (7034/7031) and the missing-module error (7023) indicate a pre-existing driver/processor-related instability.
- **Limitation:** The provided log excerpt does not name the specific missing module, the specific policy/GPO that changed the logon right, or who/what applied it. Confirming the exact driver/processor file and the specific policy change would require reviewing the Print Service operational/admin logs, driver store contents, and Group Policy change history (e.g., `gpresult`, event ID 4719/5136 security audit events, or GPO version history) around the incident time.

## Final Determination
The Print Spooler entered a crash loop (Event 7034 x3, then 7031) most likely due to a missing or corrupted print driver/print processor module. When Service Control Manager's scheduled 60-second recovery attempted to restart the service, the restart failed outright because the service could not log on as NT AUTHORITY\SYSTEM (Event 7038) due to a "Log on as a service" logon-type restriction, in addition to the same missing-module error recurring (Event 7023). The logon-type restriction is the most likely root cause of the service's inability to self-recover, and points to a recent security policy/GPO change to User Rights Assignment that was applied without validating its impact on built-in service accounts required by the Print Spooler.
