# Root Cause Analysis (RCA)

## Incident Title
Autopilot Enrolment Failure — DESKTOP-FB099 (FINBRIDGE\rthomas)

## Incident Status
Root cause confirmed — remediation plan finalised, pending device-side action

## Incident Date
2026-08-11

## Resolution Time
Pending — remediation plan issued, device-side action not yet executed at time of writing

## Executive Summary
At 09:18:44 on 2026-08-11, Autopilot enrolment for DESKTOP-FB099 (user FINBRIDGE\rthomas) failed with error `0x80180014` ("The device is already enrolled in MDM"). The MDM diagnostic export confirmed the device carried a legacy manual MDM enrolment dated 2023-11-04 that was never retired before the device was targeted for Autopilot deployment as part of the Win11 migration. Because the legacy enrolment was still active, the new Autopilot enrolment attempt collided with it and was rejected — Windows permits only one active MDM enrolment per device. As a direct consequence, 0 of 4 configuration profiles applied (`0x80070005 Access denied` on `FinBridge-Win11-Security-Baseline`), and the Compliance Engine could not evaluate the device at all, since compliance evaluation requires a completed enrolment. Azure AD join, licensing (M365, Intune P1, Autopilot), and network connectivity to all required endpoints were independently confirmed healthy, ruling out identity, licensing, and connectivity as contributing factors.

## Scope and Impact
- Affected device: DESKTOP-FB099
- Affected user: FINBRIDGE\rthomas
- Enrolment result: **Failed** — `0x80180014`
- Azure AD joined: Yes (confirmed healthy, not a contributing factor)
- Existing MDM enrolment: **Yes** — legacy manual enrolment from 2023-11-04 (root cause)
- Policy application: **Failed** — 0 of 4 profiles applied, `0x80070005 (Access denied)` on `FinBridge-Win11-Security-Baseline`
- Compliance evaluation: Could not evaluate — enrolment not complete
- Licensing: Correct — M365, Intune P1, and Autopilot licenses all present (ruled out)
- Network connectivity: Healthy — login.microsoftonline.com, enrollment.manage.microsoft.com, enterpriseregistration.windows.net all reachable, no proxy detected (ruled out)
- Business impact: single device/user blocked from completing Autopilot provisioning; device unusable for managed work until resolved; no other devices confirmed affected at time of writing, though the same failure pattern is a fleet-wide risk for any device with an un-retired legacy enrolment ahead of the Win11 migration

## Supporting Evidence

### EnrollmentStatus
- Timestamp: 2026-08-11 09:18:44
- EnrollmentType: Autopilot
- EnrollmentState: Failed
- ErrorCode: `0x80180014`
- ErrorDescription: "The device is already enrolled in MDM"

### PolicyManager
- Timestamp: 2026-08-11 09:19:01
- ProfilesAttempted: 4
- ProfilesApplied: 0
- LastError: `0x80070005 (Access denied)`
- FailedProfile: `FinBridge-Win11-Security-Baseline`

### ComplianceEngine
- Timestamp: 2026-08-11 09:19:45
- EvaluationResult: "Could not evaluate"
- Reason: "Enrolment not complete"

### DeviceInfo
- AzureADJoined: Yes
- MDMEnrolled: Yes (previous enrolment)
- EnrolmentSource: Legacy (manual MDM enrolment, 2023-11-04)
- AutopilotProfile: `FinBridge-Autopilot-Standard`
- TPMVersion: 2.0, TPMStatus: Ready
- SecureBoot: Enabled
- OS build: 22621.2861

### NetworkCheck
- login.microsoftonline.com: OK
- enrollment.manage.microsoft.com: OK
- enterpriseregistration.windows.net: OK
- ProxyDetected: No

### Licensing
- M365LicenseFound: Yes
- IntuneP1License: Yes
- AutopilotLicense: Yes

### Evidence Conclusion
The evidence chain is consistent and complete: a legacy manual MDM enrolment from 2023-11-04 was still active on DESKTOP-FB099 when the Autopilot enrolment attempt started on 2026-08-11 → the enrolment service rejected the new attempt because only one MDM enrolment is permitted per device (`0x80180014`) → because enrolment never completed, the device's MDM client could not take ownership of the policy CSP namespace, so all 4 configuration profiles were rejected (`0x80070005`) → the Compliance Engine could not evaluate the device since compliance evaluation requires a completed enrolment. Identity, licensing, and network connectivity were each independently verified healthy in the same export and do not contribute to the failure.

## Detailed Timeline (Local Time)
- 2023-11-04 — Legacy manual MDM enrolment created for DESKTOP-FB099 (pre-dates the current Autopilot/Win11 migration project).
- 2026-08-11, pre-09:18 — DESKTOP-FB099 targeted for Autopilot deployment under profile `FinBridge-Autopilot-Standard`; legacy enrolment not retired beforehand.
- 09:18:44 — `EnrollmentStatus`: Autopilot enrolment attempt fails, `EnrollmentState: Failed`, `ErrorCode: 0x80180014`, "The device is already enrolled in MDM".
- 09:19:01 — `PolicyManager`: 0 of 4 profiles applied; `FailedProfile: FinBridge-Win11-Security-Baseline`; `LastError: 0x80070005 (Access denied)`.
- 09:19:45 — `ComplianceEngine`: evaluation result "Could not evaluate", reason "Enrolment not complete".
- 09:22 — MDM diagnostic export generated for DESKTOP-FB099 / FINBRIDGE\rthomas, OS build 22621.2861, capturing the full sequence above.

## Root Cause Statement
Autopilot enrolment for DESKTOP-FB099 failed because a legacy manual MDM enrolment from 2023-11-04 was never retired before the device was targeted for Autopilot deployment. Windows permits only one active MDM enrolment per device, so the pre-existing enrolment blocked the new Autopilot enrolment attempt (`0x80180014`), which in turn prevented policy application (`0x80070005`) and compliance evaluation.

## 5 Whys Analysis
1. **Why did Autopilot enrolment fail?**
   Because the enrolment service returned `0x80180014`, "The device is already enrolled in MDM."

2. **Why did the enrolment service report the device as already enrolled?**
   Because `DeviceInfo` confirms `MDMEnrolled: Yes`, with `EnrolmentSource: Legacy (manual MDM enrolment, 2023-11-04)` still active on the device.

3. **Why was the legacy enrolment still active when Autopilot enrolment was attempted?**
   Because it was never retired or removed before the device was targeted for the Autopilot/Win11 migration deployment.

4. **Why did the blocked enrolment also cause 0 of 4 configuration profiles to apply?**
   Because policy CSPs can only be owned by one active MDM enrolment at a time, and with the new enrolment never completing, the MDM client could not take ownership to apply `FinBridge-Win11-Security-Baseline`, resulting in `0x80070005 (Access denied)`.

5. **Why could the Compliance Engine not evaluate the device?**
   Because compliance evaluation requires a completed enrolment, and enrolment never progressed past the `0x80180014` failure, so the engine correctly reported "Enrolment not complete" rather than a pass/fail result.

## Remediation Plan

Each step is tagged **[Admin center only]** or **[Requires device access]** (physical or remote — the device cannot complete this remotely through Intune alone once it's stuck in this state, since it isn't fully enrolled).

### Order of operations
1. **[Admin center only]** In Intune admin center, go to **Devices > All devices**, search `DESKTOP-FB099`, and confirm whether a device object exists tied to the legacy 2023-11-04 enrolment.
2. **[Admin center only]** Select the stale device object → **Retire** (or **Wipe** if company data must also be removed) → once complete, **Delete** the device object so the enrolment record and any associated certificates are cleared server-side.
3. **[Admin center only]** Check **Entra ID (Azure AD) > Devices** for a corresponding device object tied to the legacy enrolment and remove/disable it if it's a duplicate of the Autopilot-registered device.
4. **[Requires device access]** On the device, go to **Settings > Accounts > Access work or school**, select the existing legacy work/school connection, and choose **Disconnect**. Run `dsregcmd /status` to confirm no lingering MDM enrollment URL is reported.
5. **[Requires device access]** If the connection can't be removed via Settings, use `MdmDiagnosticsTool.exe` to run the built-in reset enrollment action, or clear the enrolment certificate manually in `certlm.msc`.
6. **[Requires device access]** Trigger a clean re-enrolment via **Autopilot Reset** (or a full OOBE re-run), so the device re-registers cleanly against `FinBridge-Autopilot-Standard`.
7. **[Admin center only]** Confirm in Intune admin center that the device re-appears under **Devices > All devices** as a fresh Autopilot-enrolled object.

> Steps 1–3 (admin center) must be completed before steps 4–6 (device-side) to ensure no stale record re-attaches to the device mid-re-enrolment.

## Verification of Recovery
- **Devices > Manage devices > Compliance > Policies > FinBridge-Win11-Security-Baseline > Device status** shows DESKTOP-FB099 with an evaluated compliance state (Compliant/Not compliant/In grace period), not "Could not evaluate."
- **Devices > Manage devices > Configuration > \[each of the 4 profiles] > Device status** shows Succeeded for DESKTOP-FB099, replacing the prior `0 of 4 applied`.
- On the device, `dsregcmd /status` shows a current-tenant MDM enrollment URL, not the legacy value.
- A freshly generated `MdmDiagnosticsTool.exe` export shows `EnrollmentState: Succeeded` with no `0x80180014` or `0x80070005` entries.

## Preventive Actions
1. Add a mandatory pre-enrolment check to the Win11 migration runbook: query Intune/Entra ID (e.g. via Graph API) for any existing MDM enrolment tied to the target device's hardware hash or serial number before shipping/re-imaging for Autopilot.
2. Retire and delete any legacy enrolment found during the pre-check before the device reaches the Autopilot deployment stage, rather than relying on manual awareness of historical manual enrolments.
3. Add a triage step for any future `0x80180014` failure to immediately check `DeviceInfo.EnrolmentSource` for a legacy/manual enrolment before investigating licensing, network, or identity causes, since this evidence pattern is a fast, high-confidence indicator.
4. Capture a 24-hour post-remediation observation window (first successful sync plus one subsequent compliance evaluation cycle) to confirm no recurrence of `0x80180014`/`0x80070005` for the same device.

## Ownership
- Incident owner: DWP Engineering
- Affected user: FINBRIDGE\rthomas
- Remediation actions: Intune admin center steps + device-side actions as listed above
