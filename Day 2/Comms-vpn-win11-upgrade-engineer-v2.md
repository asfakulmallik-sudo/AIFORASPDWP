Engineer:
- Root cause: Win11 upgrade removed the legacy VPN client; Intune re-deployment of the new client did not trigger due to a detection-rule gap.
- Action taken: Manually removed stale VPN registry entries under `HKLM\SOFTWARE\<vendor>`; force-triggered Intune sync; new client deployed.
- Config detail: Split-tunnel config applied post-deployment.
- Verification: Connectivity confirmed to all internal subnets; no data loss.
- Preventive action needed: Fix the Intune detection rule so it correctly identifies the absence/version mismatch of the VPN client post-Win11 upgrade, preventing this gap from recurring on future OS upgrades/rollouts.
