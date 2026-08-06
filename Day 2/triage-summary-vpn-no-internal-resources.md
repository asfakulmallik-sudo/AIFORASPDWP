# Triage Summary

## Ticket reference
T-1008

## Summary (one line)
VPN connects successfully but no internal resources are reachable after a Windows 11 upgrade.

## Impact (who/how many/ business urgency)
- Affected user: one end user reported (to confirm).
- Scope: one device reported (to confirm).
- Business impact: user cannot access internal resources needed for work while remote (to confirm).
- Business urgency: to confirm.

## Known facts
- The VPN connects successfully.
- No internal resources are reachable once connected.
- The issue began after a Windows 11 upgrade.

## Missing information to gather
- User name, contact details, and device/asset name.
- Which internal resources are being tried (file shares, intranet sites, internal apps) and exact error/behaviour for each.
- VPN client name/version and connection profile used.
- Whether DNS resolution works for internal hostnames while connected.
- Whether ping/traceroute to internal resources succeeds or times out.
- Any changes to VPN client, firewall, or network adapter settings caused by the Windows 11 upgrade.
- Whether other users who upgraded to Windows 11 report the same issue.
- Whether reverting to a previous known-good network/VPN configuration is possible for testing.

## Likely category
VPN/network connectivity issue following Windows 11 upgrade (to confirm).

## Suggested first diagnostic step
With the VPN connected, check DNS resolution and connectivity (e.g. ping/traceroute) to a known internal resource to determine whether the issue is DNS, routing, or firewall related (to confirm).
