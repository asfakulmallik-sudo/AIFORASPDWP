# Microsoft 365 Copilot Readiness Checklist — Finance Department

Title: M365 Copilot Readiness Checklist — Finance (~200 users)
Version: 1.0
Date: 2026-08-12
Author: DWP Engineer
Status: Draft
Scope: Finance department, ~200 users, M365 E5 (Copilot add-on not yet assigned)

## Context

- ~200 users, all licensed M365 E5; Copilot add-on **not yet assigned**.
- Data sensitivity: **High** — payroll, board packs, M&A documents, client financial data on shared drives.
- SharePoint permissions inherited from a **2019 migration**, never fully audited since.
- Because Copilot surfaces content a user can already access (including over at-risk oversharing), permissions/oversharing must be treated as a **blocking prerequisite**, not a parallel task. **No Copilot licenses should be assigned to this department until Priority 0 below is signed off.**

---

## Priority 0 (Blocking) — SharePoint/OneDrive Permissions & Oversharing

This is the highest-risk area for this rollout and must be completed and signed off before any Copilot licence is assigned.

- [ ] Run a full permissions inventory across all Finance SharePoint sites and OneDrive accounts (e.g. SharePoint Advanced Management / access reviews, or Purview data assessment) — do not rely on the 2019 migration state as accurate.
- [ ] Identify and report all **"Everyone" / "Everyone except external users" / broad "Company-wide" or "All Users" shares** on Finance sites and document libraries.
- [ ] Identify all links shared as **"Anyone with the link"** (anonymous) and **"People in [organisation]"** links across Finance content; inventory before deciding whether to remove or restrict.
- [ ] Identify **direct/individual sharing grants** that bypass the site's owner/member/visitor group structure (a common by-product of ad-hoc migrations).
- [ ] Confirm **inherited vs broken permission inheritance** on every Finance library/folder — flag folders with unique permissions inherited unchanged since 2019.
- [ ] Reconcile SharePoint/OneDrive group membership against **current** Finance org structure — remove access for leavers, movers, and contractors whose access was never revoked.
- [ ] Specifically locate and lock down access to **payroll, board packs, M&A, and client financial data** libraries — confirm these are restricted to named, current-need groups only (not broad Finance-wide access).
- [ ] Check for and remediate **guest/external user access** to any Finance site inherited from the 2019 migration.
- [ ] Run Microsoft's **SharePoint oversharing/"site access review"** report (or equivalent Purview content search) to quantify how many items are broadly shared before/after remediation, to evidence progress.
- [ ] Apply **restricted content discoverability** (e.g. Restricted SharePoint Search / Restricted Content Discovery) for the highest-sensitivity libraries (M&A, board packs) as a control independent of permissions cleanup, given Copilot's ability to surface content in chat responses.
- [ ] Re-run the permissions inventory **after** remediation and obtain written sign-off from Finance data owner + Information Security before proceeding to licence assignment.

---

## Priority 1 — Licensing Prerequisites

- [ ] Confirm all ~200 users hold an active **M365 E5** licence (already confirmed) — verify none are on a stripped-down or trial variant.
- [ ] Confirm **Microsoft 365 Copilot** add-on SKUs are available/procured but **not yet assigned** to any Finance user (per current state).
- [ ] Confirm prerequisite licence dependencies for Copilot (e.g. Entra ID P1/P2, Purview components) are active — largely covered by E5, but verify no add-on has been unassigned/downgraded.
- [ ] Define and agree the **assignment order**: Priority 0 sign-off → pilot group → phased rollout — do not bulk-assign to all 200 users at once.
- [ ] Identify a small **pilot group** (e.g. 5–10 users spanning payroll, FP&A, and treasury) for first assignment once P0 is signed off.

---

## Priority 2 — Microsoft 365 Apps Client Version Requirements

- [ ] Confirm target devices are on **Microsoft 365 Apps for enterprise (Current Channel or Monthly Enterprise Channel)** — Copilot in Word/Excel/PowerPoint/Outlook requires a currently-supported build, not perpetual/volume-licensed Office.
- [ ] Verify minimum build levels for Copilot in each app (Word, Excel, PowerPoint, Outlook, Teams) against current Microsoft requirements at rollout time (version requirements change — confirm live, do not rely on this document being current).
- [ ] Confirm Finance devices are not pinned to an old **Semi-Annual Enterprise Channel** build that lags behind Copilot's minimum version.
- [ ] Confirm **Teams** client is on the required version for Copilot in Teams meetings/chat.
- [ ] Check for any **VDI/AVD** Finance users (if applicable) and confirm the Cloud PC/AVD image meets the same client version bar.
- [ ] Schedule an update ring/deployment ring check to bring any lagging Finance devices current before pilot assignment.

---

## Priority 3 — Identity & MFA Readiness

- [ ] Confirm **MFA is enforced** for all Finance users (Conditional Access or Security Defaults) — no exemptions for this high-sensitivity group.
- [ ] Confirm **Conditional Access** policies covering Finance apply to Copilot experiences (Copilot rides on existing app/data access, so CA gaps carry through).
- [ ] Review any **legacy authentication** or break-glass accounts in Finance and confirm they are blocked/monitored.
- [ ] Confirm **device compliance** (Intune) is required for Finance sign-in where CA policy depends on device state.
- [ ] Review **Privileged/Global Admin accounts** that also hold Finance data access — confirm they follow least-privilege and are not swept into Copilot access unnecessarily.

---

## Priority 4 — Sensitivity Labelling

- [ ] Confirm **sensitivity labels** (Purview Information Protection) are published and available to Finance users, with a default label applied at creation for new content.
- [ ] Audit existing payroll, board pack, M&A, and client financial documents for **label coverage** — flag unlabelled high-sensitivity content for retroactive labelling/auto-labelling policy.
- [ ] Confirm label-based **encryption/access restrictions** are configured for the highest-sensitivity labels (e.g. "Highly Confidential — Board/M&A") so protection travels with the document regardless of where it's shared.
- [ ] Confirm **DLP policies** exist for payroll and client financial data to prevent oversharing via Copilot-generated content (e.g. summaries pasted into email/Teams).
- [ ] Test that Copilot **respects and surfaces sensitivity labels** correctly in a pilot before wider rollout (e.g. labelled content is not summarised/exposed beyond the label's access rules).

---

## Priority 5 — End-User Comms & Enablement

- [ ] Prepare a plain-language comms note for Finance explaining what Copilot is, what it can access (their own permitted content only), and what changed as a result of the permissions cleanup.
- [ ] Set expectations that **some previously-visible files may no longer appear** post-remediation, and provide a clear route to request access back if legitimately needed.
- [ ] Provide a short **enablement/training session** covering safe use of Copilot with sensitive financial data (e.g. do not paste Copilot outputs containing payroll/M&A data into unapproved channels).
- [ ] Nominate **Finance champions/pilot users** to gather feedback and surface issues before full department rollout.
- [ ] Publish a simple **self-service FAQ/KB** (access changes, how to request access, who to contact) ahead of pilot go-live.
- [ ] Confirm a **feedback/issue-reporting channel** is in place for the pilot group before expanding to all ~200 users.

---

## Sign-off before licence assignment

| Area | Owner | Status |
|---|---|---|
| Priority 0 — Permissions & oversharing remediation | Finance data owner + InfoSec | ☐ Not signed off |
| Priority 1 — Licensing | IT licensing | ☐ Not signed off |
| Priority 2 — Client versions | Endpoint engineering | ☐ Not signed off |
| Priority 3 — Identity/MFA | Identity/Security team | ☐ Not signed off |
| Priority 4 — Sensitivity labelling | InfoSec/Compliance | ☐ Not signed off |
| Priority 5 — Comms/enablement | Finance change lead | ☐ Not signed off |

**Do not assign Copilot licences to any Finance user until Priority 0 is signed off.** Remaining priorities can progress in parallel but should also be complete before the wider 200-user rollout.
