# Intune Compliance Policy: Windows 11 Security Baseline Translation

Title: Windows 11 Device Compliance Policy — Security Baseline Mapping
Version: 1.1
Date: 2026-08-13
Author: DWP Endpoint Security Engineer
Status: Draft
Scope: Microsoft Intune, Windows 11 managed devices, Settings Catalog / Compliance policy (System Security, Device Health, Device Properties)

> **Change log (v1.1, 2026-08-13):** Added post-assignment validation steps for the first test device (where to check per-policy compliance status, Compliant/Not compliant/In grace period meaning for Conditional Access, and the three most common causes of a BitLocker false-non-compliant flag). See "Post-assignment validation steps" section below.

> **Disclaimer on UI paths:** Intune admin center navigation and setting labels are updated frequently by Microsoft. Confirmed against a live tenant screenshot (2026-08-11): the top-level nav is **Devices > Manage devices > Compliance** (compliance policies now sit as a sibling of Configuration under "Manage devices", not as a standalone "Compliance" node). Paths below have been corrected to this structure. Any path still flagged with ⚠️ below that level (setting groupings inside a policy) has not yet been screenshot-confirmed and should be verified live before deployment.

---

## Requirement 1 — BitLocker must be enabled on the OS drive

- **Setting name:** `Encryption of data storage on device` (compliance check) — under **System Security**
- **Value:** Require
- **Effect:** Marks the device non-compliant if the OS drive is not reporting as encrypted. This setting only *checks* encryption status — it does not turn BitLocker on.
- **False-positive risk:** Devices flag non-compliant during the window between provisioning/ESP completion and BitLocker finishing encryption (can take minutes to hours on large disks); devices with encryption paused for a pending firmware/driver update; devices where TPM isn't yet initialised at first compliance evaluation.
- **Recommendation:** Deploy a paired **Endpoint security > Disk encryption** profile (BitLocker) to actively enforce encryption, not just check it. Use the 7-day grace period to absorb the ESP-to-encrypted window, and add a device group filter to delay evaluation until Autopilot/ESP is marked complete.
- **UI path:** Intune admin center > Devices > Manage devices > Compliance > Policies > \[Windows 10 and later policy] > System Security > Encryption of data storage on device ⚠️ *(compliance node is separate from the BitLocker encryption profile under Endpoint security > Disk encryption — verify both still exist under these names).*

---

## Requirement 2 — Secure Boot must be enabled

- **Setting name:** `Secure Boot must be enabled on the device` — under **Device Health / System Security**
- **Value:** Require
- **Effect:** Ensures firmware only loads a signed, trusted boot chain, blocking unsigned/tampered bootloaders (rootkits, bootkits).
- **False-positive risk:** Legacy BIOS (non-UEFI) hardware and most VMs report as non-compliant by design; some GPU/driver stacks or dual-boot configurations require Secure Boot disabled for compatibility; a pending firmware update can transiently disable it.
- **Recommendation:** Scope this policy to a device group that excludes known legacy/VM hardware (use a separate, relaxed compliance policy for that group rather than disabling the check tenant-wide) so the main baseline isn't weakened.
- **UI path:** Intune admin center > Devices > Manage devices > Compliance > Policies > \[policy] > Device Health > Secure Boot must be enabled on the device ⚠️ *(sometimes listed under System Security instead of Device Health depending on catalog version — check both).*

---

## Requirement 3 — Minimum OS build: N-1 (22621.2861)

- **Setting name:** `Minimum OS version` — under **Device Properties**
- **Value:** `10.0.22621.2861`
- **Effect:** Blocks any device running a build older than the specified version from being compliant.
- **False-positive risk:** Devices legitimately mid-rollout on an Update Ring with a longer deferral than the baseline expects; offline/remote devices that haven't checked in to receive the update; devices where the reported OS build lags due to delayed Windows Update telemetry sync.
- **Recommendation:** Align the compliance grace period and the Update Ring's feature/quality update deferral days so devices aren't marked non-compliant before they've had a realistic chance to update. Re-check this value each time Microsoft ships a new cumulative update, since "N-1" is a moving target.
- **UI path:** Intune admin center > Devices > Manage devices > Compliance > Policies > \[policy] > Device Properties > Minimum OS version ⚠️ *(build number format and whether it accepts full 4-part version strings has changed before — confirm current accepted format live).*

---

## Requirement 4 — Windows Defender real-time protection must be on

- **Setting name:** `Require Real-time protection` — under **System Security** (Microsoft Defender Antivirus)
- **Value:** Require
- **Effect:** Confirms Defender's real-time scanning engine is active, not just installed.
- **False-positive risk:** Devices running an approved third-party AV cause Defender to enter passive/disabled mode by design and will flag non-compliant even though the device is protected; Tamper Protection or MDE onboarding scripts can transiently toggle this state; conflicting GPO/registry settings pushed outside Intune.
- **Recommendation:** If any device group uses a third-party AV, put it in a separate compliance policy that excludes this check (don't apply the baseline unmodified to that group) — do not disable the check tenant-wide. Confirm via Defender for Endpoint reporting rather than assuming.
- **UI path:** Intune admin center > Devices > Manage devices > Compliance > Policies > \[policy] > System Security > Microsoft Defender Antivirus > Require Real-time protection ⚠️ *(this setting has moved between "Defender" and "System Security" groupings across Intune UI revisions).*

---

## Requirement 5 — Firewall must be enabled for all profiles

- **Setting name:** `Firewall` — under **System Security**
- **Value:** Require
- **Effect:** Confirms the Windows Defender Firewall service is running. Note: the compliance policy setting is a single on/off check of the firewall service — it does **not** independently verify Domain, Private, and Public profiles are each individually enabled.
- **False-positive risk:** A third-party firewall replacing/disabling the Windows Firewall service reports non-compliant even if network protection is otherwise adequate; some hardening scripts stop-then-restart the firewall service causing a brief non-compliant window.
- **Recommendation:** The compliance check alone does not satisfy "all profiles enabled" — pair it with an **Endpoint security > Firewall** configuration profile that explicitly sets Domain, Private, and Public network profiles to On. Compliance policy confirms the service is running; the firewall profile enforces the per-profile requirement.
- **UI path:** Compliance check: Devices > Manage devices > Compliance > Policies > \[policy] > System Security > Firewall. Per-profile enforcement: Devices > Endpoint security > Firewall > \[policy] > Domain/Private/Public network > Firewall = On ⚠️ *(Endpoint security blade layout and per-profile setting names have been restructured before — confirm current labels).*

---

## Requirement 6 — A PIN or password must be configured

- **Setting name:** `Require a password to unlock mobile devices` (Password Required) plus `Minimum password length` — under **System Security**
- **Value:** Password Required = Require; Minimum password length = 6 (adjust to org standard)
- **Effect:** Requires a PIN/password (or Windows Hello for Business PIN) to unlock the device before use.
- **False-positive risk:** Devices where Windows Hello for Business is enforced via a separate Authentication Methods/Account protection policy can show a mismatch if the legacy password node conflicts with Hello PIN policy; newly provisioned devices flag non-compliant in the window between ESP completion and the user actually setting a PIN.
- **Recommendation:** Use the grace period to cover the ESP-to-PIN-setup window. For PIN complexity specifically, configure it via **Endpoint security > Account protection > Windows Hello for Business** rather than relying solely on the legacy password compliance node, to avoid the two policies disagreeing.
- **UI path:** Devices > Manage devices > Compliance > Policies > \[policy] > System Security > Password Required / Minimum password length. Hello for Business PIN policy: Devices > Endpoint security > Account protection ⚠️ *(Account protection blade is a relatively newer addition — confirm it still exists under this name).*

---

## Requirement 7 — Device must not be jailbroken or rooted

- **Setting name:** No direct Windows equivalent exists. `Jailbroken/rooted devices` (Block) is an **iOS/Android-only** Device Health setting in Intune; Windows compliance policies do not expose this check.
- **Value:** N/A for Windows — see recommendation.
- **Effect:** N/A for Windows.
- **False-positive risk:** N/A — but attempting to apply this setting to a Windows 10/11 policy will either be unavailable or silently ignored, giving a false sense of coverage if someone assumes it's enforced.
- **Recommendation:** For Windows, the closest equivalent protection is **Device Health Attestation**, already substantially covered by Requirements 1 (BitLocker) and 2 (Secure Boot) plus optionally enabling `Require Code integrity` and `Restrict web browser to system default and hide access to legacy Internet Explorer` (unrelated but co-located) under the same Device Health blade. Flag to stakeholders that "not jailbroken/rooted" is a mobile-OS concept and should be re-scoped for Windows as "Device Health Attestation must pass (Secure Boot + Code Integrity + BitLocker)" rather than mapped 1:1.
- **UI path:** Devices > Manage devices > Compliance > Policies > \[policy] > Device Health > Require Code integrity (Windows substitute check) ⚠️ *(confirm exact wording — "Code integrity" enforcement setting naming has varied across catalog versions).*

---

## Grace period — 7 days for all settings

- **Setting name:** `Actions for noncompliance` schedule, within each compliance policy
- **Value:** Schedule the "Mark device noncompliant" action for 7 days after the device is first found out of compliance (instead of 0/immediate), then chain a follow-on action (e.g. block access via Conditional Access, or send push notification) after the 7-day mark.
- **Effect:** Gives users/devices a 7-day window to remediate (e.g. finish encrypting, install pending update, set a PIN) before compliance failure triggers downstream enforcement such as Conditional Access blocking.
- **False-positive risk:** If the grace period is applied only at the "mark noncompliant" action but Conditional Access is evaluated independently/immediately, users can still be blocked before the 7 days elapse — the grace period must be reflected consistently in both the compliance policy actions and any CA policy relying on device compliance state.
- **Recommendation:** Confirm the same 7-day tolerance is acceptable across all seven requirements — a build-update grace period of 7 days may be too long for BitLocker/Secure Boot (higher risk items) but reasonable for OS build currency. Consider tiered grace periods per policy if the baseline allows it, rather than one flat 7-day window for every setting.
- **UI path:** Devices > Manage devices > Compliance > Policies > \[policy] > Actions for noncompliance > Schedule (days after noncompliance) ⚠️ *(this tab has been relabelled "Actions for noncompliance" vs "Noncompliance actions" in different releases — confirm current name).*

---

## Summary table

| Requirement | Setting name | Value | UI path confirmed stable? |
|---|---|---|---|
| 1. BitLocker | Encryption of data storage on device | Require | ⚠️ Verify (split across Compliance + Endpoint security) |
| 2. Secure Boot | Secure Boot must be enabled on the device | Require | ⚠️ Verify (Device Health vs System Security) |
| 3. Min OS build | Minimum OS version | 10.0.22621.2861 | ⚠️ Verify (accepted format) |
| 4. Defender RTP | Require Real-time protection | Require | ⚠️ Verify (grouping) |
| 5. Firewall | Firewall (+ Endpoint security Firewall profile for per-profile) | Require / On | ⚠️ Verify (blade restructure) |
| 6. PIN/password | Password Required + Minimum password length | Require / 6 | ⚠️ Verify (Account protection blade) |
| 7. Jailbreak/root | Not applicable to Windows — substitute Code integrity | N/A | ⚠️ Verify wording |
| Grace period | Actions for noncompliance schedule | 7 days | ⚠️ Verify tab name |

**Recommendation before go-live:** Top-level nav (Devices > Manage devices > Compliance) is screenshot-confirmed as of 2026-08-11. Still log into the live tenant and confirm each remaining ⚠️ path (setting groupings within a policy), since those were translated from training knowledge that may lag current UI releases.

---

## Post-assignment validation steps (single test device)

### 1. Where to check the device's compliance status for this specific policy

- Intune admin center > **Devices > Manage devices > Compliance > Policies** > select the policy > **Device status** tab — lists every assigned device with an overall Compliant/Not compliant/In grace period result for that policy.
- Click the specific device row (or go via **Devices > All devices** > select the device > **Device compliance** blade) to open **Per-setting status**, which breaks the result down setting-by-setting (e.g. BitLocker = Compliant, Secure Boot = Not compliant), not just the overall pass/fail.
- Allow for sync latency: the device's status here only updates after its next compliance evaluation check-in — a "just synced" device should reflect within a few minutes, but if it doesn't, use **Devices > All devices > \[device] > Sync** to force re-evaluation rather than assuming the policy is broken.

### 2. What each state means for Conditional Access

| State | Meaning | Conditional Access impact |
|---|---|---|
| **Compliant** | Device passed every setting in the policy at last evaluation. | CA policies requiring "Require device to be marked as compliant" allow sign-in. |
| **Not compliant** | Device failed at least one setting and any grace period has expired. | CA blocks (or applies whatever restrictive controls the CA policy specifies) — this is the state that locks users out. |
| **In grace period** | Device failed at least one setting, but the configured grace period (e.g. 7 days) hasn't elapsed yet. | CA still treats the device as compliant for access purposes — the user is **not** blocked during grace, but the device is quietly at risk of dropping to Not compliant if unresolved when the grace period ends. |

### 3. Device shows Not compliant on BitLocker despite BitLocker being visibly enabled — three most common causes and fastest check

1. **Recovery key not yet escrowed to Azure AD/Entra.** Intune's compliance check for BitLocker looks for a recovery key escrowed to the tenant, not just the local encryption state — if the key hasn't synced up yet, the device reports non-compliant even though `manage-bde -status` shows encrypted.
   *Fastest check:* On the device, run `manage-bde -protectors -get C:` and confirm a recovery password protector exists, then check **Devices > All devices > \[device] > Recovery keys** in the admin center — if no key is listed there, that's the cause.
2. **Encryption method/cipher strength mismatch with the configured BitLocker profile.** If the Endpoint security disk encryption profile specifies a cipher (e.g. XTS-AES 256) different from what was actually used to encrypt the drive (e.g. it was encrypted with the OS default before the profile applied), compliance can flag it as not meeting policy even though the drive is encrypted.
   *Fastest check:* Run `manage-bde -status C:` and compare the "Encryption Method" line against the cipher strength set in the Disk encryption profile.
3. **Stale compliance report / evaluation hasn't caught up yet.** The device's local BitLocker state changed (e.g. encryption just completed) but Intune hasn't received an updated compliance report — the admin center is showing a cached prior result.
   *Fastest check:* Force a sync (`Devices > All devices > [device] > Sync`, or locally `Get-ScheduledTask -TaskName "Schedule#*" | Where TaskName -like "*PushLaunch*"` / Company Portal > Settings > Sync), wait a few minutes, then re-check the per-setting status — if it flips to Compliant with no other change, it was just a stale report.
