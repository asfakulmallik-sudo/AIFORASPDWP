# DEX Signal Scope Facts — Finance-Win11 Startup Performance

Date: 2026-08-12
Status: Draft

## Scope Facts

**Affected device group:** Finance-Win11 — 215 devices.

**What changed and when:** 2026-08-04 at 02:00 — a new security baseline configuration profile (startup script added for compliance logging, plus an additional Defender scan policy) was deployed to the Finance-Win11 group only.

**Magnitude of score drop:**
- Median startup time rose from 17.5 sec (2026-08-03, pre-change) to 41.3 sec (2026-08-04, day of change) — an increase of 23.8 seconds, and remained elevated at 43.8 sec (08-05) and 42.1 sec (08-06).
- DEX score fell from 84 (08-03) to 61 (08-04), a drop of 23 points, and stayed depressed at 59 (08-05) and 60 (08-06).

**Unaffected comparison group:** IT-Win11 — 40 devices, not in scope for the config change. Its scores stayed stable across the same window: 85 (08-03), 84 (08-04), 85 (08-05) — no equivalent startup-time or score degradation.
