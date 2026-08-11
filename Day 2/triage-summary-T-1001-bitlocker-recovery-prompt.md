# Triage Summary

## Ticket reference
T-1001

## Summary (one line)
New Windows 11 laptop is prompting for a BitLocker recovery key on every boot.

## Impact (who/how many/ business urgency)
- Affected user: one user reported (to confirm).
- Scope: one new Win11 laptop reported (to confirm whether other new devices are affected).
- Business impact: user likely cannot log in/access the device without the recovery key, which may block all work on this machine (to confirm).
- Business urgency: to confirm.

## Known facts
- The laptop is a new Windows 11 machine.
- BitLocker is prompting for a recovery key.
- The prompt occurs on every boot.

## Missing information to gather
- User name, contact details, and asset/device name.
- Whether the user can currently enter the recovery key and get into Windows, or is fully locked out (to confirm).
- Whether the recovery key/ID has already been retrieved from Entra ID/AD/Intune (to confirm - do not invent the actual key or ID).
- When the device was first provisioned/enrolled and when this prompt first appeared.
- Any recent changes: firmware/BIOS update, boot order change, TPM change, hard drive/disk change, or Windows update.
- Whether the device is Autopilot/Intune-enrolled and its current compliance/encryption status.
- Whether this is affecting only this device or other newly deployed Win11 laptops (to confirm).
- Exact on-screen prompt wording (to confirm - do not invent error codes).

## Likely category
Endpoint security / BitLocker-TPM issue on newly provisioned device (to confirm).

## Suggested first diagnostic step
Confirm whether the recovery key stored against the device in the management console matches what's being requested, and check the device's TPM/BitLocker status and recent boot/firmware event history before attempting to unlock (to confirm).
