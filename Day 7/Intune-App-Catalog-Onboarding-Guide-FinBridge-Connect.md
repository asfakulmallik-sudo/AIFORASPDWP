# Guide: Adding a Windows Application to the Intune App Catalog (Pre-Rollout)

Title: Onboarding a Windows LOB App into Intune Before Phased Rollout
Version: 1.0
Date: 2026-08-11
Author: DWP Endpoint Engineer
Status: Draft
Worked example used throughout: **FinBridge Connect v3.1** — a Windows LOB app packaged as a `.intunewin` file, install command `FinBridgeConnect_Setup.exe /silent`, uninstall command `FinBridgeConnect_Setup.exe /uninstall /silent`, detection via registry key `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1`.

> **Note on UI labels:** Intune admin center navigation, blade names, and field labels change between tenant releases. Every step below is flagged with ⚠️ where labels are known to vary — always verify the exact wording live in your own tenant before relying on this guide, rather than assuming the label shown here is current.

---

## Part 1 — Where to add an app in Intune

1. Sign in to the Intune admin center with an account that has Application Manager (or equivalent) permissions.
Expected result: You land on the Intune admin center home page.

2. Navigate to **Apps > All apps**.
Expected result: You see the existing app catalog list, with a "Create" or "+ Create" button visible at the top.
⚠️ *The top-level "Apps" node and its sub-items ("All apps", "Policies", "Monitor") have been reorganised before — confirm this exact grouping still exists in your tenant.*

3. Select **+ Create** (or **Add**) to start a new app.
Expected result: A panel opens asking you to select an **App type**.

4. Choose the correct app type for what you are deploying:
   - **Line-of-business app** — select this for a Windows LOB app packaged as a `.intunewin` file (this is the type used for FinBridge Connect v3.1).
   - **Microsoft Store app (new)** or **Microsoft Store app** — select this only if the app is being sourced directly from the Microsoft Store, not for a custom/internal `.intunewin` package.
   - **Web link** — select this only for a shortcut to a web application; it does not install any software or use install/uninstall commands or detection rules.
Expected result: Selecting **Line-of-business app** advances you to the app package upload screen.
⚠️ *Exact wording ("Line-of-business app" vs "Windows app (Win32)" vs similar) has varied across Intune releases — if "Line-of-business app" isn't present, look for a Win32/LOB-labelled option and confirm it accepts `.intunewin` packages before proceeding.*

5. Upload the `.intunewin` package for FinBridge Connect v3.1 when prompted.
Expected result: The upload completes and the wizard advances to **App information**.

---

## Part 2 — Required fields when creating the LOB Windows app

Work through each wizard step in order. Do not skip a step — an incomplete required field blocks the app from being saved.

### 2.1 App information

6. Complete the **App information** fields:
   - **Name:** `FinBridge Connect`
   - **Description:** `FinBridge Connect client v3.1 — internal connectivity application for Finance systems access.`
   - **Publisher:** `FinBridge`
   - **App version:** `3.1`
Expected result: All required fields show green/valid, and **Next** becomes selectable.
⚠️ *Some tenant versions add extra optional fields here (Category, Logo, Information URL, Privacy URL) — these are not required to proceed but confirm which fields are mandatory in your tenant, as this can change.*

### 2.2 Program

7. Complete the **Program** fields:
   - **Install command:** `FinBridgeConnect_Setup.exe /silent`
   - **Uninstall command:** `FinBridgeConnect_Setup.exe /uninstall /silent`
   - **Install behavior:** choose **System** if FinBridge Connect must be available to all users on the device regardless of who signs in (the normal choice for a managed line-of-business app); choose **User** only if the app must install per-user in the user's own context.
Expected result: All install/uninstall command fields accept the text with no validation errors.
⚠️ *"Install behavior" has also been labelled "Device restart behavior" or split into separate fields in some releases — confirm you are setting the System vs User install context specifically, not just restart behaviour.*

### 2.3 Requirements

8. Complete the **Requirements** fields:
   - **Operating system architecture:** select the architecture(s) FinBridge Connect v3.1 supports (e.g. 64-bit only, if that is the packaged build).
   - **Minimum operating system:** select the lowest Windows version FinBridge Connect v3.1 is supported and tested on (e.g. Windows 11 22H2, or your organisation's current baseline).
Expected result: Both fields are set; leaving architecture unset blocks progression on most tenant versions.
⚠️ *Additional optional requirement rules (disk space, memory, processor count) may appear depending on tenant version — these are optional unless your organisation's standard mandates them.*

### 2.4 Detection rules

9. Set the detection rule so Intune can confirm the app installed successfully. For FinBridge Connect v3.1, use the registry-based method:
   - **Rule type:** Registry
   - **Key path:** `HKLM\SOFTWARE\FinBridge\Connect`
   - **Value name:** `Version`
   - **Detection method:** "Value exists" or "String comparison" — for this app, use **String comparison**, operator **Equals**, value `3.1`, so Intune only reports success once the specific version is present, not just any value.
Expected result: The rule saves with no validation error, and you see it listed as one configured detection rule.
⚠️ *Registry detection is one of three common methods — "MSI product code" is used if the package is an MSI with a known product code, and "File" detection (path + file/version) is used if a version-stamped file is a more reliable indicator than a registry key. For FinBridge Connect v3.1, the registry key is the confirmed method — do not switch methods without confirming the alternative also reliably reflects a completed install.*

### 2.5 Return codes

10. Review the **Return codes** table (Intune pre-populates common defaults — confirm they match the FinBridge Connect installer's actual exit code behaviour rather than accepting the defaults blindly):
    - `0` — Success
    - `1707` — Success
    - `3010` — Soft reboot required (treated as success)
    - `1641` — Hard reboot initiated (treated as success)
    - `1618` — Retry (another installation in progress)
    - Any other/unlisted code — treated as **Failure** by default
Expected result: The return code table reflects what the FinBridge Connect Setup.exe installer actually returns on success vs failure — confirm this against the installer's documentation or a manual test run before relying on it, since an installer that returns a non-standard success code (e.g. a custom code outside this default list) will otherwise be misreported as Failed.

11. Select **Next** through **Scope tags** and **Assignments** (leave assignments blank for now — this is covered in Part 3), then **Create** to save the app.
Expected result: The app is created and appears in **Apps > All apps** as "FinBridge Connect" with an upload/processing status that changes to **Ready** once package processing completes.

---

## Part 3 — Assignment basics

12. Understand the three assignment types before assigning FinBridge Connect to any group:
    - **Required:** the app installs automatically on every device/user in the assigned group, without the user requesting it — used once you are ready to push the app to a defined population.
    - **Available for enrolled devices:** the app is listed in Company Portal for users to install voluntarily — it does not push automatically.
    - **Uninstall:** any device/user in the assigned group has the app removed — used to retract an app from a group, not to deploy it.
Expected result: You can articulate which of the three you intend to use for the pilot before assigning anything.

13. Assign FinBridge Connect v3.1 as **Required** to a small pilot/test device group first (for example a group of 10–25 known-good, monitored devices) — do **not** assign it to the full fleet of 10,000 devices at this stage.
Expected result: Only the pilot group receives the install; the remaining fleet is unaffected.

14. Reasoning to document alongside the pilot assignment: a phased pilot lets you catch install failures, detection-rule mismatches, or return-code misclassification (see Part 2.5) on a small, recoverable population before they can affect the whole fleet at once. If the detection rule or return codes are wrong, a full-fleet assignment would report false Failed (or false Installed) status across all 10,000 devices simultaneously, which is far harder to diagnose and roll back than a pilot-scale issue.
Expected result: The decision to pilot-first is documented in the change record before proceeding to a broader assignment ring.

---

## Part 4 — Verification steps

### 4.1 Confirm the app appears correctly in the catalog

15. Go to **Apps > All apps**, locate "FinBridge Connect", and open it.
Expected result: The app's overview shows the correct name, publisher, version (3.1), and a status of **Ready** (not "Processing" or "Error").

16. Open the app's **Properties** and re-check the Program, Requirements, and Detection rules sections against what was entered in Part 2.
Expected result: All values match exactly what was intended — this catches any field that was mistyped or not saved during creation.

### 4.2 Check install status on an assigned test device

17. Go to the app's **Monitor > Device install status** (or equivalent) tab.
Expected result: The pilot group's devices are listed with an individual install status each.
⚠️ *This tab has been named "Device install status" or "Device status" depending on tenant version — if not found under Monitor, check directly under the app's own page for a status/reporting tab.*

18. Select one pilot device and confirm its status matches what you expect given the timing of assignment and sync (allow time for the device to check in and attempt install before treating a pending status as a problem).
Expected result: You can see a per-device result rather than only an aggregate count.

19. On the pilot device itself, confirm the registry key exists as expected once install status shows Installed.
Expected result: `HKLM\SOFTWARE\FinBridge\Connect\Version` is present and equals `3.1`.

```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\FinBridge\Connect" -Name "Version"
```

### 4.3 What the status values mean

- **Installed:** the device reported the detection rule as satisfied (for FinBridge Connect, the registry value `3.1` was found) — the app is confirmed present and correctly versioned.
- **Failed:** the install command ran but did not complete successfully, returned an unrecognised/failure exit code, or completed but the detection rule did not find the expected registry value afterward — check the return code first, then confirm the detection rule value matches exactly what the installer actually writes.
- **Not applicable:** the device does not meet the Requirements (e.g. wrong OS architecture or below the minimum OS version) or is not in scope for the assignment — this is expected/benign for devices intentionally excluded, not a fault, but should be checked against the pilot group membership to confirm no intended target device is being incorrectly excluded.

20. Only proceed to a broader assignment ring once the pilot group consistently shows **Installed**, with no unexplained **Failed** results and any **Not applicable** results matching devices genuinely out of scope.
Expected result: Confidence in the package, detection rule, and return codes is established before expanding to the next ring, ahead of the eventual 10,000-device fleet.
