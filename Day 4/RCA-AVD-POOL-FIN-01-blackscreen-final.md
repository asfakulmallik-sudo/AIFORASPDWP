# Root Cause Analysis (RCA)

## Incident Title
AVD POOL-FIN-01 Black Screen Post Login

## Incident Status
Resolved

## Incident Date
2026-08-07

## Resolution Time
10:00 AM (service restored and user-verified)

## Executive Summary
Between approximately 07:00 and 10:00, users connecting to POOL-FIN-01 experienced a black/blank screen after login. Some sessions recovered after about 30 seconds, while others disconnected or remained unusable. POOL-FIN-02 remained unaffected. The issue correlated with an overnight image update applied only to POOL-FIN-01 at 02:00. Event evidence from affected hosts showed repeated Desktop Window Manager (dwm.exe) crashes in Intel graphics module igdumd64.dll, followed by session disconnects. The applied remediation resolved the condition, and by 10:00 AM users were logging into POOL-FIN-01 hosts with no further reported issues.

## Scope and Impact
- Affected environment: POOL-FIN-01
- Unaffected control: POOL-FIN-02
- User impact: approximately 40% of users in POOL-FIN-01
- Symptom: black screen immediately post-login
- Symptom behavior: cleared after about 30 seconds for some users, persisted or disconnected for others
- Business impact: degraded user productivity and intermittent inability to establish stable desktop sessions

## Change Context
- 02:00: overnight image update deployed to POOL-FIN-01
- POOL-FIN-02 was not updated
- Incident started after the update window

## Supporting Evidence

### Affected Host Evidence (SHFIN-01-A)
- 07:02:10 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (FINBRIDGE\\mlopez, Session ID 3)
- 07:02:14 - Microsoft-Windows-Kernel-General Event 1
  - Boot time reported as 02:03:11 (host restart after overnight update)
- 07:02:16 - Application Error Event 1000
  - Faulting application: dwm.exe (10.0.22621.2861)
  - Faulting module: igdumd64.dll (31.0.101.4146)
  - Exception: 0xc0000005
- 07:02:17 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 40
  - Session disconnected (mlopez)
- 07:02:18 - Desktop Window Manager Event 9009
  - DWM exited with code 0x40010004
- 07:02:44 - Event 21 logon succeeded (reconnect)
- 07:02:46 - Event 1000 repeated (dwm.exe faulting in igdumd64.dll)
- 07:02:47 - Event 40 session disconnected
- 07:03:01 - Event 9009 DWM exited again
- 07:03:10 - Event 21 second reconnect succeeded
- 07:08:22 - Event 21 logon succeeded (FINBRIDGE\\akapoor)
- 07:08:24 - Event 1000 repeated (dwm.exe faulting in igdumd64.dll)

### Unaffected Host Evidence (SHFIN-02-A)
- 07:01:44 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded
- 07:01:46 - Desktop Window Manager Event 9011
  - DWM started successfully
- No Application Error Event 1000 in the same window

### Evidence Conclusion
The repeated pattern on the affected pool is:
- successful logon (Event 21) -> DWM/graphics module crash (Event 1000, igdumd64.dll) -> DWM exit (Event 9009) and/or session disconnect (Event 40)

This pattern is absent on the unaffected control pool host.

## Detailed Timeline (All Times Local)
- 02:00 - POOL-FIN-01 overnight image update started/applied
- 02:03:11 - SHFIN-01-A booted post-update (confirmed by Event 1 at 07:02:14)
- Approximately 07:00 - Users begin reporting black screen post-login in POOL-FIN-01
- 07:02 to 07:08 - Repeated evidence of logon success followed by DWM crash and disconnect on SHFIN-01-A
- During triage window - Comparator checks on POOL-FIN-02 show normal DWM startup and no crash events
- Mitigation and remediation actions applied per graphics-path hypothesis
- 10:00 - Issue resolved; verified users can log in to POOL-FIN-01 hosts with no reported issues

## Root Cause Statement
A graphics stack regression introduced in the updated POOL-FIN-01 image caused Desktop Window Manager (dwm.exe) to crash in Intel graphics user-mode driver module igdumd64.dll, resulting in black-screen sessions and disconnect loops for a subset of users.

## 5 Whys Analysis
1. Why did users see a black screen or disconnect after login?
- Because DWM crashed shortly after successful session logon, breaking desktop rendering.

2. Why did DWM crash?
- Because dwm.exe faulted repeatedly in igdumd64.dll (Application Error Event 1000).

3. Why was this crash path present in POOL-FIN-01?
- Because POOL-FIN-01 received the overnight image update that introduced the unstable graphics path.

4. Why did POOL-FIN-02 not show the issue?
- Because POOL-FIN-02 was not updated and retained the pre-update stable image baseline.

5. Why was this not caught before broad user impact?
- Because pre-production/canary validation and release gates were insufficient to detect DWM + graphics-driver crash behavior under real logon/reconnect conditions.

## Hypothesis Elimination Summary
- Gold image regression (general): supported by timing and pool isolation.
- FSLogix/profile attach issue: weakened by immediate graphics crash signature and successful logon events.
- Graphics/remoting stack regression: strongly supported by Event 1000 (dwm.exe/igdumd64.dll), Event 9009, Event 40 sequence.
- Bad subset of FIN-01 hosts: possible but secondary without broader host-cluster proof.
- Policy/script interaction: weakened by explicit DWM graphics module fault pattern.

## Resolution Actions Applied
1. Containment
- Limited exposure on affected FIN-01 hosts while investigation proceeded.

2. Targeted Validation
- Confirmed repeat event sequence linking login flow to DWM graphics module crash.

3. Corrective Action
- Applied the recommended graphics-path remediation for the updated FIN-01 image/host path.
- Restored stable user logon behavior.

4. Service Verification
- By 10:00 AM, users successfully logged in to POOL-FIN-01 hosts.
- No active issue reports after remediation.

## Recovery Verification Criteria (Met)
- Users can log in to POOL-FIN-01 hosts successfully.
- No continuing reports of black screen symptom post-login.
- Incident declared resolved at 10:00 AM.

## Preventive Actions

### Release Engineering Controls
1. Enforce canary-first rollout for host pool images (small ring before full rollout).
2. Add automated rollback trigger if DWM crash pattern is detected post-deploy.
3. Add pre-release driver inventory diff check between candidate image and last known-good image.
4. Require explicit sign-off on graphics driver changes in image release checklist.

### Validation and Monitoring
1. Add synthetic login/reconnect tests that validate desktop render readiness, not only auth success.
2. Add alert correlation for:
   - Application Error Event 1000 where faulting app is dwm.exe and module is igdumd64.dll
   - Desktop Window Manager Event 9009 spikes
   - TerminalServices Event 40 disconnect spikes after Event 21 logons
3. Define objective go/no-go thresholds for post-deploy soak window (e.g. zero Event 1000 dwm.exe crashes and less than 1% session-disconnect rate across a 2-hour, 50-session canary soak before wider rollout).

### Operational Readiness
1. Maintain documented fast rollback procedure for every image release.
2. Keep a stable control pool or rollback ring available for user continuity.
3. Run post-incident rehearsal for graphics-path failure response.

## Owner and Follow-Up
- Incident owner: DWWP Engineering
- Follow-up items:
  - Implement release gates and synthetic render checks
  - Update image deployment SOP with graphics risk controls
  - Review telemetry dashboards for early crash signature detection
