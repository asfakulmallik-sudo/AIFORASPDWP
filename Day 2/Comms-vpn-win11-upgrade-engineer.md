Engineer:
Root cause: Win11 upgrade removed the legacy VPN client and failed to trigger Intune re-deployment of the new client due to a detection-rule gap.
Action taken: Manually removed stale VPN registry entries under HKLM\SOFTWARE\<vendor>, force-triggered Intune sync, new client deployed.
Config detail: Split-tunnel configuration applied post-install.
Verification: Confirmed connectivity to all internal subnets; no data loss.
Preventive action: Update Intune detection rule to correctly identify Win11 upgrade scenarios and ensure automatic VPN client re-deployment; validate on pilot devices before wider Win11 rollout.
