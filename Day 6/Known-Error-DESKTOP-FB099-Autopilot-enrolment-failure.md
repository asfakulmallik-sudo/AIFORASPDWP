Symptom: Autopilot enrolment fails for DESKTOP-FB099 (FINBRIDGE\rthomas) at the enrolment stage, with error `0x80180014` ("The device is already enrolled in MDM"). The device does not complete provisioning and no configuration profiles apply.

Cause: A legacy manual MDM enrolment from 2023-11-04 was never retired on the device before it was targeted for Autopilot deployment. Windows permits only one active MDM enrolment per device, so the pre-existing enrolment blocked the new Autopilot enrolment attempt, which in turn prevented all 4 configuration profiles from applying (`0x80070005 Access denied`) and left the device unable to be evaluated for compliance.

Scope: Confirmed on DESKTOP-FB099 / FINBRIDGE\rthomas. Any other device carried over from before the current Win11 migration project with a pre-existing manual/legacy MDM enrolment is at risk of the same failure.

Workaround: Retire and delete the stale legacy device object in Intune and Azure AD, disconnect the legacy work/school account on the device, then trigger a clean Autopilot Reset or full OOBE re-run so the device re-enrols cleanly.

Permanent fix: Add a mandatory pre-enrolment check to the Win11 migration runbook that queries Intune/Azure AD for an existing MDM enrolment tied to the target device's hardware hash or serial number, and retires/deletes any legacy enrolment found before the device reaches the Autopilot deployment stage.

How to spot it: Look for `EnrollmentState: Failed` with `ErrorCode 0x80180014` in the MDM diagnostic export, `DeviceInfo.MDMEnrolled: Yes` with an `EnrolmentSource` predating the current migration project, and a downstream `PolicyManager` result of `0 of N profiles applied` with `LastError 0x80070005 (Access denied)`.
