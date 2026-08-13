# Incident Communication Pack - Autopilot Enrolment Failure (DESKTOP-FB099)

## Audience 1 - Non-Technical Executive
Your device and account access are fully restored, and no company data was at risk. A newly issued laptop failed its automatic setup process due to a leftover technical record from before the device was prepared, which blocked the device from completing setup and receiving its required security settings. IT identified the cause, cleared the leftover record, and the laptop completed setup successfully. No action is needed from you.

## Audience 2 - Affected End-User Team (FINBRIDGE\rthomas)
Your laptop (DESKTOP-FB099) is now fully set up and working. During initial setup, the device failed to complete because a leftover setup record from before it was prepared for you was still present, which stopped the automatic company setup process from finishing. IT removed the old record and reset the device's setup, and it completed successfully with all required security settings applied. If your laptop setup ever gets stuck again, restart it once; if it's still stuck, contact the IT Help Desk.

## Audience 3 - Engineer-to-Engineer Internal Note
Device fully enrolled and compliant; no data or access-control gap during the incident window (device was never in active use pre-remediation).

Fact set (same incident facts):
- Device: DESKTOP-FB099, user FINBRIDGE\rthomas.
- Failure time: 09:18:44, `EnrollmentState: Failed`, `ErrorCode: 0x80180014` ("The device is already enrolled in MDM").
- Downstream effect: 09:19:01, `PolicyManager` — 0 of 4 profiles applied, `LastError: 0x80070005 (Access denied)` on `FinBridge-Win11-Security-Baseline`; 09:19:45 Compliance Engine could not evaluate (enrolment not complete).
- Root cause: `DeviceInfo.EnrolmentSource` confirmed a legacy manual MDM enrolment from 2023-11-04 still active on the device, blocking the new Autopilot enrolment (only one active MDM enrolment permitted per device).
- Ruled out: Azure AD join, licensing (M365/Intune P1/Autopilot), and network connectivity to all required endpoints were all confirmed healthy in the same diagnostic export.
- Exact action taken: Retired and deleted the stale legacy device object in Intune (Devices > All devices) and the corresponding object in Azure AD (Entra ID) > Devices; disconnected the legacy work/school account on the device (Settings > Accounts > Access work or school) and confirmed via `dsregcmd /status` no legacy MDM enrolment URL remained; triggered Autopilot Reset to re-enrol cleanly.
- Verification step: Confirmed via Intune (`Devices > Manage devices > Compliance > Policies > FinBridge-Win11-Security-Baseline > Device status`) and Configuration profile status that all 4 profiles applied successfully and the device returned an evaluated compliance state; confirmed via a fresh `MdmDiagnosticsTool.exe` export showing `EnrollmentState: Succeeded`.

Config detail to retain for recurrence handling:
- Fault signature: `ErrorCode 0x80180014` plus `DeviceInfo.EnrolmentSource` showing a legacy/manual enrolment date predating the current migration project.
- Confirming downstream signature: `PolicyManager.LastError 0x80070005 (Access denied)` with `ProfilesApplied: 0` and `ComplianceEngine.EvaluationResult: Could not evaluate`.

Preventive action needed (carry forward from RCA):
1. Mandatory pre-enrolment check in the Win11 migration runbook: query Intune/Azure AD for an existing MDM enrolment tied to the target device's hardware hash/serial number before shipping/re-imaging for Autopilot.
2. Retire and delete any legacy enrolment found during the pre-check before the device reaches the Autopilot deployment stage.
3. Triage runbook update: treat `0x80180014` as a high-confidence indicator to check `EnrolmentSource` first, before investigating licensing, network, or identity causes.
4. Post-remediation observation window (first sync plus one compliance evaluation cycle) to confirm no recurrence for the same device.
