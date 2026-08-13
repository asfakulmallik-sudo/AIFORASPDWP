# Runbook: AVD POOL-FIN-01 Black Screen Post Login (DWM igdumd64.dll Crash)

Title: AVD POOL-FIN-01 Black Screen Post Login Remediation Runbook  
Version: v1.0  
Date: 2026-08-07  
Author: Sathishbabu  
Reviewed: self  
Status: draft  
Change: initial version from RCA

## 1) Prerequisites

Complete every prerequisite before starting the procedure.

1. Confirm this is the same incident pattern.
Expected result: The ticket states black screen after login in POOL-FIN-01, and POOL-FIN-02 is stable.

2. Confirm you are working from an approved incident and change record.
Expected result: Incident ID and change ID are open and ready for timestamps and evidence.

3. Verify you have Azure Contributor access to POOL-FIN-01.
Expected result: You can set drain mode and manage session host assignment.

4. Verify you have at least Reader access to POOL-FIN-02.
Expected result: You can use POOL-FIN-02 as a control for comparison.

5. Verify you have local admin rights on affected POOL-FIN-01 hosts.
Expected result: You can open Event Viewer, run host remediation, and restart hosts.

6. Verify restart approval is already granted for session hosts.
Expected result: No additional approvals are needed when the runbook reaches reboot steps.

7. Sign in to Azure Portal in the production tenant.
Expected result: You can open Azure Virtual Desktop and see POOL-FIN-01 and POOL-FIN-02.

8. Connect to one known-affected host (example: SHFIN-01-A).
Expected result: You have an admin session on the host and can open local tools.

9. Open Event Viewer on the affected host.
Expected result: You can view Windows Logs and Applications and Services Logs.

10. Open the approved DWP graphics-path remediation package or SOP for the active image version.
Expected result: You have the exact approved package and instructions to apply.

11. Notify Service Desk and business stakeholders that controlled remediation is starting.
Expected result: Stakeholders are aware users may be asked to reconnect during host restarts.

## 2) Procedure

Follow steps in order. Each step is one action.

1. Set one affected POOL-FIN-01 session host to drain mode in Azure Virtual Desktop.
Expected result: No new user sessions are assigned to that host.

2. Move active user sessions off the drained host using standard user communication and sign-out workflow.
Expected result: The drained host shows zero active user sessions.

3. Connect to the drained host with an admin session.
Expected result: You are logged in with administrative context on the host.

4. [Elevated permissions required] Open Event Viewer on the host.
Expected result: Event Viewer loads and shows local event channels.

5. In Windows Logs > Application, filter for Event ID 1000 in the last 4 hours.
Expected result: Filtered list shows Application Error entries for recent failures.

6. Open the latest Event ID 1000 entry where faulting application is dwm.exe.
Expected result: Event details show faulting module igdumd64.dll and exception 0xc0000005 on affected host.

7. In Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational, filter for Event ID 9009 in the same time window.
Expected result: You see DWM exit events temporally aligned with login attempts.

8. In Applications and Services Logs > Microsoft > Windows > TerminalServices-LocalSessionManager > Operational, filter for Event IDs 21 and 40 in the same time window.
Expected result: You see logon success (21) followed by disconnect (40) patterns.

9. Record one timestamped evidence sequence of 21 -> 1000 -> 9009 or 40 in the incident ticket.
Expected result: Ticket contains reproducible proof of the crash chain.

10. [Elevated permissions required] Apply the approved DWP graphics-path remediation package to the drained host.
Expected result: Remediation tool completes successfully with no fatal errors.

11. [Elevated permissions required] Restart the drained host.
Expected result: Host returns to running state and AVD agent reports Available.

12. Reconnect to the remediated host and repeat Event Viewer checks for Event IDs 1000 and 9009 over a fresh 10-minute window after first user logon.
Expected result: No new dwm.exe crash in igdumd64.dll and no DWM exit spike in that window.

13. Remove drain mode from the remediated host.
Expected result: Host accepts new user sessions.

14. Run a controlled user login test to the remediated host.
Expected result: Desktop renders normally without prolonged black screen and session remains connected.

15. Repeat steps 1 through 14 for each remaining affected host in POOL-FIN-01.
Expected result: All targeted hosts are remediated and returned to service.

16. Update incident timeline with remediation start, per-host completion, and service restoration time.
Expected result: Incident record contains complete operational timeline.

## 3) Verification

Complete all verification checks before closure.

1. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Expected result: The Session hosts grid for POOL-FIN-01 is visible.

2. In the Session hosts grid, confirm each remediated host shows Status = Available and Allow new sessions = On.
Expected result: No remediated host is Unavailable or left in drain mode.

3. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions.
Expected result: The User sessions list is visible with active sessions.

4. Start one test login to each of three different remediated POOL-FIN-01 hosts.
Expected result: Each user reaches full desktop with no black screen and no immediate disconnect.

5. On a remediated host, open Event Viewer > Windows Logs > Application.
Expected result: Application log is open on the remediated host.

6. In Application log, click Filter Current Log..., set Event IDs = 1000 and Logged = Last 30 minutes, then click OK.
Expected result: Only recent Application Error events are shown.

7. In filtered results, check there are zero entries where Faulting application name = dwm.exe and Faulting module name = igdumd64.dll.
Expected result: No new dwm.exe/igdumd64.dll crash entry exists in the last 30 minutes.

8. On the same host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational.
Expected result: Desktop Window Manager Operational log is open.

9. In Desktop Window Manager Operational log, click Filter Current Log..., set Event IDs = 9009 and Logged = Last 30 minutes, then click OK.
Expected result: You can directly verify whether DWM exit events were generated.

10. Confirm no repeated Event ID 9009 pattern appears after user logins in the last 30 minutes.
Expected result: No post-login DWM exit loop is present.

11. On the same host, open Event Viewer > Applications and Services Logs > Microsoft > Windows > TerminalServices-LocalSessionManager > Operational.
Expected result: TerminalServices LocalSessionManager Operational log is open.

12. In that log, click Filter Current Log..., set Event IDs = 21,40 and Logged = Last 30 minutes, then click OK.
Expected result: Recent logon and disconnect events are isolated for review.

13. Confirm no repeated sequence of Event 21 followed by Event 40 for the same user within 1 minute.
Expected result: Logon-disconnect loop is absent.

14. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts.
Expected result: Control pool host health is visible.

15. Confirm POOL-FIN-02 hosts show normal Available status without matching incident symptom reports.
Expected result: Control pool remains stable and supports comparison.

16. Add screenshots of POOL-FIN-01 Session hosts, filtered Event Viewer results, and successful user test outcomes to the incident ticket.
Expected result: Closure evidence is complete and auditable.

17. Close the incident only after all verification steps pass.
Expected result: Incident is resolved with objective proof attached.

## 4) Rollback

Use this rollback immediately if black-screen behavior worsens, logon disconnect loops continue, or host remediation fails.

### Emergency rollback target: complete steps 1-6 within 3 minutes

1. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Expected result: The affected host is visible in the Session hosts list.

2. Select the affected host and set Allow new sessions = Off (drain mode).
Expected result: New user connections stop landing on that host immediately.

3. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions.
Expected result: Active sessions list is visible.

4. Filter User sessions by the affected host name.
Expected result: Only sessions on the unstable host are listed.

5. Select each listed session and click Send message to announce immediate reconnect to healthy host.
Expected result: Connected users receive a warning before sign-out.

6. Select each listed session and click Sign out.
Expected result: Users are disconnected from the unstable host and can reconnect elsewhere.

### Stabilization actions after containment

7. In Azure Portal, go to Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts and confirm at least one host Status = Available.
Expected result: Healthy capacity exists for user reconnection.

8. [Elevated permissions required] On the affected VM, open Event Viewer > Windows Logs > Application.
Expected result: Application log is open for rollback evidence capture.

9. In Application log, click Filter Current Log..., set Event IDs = 1000 and Logged = Last 15 minutes.
Expected result: Recent crash events are isolated.

10. Capture the newest Event ID 1000 details showing dwm.exe and igdumd64.dll in the incident ticket.
Expected result: Ticket contains rollback trigger evidence.

11. [Elevated permissions required] Reimage or redeploy the affected session host to the last known-good image version used before the 02:00 change.
Expected result: Host returns to pre-incident image baseline.

12. [Elevated permissions required] Restart the reimaged host.
Expected result: VM boots and AVD agent returns to Available.

13. Keep Allow new sessions = Off and run one admin login test on the host.
Expected result: Admin reaches full desktop with no black screen.

14. Keep Allow new sessions = Off and run one standard user login test on the host.
Expected result: User reaches desktop with no disconnect loop.

15. If both tests pass, set Allow new sessions = On for that host.
Expected result: Host safely returns to production rotation.

16. If either test fails, leave Allow new sessions = Off and remove the host from service rotation in POOL-FIN-01.
Expected result: Failed host is isolated and cannot impact users.

17. Route affected users to POOL-FIN-02 until replacement capacity is ready.
Expected result: User service continues on stable hosts.

18. Escalate to DWP Engineering with host name, image version, remediation package version, and copied Event Viewer evidence paths.
Expected result: Engineering receives complete rollback context for deep triage.

## 5) Notes

- Elevated permissions are required for Event Viewer access on hosts, applying remediation, image reversion, and host restarts.
- The signature for this incident is the sequence: Event 21 logon success followed by Event 1000 (dwm.exe fault in igdumd64.dll), then Event 9009 and/or Event 40.
- A temporary black screen that clears in about 30 seconds can still indicate instability; do not treat it as resolved without event validation.
- POOL-FIN-02 is the control pool and should remain unchanged during incident handling unless capacity emergency requires temporary routing.
- If only a subset of POOL-FIN-01 hosts are affected, remediate per-host and keep unaffected hosts in service to preserve capacity.
- Related incidents and documents:
  - Known-Error-POOL-FIN-01-blackscreen.md
  - Closure-POOL-FIN-01-blackscreen.md
  - Comms-POOL-FIN-01-incident-resolution.md
  - Triage-POOL-FIN-01-blackscreen-ranked-causes.md
  - RCA-AVD-POOL-FIN-01-blackscreen-final.md
