# KB: Print Spooler Recurring Crash and Restart Failure (SYSTEM Logon-Type Restriction) — L2/L3

**Version:** v1.0 | **Date:** 07/08/2026 | **Status:** Draft

## Background
The Print Spooler (`Spooler`) service manages all print job queuing, spooling, and routing to local and network printers on Windows hosts, and runs under the built-in **NT AUTHORITY\SYSTEM** account. It matters because it's a default, always-on Windows service — if it cannot start, the host (or, on a shared print server, every user routed through it) loses all printing capability, and dependent line-of-business workflows that trigger printing (invoices, labels, reports) fail silently or queue indefinitely.

## Symptom

### What users report
- "I can't print anything, the job just sits there."
- "The print server/printer shows as offline or not responding."

### What the engineer observes
- Print Spooler service repeatedly stops and restarts on its own, then eventually fails to restart at all and stays **Stopped**.
- Multiple crash-related errors logged in quick succession (roughly 30 seconds apart) in the System event log, followed by a final pair of errors during the last restart attempt that do not resolve on their own.

## Root Cause
**Primary cause:** A security policy change (local policy or domain GPO) removed or restricted the **"Log on as a service"** user right for NT AUTHORITY\SYSTEM, which prevented the Print Spooler from being recreated once Service Control Manager (SCM) attempted its scheduled automatic restart.
**Contributing factor:** The spooler was already unstable before that, crash-looping due to a missing or corrupted print driver/print processor module — this is what started the crash cycle in the first place, independent of the logon-rights issue.

### Evidence that confirms root cause
- **Event ID 7034** (Error, Source: Service Control Manager) logged 3 times at 30-second intervals (occurrence counts 1, 2, 3) — confirms a genuine crash loop, not a one-off fault.
- **Event ID 7031** (Error, Source: Service Control Manager), 4th occurrence — states corrective action "restart the service in 60,000 milliseconds," confirming SCM moved to its final, longer-delay recovery attempt.
- **Event ID 7023** (Error, Source: Service Control Manager), logged ~62 seconds later — error text **"The specified module could not be found"** (Win32 126, `ERROR_MOD_NOT_FOUND`) — confirms a required component (driver/print processor DLL) could not be loaded during the restart.
- **Event ID 7038** (Error, Source: Service Control Manager), logged 1 second after 7023, same restart attempt — account **NT AUTHORITY\SYSTEM**, reason **"Logon failure: the user has not been granted the requested logon type at this computer"** (Win32 1385, `ERROR_LOGON_TYPE_NOT_GRANTED`) — confirms the logon-rights restriction is what finally blocked recovery. SYSTEM does not need this right manually granted under normal configuration, so this event is a strong, specific signal of a policy regression rather than a transient error.

## Detection
Confirm all of the following before making any change.

1. Open Event Viewer > **Windows Logs > System** on the affected host.
   **Look for:** Source = `Service Control Manager`, Event IDs `7034`, `7031`, `7023`, `7038`, within the same short window (all four typically within ~2–3 minutes of each other).
2. Open the newest **Event ID 7034** entry.
   **Field to check:** Message text states the service name (`Print Spooler`/`Spooler`) "has done this N time(s)" — confirm N ≥ 2, indicating a repeat crash rather than a single event.
3. Open the newest **Event ID 7031** entry.
   **Field to check:** Message text names the corrective action and delay — confirm it reads "restart the service in 60000 milliseconds," indicating SCM's last automated retry.
4. Open the newest **Event ID 7023** entry (should be timestamped ~60 seconds after the 7031 entry).
   **Field to check:** Message text — confirm it reads exactly **"The specified module could not be found."**
5. Open the **Event ID 7038** entry logged immediately after 7023 (same restart attempt, ~1 second later).
   **Field to check:** Message text — confirm the account is `NT AUTHORITY\SYSTEM` and the reason is **"the user has not been granted the requested logon type at this computer."**
6. Open Services console (`services.msc`), locate **Print Spooler**.
   **Field to check:** **Status** column — confirm it shows blank/Stopped (not Running), consistent with SCM having given up after the failed restart.
7. **Comparison check:** Identify at least one other host that received the same recent security policy/GPO push (same OU, same GPO link) but is **not** reporting the issue.
   - On that comparison host, open `secpol.msc` > Local Policies > User Rights Assignment > **"Log on as a service"** and confirm NT AUTHORITY\SYSTEM (or the built-in default) is present with no Deny entry.
   - If the comparison host shows the right correctly granted while the affected host does not, this isolates the problem to a host-specific policy application gap (e.g., partial GPO replication, conflicting local override) rather than a fleet-wide rollout — narrowing where the fix must be applied.
8. Confirm diagnosis only if **all** of the following are true:
   - Events 7034 (×2 or more) and 7031 are present on the affected host.
   - Event 7023 with "The specified module could not be found" is present.
   - Event 7038 naming NT AUTHORITY\SYSTEM and the logon-type-not-granted reason is present, timestamped within ~1 second of the 7023 event.
   - The comparison host in step 7 does not exhibit the same "Log on as a service" gap.

## Resolution
No Azure Portal component applies to this incident (on-host Windows service / local or domain Group Policy issue) — the equivalent authoritative admin consoles are Group Policy Management Console (GPMC), Local Security Policy (`secpol.msc`), and Services (`services.msc`). Exact console paths are given below.

1. Connect to the affected host with an admin session.
   **Expected result:** Administrative session established.
2. Run `gpresult /h C:\Temp\gpresult-<hostname>-<date>.html` on the host and open the report.
   **Expected result:** Report shows whether a domain GPO (name + version) is applying the "Log on as a service" User Rights Assignment, or whether it's local-policy only.
3. **Console path:** `secpol.msc` > **Security Settings > Local Policies > User Rights Assignment > Log on as a service**.
   **Expected result:** Current list of accounts/groups granted the right is visible on this host.
4. Back up before changing anything:
   - Local policy: run `secedit /export /cfg C:\Temp\secpol-backup-<hostname>-<date>.inf`.
   - Domain GPO: **Console path:** Group Policy Management Console > Group Policy Objects > right-click the identified GPO > **Back Up...**
   **Expected result:** A restorable backup file/backup ID exists, path recorded in the ticket.
5. If a domain GPO is the source: **Console path:** GPMC > Group Policy Objects > \<identified GPO\> > right-click > Edit > Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > User Rights Assignment > **Log on as a service** > add `NT AUTHORITY\SYSTEM` (or remove it from any Deny list) > OK.
   **Expected result:** GPO updated to restore SYSTEM's logon right.
6. If local-policy only: **Console path:** `secpol.msc` > User Rights Assignment > **Log on as a service** > Add User or Group > `NT AUTHORITY\SYSTEM` (or remove the Deny entry) > Apply.
   **Expected result:** Local policy corrected on this host.
7. Run `gpupdate /force` on the affected host.
   **Expected result:** Policy applies with no errors.
8. **Console path:** Services (`services.msc`) > **Print Spooler** > right-click > **Start**.
   **Expected result:** Status changes to Running with no immediate failure.
9. Watch Event Viewer > System for 60 seconds.
   **Expected result:** No new Event 7034 or 7038 appears.
10. **Console path:** Print Management > Print Servers > \<host\> > **Drivers** (or run `pnputil /enum-drivers`) — identify the driver/print processor package associated with the original crash loop.
    **Expected result:** Specific suspect driver package identified.
11. Export the current package before touching it: `pnputil /export-driver <published name> C:\Temp\driver-backup-<date>`.
    **Expected result:** Pre-change driver package saved for rollback.
12. **Console path:** Print Management > Print Servers > \<host\> > Drivers > right-click the suspect driver > **Remove Driver Package**, then reinstall (or repair) it from the vendor/known-good source.
    **Expected result:** Driver reinstalls cleanly with no errors.
13. **Console path:** Services (`services.msc`) > **Print Spooler** > **Restart**.
    **Expected result:** Service starts cleanly, no Event 7023.
14. Record the GPO/local-policy backup ID/path, driver backup path, and all timestamps in the incident ticket.
    **Expected result:** Fully reversible change record exists.

## Verification
1. **Console path:** Services (`services.msc`) — confirm **Print Spooler**: Status = Running, Startup Type = Automatic.
2. Event Viewer > System, filter Event IDs `7034, 7031, 7023, 7038`, Logged = last 30 minutes.
   **Expected result:** Zero new occurrences.
3. Send a test print job through the affected host/spooler.
   **Expected result:** Job completes with no crash or restart.
4. Re-run `gpresult /r` and confirm "Log on as a service" now includes NT AUTHORITY\SYSTEM with no conflicting Deny entry.
5. **Comparison check:** Confirm the affected host's User Rights Assignment for "Log on as a service" now matches the healthy comparison host identified in Detection step 7.
6. **Console path:** Print Management > Drivers — confirm the reinstalled driver/print processor shows no error/corruption flag.
7. Monitor for at least 10 minutes of normal print activity with no recurrence before closing the incident.

## Rollback
Trigger immediately if the spooler still fails to start, a new crash loop begins, or the policy change causes unrelated access issues elsewhere.

- **If the GPO change is suspect:** GPMC > Group Policy Objects > \<GPO\> > right-click > **Restore from Backup...** > select the backup ID from Resolution step 4 > Restore. Then run `gpupdate /force`.
- **If the local policy change is suspect:** run `secedit /configure /db C:\Windows\security\local.sdb /cfg C:\Temp\secpol-backup-<hostname>-<date>.inf /overwrite`, then `gpupdate /force`.
- **If the driver reinstall is suspect:** Print Management > Drivers > remove the newly installed package, then run `pnputil /add-driver C:\Temp\driver-backup-<date>\*.inf /install` to restore the exact pre-change package from Resolution step 11.
- In all cases: restart Print Spooler and confirm it stays Running for 60 seconds with no new 7023/7034/7038 before considering rollback complete.
- If the service still won't stay running after full rollback, stop making changes on this host, escalate to DWP Engineering with the ticket and both backup files attached, and leave the host in its current (documented) state rather than attempting further fixes.

## Preventive
- Add a mandatory pre-deployment validation gate for any User Rights Assignment / security baseline change: before fleet rollout, apply the change to a test-ring host and run an automated check that Print Spooler (and other default SYSTEM/LocalService/NetworkService-dependent services) can still stop/start successfully.
- Convert GPO security-policy rollout to a staged ring deployment (pilot OU → broader OU → fleet) with a required health-check gate between rings, rather than direct fleet-wide application.
- Add a monitoring rule (e.g., via a log-forwarding/SIEM or Log Analytics alert) that fires on 3+ Event ID 7034/7031 occurrences for the same service within a 5-minute window, so responders are alerted mid-crash-loop instead of after full outage.
- Add a dedicated alert for Event ID 7038 on any core Windows service, since this event type is a specific, high-confidence indicator of a security/policy misconfiguration rather than a generic fault.
- Add a scheduled integrity check (e.g., `pnputil /enum-drivers` diff against a known-good baseline) on print servers/shared endpoints to catch missing or corrupted print driver/processor files before they cause spooler instability.

## Related
- [Day 5/Runbook-Print-Spooler-Service-Crash-remediation.md](Day%205/Runbook-Print-Spooler-Service-Crash-remediation.md)
- [Day 3/RCA-print-spooler-service-crash.md](Day%203/RCA-print-spooler-service-crash.md)
- No companion Known-Error, Closure, or Comms document exists yet for this incident — consider authoring those to complete the incident lifecycle set.
