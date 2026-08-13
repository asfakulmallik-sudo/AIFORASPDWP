# DWP Intune L3 Engineer — Skills, Access & Tasks

## Skills required (basic to advanced)
- **Basic**
  - Understanding of Windows 11/10 OS fundamentals (updates, drivers, local profiles).
  - Basic Active Directory / Entra ID (Azure AD) concepts (users, groups, devices).
  - Familiarity with the Microsoft Intune admin center navigation and reporting.
  - Basic troubleshooting of device enrolment and sync issues.
- **Intermediate**
  - Configuration profiles (settings catalog, templates) and compliance policies.
  - App deployment (Win32, MSI, store apps) and app assignment/targeting.
  - Conditional Access policy concepts and how they interact with Intune compliance.
  - Autopilot deployment profiles and enrolment status page (ESP) troubleshooting.
  - PowerShell scripting for device/app remediation and reporting.
- **Advanced**
  - Microsoft Graph API for Intune (bulk operations, custom reporting, automation).
  - Endpoint security baselines (Defender, disk encryption/BitLocker, attack surface reduction).
  - Co-management with Configuration Manager (SCCM/MECM) and hybrid Azure AD join troubleshooting.
  - Advanced conditional access, zero trust design, and device compliance escalations.
  - Root cause analysis for large-scale enrolment/compliance failures.

## Access required
- **Intune admin center** — role-based access (e.g. Intune Administrator or a scoped custom role) to manage devices, profiles, apps, and compliance policies.
- **Entra ID (Azure AD) admin center** — access to view/manage users, groups, and device objects; Conditional Access read (and write, if in scope).
- **Microsoft Graph API / PowerShell** — an app registration or delegated permissions for automation and scripted tasks (least-privilege, scoped to Intune Graph permissions).
- **Configuration Manager console (MECM/SCCM)** — if the environment uses co-management or hybrid join.
- **Privileged Identity Management (PIM)** — if roles are assigned just-in-time rather than standing access.
- **Ticketing/ITSM tool** — to log, update, and close tasks/incidents.

## Task types by difficulty

### Basic
- Reviewing device enrolment/compliance status and sync issues.
- Adding/removing users or devices from Intune-assigned groups.
- Checking app deployment status for a single device/user.
- First-line troubleshooting of Autopilot enrolment stuck at ESP.

### Intermediate
- Creating/editing configuration profiles and compliance policies.
- Deploying and troubleshooting Win32 app packages.
- Investigating Conditional Access blocks tied to device compliance.
- Building/updating Autopilot deployment profiles.
- Writing PowerShell scripts for remediation (proactive remediations).

### Advanced
- Diagnosing large-scale compliance or enrolment failures across a device estate.
- Designing/implementing endpoint security baselines and hardening policies.
- Troubleshooting co-management and hybrid Azure AD join failures.
- Automating reporting/remediation via Microsoft Graph API.
- Leading root cause analysis and producing permanent fixes for recurring Intune-related incidents.

> Note: Specific DWP role scope, tooling, and access levels — Need to confirm against DWP's own role definitions and access model.
