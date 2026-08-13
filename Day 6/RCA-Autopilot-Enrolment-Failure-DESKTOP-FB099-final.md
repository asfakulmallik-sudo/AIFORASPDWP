# Root Cause Analysis (RCA)

## Incident Title
Autopilot Enrolment Failure — DESKTOP-FB099 (FINBRIDGE\rthomas)

## Incident Status
Root cause confirmed — remediation plan finalised, pending device-side action

## Incident Date
2026-08-11

## Executive Summary
DESKTOP-FB099, assigned to FINBRIDGE\rthomas, failed Autopilot enrolment at 09:18:44 with error `0x80180014` ("The device is already enrolled in MDM"). The MDM diagnostic export confirmed the device already carried a legacy manual MDM enrolment dated 2023-11-04, which conflicted with the new Autopilot enrolment attempt. As a direct consequence, 0 of 4 configuration profiles applied (`LastError 0x80070005 — Access denied` on `FinBridge-Win11-Security-Baseline`), and the Compliance Engine could not evaluate the device because enrolment never completed. Azure AD join, licensing (M365, Intune P1, Autopilot), and network connectivity to all required endpoints were all confirmed healthy, ruling out identity, licensing, and connectivity as contributing factors.

## Scope and Impact
- Affected device: DESKTOP-FB099
- Affected user: FINBRIDGE\rthomas
- Enrolment result: **Failed** — `0x80180014`
- Azure AD joined: Yes (not a contributing factor)
- Existing MDM enrolment: **Yes** — legacy manual enrolment from 2023-11-04 (root cause)
- Policy application: **Failed** — 0 of 4 profiles applied, `0x80070005 (Access denied)` on `FinBridge-Win11-Security-Baseline`
- Licensing: Correct — M365, Intune P1, and Autopilot licenses all present (ruled out)
- Network connectivity: Healthy — login.microsoftonline.com, enrollment.manage.microsoft.com, enterpriseregistration.windows.net all reachable, no proxy (ruled out)
- Business impact: single device/user blocked from completing Autopilot provisioning; device unusable for managed work until resolved

## Supporting Evidence

### MDM Diagnostic Export (2026-08-11)
- 09:18:44 — `EnrollmentStatus`: EnrollmentType Autopilot, EnrollmentState Failed, ErrorCode `0x80180014`, ErrorDescription "The device is already enrolled in MDM"
- 09:19:01 — `PolicyManager`: ProfilesAttempted 4, ProfilesApplied 0, LastError `0x80070005 (Access denied)`, FailedProfile `FinBridge-Win11-Security-Baseline`
- 09:19:45 — `ComplianceEngine`: EvaluationResult "Could not evaluate", Reason "Enrolment not complete"
- `DeviceInfo`: AzureADJoined Yes; MDMEnrolled Yes (previous enrolment); EnrolmentSource "Legacy (manual MDM enrolment, 2023-11-04)"; AutopilotProfile `FinBridge-Autopilot-Standard`; TPM 2.0 Ready; Secure Boot Enabled
- `NetworkCheck`: login.microsoftonline.com OK, enrollment.manage.microsoft.com OK, enterpriseregistration.windows.net OK, no proxy detected
- `Licensing`: M365, Intune P1, and Autopilot licenses all present

### Evidence Conclusion
The sequence is: a legacy manual MDM enrolment created on 2023-11-04 was never removed from the device → the new Autopilot enrolment attempt on 2026-08-11 collided with it, causing the MDM enrolment service to reject the request with `0x80180014` → because enrolment never completed, the device's MDM client could not take ownership of the policy CSP namespace, so all 4 configuration profiles were rejected with `0x80070005 (Access denied)` → the Compliance Engine could not evaluate the device at all, since compliance evaluation requires a completed enrolment. Identity (Azure AD join), licensing, and network connectivity were all independently confirmed healthy and are ruled out.

## Causes Considered
1. **Confirmed root cause:** Stale legacy MDM enrolment (2023-11-04) blocking the new Autopilot enrolment — directly matches the `0x80180014` description and the `DeviceInfo` record.
2. Access-denied policy push as a downstream symptom of #1 (same conflicting enrolment owning the CSP namespace) — consistent with, not separate from, the root cause.
3. Enrolment restriction / device-count limit — considered but not supported by the export (no restriction-specific error present); not pursued further as the evidence fully explains the failure without it.

## Root Cause Statement
Autopilot enrolment for DESKTOP-FB099 failed because a legacy manual MDM enrolment from 2023-11-04 was never retired before the device was targeted for Autopilot deployment. The pre-existing enrolment blocked the new enrolment attempt (`0x80180014`), which in turn prevented policy application (`0x80070005`) and compliance evaluation, since Windows permits only one active MDM enrolment per device.

---

## Remediation Plan

Each step is tagged **[Admin center only]** or **[Requires device access]** (physical or remote, e.g. via remote PowerShell/RMM — the device cannot complete this remotely through Intune alone once it's stuck in this state, since it isn't fully enrolled).

### Order of operations

1. **[Admin center only]** Confirm the duplicate/stale record: in Intune admin center, go to **Devices > All devices**, search `DESKTOP-FB099`, and confirm whether a device object exists tied to the legacy 2023-11-04 enrolment (it may show as a separate object from any Autopilot-registered hardware hash entry).
2. **[Admin center only]** If a stale device object is found, select it and choose **Retire** (or **Wipe** if company data must also be removed), then once the retire/wipe completes, **Delete** the device object from Intune so the enrolment record and any associated certificates are cleared server-side.
3. **[Admin center only]** Check **Azure AD (Entra ID) > Devices** for a corresponding device object tied to the legacy enrolment and remove/disable it if it's a duplicate of the Autopilot-registered device, so the new enrolment isn't blocked by a stale device identity.
4. **[Requires device access]** On the device itself (physical console, or remote session if still reachable), remove the local enrolment artefacts left by the legacy MDM client:
   - Go to **Settings > Accounts > Access work or school**, select the existing legacy work/school connection, and choose **Disconnect**.
   - Run `dsregcmd /status` to confirm no lingering `MDM enrollment URL` is reported.
   - If the connection cannot be removed via Settings (greyed out or "managed by your organisation" blocking it), use `MdmDiagnosticsTool.exe /? ` to run the built-in **Reset enrollment** action, or clear the enrolment certificate manually in `certlm.msc` under the Enterprise store used by MDM.
5. **[Requires device access]** Once local enrolment artefacts are cleared, trigger a clean re-enrolment: run **Autopilot Reset** (Settings > Accounts > Access work or school > Related settings, or via `systemreset.exe /autopilotreset` if scripted), or re-run OOBE from a full reset, so the device re-registers cleanly against the `FinBridge-Autopilot-Standard` profile.
6. **[Admin center only]** Confirm in Intune admin center that the device re-appears under **Devices > All devices** as a fresh Autopilot-enrolled object.

> Steps 1–3 (admin center) should be completed before steps 4–5 (device-side) to ensure no stale record re-attaches to the device mid-re-enrolment.

---

## Verification Check — confirm Autopilot completes successfully after remediation

- In Intune admin center, go to **Devices > Manage devices > Compliance > Policies** > select `FinBridge-Win11-Security-Baseline` > **Device status**, and confirm DESKTOP-FB099 now appears with an evaluated compliance state (Compliant / Not compliant / In grace period) rather than "Could not evaluate."
- Go to **Devices > All devices > DESKTOP-FB099 > Device compliance** (per-setting status) and confirm all 4 configuration profiles show **Succeeded** under **Devices > Manage devices > Configuration > \[each profile] > Device status**, replacing the prior `0 of 4 applied`.
- On the device, run `dsregcmd /status` and confirm `MDM enrollment URL` now shows the current tenant's Intune enrolment endpoint (not blank, not the legacy value).
- Re-run `MdmDiagnosticsTool.exe` to generate a fresh diagnostic export and confirm `EnrollmentState: Succeeded` with no `0x80180014`/`0x80070005` entries in the new log.

## Preventive Action — stop recurrence across the fleet

- Before enrolling any device into Autopilot as part of the Win11 migration, run a pre-check against Intune/Azure AD for an existing MDM enrolment record tied to that device's hardware hash or serial number, and retire/delete any legacy enrolment found **before** the device is shipped/re-imaged for Autopilot.
- Build this pre-check into the migration runbook as a mandatory gate (e.g. a scripted query against Graph API for existing device management records matching the target hardware hash) rather than relying on manual awareness, since legacy manual enrolments (like this 2023-11-04 record) are easy to miss when they predate the current migration project.
