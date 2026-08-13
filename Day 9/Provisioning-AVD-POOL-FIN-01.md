# AVD Provisioning Record — POOL-FIN-01 / FinBridge-Workspace

## Environment

| Item | Value |
|---|---|
| Subscription ID | d1b00664-6bd2-4c15-8ba0-26c52c4693bf |
| Resource group | dwp-lab-rg |
| Region (actual) | East US |
| M365 tenant | zippyops.in |
| M365 account to grant access | p33@zippyops.in |
| CLI signed-in identity | traininguser53@zippyops.in |

## Build target

1. Pooled host pool `POOL-FIN-01` — BreadthFirst load balancing, max 5 sessions/host
2. Desktop application group registered to workspace `FinBridge-Workspace`
3. One session host VM — Windows 11 multi-session (AVD-optimized image), `Standard_B2ms`, Trusted Launch with Secure Boot + vTPM
4. Session host Microsoft Entra ID joined only (no on-prem AD)
5. `p33@zippyops.in` granted roles for direct RDP and AVD client desktop access

## Steps followed

1. **Confirmed CLI identity and permissions** — `az account show`, `az ad signed-in-user show`, `az role assignment list` confirmed `traininguser53@zippyops.in` has **Owner** at the subscription scope, so role-assignment creation was permitted.
2. **Inventoried existing resources** in `dwp-lab-rg` with `az resource list` to confirm what was already provisioned before making further changes (host pool, app group, workspace, VM, NIC, VNet all already present in East US).
3. **Verified host pool** `POOL-FIN-01` via `az desktopvirtualization hostpool show`: type `Pooled`, `loadBalancerType: BreadthFirst`, `maxSessionLimit: 5`, location `eastus`, custom RDP property includes `targetaadjoined:i:1` and `enablerdsaadauth:i:1` (required for Entra-ID-joined-only auth).
4. **Verified application group** `POOL-FIN-01-DAG` via `az desktopvirtualization applicationgroup show`: kind `Desktop`, correctly linked to host pool `POOL-FIN-01` and workspace `FinBridge-Workspace`.
5. **Verified workspace** `FinBridge-Workspace` via `az desktopvirtualization workspace show`: correctly references the app group.
6. **Verified session host VM** `fin-avd-02` via `az vm show`: size `Standard_B2ms`, `securityType: TrustedLaunch`, Secure Boot and vTPM both enabled, image `MicrosoftWindowsDesktop:windows-11:win11-23h2-avd:latest`.
7. **Verified VM power/provisioning state** via `az vm get-instance-view`: `ProvisioningState/succeeded`, `PowerState/running`.
8. **Verified VM extensions** via `az vm extension list`: `AADLoginForWindows` and `DSC` both report `ProvisioningState: Succeeded` (no on-prem AD-join extension present, consistent with Entra-ID-only requirement).
9. **Verified networking** via `az network nic show`: private IP only (`10.0.0.4`), no public IP, no NSG attached — RDP/AVD reachability depends on the existing VNet's line of sight (VPN/ExpressRoute/Bastion), not a public endpoint.
10. **Checked session host registration/health** via `az rest` against `Microsoft.DesktopVirtualization/hostPools/{pool}/sessionHosts?api-version=2024-04-03` (the `desktopvirtualization` CLI extension has no `session-host` subcommands):
    - Session host `fin-avd-02` registered, `sessions: 0`, but **status: `Unavailable`**.
    - Health checks: `SxSStackListenerCheck` ✅, `UrlsAccessibleCheck` ✅, **`DomainJoinedCheck` ❌**, **`DomainTrustCheck` ❌** (`"SessionHost is not joined to a domain"`).
11. **Diagnosed the failing health checks directly on the VM** using `az vm run-command invoke`:
    - `dsregcmd /status` confirmed `AzureAdJoined: YES`, `DomainJoined: NO`, with a valid `DeviceId` — i.e. the VM **is** correctly Entra-ID-joined as designed.
    - Confirmed `RDAgentBootLoader` service is `Running`/`Automatic`.
    - Reviewed `WVD-Agent` Application event log — agent repeatedly reconnected to the broker successfully (event ID 3019) and reported accessible URLs (event ID 3701) with no errors.
    - Re-queried the session host status via `az rest` a second time — health check timestamps were unchanged, confirming the `Unavailable` status was not simply a stale/in-flight registration artifact at the time of checking.
12. **Wrote `check-domain-events.ps1`** (see below) to pull any `WVD-Agent` event log entries mentioning "Domain" from the session host for further root-cause analysis, run via `az vm run-command invoke --scripts @check-domain-events.ps1`.
13. **Verified RBAC on `p33@zippyops.in`** via `az role assignment list --assignee p33@zippyops.in`: already holds
    - **Virtual Machine User Login** scoped to VM `fin-avd-02` (enables direct RDP sign-in with Entra credentials)
    - **Desktop Virtualization User** scoped to app group `POOL-FIN-01-DAG` (enables AVD client access to the published desktop)

## Current status

- Host pool, application group, workspace, and RBAC assignments are all correctly provisioned and verified.
- VM `fin-avd-02` is running, correctly sized/secured (Trusted Launch, Secure Boot, vTPM), and confirmed Entra-ID-joined only.
- Session host is registered but reporting **`Unavailable`** solely due to `DomainJoinedCheck` / `DomainTrustCheck` failures. `dsregcmd` on the VM confirms the Entra ID join itself is healthy, so this is a health-check/agent-side issue rather than an actual join failure — root cause investigation was in progress (event log review) at the point this record was written and needs to be continued/closed out.

## Scripts

- **`check-domain-events.ps1`** — queries the `WVD-Agent` Application event log on the session host for entries mentioning "Domain", to help root-cause the `DomainJoinedCheck`/`DomainTrustCheck` health check failures. Run with:

  ```powershell
  az vm run-command invoke -g dwp-lab-rg -n fin-avd-02 --command-id RunPowerShellScript --scripts @check-domain-events.ps1
  ```
