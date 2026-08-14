# Analysis: Citrix VDI Session Launch Failure — FinBridge-VDI-Pool-02

## 1. Scope Facts (from logs)

- **Affected pool:** FinBridge-VDI-Pool-02 — 22 of 30 users affected.
- **Unaffected pool:** FinBridge-VDI-Pool-01 (same site, different pool).
- **Exact broker error:** `error 1030 'No machines available in the desktop group'`, preceded by "Timeout waiting for machine registration response (30000ms exceeded)."
- **Machine catalog registration status:**
  - Pool-02 (affected): 25 machines provisioned — 3 registered, 22 unregistered, 0 in maintenance mode.
  - Pool-01 (unaffected): 20 machines provisioned — 19 registered, 1 unregistered.
- **Unregistered machine detail (Pool-02 sample):** VDI-P02-014 and VDI-P02-017 both last attempted registration around 06:15–06:16, failing with "Unable to contact Delivery Controller" — `dc-vdi-02.finbridge.local:80 - connection refused`.
- **Delivery Controller health:**
  - dc-vdi-02 (serves Pool-02): Citrix Broker Service **STOPPED**; last known running yesterday 23:40; Windows Update installed today 00:15 with reboot-required flag set, host not rebooted.
  - dc-vdi-01 (serves Pool-01): Citrix Broker Service **RUNNING**; uptime 14 days.

## 2. Ranked Likely Causes

| Rank | Cause | Why it fits the evidence | Fastest check | Remediation if confirmed |
|---|---|---|---|---|
| 1 (most probable) | Citrix Broker Service stopped on dc-vdi-02 | dc-vdi-02 (controller for Pool-02) shows Broker Service `STOPPED`; unregistered VDAs get "connection refused" on port 80 to dc-vdi-02 — the expected symptom of a non-listening service; unregistered count (22) closely matches affected users (22); Pool-01 (healthy dc-vdi-01) unaffected | `Get-Service` for Broker Service on dc-vdi-02; check Citrix Studio Delivery Controller state | Start Citrix Broker Service on dc-vdi-02; confirm VDA re-registration |
| 2 (contributing) | Windows Update installed with reboot-required flag, host not rebooted | Update installed at 00:15 on dc-vdi-02 with reboot-required flag still set and no reboot performed; plausible cause of the service being left stopped; timing precedes first failed VDA registration attempts (06:15) | Review Windows Update history / pending-reboot registry flag on dc-vdi-02; check System event log 00:15–06:15 for service stop/crash tied to the update | Complete the pending reboot on dc-vdi-02 rather than only restarting the service |
| 3 (less likely) | Network/firewall blocking port 80 to dc-vdi-02 | "Connection refused" on port 80 could also indicate a firewall/ACL block rather than a stopped service | `Test-NetConnection dc-vdi-02 -Port 80` from an affected VDA; review firewall rules/ACLs on dc-vdi-02 | Correct the firewall rule/ACL blocking the port |

**Note on error code:** The meaning of "error 1030" is taken at face value from the log message text ("No machines available in the desktop group"); the official Citrix error-code numbering was not independently verified.

**Ranking basis:** Rank 1 has direct, confirmed evidence (service state + connection-refused pattern + registration counts all align, and the unaffected pool's controller is healthy). Rank 2 most plausibly explains *why* Rank 1 occurred. Rank 3 is a plausible alternative but less consistent, since a stopped service alone already fully explains "connection refused."

## 3. Finalized Hypothesis

**Root cause:** The Citrix Broker Service on dc-vdi-02 stopped — most likely as a result of a Windows Update requiring a reboot that was never performed — preventing Pool-02 VDAs from registering with their Delivery Controller and causing the broker to report no available machines for session launches.

## 4. Remediation Plan

### Order of Operations
1. Confirm no conflicting maintenance is in progress on dc-vdi-02.
2. Reboot dc-vdi-02 to cleanly complete the pending Windows Update (preferred over a bare service restart, since the reboot-required flag is set).
3. After reboot, confirm the Citrix Broker Service is `RUNNING` (`Get-Service`).
4. Confirm dc-vdi-02 shows as Active/OK in Citrix Studio's Delivery Controller state.
5. Allow/trigger VDA re-registration for Pool-02; if sample machines (VDI-P02-014, VDI-P02-017) don't auto re-register, restart the Citrix Desktop Service on them.
6. Confirm Pool-02 catalog registration count returns to 25/25 registered, 0 unregistered.
7. Perform a test session launch on Pool-02 (e.g., as jsmith) to confirm the broker no longer returns error 1030.

### Verification Check
Pool-02 machine catalog shows 0 unregistered machines, dc-vdi-02 Broker Service is `RUNNING` with stable uptime, and a test session launch succeeds without a registration timeout or error 1030.

### Preventive Action
Add monitoring/alerting on Citrix Broker Service state for all Delivery Controllers, and enforce automatic/scheduled reboot after patching (via WSUS/Intune reboot enforcement) so a controller doesn't sit for hours with a pending-reboot flag and a stopped critical service.
