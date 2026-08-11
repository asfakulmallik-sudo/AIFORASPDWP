# Triage Summary

## Ticket reference
T-1004

## Summary (one line)
Company app fails to install from Company Portal with error 0x87D1041C.

## Impact (who/how many/ business urgency)
- Affected user: one end user reported (to confirm).
- Scope: one device, one application reported (to confirm).
- Business impact: user cannot install/use the required application (to confirm).
- Business urgency: to confirm.

## Known facts
- The installation of a company app from Company Portal fails.
- The error code reported is 0x87D1041C.

## Missing information to gather
- User name, contact details, and device/asset name.
- Name of the specific application that fails to install.
- Whether the install fails every time or intermittently.
- Whether other apps install successfully from Company Portal on this device.
- Device compliance status and Intune enrollment status.
- Available disk space and network connectivity at the time of install.
- Whether the device has been restarted since the failure.
- Any recent changes (OS update, policy change, re-enrollment).
- Whether other users/devices see the same error for this app.

## Likely category
Intune/Company Portal application deployment issue (to confirm).

## Suggested first diagnostic step
Look up error code 0x87D1041C against Intune/Company Portal known error references, and confirm device compliance and enrollment status before re-attempting the install (to confirm).
