# Microsoft 365 Copilot Readiness — Rollout Tiering (Finance)

Title: Copilot Readiness Checklist — Rollout Tiering & Justification
Version: 1.0
Date: 2026-08-12
Author: DWP Engineer
Status: Draft
Source: Derived from [Copilot-Readiness-Checklist-Finance.md](./Copilot-Readiness-Checklist-Finance.md)
Scope: Finance department, ~200 users, M365 E5, Copilot add-on not yet assigned

## Purpose

Re-ranks every item from the Finance Copilot readiness checklist into three tiers by rollout risk, so the team can sequence work realistically instead of treating all items as equally urgent.

---

## Tier 1 — MUST complete before rollout (blocking)

No Copilot licence is assigned to any Finance user until every item below is done and signed off.

- [ ] Full SharePoint/OneDrive permissions inventory across all Finance sites and OneDrive accounts.
- [ ] Identify and remediate all "Everyone" / "Everyone except external users" / company-wide shares on Finance sites.
- [ ] Identify and remediate "Anyone with the link" (anonymous) and "People in [organisation]" links on Finance content.
- [ ] Identify direct/individual sharing grants that bypass site owner/member/visitor groups.
- [ ] Confirm inheritance state on every Finance library/folder; flag anything unique/unchanged since 2019.
- [ ] Reconcile group membership against current Finance org structure; remove leavers/movers/contractor access.
- [ ] Lock down payroll, board pack, M&A, and client financial data libraries to named, current-need groups.
- [ ] Check for and remediate guest/external access inherited from the 2019 migration.
- [ ] Run the oversharing/site access review report to quantify before/after remediation.
- [ ] Apply restricted content discoverability to the highest-sensitivity libraries (M&A, board packs).
- [ ] Re-run the permissions inventory post-remediation and obtain written sign-off from Finance data owner + InfoSec.
- [ ] Confirm MFA is enforced for all Finance users with no exemptions.
- [ ] Confirm Conditional Access covers Finance apps/data that Copilot will ride on.

---

## Tier 2 — SHOULD complete before rollout (high risk if skipped)

Not individually blocking, but skipping these creates material risk that should be closed before the wider 200-user rollout, ideally before or alongside the pilot.

- [ ] Confirm sensitivity labels are published and a default label applies to new Finance content.
- [ ] Audit existing payroll/board pack/M&A/client documents for label coverage; flag unlabelled high-sensitivity content.
- [ ] Confirm label-based encryption/access restrictions on the highest-sensitivity labels.
- [ ] Confirm DLP policies exist for payroll and client financial data to prevent Copilot-output oversharing.
- [ ] Test that Copilot respects sensitivity labels correctly in the pilot before wider rollout.
- [ ] Review legacy authentication/break-glass accounts in Finance.
- [ ] Review device compliance requirements for Finance sign-in.
- [ ] Review privileged/admin accounts that also hold Finance data access.
- [ ] Prepare the plain-language comms note explaining what Copilot can access and what changed post-remediation.
- [ ] Set expectations that some previously-visible files may disappear post-remediation, with a route to request access back.
- [ ] Nominate Finance champions/pilot users and confirm a feedback/issue channel before expanding beyond the pilot.

---

## Tier 3 — CAN complete during/after rollout (lower risk)

Reasonable to finish in parallel with, or shortly after, initial (pilot) licence assignment — these don't materially change the risk of data exposure on day one.

- [ ] Confirm all ~200 users hold active M365 E5 (already confirmed) and verify no stripped-down/trial variants.
- [ ] Confirm Copilot add-on SKUs are procured; agree phased assignment order (pilot → wider rollout).
- [ ] Confirm prerequisite licence dependencies (Entra ID P1/P2, Purview components) are active.
- [ ] Identify the initial pilot group (5–10 users).
- [ ] Confirm devices are on Microsoft 365 Apps for enterprise (Current/Monthly Enterprise Channel), not perpetual/volume Office.
- [ ] Verify minimum build levels for Copilot in Word/Excel/PowerPoint/Outlook/Teams.
- [ ] Confirm no devices are pinned to a lagging Semi-Annual Enterprise Channel build.
- [ ] Confirm Teams client version meets the Copilot requirement.
- [ ] Check any VDI/AVD Finance image meets the same client version bar.
- [ ] Schedule update-ring remediation for lagging devices.
- [ ] Deliver the enablement/training session on safe Copilot use with sensitive data.
- [ ] Publish the self-service FAQ/KB on access changes and how to request access.

---

## Why permissions/oversharing is MUST and not just "high priority"

Licensing and client version checks are simpler to verify, but simplicity of verification is not the same as low risk if skipped — the two sit on different axes:

1. **Direction of failure is asymmetric.** If licensing or client version is wrong, Copilot simply doesn't work for a user yet — a visible, self-limiting, reversible failure with no data consequence. If permissions/oversharing is wrong, Copilot *does* work, and it correctly-but-harmfully surfaces payroll, board pack, M&A, and client financial data to anyone who technically has standing access — a silent failure that only becomes visible after exposure has already happened.

2. **Copilot changes the exploitation cost of existing oversharing, not just its existence.** The 2019-migration permissions have arguably been "wrong" for years, but that risk was previously bounded by the practical effort of a person manually finding and opening the right file. Copilot removes that friction — it can search, summarise, and surface any content a user's account can technically reach, in natural language, in seconds. The oversharing risk is not new, but Copilot is the trigger that converts a latent/theoretical exposure into an active one, on day one of rollout.

3. **The failure is not user-visible or self-reporting.** A user with a broken licence or an outdated Office build knows immediately (Copilot button is missing/greyed out) and will report it. A user who receives a Copilot summary containing board-pack or M&A content they were never supposed to see may not even recognise this as a problem, may forward it, or may act on it — there is no built-in signal that triggers a fix. Licensing/client-version issues are self-diagnosing; oversharing exposure is not.

4. **Blast radius and reversibility differ enormously.** A licensing gap affects one user until fixed in minutes. An oversharing exposure via Copilot can affect regulatory/legal standing (M&A confidentiality, payroll/PII, client financial data under contractual confidentiality) and, once information has been seen, forwarded, or acted on, cannot be "unshared" — this is a compliance and potential legal event, not an IT ticket.

5. **This specific department has known, unaudited risk.** This is not a generic Copilot rollout; the SharePoint estate has inherited, unaudited permissions since 2019 specifically in a high-sensitivity Finance context. Treating permissions as "one line among many" would mean rolling out Copilot into an environment already flagged as having an unknown quantity of broad/legacy access — a foreseeable and avoidable failure, not a hypothetical one.

**Conclusion:** licensing and client version gate *whether Copilot runs*; permissions/oversharing gates *what Copilot is allowed to expose once it runs*. For a Finance department holding payroll, board packs, M&A, and client financial data, the second risk category is the one with irreversible, regulatory-grade consequences — which is why it sits in Tier 1 (MUST) while licensing and client version sit in Tier 3 (CAN), despite being technically easier to check.
