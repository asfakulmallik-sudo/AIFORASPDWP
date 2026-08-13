# Analysis: Ranked Likely Causes — Finance-Win11 Startup Performance Drop

Date: 2026-08-12
Status: Draft
Based on: [DEX-Signal-Scope-Facts-Finance-Win11-Startup.md](./DEX-Signal-Scope-Facts-Finance-Win11-Startup.md)

Ranking is weighted heavily toward the 2026-08-04 02:00 security baseline deployment, since the score drop begins on the exact date of that change and the IT-Win11 comparison group — which did not receive the change — shows no equivalent drop. This is strong evidence the cause sits inside the new configuration profile itself, not an unrelated coincidental factor.

---

## 1. New Defender scan policy running at/near logon (Most likely)

**Why it fits the evidence:** The additional Defender scan policy was introduced in the exact same 02:00 deployment on 2026-08-04, the same day the median startup time jumped from 17.5s to 41.3s (+23.8s) and the score dropped 23 points. Defender scans are one of the heaviest CPU/disk consumers a device can run, and if the new policy causes a scan to kick off around logon, it would directly compete with the desktop-readiness process for resources. The IT-Win11 group, which never received this policy, shows flat scores across the same dates — ruling out a general environmental cause (e.g. patch Tuesday, network issue) and pointing specifically at something added only to Finance-Win11.

**Fastest check:** Pull Defender/MpCmdRun scan history (or Intune Endpoint Security > Antivirus reports) for a sample of Finance-Win11 devices and check scan start times against logon timestamps for 08-04 onward. If scans are clustering around logon, this is confirmed.

---

## 2. New compliance-logging startup script running synchronously (blocking logon)

**Why it fits the evidence:** The same deployment added a startup script for compliance logging. If this script is configured to run synchronously (blocking user desktop handoff until it completes) rather than asynchronously in the background, it would add a fixed delay to every affected device's startup — consistent with the drop appearing uniformly from 08-04 onward and not before. Again, IT-Win11 never received this script and shows no change, supporting a config-specific rather than environmental cause.

**Fastest check:** On one affected device, check Group Policy/Intune script execution settings (sync vs async) and look at Event Viewer under Applications and Services Logs > Microsoft > Windows > GroupPolicy (or the Intune Management Extension log) for the script's logged start/end time relative to the logon event — a multi-second gap confirms a blocking script.

---

## 3. Combined resource contention from both new components running concurrently at boot

**Why it fits the evidence:** Even if neither the scan policy nor the script alone fully explains a ~24-second delay, both were introduced in the same single deployment at the same timestamp, so a compounding effect (script and scan competing for CPU/disk I/O simultaneously during the startup window) is consistent with the magnitude and timing of the drop. The clean, unaffected comparison group still applies here, since IT-Win11 has neither component and shows no impact.

**Fastest check:** On a single test device, temporarily disable just one component (e.g. pause the Defender scan schedule or disable the script) via the same profile, reboot, and re-measure startup time against a device with both still active — isolates whether the delay is additive/compounding rather than caused by one component alone.
