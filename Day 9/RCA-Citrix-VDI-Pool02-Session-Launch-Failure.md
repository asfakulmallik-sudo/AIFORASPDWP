# Root Cause Analysis (RCA): Citrix VDI Session Launch Failure — FinBridge-VDI-Pool-02

## Incident Summary
- **Affected pool:** FinBridge-VDI-Pool-02 — 22 of 30 users unable to launch sessions.
- **Unaffected pool:** FinBridge-VDI-Pool-01 (same site, different pool, different Delivery Controller).
- **Symptom:** Session launches for Pool-02 timed out waiting for machine registration and failed with broker error 1030 ("No machines available in the desktop group").
- **Underlying condition:** dc-vdi-02, the Delivery Controller serving Pool-02, had its Citrix Broker Service stopped, and 22 of 25 Pool-02 machines could not register with it.

## Supporting Evidence

### Citrix Session Broker Log
```
Affected      : 22 of 30 users on FinBridge-VDI-Pool-02
Unaffected    : FinBridge-VDI-Pool-01 (same site, different pool)

[08:58:03] Session launch requested: user jsmith, Pool-02
[08:58:04] Broker: Querying available machines in Pool-02
[08:58:34] Broker: Timeout waiting for machine registration response (30000ms exceeded)
[08:58:34] Session launch FAILED: error 1030 'No machines available in the desktop group'
```

### Delivery Controller Machine Catalog Status
```
Pool-02 catalog       : 25 machines provisioned
  Registered          : 3
  Unregistered        : 22
  Maintenance mode     : 0

Pool-01 catalog       : 20 machines provisioned
  Registered          : 19
  Unregistered        : 1
```

### Unregistered Machine Detail (sample, Pool-02)
```
VDI-P02-014: Last registration attempt 06:15:22, failed
  Error: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 - connection refused

VDI-P02-017: Last registration attempt 06:16:01, failed
  Error: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 - connection refused
```

### Delivery Controller Health
```
dc-vdi-02 (serves Pool-02):
  Service 'Citrix Broker Service' : STOPPED
  Last known running               : yesterday 23:40
  Windows Update installed        : today 00:15 (reboot required flag set, host not rebooted)

dc-vdi-01 (serves Pool-01):
  Service 'Citrix Broker Service' : RUNNING
  Uptime                            : 14 days
```

## Timeline of Events

| Time | Event |
|---|---|
| Yesterday 23:40 | Citrix Broker Service on dc-vdi-02 last confirmed running. |
| Today 00:15 | Windows Update installed on dc-vdi-02; reboot-required flag set. Host is **not** rebooted. |
| 06:15:22 | VDI-P02-014 attempts registration with dc-vdi-02; fails — "connection refused" on port 80. |
| 06:16:01 | VDI-P02-017 attempts registration with dc-vdi-02; fails — "connection refused" on port 80. |
| (ongoing, unspecified times) | 22 of 25 Pool-02 machines fail to register with dc-vdi-02; only 3 remain registered. |
| 08:58:03 | User jsmith requests a session launch on Pool-02. |
| 08:58:04 | Broker queries available machines in Pool-02. |
| 08:58:34 | Broker registration query times out after 30,000ms. |
| 08:58:34 | Session launch fails with broker error 1030, "No machines available in the desktop group." |

## 5-Whys Analysis

### Problem Statement
22 of 30 users on FinBridge-VDI-Pool-02 could not launch VDI sessions; the broker reported a registration timeout and error 1030 ("No machines available in the desktop group").

1. **Why did the session launch fail with error 1030?**
   - Because the broker queried Pool-02 for available machines and found almost none registered (3 of 25), so it had no machine to allocate to the incoming session request, timing out after 30 seconds.

2. **Why were 22 of 25 Pool-02 machines unregistered?**
   - Because those VDAs could not contact their Delivery Controller, dc-vdi-02, on port 80 — every registration attempt returned "connection refused."

3. **Why was dc-vdi-02 refusing connections on port 80?**
   - Because the Citrix Broker Service on dc-vdi-02 was stopped (last running yesterday 23:40), so nothing was listening on the port to accept VDA registration requests.

4. **Why was the Citrix Broker Service stopped?**
   - Most likely because a Windows Update installed on dc-vdi-02 at 00:15 required a reboot to complete, and the service was left in a stopped/incomplete state pending that reboot — which never occurred.

5. **Why did the host go unrebooted and the stopped service go unnoticed for over 8 hours (00:15 to 08:58)?**
   - Because there is no evidence of automated reboot enforcement after patching, nor active monitoring/alerting on the Citrix Broker Service state, so the outage was only surfaced reactively when users attempted to launch sessions at 08:58.

## Root Cause
**Primary root cause:** A Windows Update applied to dc-vdi-02 at 00:15 required a reboot that was never performed, leaving the Citrix Broker Service on dc-vdi-02 stopped. This prevented the majority of Pool-02 VDAs from registering with their Delivery Controller (connection refused on port 80), leaving only 3 of 25 machines registered. When users attempted to launch sessions at 08:58, the broker could not find sufficient registered machines in the desktop group, timed out, and returned error 1030.

**Contributing factors:**
- No automated reboot enforcement/scheduling following Windows Update installation on Delivery Controllers.
- No active service-health monitoring/alerting on the Citrix Broker Service, allowing the outage to persist undetected for roughly 8+ hours before user impact was reported.
- Pool-02 had no apparent controller redundancy/failover that could have kept machines registered when dc-vdi-02 became unavailable (unlike Pool-01, which remained healthy on dc-vdi-01).

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
1. Confirm no conflicting maintenance is in progress on dc-vdi-02.
2. Reboot dc-vdi-02 to cleanly complete the pending Windows Update.
3. Confirm the Citrix Broker Service is `RUNNING` after reboot.
4. Confirm dc-vdi-02 shows as Active/OK in Citrix Studio's Delivery Controller state.
5. Trigger/confirm VDA re-registration for Pool-02 (restart Citrix Desktop Service on sample machines VDI-P02-014/017 if they do not auto re-register).
6. Confirm Pool-02 catalog returns to 25/25 registered, 0 unregistered.
7. Perform a test session launch on Pool-02 to confirm error 1030 no longer occurs.

### Verification Check
Pool-02 machine catalog shows 0 unregistered machines, dc-vdi-02 Broker Service is `RUNNING` with stable uptime, and a test session launch succeeds without a registration timeout or error 1030.

### Preventive Actions
- **Monitoring/alerting:** Add active monitoring on Citrix Broker Service state for all Delivery Controllers, alerting on service stop within minutes rather than relying on user-reported impact.
- **Patch/reboot management:** Enforce automatic or scheduled reboots after Windows Update installs a patch requiring a restart (e.g., via WSUS/Intune reboot enforcement policy), so controllers do not sit for hours with a pending-reboot flag set.
- **Redundancy review:** Evaluate whether Pool-02's desktop group should be configured with multiple Delivery Controllers for failover, similar to how Pool-01 remained unaffected.
- **Post-patch validation:** Add a post-patch health check step (service status + Studio state) to the Delivery Controller patching runbook before marking maintenance complete.
