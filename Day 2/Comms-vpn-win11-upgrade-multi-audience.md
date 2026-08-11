Executive:
Your VPN access is safe and fully restored — no data was lost at any point. The issue was caused by a software update that removed an older VPN component without automatically installing its replacement. We manually corrected this and confirmed full connectivity. No action is needed on your part.

Team:
Hi team — after the recent Windows 11 upgrade, some of you lost VPN access because the update removed the old VPN software but didn't automatically install the new version. We've fixed this and confirmed connections are working properly, with no data lost. If you see VPN issues again, please contact IT and we'll get it sorted quickly.

Engineer:
Root cause: Win11 upgrade removed the legacy VPN client and failed to trigger Intune re-deployment of the new client due to a detection-rule gap.
Action taken: Manually removed stale VPN registry entries under HKLM\SOFTWARE\<vendor>, force-triggered Intune sync, new client deployed.
Config detail: Split-tunnel configuration applied post-install.
Verification: Confirmed connectivity to all internal subnets; no data loss.
Preventive action: Update Intune detection rule to correctly identify Win11 upgrade scenarios and ensure automatic VPN client re-deployment; validate on pilot devices before wider Win11 rollout.
