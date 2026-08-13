# Phased Intune Deployment Plan — FinBridge Connect v3.1

Title: Phased Rollout Plan for FinBridge Connect v3.1 (10,000 Win11 Endpoints)
Version: 1.0
Date: 2026-08-12
Author: DWP Endpoint Engineer
Status: Draft

App: **FinBridge Connect v3.1** (`.intunewin`, already uploaded to the app catalog). Detection rule: registry version string check. Previous version **v3.0** remains in the catalog and is the rollback target.

Fleet: 10,000 Win11 endpoints. Deadline: 3 weeks (21 calendar days) from today.

Known constraints:
- Finance (500 users) require the app live by end of week 1 — highest business priority.
- ~5% of the fleet (≈500 devices) run 4GB RAM and may struggle to meet v3.1 requirements — treated as an at-risk hardware group throughout.

---

## 1. Ring Structure

| Ring | Size | Duration | Who's included | Purpose | Intune assignment group type |
|---|---|---|---|---|---|
| **Ring 1 — Pilot** | ~150 devices (1.5% of fleet) | Days 1–3 (72 hrs monitoring minimum) | IT/Endpoint Engineering volunteers, a small cross-section of departments, and a deliberately included sample of ~20–25 of the known 4GB RAM devices | Validate packaging, install command, detection rule accuracy, and uninstall path in production before wider exposure. Surface showstopper bugs while blast radius is small. | **Static (assigned) Azure AD group** — e.g. `SG-Intune-Pilot-FinBridge-Ring1`, manually curated device membership so pilot composition is controlled, not dynamic |
| **Ring 2 — Early adopters** | ~1,800 devices (~18% of fleet) | Days 4–10 (min. 5 days monitoring) | Broader mix of departments/locations, including Finance (500 users — see Section 4), remaining low-risk 4GB RAM devices not in Ring 1 | Confirm the app behaves at scale across varied hardware/network conditions and real business workloads before full-fleet exposure | **Dynamic Azure AD group** per department/OU attribute (e.g. `memberOf` department groups), assigned as one combined Ring 2 group in Intune |
| **Ring 3 — Broad** | Remaining ~8,050 devices (~80% of fleet) | Days 11–21, deployed in 2–3 waves by site/OU to avoid a single big-bang cutover | All remaining endpoints not already in Ring 1/2 and not excluded for hardware/rollback reasons | Complete fleet-wide deployment to the 3-week deadline | **"All devices" assignment with an exclusion group** — exclude Ring 1/2 (already covered), and exclude any device group isolated under Section 3's 4GB RAM trigger |

Rationale for sizing: Ring 1 stays under 2% so a bad build only affects a small, easily-supported population; Ring 2 is large enough to be statistically meaningful (catches issues that only show up at scale) while still leaving 10+ days of runway for Ring 3; Ring 3 is split into waves rather than one push so Intune reporting/Service Desk load stays manageable across 8,000 devices.

---

## 2. Advance Criteria

| Criterion | Ring 1 → Ring 2 | Ring 2 → Ring 3 |
|---|---|---|
| **Install success rate** | ≥ 95% of Ring 1 devices show "Installed" in Intune app reporting | ≥ 97% of Ring 2 devices show "Installed" |
| **Error rate (max)** | ≤ 5% of Ring 1 devices in "Failed" or "Error" state | ≤ 3% of Ring 2 devices in "Failed" or "Error" state |
| **User-reported issues (max)** | ≤ 2 Service Desk tickets per 100 devices (≤ 2%) referencing FinBridge Connect | ≤ 1 ticket per 100 users (≤ 1%) referencing FinBridge Connect |
| **Monitoring period (min)** | 72 hours from last device install in the ring | 5 business days from last device install in the ring |

All four criteria must be met simultaneously, measured directly from Intune's **Apps > Monitor > App install status** report plus a Service Desk ticket pull tagged to FinBridge Connect — no subjective sign-off. If any single criterion misses, the ring does not advance until re-measured and passing.

**Hold condition (pause without full rollback):** If install success sits between 90%–95% (below the advance bar but not at rollback severity — see Section 3) and the failures cluster around a single identifiable cause, **pause expansion to the next ring** — do not add new devices — but leave already-successful installs in place while the cause is investigated.
*Example:* Ring 1 reports 92% success, with the 8% failures traced to the detection rule mis-reading the registry version string on a specific OEM firmware batch. Rollout to Ring 2 is paused, the detection logic is corrected and re-validated against the affected batch, and only then does the ring re-enter the advance evaluation — Ring 1's successful installs are not touched.

---

## 3. Rollback Triggers

| Trigger | Threshold & timeframe | Decision maker | Decision window | Intune action |
|---|---|---|---|---|
| **Install failure rate** | ≥ 15% failure across any ring within 24 hours of deployment starting | Endpoint Engineering Lead (on-call) | Immediate — halt is automatic, confirmation within 1 hour | Set the affected ring's assignment group to **v3.1 Required → Not assigned / Removed**; no new installs proceed until reviewed |
| **Application crash rate** | ≥ 5% of installed devices reporting app crashes (via Endpoint analytics / Company Portal feedback / ticket volume) within 48 hours | Change Advisory Board (CAB), advised by Service Owner | 4 hours from threshold breach to decision | If confirmed: reassign affected device group from **FinBridge Connect v3.1 (Required)** to **v3.1 (Uninstall)** and add **FinBridge Connect v3.0 (Required)** |
| **Business-critical failure** | Any single instance of FinBridge Connect v3.1 blocking Finance transaction processing or corrupting/losing financial data — triggers immediate rollback regardless of % of devices affected | Service Owner + Finance Business Lead (joint, no CAB wait) | 2 hours — this is the fastest-track trigger in the plan | Immediately reassign the impacted device group (Finance Ring 0/Ring 2 group) to **v3.0 Required + v3.1 Uninstall**; notify affected users |
| **4GB RAM device failures** | ≥ 20% install failure or crash rate within the 4GB RAM device group specifically (tracked as its own filtered Intune report, not blended into the ring-wide %) | Endpoint Engineering Lead | 24 hours from threshold breach | **Isolate, don't rollback the whole ring**: create/confirm a dedicated `SG-Intune-4GBRAM-AtRisk` device group, exclude it from the v3.1 assignment, add it to **v3.0 Required**, and flag the group for a hardware-upgrade/replacement backlog before re-attempting v3.1 |

General rule for execution: rollback is always performed by editing the **app assignment**, not by uninstalling manually device-by-device — move the target group off v3.1 (Uninstall or unassigned) and onto v3.0 (Required), so Intune's own install/uninstall cycle handles the revert consistently and is auditable in reporting.

---

## 4. Finance Deadline Resolution

The ring plan in Section 1 places Finance inside Ring 2 (Days 4–10), which satisfies "by end of week 1" only at the earliest edge and leaves no buffer if Ring 1 slips. Two options were evaluated:

### Option A — Compress the pilot to land Finance in Ring 2 by end of week 1
- **Minimum safe pilot duration:** 3 full days (72 hours) is the floor — this is already the minimum used in Section 2 and cannot be safely compressed further, because several known failure modes (background sync timeouts, periodic license checks, second-login profile issues) only surface after a device has been through at least one full working day plus a restart cycle.
- **Risk introduced:** Compressing below 72 hours risks advancing Ring 1 before delayed-onset issues appear, meaning Finance (a business-critical, low fault-tolerance group) would be among the first to hit an undetected defect at day 4–5.
- **Compensating control:** If Option A is chosen, add real-time monitoring checkpoints every 4 hours during the pilot (instead of a single end-of-window review) and seed 10–15 Finance power users into Ring 1 itself as an early canary — so any Finance-specific issue is caught inside the controlled pilot population rather than after Finance moves to Ring 2.

### Option B — Treat Finance as a separate Ring 0, ahead of the main pilot
- **Structure:** Ring 0 = the 500 Finance devices/users, run in parallel with (not merged into) Ring 1. Within Ring 0 itself, stage it further: 25–50 Finance devices on Day 1–2 (a mini-pilot), then the remaining ~450 on Day 3–5 once the mini-pilot is clean — completing all of Finance inside week 1, independent of how the general-fleet Ring 1/2 timeline plays out.
- **Advance conditions:** Same measurable bar as Section 2 (≥95% install success, ≤5% error rate, ≤2% ticket rate) but evaluated on a tighter 24-hour cadence given the business deadline, using Ring 0's own filtered Intune report so Finance results are never blended with the general pilot.
- **Rollback plan:** Because Ring 0 is business-critical by definition, it inherits the Section 3 "business-critical failure" trigger as its primary rollback path (2-hour decision window, joint Service Owner + Finance Business Lead call) — Finance is reassigned to v3.0 Required + v3.1 Uninstall independently of whatever state the rest of the fleet is in.

### Recommendation
**Adopt Option B.** Running Finance as its own Ring 0 meets the week 1 deadline without touching the minimum safe 72-hour duration that the whole ring strategy (Section 2) depends on — compressing Ring 1 under Option A would weaken the one control that catches delayed-onset defects for *every subsequent ring*, not just Finance. Option B instead gives Finance a dedicated, tightly monitored, fast-rollback path suited to its business-critical status, while leaving Ring 1/2/3 timing and rigor for the remaining 9,500 devices completely intact.
