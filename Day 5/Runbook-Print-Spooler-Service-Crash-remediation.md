# Runbook: Print Spooler Recurring Crash and Restart Failure (SYSTEM Logon-Type Restriction)

**Incident reference:** RCA-print-spooler-service-crash.md | **Root cause:** A "Log on as a service" restriction on NT AUTHORITY\SYSTEM blocked automatic recovery after a pre-existing crash loop caused by a missing/corrupted print driver or print processor module.

## 1. Prerequisites

1. **[Elevated permissions required]** Local administrator rights on the affected host (to manage services, Event Viewer, Print Management, and local security policy).
2. **[Elevated permissions required]** Domain Group Policy edit rights (needed only if the logon restriction is traced to a domain GPO rather than local policy).
3. Confirm the ticket describes Print Spooler crashing repeatedly and then failing to restart (matches Event IDs 7034, 7031, 7023, 7038).
4. Have Event Viewer, Services console (`services.msc`), Local Security Policy (`secpol.msc`), Group Policy Management Console, and Print Management console available on/accessible from the affected host.
5. Confirm an incident ticket is open to log timestamps, backup file paths, and driver versions as you proceed.
6. If this is a shared print server, notify affected users/Service Desk that printing will be briefly unavailable during remediation.

## 2. Procedure

1. Open the incident ticket and confirm the reported symptom matches: Print Spooler down/crash-looping.
   **Expected result:** Symptom confirmed against ticket description.
2. **[Elevated]** Connect to the affected host with an admin session.
   **Expected result:** Administrative session established.
3. Open Event Viewer > Windows Logs > System, filter Source = Service Control Manager, Event IDs 7034, 7031, 7023, 7038, in the last few hours.
   **Expected result:** The crash-loop and failed-restart sequence is visible, matching the RCA signature.
4. Open the latest Event ID 7038 entry and confirm it names NT AUTHORITY\SYSTEM with reason "the user has not been granted the requested logon type at this computer."
   **Expected result:** Logon-type restriction confirmed as the immediate blocker to recovery.
5. Open the latest Event ID 7023 entry and confirm the error text "The specified module could not be found."
   **Expected result:** Missing/corrupted module confirmed as the contributing instability.
6. **[Elevated]** Open Local Security Policy (`secpol.msc`) > Local Policies > User Rights Assignment > "Log on as a service."
   **Expected result:** Current list of accounts/groups granted this right is visible.
7. Check whether NT AUTHORITY\SYSTEM is present in "Log on as a service," and separately check "Deny log on as a service" for any entry covering SYSTEM or a group SYSTEM belongs to.
   **Expected result:** You identify either a missing grant or an explicit deny.
8. **[Elevated]** Run `gpresult /h C:\Temp\gpresult-<hostname>-<date>.html` on the host.
   **Expected result:** Report generated showing whether a domain GPO (name/version) is enforcing this User Rights Assignment, overriding the local setting.
9. **[Elevated]** Before changing anything, back up the current state:
   - If the restriction is local: run `secedit /export /cfg C:\Temp\secpol-backup-<hostname>-<date>.inf`.
   - If the restriction comes from a domain GPO: in GPMC, right-click the identified GPO > Back Up..., and note the backup ID.
   **Expected result:** A backup file/backup ID exists and its path is recorded in the ticket — this is the artifact rollback will restore from.
10. **[Elevated]** If the GPO is the source: in GPMC, open the identified GPO, add NT AUTHORITY\SYSTEM to "Log on as a service" (or remove it from the Deny list), and save.
    **Expected result:** GPO updated to restore SYSTEM's logon right.
11. **[Elevated]** If the restriction is local-only (no overriding GPO found in step 8): in `secpol.msc`, add NT AUTHORITY\SYSTEM to "Log on as a service" (or remove the Deny entry), and apply.
    **Expected result:** Local policy corrected.
12. **[Elevated]** Run `gpupdate /force` on the affected host.
    **Expected result:** Policy update applies with no errors reported.
13. **[Elevated]** Open Services console, select Print Spooler, click Start.
    **Expected result:** Status changes to Running with no immediate failure.
14. Watch Event Viewer for 60 seconds after start.
    **Expected result:** No new Event 7034 (crash) or 7038 (logon failure) is logged.
15. **[Elevated]** Open Print Management (or run `pnputil /enum-drivers`) and identify the print driver/print processor package referenced around the time of the 7023 error.
    **Expected result:** The specific driver/processor package is identified for comparison against a known-good version.
16. **[Elevated]** Before removing anything, export the current (suspect) driver package: `pnputil /export-driver <published name> C:\Temp\driver-backup-<date>`.
    **Expected result:** A copy of the current driver package exists on disk, recorded in the ticket, before any change is made.
17. **[Elevated]** In Print Management, remove and reinstall (or repair via vendor package) the identified print driver/print processor.
    **Expected result:** Driver reinstalls cleanly with no errors.
18. **[Elevated]** Restart the Print Spooler service once more after the driver repair.
    **Expected result:** Service starts cleanly with no Event 7023 this time.
19. Record the GPO/local-policy backup path, the driver package backup path, and all timestamps in the incident ticket.
    **Expected result:** Ticket contains a complete, reversible record of every change made.

## 3. Verification

1. Open Services console and confirm Print Spooler shows **Status = Running**, **Startup Type = Automatic**.
   **Expected result:** Confirmed running and set to auto-start.
2. In Event Viewer > System, filter Event IDs 7034, 7031, 7023, 7038, Logged = last 30 minutes.
   **Expected result:** Zero new occurrences since remediation.
3. Send a test print job through the affected spooler (to any reachable printer or the Microsoft Print to PDF driver if no physical printer is available).
   **Expected result:** Job completes successfully with no spooler crash or restart.
4. Re-run `gpresult /r` on the host and confirm "Log on as a service" now includes NT AUTHORITY\SYSTEM with no conflicting Deny entry.
   **Expected result:** Confirmed corrected and no longer overridden.
5. In Print Management, confirm the reinstalled driver/print processor shows no error or corruption indicator.
   **Expected result:** Driver listed as healthy.
6. Monitor the host for at least 10 minutes with normal print activity.
   **Expected result:** No recurrence of the crash-loop pattern.
7. Close the incident only after steps 1–6 all pass, with backup file paths and evidence attached to the ticket.

## 4. Rollback

Trigger immediately if the Print Spooler still fails to start, a new crash loop begins, or the GPO/policy change causes unintended access issues elsewhere.

**If the GPO/local policy change is the suspected cause of new problems:**
1. **[Elevated]** If you changed a domain GPO (step 10): in GPMC, right-click the GPO > Restore from Backup..., select the backup ID recorded in step 9, and restore.
   **Expected result:** GPO reverts to its exact pre-change state.
2. **[Elevated]** If you changed local policy only (step 11): run `secedit /configure /db C:\Windows\security\local.sdb /cfg C:\Temp\secpol-backup-<hostname>-<date>.inf /overwrite` using the file from step 9.
   **Expected result:** Local security policy reverts to its pre-change state.
3. **[Elevated]** Run `gpupdate /force` again to apply the reverted policy.
   **Expected result:** Host reflects the restored policy.

**If the driver reinstall is the suspected cause of new problems:**
4. **[Elevated]** In Print Management, remove the newly installed driver/print processor.
   **Expected result:** Faulty new driver package is removed.
5. **[Elevated]** Restore the pre-change driver package captured in step 16: `pnputil /add-driver C:\Temp\driver-backup-<date>\*.inf /install`.
   **Expected result:** Original driver package is reinstated exactly as it was before remediation.

**In all rollback cases:**
6. **[Elevated]** Restart the Print Spooler service and confirm it reaches Running with no new 7023/7034/7038 events within 60 seconds.
   **Expected result:** Service is stable on the reverted configuration, even if the original crash-loop symptom returns.
7. If the service still will not stay running after full rollback, stop further changes on this host and escalate to DWP Engineering with the ticket, both backup files, and the latest Event Viewer export attached.
   **Expected result:** Host is left in a known, documented state (not worse than pre-incident) pending deeper investigation.

## 5. Notes

- Diagnostic signature: Event 7034 (repeated, ~30s apart) → Event 7031 (60s recovery scheduled) → Event 7023 ("specified module could not be found") and Event 7038 (SYSTEM logon-type denied), both on the same restart attempt.
- Treat 7023 and 7038 as **two distinct, independent faults** occurring on the same restart — fixing only one (e.g., only the driver, or only the logon right) may leave the service still unable to recover.
- SYSTEM does not normally need explicit "Log on as a service" configuration; seeing Event 7038 for SYSTEM is a strong indicator of a recent security policy/GPO change and should be treated as a policy regression, not a one-off glitch.
- Always take the backups in steps 9 and 16 **before** making any change — without them, rollback in section 4 cannot be performed precisely.
- If multiple machines received the same GPO push, check for other hosts with the same 7034/7031/7023/7038 pattern before considering this incident fully closed at the fleet level.
- Related documents: RCA-print-spooler-service-crash.md (this RCA has no companion Known-Error/Closure/Comms files yet in the repo — consider authoring those once this runbook is validated).
