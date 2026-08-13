# Triage Summary

## Ticket reference
Not provided — to assign (source: Intune Management Extension / AppInstaller log).

## Summary (one line)
Adobe Acrobat Pro v23.6 Intune app install fails with MSI error 1603 on first attempt and retry 1; detection rule checks a registry path for Acrobat *Reader*, not Acrobat *Pro*.

## Impact (who/how many/ business urgency)
- Affected user(s): unknown — log shows a single device/agent execution (to confirm).
- Scope: at least one device; total affected device count not known from this log alone (to confirm).
- Business impact: device shows the app as not installed/not detected; user cannot use Acrobat Pro until resolved (to confirm).
- Business urgency: to confirm — depends on whether this is one device or fleet-wide (e.g. part of a phased rollout).

## Known facts
- Install context: SYSTEM.
- Package: `AdobeAcrobatPro.intunewin`.
- Install command: `msiexec /i AcrobatPro.msi /quiet`.
- First install attempt at 10:01:00 failed with **return code 1603** (generic MSI fatal error).
- Detection rule (registry check) ran immediately after: key `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0`, value not found → "Not detected".
- **The detection rule path references "Acrobat Reader", not "Acrobat Pro"** — this looks like a mismatched/incorrect detection rule for this app, independent of the 1603 failure.
- Retry 1 (60 minutes later, 11:01:47) ran the same install command and failed again with return code 1603.
- A second retry is scheduled 60 minutes after retry 1.

## Missing information to gather
- Device name/asset tag and affected user, and total count of devices showing this failure.
- Full MSIEXEC verbose log (`msiexec /i AcrobatPro.msi /quiet /l*v <logfile>`) to translate 1603 into its underlying root cause (1603 is generic — the real cause is in the verbose log, e.g. prerequisite missing, file in use, insufficient permissions, disk space, prior failed install leaving a bad state).
- Whether Acrobat Reader (a separate product) is expected/required to already be installed, or whether the detection rule was copy-pasted from an Acrobat Reader app definition in error.
- What registry key/value Acrobat Pro v23.6 actually writes on a successful install (needs confirming against a known-good manual install).
- Disk space, pending reboot state, and whether any other Adobe product (Reader/DC) is already installed on the device.
- Whether this failure is isolated to one device or reproducing across the pilot/ring it was assigned to.
- Whether return code 1603 correlates with a specific OS build, prior app version, or hardware profile.

## Likely category
Intune Win32 app deployment failure — likely two compounding issues: (1) an MSI-level install fault (1603) needing verbose log analysis, and (2) a detection rule misconfiguration (checking Acrobat Reader's registry path instead of Acrobat Pro's) that would report "Not detected" even if the MSI succeeded (to confirm).

## Suggested first diagnostic step
Pull the verbose MSI log from the affected device to identify the true cause behind return code 1603, and in parallel verify/correct the detection rule to reference the actual registry key Acrobat Pro v23.6 writes on install — do not rely on the current Acrobat Reader path even after the 1603 issue is fixed (to confirm).
