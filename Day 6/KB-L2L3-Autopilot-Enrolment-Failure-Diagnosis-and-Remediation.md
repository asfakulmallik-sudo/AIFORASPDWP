# KB: Autopilot Enrolment Failure — Legacy MDM Enrolment Conflict (L2/L3)

Version: v1.0
Date: 2026-08-11
Status: Draft

## Background
Devices are provisioned via Windows Autopilot against the profile `FinBridge-Autopilot-Standard`, which enrols the device into Intune MDM and applies the `FinBridge-Win11-Security-Baseline` configuration and compliance policies. Windows permits only one active MDM enrolment per device. Devices carried over from before the current migration project (previously manually enrolled into MDM, or enrolled via a different management path) can retain a stale enrolment record that was never retired. When such a device is targeted for Autopilot, the new enrolment attempt collides with the still-active legacy enrolment and fails.

## Symptom
### What users report
- "My new/reset laptop is stuck on the setup screen."
- "I get an error during first sign-in and setup won't finish."
- "IT gave me a laptop but it never finishes installing my work apps/settings."

### What the engineer observes
- MDM diagnostic export shows `EnrollmentType: Autopilot`, `EnrollmentState: Failed`, `ErrorCode: 0x80180014` ("The device is already enrolled in MDM").
- `PolicyManager` shows `ProfilesApplied: 0` of the expected total, with `LastError: 0x80070005 (Access denied)`.
- `ComplianceEngine` reports `EvaluationResult: Could not evaluate`, `Reason: Enrolment not complete`.
- `DeviceInfo.MDMEnrolled: Yes`, with `EnrolmentSource` showing a legacy/manual enrolment predating the current Autopilot/migration project.
- Azure AD join, licensing (M365/Intune P1/Autopilot), and network connectivity to `login.microsoftonline.com`, `enrollment.manage.microsoft.com`, and `enterpriseregistration.windows.net` all report healthy in the same export — these are not the cause.

## Root Cause
A legacy manual (or otherwise pre-existing) MDM enrolment on the device was never retired before it was targeted for Autopilot deployment. Because Windows allows only one active MDM enrolment per device, the enrolment service rejects the new Autopilot enrolment attempt with `0x80180014`. As enrolment never completes, the MDM client cannot take ownership of the policy CSP namespace, so configuration profiles fail to apply (`0x80070005`), and the Compliance Engine cannot evaluate the device.

### Evidence that confirms root cause
- `EnrollmentStatus`: `EnrollmentState: Failed`, `ErrorCode: 0x80180014`, description "The device is already enrolled in MDM"
- `DeviceInfo`: `MDMEnrolled: Yes (previous enrolment)`, `EnrolmentSource: Legacy (manual MDM enrolment, <date>)`
- `PolicyManager`: `ProfilesApplied: 0`, `LastError: 0x80070005 (Access denied)` on the security baseline profile
- `ComplianceEngine`: `EvaluationResult: Could not evaluate`, `Reason: Enrolment not complete`
- Control checks in the same export (Azure AD join, licensing, network reachability) all pass, ruling out those as contributing causes

## Detection
Run these steps before remediation.

1. Generate or review the MDM diagnostic export for the affected device.
Expected result: You can confirm `ErrorCode 0x80180014` and the `EnrolmentSource` value.

```powershell
# On the affected device (requires device access)
MdmDiagnosticsTool.exe -area DeviceEnrollment -cab C:\Temp\mdm-diag.cab
```

2. Confirm current enrolment/MDM URL state on the device.
Expected result: Output shows whether an MDM enrolment URL is present and which tenant/enrolment it points to.

```powershell
# On the affected device (requires device access)
dsregcmd /status
```

3. Check Intune admin center for a duplicate/stale device object.
Expected result: A device object exists for the same device tied to an older enrolment date, separate from (or blocking) the new Autopilot registration.

- Intune admin center > Devices > All devices > search the device name > review Enrolled date and Management name/enrolment type.

4. Check Azure AD (Entra ID) for a duplicate device object.
Expected result: A matching or duplicate device object is present, consistent with the legacy enrolment.

- Entra admin center > Devices > search the device name or associated user.

5. Confirm this incident type only if all conditions are true.
Expected result: High-confidence diagnosis before action.

- `ErrorCode 0x80180014` is present in the export.
- `DeviceInfo.EnrolmentSource` shows a legacy/manual enrolment predating the current Autopilot deployment.
- `PolicyManager.ProfilesApplied` is 0 (or less than expected) with `0x80070005 (Access denied)`.
- Azure AD join, licensing, and network checks in the same export are all healthy.

## Resolution
Remove the stale legacy enrolment, then trigger a clean re-enrolment. Complete admin-center steps before device-side steps so no stale record re-attaches mid-re-enrolment.

1. **[Admin center only]** In Intune admin center, go to Devices > All devices, select the stale device object tied to the legacy enrolment, and choose Retire (or Wipe if company data must also be removed).
Expected result: The device object's management state changes to Retire/Wipe pending, then completes.

2. **[Admin center only]** Once retire/wipe completes, delete the stale device object from Intune.
Expected result: The device no longer appears in Devices > All devices under the old enrolment record.

3. **[Admin center only]** In Entra admin center > Devices, confirm and remove any duplicate device object tied to the legacy enrolment.
Expected result: No duplicate device identity remains for the device.

4. **[Requires device access]** On the device, go to Settings > Accounts > Access work or school, select the existing legacy connection, and choose Disconnect.
Expected result: The legacy work/school connection is removed.

```powershell
# On the affected device (requires device access) — confirm no legacy MDM URL remains
dsregcmd /status
```

5. **[Requires device access]** If the connection cannot be removed via Settings, use the built-in reset action or clear the enrolment certificate manually.
Expected result: No lingering enrolment certificate remains in the Enterprise certificate store used by MDM.

```powershell
# On the affected device (requires device access)
certlm.msc
```

6. **[Requires device access]** Trigger a clean re-enrolment via Autopilot Reset, or a full OOBE re-run if Autopilot Reset is unavailable.
Expected result: The device re-registers against `FinBridge-Autopilot-Standard` and begins a fresh enrolment.

```powershell
# On the affected device (requires device access)
systemreset.exe /autopilotreset
```

7. **[Admin center only]** Confirm the device re-appears in Intune as a fresh Autopilot-enrolled object.
Expected result: Devices > All devices shows a new enrolment date and `EnrollmentType: Autopilot`.

## Verification
1. Confirm compliance evaluation completes for the device.
Expected result: Device status shows Compliant, Not compliant, or In grace period — not "Could not evaluate."

- Devices > Manage devices > Compliance > Policies > FinBridge-Win11-Security-Baseline > Device status.

2. Confirm all configuration profiles applied successfully.
Expected result: Device status shows Succeeded for each profile, replacing the prior `0 of N applied`.

- Devices > Manage devices > Configuration > [each profile] > Device status.

3. Confirm no legacy MDM enrolment URL remains on the device.
Expected result: `dsregcmd /status` shows a current-tenant enrolment URL, not the legacy value.

```powershell
dsregcmd /status
```

4. Generate a fresh MDM diagnostic export and confirm no recurrence.
Expected result: `EnrollmentState: Succeeded`, with no `0x80180014` or `0x80070005` entries.

```powershell
MdmDiagnosticsTool.exe -area DeviceEnrollment -cab C:\Temp\mdm-diag-verify.cab
```

5. Add the diagnostic export, Intune/Entra device object confirmation, and successful profile/compliance status to the incident ticket.
Expected result: Closure evidence is complete and auditable.

## Rollback
Trigger rollback only if retiring/deleting the device object causes an unexpected issue (for example, an incorrect device object was removed, or company data on the device is needed before a Wipe completes).

### Immediate containment (target: under 3 minutes)
1. If the wrong device object was selected, stop the Retire/Wipe action immediately if still pending, or restore access via alternate means (backup, OneDrive) if data loss is a risk.
Expected result: Impact of an incorrect action is minimised while the correct device object is identified.

2. Notify the affected user and Service Desk that remediation has been paused pending verification.
Expected result: Stakeholders are aware of the pause and next update time.

### Recovery rollback
3. Re-confirm the correct device object using serial number/hardware hash, not just device name, before repeating the Retire/Delete steps.
Expected result: The correct legacy object is targeted this time.

4. If company data was lost due to an incorrect Wipe, escalate to DWP Endpoint Engineering with the device serial number and last known backup/OneDrive sync status for data recovery options.
Expected result: Data recovery path is engaged promptly while the user is kept informed.

5. Re-apply the resolution steps (Retire/Delete stale object, disconnect legacy account, Autopilot Reset) once the correct scope is confirmed.
Expected result: Device re-enrols successfully without repeating the earlier mistake.

## Preventive
Implement these process/tooling controls to prevent recurrence.

1. Add a mandatory pre-enrolment check to the Win11 migration runbook: query Intune/Azure AD (e.g. via Graph API) for any existing MDM enrolment tied to the target device's hardware hash or serial number before the device is shipped/re-imaged for Autopilot.

2. Retire and delete any legacy enrolment found during the pre-check before the device reaches the Autopilot deployment stage, rather than relying on manual awareness of historical enrolments.

3. Add a triage step for any future `0x80180014` failure to check `DeviceInfo.EnrolmentSource` first, before investigating licensing, network, or identity causes, since this evidence pattern is a fast, high-confidence indicator.

4. Maintain an inventory of devices with enrolment dates predating the current migration project, and proactively retire stale records for those devices ahead of their scheduled migration wave.

5. Capture a short post-remediation observation window (first successful sync plus one subsequent compliance evaluation cycle) to confirm no recurrence of `0x80180014`/`0x80070005` for the same device.

## Related
- `Day 6/RCA-Autopilot-Enrolment-Failure-DESKTOP-FB099-final.md`
- `Day 6/RCA-Autopilot-Enrolment-Failure-DESKTOP-FB099-detailed.md`
- `Day 6/Known-Error-DESKTOP-FB099-Autopilot-enrolment-failure.md`
- `Day 6/KB-L1-Self-Service-Autopilot-Setup-Stuck.md`
