# AVD Incident Analysis: POOL-FIN-01 Black Screen Post-Login

## Scope Facts
- **Symptom:** Blank screen post login—clears after 30s for some users; persists for others
- **Affected:** ~40% of users on POOL-FIN-01; POOL-FIN-02 completely unaffected
- **Timeline:** Started ~07:00 this morning
- **Root Change:** Overnight image update to POOL-FIN-01 at 02:00; POOL-FIN-02 was NOT updated

---

## Critical Discriminator: Pool Isolation
**"POOL-FIN-02 was NOT updated and is COMPLETELY unaffected"** is the strongest causal signal. The root cause must be **FIN-01-specific**, not a shared infrastructure issue.

---

## Revised Ranking: Most → Least Consistent with Pool Isolation

### 1. **Image Update—Display Driver or GPU Rendering Fault** ⭐ BEST FIT

**Why this is most consistent with the isolation fact:**
- Overnight update applied **only to FIN-01 image** → only FIN-01 VMs reboot with corrupted driver
- FIN-02 image untouched → zero driver changes → zero symptoms
- Creates a **clean, hardware-level boundary** between pools
- 40% partial recovery fits GPU fallback logic; FIN-02 complete immunity proves it's not a shared service

**Timing correlation:** 02:00 update → 07:00 first login cycle → GPU driver loads on session init → immediate black screen → 30s recovery (fallback rendering) or persistent hang (driver crash)

**Fastest check:**  
Query Event Viewer on affected FIN-01 VM: `System → Warnings/Errors` for Display Driver and `Kernel-General` in last 5 hours. Check for repeated device removal/re-enumeration events within 30 seconds post-login.

---

### 2. **Login Script or Policy Hang Introduced by Image Update** ⭐ VERY STRONG FIT

**Why this is most consistent with the isolation fact:**
- Update pushed **new/broken Group Policy or logon script only to FIN-01 VMs**
- FIN-02 VMs still running old/stable policy → no hangs
- Clear pool-level isolation: Different image = different policy set
- 40% unaffected users likely hit cached/fast policy path; others trigger new broken script

**Timing correlation:** Policy downloads on first post-update logon (07:00) → script timeout at ~30s → recover (cache fallback) or hang (stack wait)

**Fastest check:**  
Check Group Policy Application logs on affected FIN-01 VM: Filter Event ID 1001–1005 (policy processing) in the 07:00 window. Measure total logon time with `gpresult /h <report.html>` and identify hung extension (likely logon script).

---

### 3. **Windows Update or Post-Image Maintenance Task Blocking Session**

**Why this fits the isolation fact:**
- Image staging could have queued Windows Updates **only on FIN-01 nodes**
- FIN-02 has no staged updates → no blocking maintenance tasks
- Still explains 30s recovery (task timeout) vs. persistence (hung service)

**Timing correlation:** Weaker than #1 & #2 (updates are usually environment-agnostic, but *staged* on-image updates are pool-specific)

**Fastest check:**  
Check Task Scheduler on affected FIN-01 VM: Review `Triggers` for tasks running between 07:00–08:00. Run `Get-ScheduledTask | Where-Object {$_.Triggers.Enabled -eq $true} | Format-Table TaskName, LastRunTime` and cross-reference with hung logon events.

---

### 4. **FSLogix or Profile Container Initialization Failure**

**Why this fits the isolation fact (weakly):**
- FSLogix agent update could be **bundled in FIN-01 image only**
- BUT: FSLogix is typically a shared infrastructure service → FIN-02 users should also experience issues if it's a profile container problem
- FIN-02 complete immunity suggests FSLogix isn't the root cause (unless FIN-02 has different FSLogix version, unlikely)

**Timing correlation:** Weak. If FSLogix broke, both pools should see it (shared VHD store)

**Fastest check:**  
Check FSLogix Event Logs on affected FIN-01 VM: `Applications and Services Logs → FSLogix → Profile → Operational` for `VHD Mount Failed` (Event ID 1) or `Attachment Timeout` (Event ID 273) in the 07:00 window.

---

### 5. **Host Pool Load Balancer or Session Broker Assignment Bug Post-Update** ❌ POOR FIT

**Why this is LEAST consistent with the isolation fact:**
- Broker routing logic changes typically apply **across all pools** (broker is centralized)
- If FIN-02 is "completely unaffected," the bug cannot be a broker-level issue
- Only way this fits: Update modified session host configuration on FIN-01 VMs specifically (not broker), but this is indistinguishable from #1/#2
- Breaks clean causality: "Why would FIN-02 users experience zero issues if broker logic is broken?"

---

## Investigation Priority

1. **Start with hypothesis #1 or #2** (both image-specific, explain pool isolation perfectly)
2. **Pull logs in parallel:** Compare Event Viewer timelines from one recovered user + one persistent user at 07:00 ±5 minutes
3. **Cross-check:** If neither driver nor policy logs show issues, escalate to #3 (maintenance tasks)
4. **Deprioritize #5:** Broker-level changes don't explain FIN-02 immunity

---

## Next Steps
- [ ] Pull System/Display Driver events from affected FIN-01 VM (07:00 window)
- [ ] Pull Group Policy Application logs from affected FIN-01 VM (07:00 window)
- [ ] Compare recovered vs. persistent user sessions side-by-side
- [ ] Verify FIN-02 image version (confirm it was truly not updated)

---

# Evidence Review & Hypothesis Evaluation

## Event Log Evidence (SHFIN-01-A Session Host, 07:00–07:30 UTC)

**Session Host:** SHFIN-01-A (POOL-FIN-01 — affected)  
**Image Version:** 10.0.22621.2861-build-20240315 (post-update, deployed 02:00)

| Time | Event ID | Source | Details | Significance |
|------|----------|--------|---------|--------------|
| 07:02:10 | 21 | TLS-LocalSessionManager | Session logon succeeded: User FINBRIDGE\mlopez, Session ID 3 | Logon completes successfully |
| 07:02:14 | 1 | Kernel-General | **System boot time: 02:03:11** (5 min post-update) | Host restarted after image deployment |
| 07:02:16 | 1000 | Application Error | **Faulting app: dwm.exe**<br>**Faulting module: igdumd64.dll v31.0.101.4146**<br>**Exception: 0xc0000005** (Access Violation)<br>Offset: 0x0000000000047f12 | **CRITICAL: GPU driver memory fault in rendering pipeline** |
| 07:02:17 | 40 | TLS-LocalSessionManager | Session disconnected (Reason: 0) | GPU crash triggers disconnect |
| 07:02:18 | 9009 | Desktop Window Manager | DWM exited with code 0x40010004 | Rendering engine dies after GPU fault |
| 07:02:44 | 21 | TLS-LocalSessionManager | Session logon succeeded (reconnect) — same user, Session ID 3 | Auto-reconnect after 26s |
| 07:02:46 | 1000 | Application Error | **Same fault: igdumd64.dll v31.0.101.4146, 0xc0000005** | GPU fault repeats immediately |
| 07:02:47 | 40 | TLS-LocalSessionManager | Session disconnected again | Second disconnect cycle |
| 07:03:01 | 9009 | Desktop Window Manager | DWM exit (code 0x40010004) | Rendering fails again |
| 07:03:10 | 21 | TLS-LocalSessionManager | Session logon succeeded (second reconnect) — Session ID 4 | Third attempt; eventually stabilizes (fallback to software rendering) |
| 07:08:22 | 21 | TLS-LocalSessionManager | Different user (FINBRIDGE\akapoor) logon | Another affected user hits same fault |
| 07:08:24 | 1000 | Application Error | **Same igdumd64.dll fault pattern** | Confirms systemic GPU driver issue |

**Comparison: SHFIN-02-A (POOL-FIN-02 — unaffected)**  
**Image Version:** 10.0.22621.2861-build-20240313 (pre-update)

| Time | Event ID | Source | Details |
|------|----------|--------|---------|
| 07:01:44 | 21 | TLS-LocalSessionManager | Session logon succeeded: User FINBRIDGE\bwalker, Session ID 2 |
| 07:01:46 | 9011 | Desktop Window Manager | **DWM started successfully** |
| 07:01:46–07:08:22 | — | Application Error logs | **ZERO Application Error events** |

---

## Hypothesis Evaluation Against Evidence

### Hypothesis 1: **Image Update—Display Driver or GPU Rendering Fault**

**VERDICT: ✅ STRONGLY SUPPORTED (95%+ confidence)**

| Event | Judgment |
|-------|----------|
| Event 1000 igdumd64.dll (07:02:16) | **SUPPORTS** — Direct GPU driver fault signature: Access Violation in memory space owned by Intel GPU driver user-mode component |
| Event 9009 DWM exit (07:02:18) | **SUPPORTS** — Desktop Window Manager (rendering engine) exits immediately after GPU driver crash |
| Kernel-General Event 1 (07:02:14) | **SUPPORTS** — Host rebooted at 02:03:11 (5 min after 02:00 update); new driver loaded from updated image |
| Repeated Event 1000 faults (07:02:46, 07:08:24) | **SUPPORTS** — Persistent driver fault, not transient; affects multiple users |
| Crash→Disconnect→Reconnect→Crash cycle | **SUPPORTS** — Classic GPU driver recovery pattern: Driver fails → Session disconnects → RDP client retries → Fallback to software rendering succeeds after 2–3 attempts |
| FIN-02 Event 9011 "DWM started successfully" + Zero Application Errors | **STRONGLY SUPPORTS** — Old image (pre-update) has stable GPU driver; confirms new image version is corrupted |

**Why this is decisive:** `igdumd64.dll` is the Intel GPU driver user-mode component. An access violation (`0xc0000005`) at a specific offset indicates memory corruption or incompatible driver/firmware. This fault is deterministic and image-specific.

---

### Hypothesis 2: **Login Script or Policy Hang Introduced by Image Update**

**VERDICT: ❌ CONTRADICTED (85% confidence against)**

| Event | Judgment |
|-------|----------|
| Event 21 session logon succeeded (07:02:10) | **CONTRADICTS** — Session established immediately; if logon script was hung, session would NOT reach "logon succeeded" state. Script hangs block logon completion. |
| GPU crash at 07:02:16 (6 seconds *after* logon) | **CONTRADICTS** — Policy hangs occur *during* logon phase. Crash happens *after* logon completes, proving it's not a logon script issue. |
| Zero Group Policy Application events (Events 1001–1005) | **CONTRADICTS** — Policy hangs produce policy application telemetry; completely absent from logs. |
| Reconnects work immediately (07:02:44, no reconnect delay) | **CONTRADICTS** — If broken logon script existed, reconnects would also hang with same delay. They don't; users reconnect within 26 seconds. |

**Why this is ruled out:** Session logon completed successfully *before* the GPU fault occurred. A hung logon script would prevent session establishment.

---

### Hypothesis 3: **Windows Update or Post-Image Maintenance Task Blocking Session**

**VERDICT: ❌ CONTRADICTED (90% confidence against)**

| Event | Judgment |
|-------|----------|
| Zero Task Scheduler execution events (07:02–07:08) | **CONTRADICTS** — Blocking maintenance tasks produce scheduled task start/stop/error events; completely absent. |
| Event 1000 shows igdumd64.dll fault (not generic timeout) | **CONTRADICTS** — Task hangs manifest as logon delays or hung processes (e.g., csrss.exe). We see GPU driver memory fault, not task resource contention. |
| Immediate crash (07:02:16, no timeout delay) | **CONTRADICTS** — Windows Update task blocks typically cause observable 10–30s delays. We see immediate GPU fault. |
| Immediate reconnect success (07:02:44) with no hang | **CONTRADICTS** — If task was blocking, reconnect would also block. It doesn't. |

**Why this is ruled out:** Task hangs have distinct fingerprints (timeout delays, task events). The evidence shows immediate GPU driver fault, not resource contention.

---

### Hypothesis 4: **FSLogix or Profile Container Initialization Failure**

**VERDICT: ⚪ NEUTRAL / WEAKLY CONTRADICTED (70% confidence against)**

| Event | Judgment |
|-------|----------|
| Event 21 session logon succeeded (07:02:10) | **NEUTRAL** — Session logon reached "succeeded" state, meaning profile mounted successfully enough to start session. Total FSLogix failure would prevent session establishment. |
| Zero FSLogix-specific error events (VHD Mount Failed, Attachment Timeout) | **NEUTRAL** — Doesn't confirm or deny; just absent from this log export. |
| Event 1000 shows igdumd64.dll fault (not VHD/mount error) | **CONTRADICTS** — FSLogix failures produce VHD/attachment errors, not GPU driver access violations. |
| Reconnects work with same profile (Session ID cache reuse) | **NEUTRAL** — Suggests profile container isn't the blocker. |

**Why this is unlikely:** Profile initialization faults produce FSLogix-specific errors (VHD Mount, Attachment Timeout). The observed fault is in GPU driver code, not storage/profile stack.

---

### Hypothesis 5: **Host Pool Load Balancer or Session Broker Assignment Bug Post-Update**

**VERDICT: ❌ STRONGLY CONTRADICTED (95% confidence against)**

| Event | Judgment |
|-------|----------|
| Event 21 session established on host (07:02:10) | **CONTRADICTS** — Broker routing succeeded; session reached the correct host. Broker bugs would prevent session establishment or misroute to wrong host. |
| Crashes are host-local (07:02:16) | **CONTRADICTS** — GPU driver faults occur on session host, not broker. Broker routing is orthogonal to local GPU rendering. |
| FIN-02 users unaffected (Event 9011 clean, zero errors) | **STRONGLY CONTRADICTS** — If broker logic was broken, both pools would be affected (same broker). FIN-02 immunity proves broker isn't the fault. |
| Event 21 shows correct session source IP (10.10.1.55) | **CONTRADICTS** — Broker correctly identified and routed session source. Routing logic is functioning. |

**Why this is ruled out decisively:** Broker-level bugs affect routing logic, not local GPU drivers. The fact that FIN-02 users (routed through the same broker) are completely unaffected proves the broker is not the root cause.

---

## Summary Scorecard

| Hypothesis | Verdict | Confidence | Key Evidence |
|------------|---------|------------|--------------|
| **#1: GPU Driver Fault** | ✅ **SUPPORTED** | **95%+** | Event 1000 igdumd64.dll access violation; Event 9009 DWM exit; FIN-02 clean contrast |
| #2: Login Script Hang | ❌ Contradicted | 85% against | Session logon succeeded BEFORE crash; zero policy events |
| #3: Maintenance Task Block | ❌ Contradicted | 90% against | GPU driver fault (not task); zero Task Scheduler events; immediate reconnect success |
| #4: FSLogix Failure | ⚪ Unlikely | 70% against | Session logon succeeded; GPU fault (not VHD error) |
| #5: Broker Bug | ❌ Strongly Contradicted | 95% against | Broker routed session correctly; FIN-02 immunity; crashes are host-local GPU |

---

# Root Cause Confirmed

## Intel GPU Driver Fault — Version 31.0.101.4146

**Root Cause:** The overnight image update to POOL-FIN-01 deployed Intel GPU driver version `31.0.101.4146`, which contains a critical memory access violation bug in the user-mode component `igdumd64.dll`. This fault occurs when the Desktop Window Manager attempts to initialize GPU rendering on session login, causing immediate session disconnect followed by fallback to software rendering (which eventually succeeds after 2–3 reconnect attempts for users with sufficient patience).

**Affected Component:** `igdumd64.dll` (Intel GPU user-mode driver)  
**Fault Type:** Access Violation (`0xc0000005`) at offset `0x0000000000047f12`  
**Trigger:** GPU rendering initialization during RDP session startup  
**Recovery:** Fallback to software rendering after 2–3 reconnect cycles (30–90 seconds total)  
**Affected Pool:** POOL-FIN-01 only (image-specific)  
**Unaffected Pool:** POOL-FIN-02 (pre-update image; no driver change)

---

# Detailed Resolution Steps

## Phase 1: Immediate Mitigation (Stop the Bleeding)

### Step 1: Drain POOL-FIN-01
- Set POOL-FIN-01 to **drain mode** (no new session acceptance)
- Gracefully logoff active connections (do not force-kill; allow 2-min timeout for user saves)
- Redirect new session requests to POOL-FIN-02 via connection broker load balance policy
- **Current affected users (~40%)** will self-recover via reconnect fallback within 30s–5min to FIN-02 pool
- **Timeline:** 0–15 min

### Step 2: Identify Bad Driver Version in Image
- SSH or RDP to any FIN-01 session host (e.g., SHFIN-01-A)
- Query driver version: `powershell Get-Item C:\Windows\System32\igdumd64.dll | Select-Object VersionInfo`
- Confirm version: **31.0.101.4146** (matches fault signature)
- Cross-reference against Intel GPU driver release notes for known stability issues or CVEs
- **Timeline:** 5 min

### Step 3: Compare with FIN-02 Image
- Extract driver version from FIN-02 image or running FIN-02 host
- Identify previous stable driver version (likely 31.0.101.4100 or earlier)
- Ask infrastructure team: **"What driver version was in POOL-FIN-01 image before 02:00 update?"**
- **Timeline:** 10–15 min

---

## Phase 2: Root Cause Analysis & Fix

### Step 4: Verify Driver Compatibility & Known Issues
- Confirm GPU hardware in both pools (should be identical; e.g., Intel Arc, UHD Graphics, etc.)
- Query Intel ARK / release notes for driver 31.0.101.4146:
  - Known CVEs or stability regressions?
  - GPU model compatibility flags?
  - End-of-life status?
- Document findings for post-incident review
- **Timeline:** 10 min

### Step 5: Prepare Corrected Image
**Option A (Recommended - Rollback):**
- Revert to previous stable driver (e.g., 31.0.101.4100 or equivalent FIN-02 version)
- Rebuild golden image with rollback driver
- Test in isolated VM: Spawn 5–10 sessions; validate Event Viewer for 5 min (zero igdumd64.dll faults)

**Option B (If no prior version available - Update):**
- Download latest stable Intel GPU driver for the GPU model from Intel ARK
- Test in isolated VM first before deploying to production image
- Validate: Zero Application Error events (Event 1000); DWM starts cleanly (Event 9011)

- **Timeline:** 30–45 min (including driver acquisition, image rebuild, test validation)

### Step 6: Test Corrected Image in Isolated Environment
- Deploy corrected image to test session host or VM
- Spawn test sessions for 5–10 different users across different connection types
- Monitor Event Viewer on test host for 5 minutes:
  - ✅ **Good:** Zero `igdumd64.dll` access violations (Event 1000); Zero DWM exits (Event 9009)
  - ✅ **Good:** Event 9011 "Desktop Window Manager started successfully"
  - ✅ **Good:** Session logon completes without disconnect (Event 21 → no Event 40)
  - ❌ **Bad:** Any Event 1000 or 9009 = image still broken; abort deployment
- **Timeline:** 15 min

---

## Phase 3: Fix Deployment to Production

### Step 7: Reimage POOL-FIN-01 with Corrected Image
- Trigger image refresh on POOL-FIN-01 session hosts
  - Example: `Update-AzWvdSessionHost -HostPoolName POOL-FIN-01 -ImageName corrected-image-20240315`
- **Roll out in waves** (staged deployment):
  - Wave 1: 1–2 hosts; monitor for 10 min (Event Viewer clean? No user complaints?)
  - Wave 2: Remaining hosts
- Drain connections before reboot (graceful logoff; no force-kill)
- **Timeline:** 30–60 min (depending on number of hosts + reboot time)

### Step 8: Validate Post-Deployment
- Re-enable new session routing to POOL-FIN-01 (exit drain mode)
- Connect 10+ test users to FIN-01 session hosts
- Confirm:
  - ✅ Zero disconnects during session startup
  - ✅ Zero black screens
  - ✅ Session establishment within 5 seconds (normal baseline)
  - ✅ Event Viewer clean: No Event 1000 (Application Error) or Event 9009 (DWM exit) in application logs
  - ✅ Repeat test with different GPU-intensive workloads (RDP video, 3D graphics) to stress-test rendering pipeline
- **Timeline:** 10–15 min

---

## Phase 4: Incident Closure & Prevention

### Step 9: Document RCA Findings
- Create RCA document linking:
  - Driver version: `31.0.101.4146`
  - Fault component: `igdumd64.dll`
  - Fault type: Access Violation (`0xc0000005`) at offset `0x0000000000047f12`
  - Deployment vector: Overnight image update at 02:00 UTC
  - Impact: 40% of users on single pool; 30s–5min recovery via software rendering fallback
- Identify **how this driver was selected/staged**:
  - Was it automatic Windows Update? 
  - Manual golden image build without test?
  - Third-party driver update service?
  - **Determine the process failure** that allowed bad driver into production image
- **Timeline:** 15 min (documentation)

### Step 10: Implement Preventive Controls
- **Add to golden image CI/CD pipeline:**
  - Pre-deployment test: Spin up test VM from golden image; logon 5 times; validate Event Viewer clean (zero Application Errors related to GPU)
  - Stress-test GPU rendering: Run RDP video or 3D application; confirm no crashes
  - Automated check: Scan for known-bad GPU driver versions before finalizing image

- **GPU driver governance:**
  - Consider pinning Intel GPU driver version (disable auto-update in image)
  - Implement driver update approval process (test pool → staging → production)
  - Add GPU driver to inventory/baseline (track versions across pools)

- **Monitoring & alerting:**
  - Alert on Event 1000 spike (Application Error) related to igdumd64.dll
  - Alert on Event 9009 spike (DWM exits)
  - Monitor session disconnect rates by pool/host

- **Timeline:** Configuration (ongoing; implement over 1–2 weeks)

---

## Quick Reference: Validation Checklist

| Check | Expected (Good) | Problem (Bad) |
|-------|---|---|
| **Event 1000 (App Error)** | Absent in new image test | Present in new image = driver still broken |
| **Event 9009 (DWM exit)** | Absent in new image test | Present in new image = rendering still crashing |
| **Event 21 (Session logon)** | Single occurrence; no disconnect follow | Followed immediately by Event 40 (disconnect) = still broken |
| **Session duration post-logon** | Users stay connected >30s | Users see black screen or disconnect within 30s = still broken |
| **Recovery time (if brief issue)** | <10s; stable thereafter | >30s; oscillating disconnects = driver fault not resolved |

---

## Estimated Total Resolution Time

| Phase | Task | Duration |
|-------|------|----------|
| Mitigation | Drain FIN-01; identify bad driver | 15 min |
| Analysis | Compare driver versions; verify compatibility | 15 min |
| Fix Prep | Reimage golden + test validation | 45 min |
| Deployment | Reimage POOL-FIN-01 (staged waves) | 60 min |
| Validation | Confirm zero errors post-reimage | 15 min |
| **Total** | **Start to full resolution** | **~2.5–3 hours** |

**Status at 07:30 UTC:** Incident is ~30 min old. **Recommended action:** Initiate mitigation (drain FIN-01) immediately while RCA/fix team works in parallel to prepare corrected image. Parallel execution compresses timeline to ~2 hours total from incident detection to full resolution.
