# JAMF Configuration Profile: macOS Security Baseline Translation — Design Team Fleet

Title: macOS Configuration Profile — Security Baseline Mapping
Date: 2026-08-14
Author: DWP Endpoint Security Engineer
Status: Draft
Scope: JAMF Pro, macOS managed devices, Design team fleet (25 devices), Configuration Profiles (Computer level)

> **Disclaimer on JAMF UI/payload naming:** JAMF Pro payload names and their location within **Computers > Configuration Profiles > New** have changed across versions (e.g. payload groupings have been renamed/reorganised, and some settings have moved between the general macOS payload library and JAMF's own "Security" bundles). The payload names and paths below reflect the naming as of my training data and are **not guaranteed to match your current JAMF Pro instance**. Verify each payload name and setting location live in your own tenant before building the profile — do not trust the exact label given here, following the same discipline applied to the Intune labs on Day 6.

---

## Requirement 1 — FileVault disk encryption must be enabled

- **Payload type:** `FileVault` (Security & Privacy family; often listed as its own top-level payload named "FileVault" rather than nested under a general "Security & Privacy" payload)
- **Value:** Enable FileVault = ON; Enable "Defer enablement until logout" if forcing a prompt at next logout is desired; Recovery key type = Institutional (with escrow to JAMF Pro) or Personal recovery key with escrow, per org key-management policy
- **Effect:** Enforces full-disk encryption on the boot volume so data at rest is unreadable without the correct recovery key or user password, protecting against data exposure from lost/stolen devices.
- **False-positive risk:** Devices flag as non-compliant during the window between profile install and the user's next logout/login (FileVault enablement is often deferred until the next logout, not instant); devices where a user cancelled the enablement prompt; devices with pending macOS updates that block encryption completion; institutional recovery key escrow failing silently if the profile lacks a valid certificate.
- **Recommendation:** Pair with a JAMF Smart Group / Extension Attribute checking `fdesetup status` and a recovery key escrow report, rather than relying on the profile install status alone.
- **UI path:** JAMF Pro > Computers > Configuration Profiles > New > FileVault payload ⚠️ *(verify whether recovery key escrow settings are still under this same payload or split into a separate "Security" payload in your version).*

---

## Requirement 2 — Gatekeeper must be enabled (identified developers only)

- **Payload type:** `Security & Privacy` payload, General tab (Gatekeeper section)
- **Value:** "Allow apps downloaded from" = Mac App Store and identified developers (do not select "Anywhere")
- **Effect:** Blocks execution of unsigned or unnotarized applications from unidentified sources, reducing risk of malware execution from untrusted downloads.
- **False-positive risk:** Legitimate in-house/unsigned Design tools (e.g. internally built plugins, unsigned Adobe/Creative plugins, or beta build tools) get blocked and reported as "tampered/unsafe" by users, which can look like a security incident rather than expected Gatekeeper behavior; some older signed apps with expired notarization tickets will also be blocked.
- **Recommendation:** Maintain an approved-software exception list for Design-specific unsigned tools (notarize internally built tools where possible) rather than loosening Gatekeeper fleet-wide.
- **UI path:** JAMF Pro > Computers > Configuration Profiles > New > Security & Privacy > General ⚠️ *(the Gatekeeper option set — "App Store", "App Store and identified developers", "Anywhere" — and its exact tab location have shifted between JAMF/macOS versions; confirm current wording live).*

---

## Requirement 3 — Minimum macOS version: current stable minus one point release

- **Payload type:** JAMF does not enforce a minimum OS version via a configuration profile payload directly — this is implemented as a **Smart Group** (Computers > Smart Computer Groups, criterion "Operating System Version") combined with a **Compliance/Restricted Software or self-service enforcement policy**, not a profile setting.
- **Value:** Smart Group criterion: `Operating System Version` less than `<current stable version minus one point release>` (e.g. if current stable is 15.5, target is "less than 15.4"); attach an enforcement Policy (e.g. forced `softwareupdate` install or a Self Service prompt) to devices matching this group.
- **Effect:** Identifies and remediates/flags devices running an OS version older than the approved floor, ensuring the fleet stays within one point release of current to receive security patches.
- **False-positive risk:** Devices legitimately mid-rollout on a staged/deferred update policy; devices offline/not checking in to JAMF recently (stale inventory causes a false "outdated" flag even if the device has since updated); the "current stable" version itself is a moving target and needs manual re-baselining each Apple release.
- **Recommendation:** Re-check and update the Smart Group's version threshold on each Apple point release; ensure JAMF inventory update frequency is sufficient to avoid stale-version false positives.
- **UI path:** JAMF Pro > Computers > Smart Computer Groups > New > Criteria: Operating System Version ⚠️ *(there is no direct "minimum OS version" configuration profile payload in JAMF, unlike Intune's Device Properties setting — confirm this remains true in your version, as JAMF has added native compliance/benchmark features in some versions that may now support this directly).*

---

## Requirement 4 — Firewall must be enabled

- **Payload type:** `Firewall` payload (its own top-level payload, separate from Security & Privacy)
- **Value:** Enable Firewall = ON; Block all incoming connections = per org policy (typically off, allowing signed apps); Enable stealth mode = ON (recommended)
- **Effect:** Enforces the built-in macOS application firewall to block unsolicited inbound connections, reducing exposure to network-based attacks.
- **False-positive risk:** Devices with the firewall enabled but a specific Design-team collaboration/rendering tool needing inbound ports (e.g. network render farm agents, screen-sharing tools) may appear "broken" rather than non-compliant, prompting users to disable the firewall locally, which then flags as a policy drift; local admin override of the setting outside JAMF control (if the profile isn't locked/enforced) resets on next check-in but shows a temporary gap.
- **Recommendation:** Add explicit allowed-application entries for known Design-team network tools instead of leaving the firewall permissive fleet-wide; lock the profile so local toggling cannot persist.
- **UI path:** JAMF Pro > Computers > Configuration Profiles > New > Firewall ⚠️ *(confirm "stealth mode" and "block all incoming" remain under this same payload name and haven't been merged into Security & Privacy in your JAMF version).*

---

## Requirement 5 — Login password required after sleep/screen saver

- **Payload type:** `Security & Privacy` payload, General tab (or `Login Window` payload for some related session settings)
- **Value:** "Require password after sleep or screen saver begins" = Checked; Delay = Immediately (0 seconds recommended)
- **Effect:** Forces re-authentication whenever the device wakes from sleep or the screen saver activates, preventing walk-up access to an unlocked, unattended session.
- **False-positive risk:** Devices using certain external displays/docks that trigger frequent sleep/wake cycles can generate excessive password prompts that users perceive as a fault; Touch ID/Apple Watch unlock misconfiguration can make this feel like "always locked" even when working as intended; a delay value other than "Immediately" (e.g. 5 seconds) may be flagged as non-compliant depending on how strictly the baseline is scored.
- **Recommendation:** Confirm intended delay tolerance with the Design team (some may need a short grace period for multi-monitor wake behavior) and document it as an accepted deviation rather than a false positive if a small delay is approved.
- **UI path:** JAMF Pro > Computers > Configuration Profiles > New > Security & Privacy > General ⚠️ *(this setting has historically also appeared under the Login Window payload in some macOS/JAMF versions — verify which payload currently owns it).*

---

## Requirement 6 — Automatic security updates enabled

- **Payload type:** `Software Update` payload (top-level payload governing `softwareupdate` behavior)
- **Value:** "Automatically check for updates" = ON; "Install system data files and security updates" = ON; "Automatically install app updates" = ON (recommended); "Automatically install macOS updates" = per org change-control policy (often left OFF for major/minor OS upgrades while security updates remain forced ON)
- **Effect:** Ensures security-relevant patches (system data files, malware definition updates, XProtect/Gatekeeper data) are applied automatically without requiring user action, closing the window of exposure for known vulnerabilities.
- **False-positive risk:** Devices reporting non-compliant because a security update requires a restart the user has deferred; devices on a metered/slow network failing to download updates in the expected window; a device recently re-enrolled that hasn't completed its first `softwareupdate` check-in cycle yet.
- **Recommendation:** Pair with an Extension Attribute or Smart Group checking last successful `softwareupdate` run timestamp, and set a grace period before flagging a device as non-compliant to absorb normal restart-deferral behavior.
- **UI path:** JAMF Pro > Computers > Configuration Profiles > New > Software Update ⚠️ *(the split between "security updates" and "system data files" toggles vs. a single combined toggle has changed across macOS versions — confirm the exact toggle set live).*

---

## General Note on Baseline Maintenance
As with the Day 6 Intune baseline, every JAMF payload name, tab location, and toggle wording listed above should be treated as a **starting point for verification, not a guaranteed-accurate label**. Confirm each setting against a live JAMF Pro instance screenshot before building or deploying the profile to the 25-device Design fleet.
