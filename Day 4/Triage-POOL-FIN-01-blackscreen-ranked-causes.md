# AVD Incident Analysis: POOL-FIN-01 Black Screen Post Login

Date: 2026-08-07
Scope basis only: no additional telemetry used

## Scope Facts
- Symptom: blank screen post login; clears after ~30s for some users, persists for others.
- Who: ~40% of users on POOL-FIN-01. POOL-FIN-02 unaffected.
- Since: ~07:00.
- Change: overnight image update to POOL-FIN-01 at 02:00. POOL-FIN-02 was not updated.

## Most Important Timing/Control-Group Inference
The strongest clue is that POOL-FIN-02 was not updated and is completely unaffected. This makes an update-coupled cause in POOL-FIN-01 the leading hypothesis class, and lowers likelihood of tenant-wide or platform-wide causes.

## Re-Ranked Likely Causes (Most Probable First)

1. Gold image regression in POOL-FIN-01 (logon shell/profile-init path)
- Why this fits scope facts:
  - Directly aligned to the only scoped change (02:00 image update on FIN-01 only).
  - Control pool (FIN-02) unaffected supports a pool-specific regression.
  - Mixed behavior (30s clear for some, persistent for others) fits delayed vs hung initialization.
- Single fastest check:
  - Compare logon-to-shell start timing/events for a similar user on one affected FIN-01 host vs one FIN-02 host.

2. FSLogix/profile container attach behavior changed by the new image
- Why this fits scope facts:
  - Update-coupled and pool-scoped; consistent with control pool being clean.
  - Profile attach delays/failures commonly produce black screen after auth.
  - Partial impact (~40%) matches per-user/profile state variance.
- Single fastest check:
  - For one impacted FIN-01 user, check profile container attach and user hive load timeline during first ~30s post-login.

3. Graphics/remoting stack regression introduced in FIN-01 image
- Why this fits scope facts:
  - Also directly image-dependent and one-pool scoped.
  - Black screen symptom is consistent with delayed graphics initialization.
  - Some sessions recovering after ~30s can match late render path recovery.
- Single fastest check:
  - Force software rendering on one affected FIN-01 test session and verify whether symptom disappears.

4. Subset of FIN-01 hosts failed or diverged during image rollout
- Why this fits scope facts:
  - Explains ~40% impact while still tied to FIN-01 update activity.
  - Users with persistent symptom may repeatedly land on problematic host subset.
- Single fastest check:
  - Correlate impacted users to hostnames; check whether incidents cluster on specific FIN-01 hosts.

5. Policy/logon script/app-assignment interaction triggered by new image baseline
- Why this fits scope facts:
  - Can be update-induced, but weaker than image/profile/graphics paths.
  - If this were broadly policy-driven, similar behavior might appear across pools unless FIN-01 targeting differs.
- Single fastest check:
  - Capture one affected user logon processing timeline and identify a blocking synchronous policy/script step unique to FIN-01 sessions.

## Positioning Statement
Do not commit to a single root cause yet. Current weighting favors update-coupled FIN-01 image effects because FIN-02 is an unaffected control.

## Event Evidence Addendum (Incident Window Review)

### Evidence Reviewed

AVD Session Host: SHFIN-01-A (affected pool)
- 07:02:10 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (FINBRIDGE\mlopez, Session 3).
- 07:02:14 - Microsoft-Windows-Kernel-General Event 1
  - Host boot time reported as 02:03:11 (post-update reboot context).
- 07:02:16 - Application Error Event 1000
  - Faulting application: dwm.exe (10.0.22621.2861)
  - Faulting module: igdumd64.dll (31.0.101.4146)
  - Exception code: 0xc0000005.
- 07:02:17 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 40
  - Session disconnected (mlopez, Session 3).
- 07:02:18 - Desktop Window Manager Event 9009
  - DWM exited with code 0x40010004.
- 07:02:44 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Reconnect logon succeeded (mlopez, Session 3).
- 07:02:46 - Application Error Event 1000
  - Repeat dwm.exe fault in igdumd64.dll.
- 07:02:47 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 40
  - Session disconnected again.
- 07:03:01 - Desktop Window Manager Event 9009
  - DWM exited again with code 0x40010004.
- 07:03:10 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Second reconnect logon succeeded (mlopez, Session 4).
- 07:08:22 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (FINBRIDGE\akapoor, Session 5).
- 07:08:24 - Application Error Event 1000
  - Repeat dwm.exe fault in igdumd64.dll.

Comparison Host: SHFIN-02-A (unaffected pool)
- 07:01:44 - Microsoft-Windows-TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (FINBRIDGE\bwalker, Session 2).
- 07:01:46 - Desktop Window Manager Event 9011
  - DWM started successfully.
- No Application Error Event 1000 entries in reviewed window.

### Hypothesis Review Against Evidence

1. Gold image regression in POOL-FIN-01 (shell/profile-init path)
- Verdict: Support.
- Determining evidence:
  - Event 1 at 07:02:14 (boot after update context).
  - Event 1000 at 07:02:16 and 07:02:46 on SHFIN-01-A.
  - Event 9011 at 07:01:46 on SHFIN-02-A with no Event 1000.

2. FSLogix/profile container attach behavior changed by the new image
- Verdict: Contradicts (or materially weakens).
- Determining evidence:
  - Event 21 successful logons at 07:02:10 and 07:08:22.
  - Immediate failure signatures are Event 1000 dwm.exe/igdumd64.dll at 07:02:16, 07:02:46, 07:08:24.

3. Graphics/remoting stack regression introduced in FIN-01 image
- Verdict: Strong support.
- Determining evidence:
  - Event 1000 at 07:02:16, 07:02:46, 07:08:24 (dwm.exe faulting in igdumd64.dll).
  - Event 9009 at 07:02:18 and 07:03:01 (DWM exit).
  - Event 40 at 07:02:17 and 07:02:47 (session disconnect following crash).
  - SHFIN-02-A Event 9011 at 07:01:46 and no Event 1000.

4. Subset of FIN-01 hosts failed or diverged during image rollout
- Verdict: Neutral.
- Determining evidence:
  - Repeated errors proven on SHFIN-01-A only (Event 1000 at 07:02:16, 07:02:46, 07:08:24).
  - Provided evidence does not include additional FIN-01 hosts to confirm/deny clustering.

5. Policy/logon script/app-assignment interaction triggered by new image baseline
- Verdict: Contradicts (or materially weakens).
- Determining evidence:
  - Event chain is logon success then DWM crash/disconnect:
    - Event 21 at 07:02:10 -> Event 1000 at 07:02:16 -> Event 40 at 07:02:17.
  - Graphics module fault signature (igdumd64.dll) dominates failure pattern.

### Surviving Working Hypothesis

Graphics/remoting stack regression introduced by the POOL-FIN-01 image update, with DWM (dwm.exe) crashing in Intel graphics module igdumd64.dll.

## Resolution Plan Addendum

### 1) Immediate Containment
- Drain affected FIN-01 hosts from new sessions.
- Route users to FIN-02 or known healthy capacity.
- Publish incident communication that FIN-01 black screen mitigation is active.

### 2) Targeted Confirmation on Canary Host
- On one impacted FIN-01 host, validate repeat sequence:
  - Event 21 (logon) -> Event 1000 (dwm.exe/igdumd64.dll) -> Event 9009/40.
- Temporarily force software rendering for test session.
- Re-test login; if crash path disappears, confirm graphics-path regression.

### 3) Rapid Service Restoration
- Preferred: rollback FIN-01 hosts to last known-good image baseline.
- If rollback lead time is longer, apply temporary software-rendering policy for remote sessions.
- Reopen hosts in controlled batches after successful test logons.

### 4) Permanent Remediation
- Build corrected image removing/replacing implicated Intel graphics driver package.
- Pin validated driver version aligned with stable baseline.
- Validate in canary ring with reconnect and burst-logon testing.
- Promote in rings (10% -> 50% -> 100%) with hold points.

### 5) Exit Criteria / Verification Gates
- No new Event 1000 entries for dwm.exe faulting in igdumd64.dll in observation window.
- No new Event 9009 DWM exits on remediated hosts.
- Session disconnect rate returns to normal baseline.
- User validation confirms black screen symptom resolved.

### 6) Preventive Hardening
- Add image promotion gate to fail rollout if DWM crash pattern appears in canary soak.
- Add pre-release pool-diff check for graphics driver inventory.
- Maintain tested rollback playbook for each image release.
- Add alert correlation for Event 1000 (dwm.exe/igdumd64.dll) plus Event 40 spikes.
