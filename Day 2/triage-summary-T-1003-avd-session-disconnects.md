# Triage Summary

## Ticket reference
T-1003

## Summary (one line)
AVD (Azure Virtual Desktop) session disconnects after approximately 10 minutes, then reconnects.

## Impact (who/how many/ business urgency)
- Affected user: one end user reported (to confirm).
- Scope: one AVD session reported (to confirm).
- Business impact: repeated disconnects may interrupt the user's work and any active sessions/applications (to confirm).
- Business urgency: to confirm.

## Known facts
- The AVD session disconnects after roughly 10 minutes of use.
- The session reconnects after disconnecting.

## Missing information to gather
- User name, contact details, and AVD host pool/session host name if known.
- Exact behaviour on disconnect (error message, blank screen, forced logout, etc.).
- Whether disconnects happen consistently at ~10 minutes or vary.
- Device and network used to connect (DWP laptop/personal device, wifi/ethernet, home/office/VPN).
- Whether any work or unsaved data is lost on disconnect.
- Whether this affects one user or multiple users on the same host pool.
- When the issue started and whether anything changed recently (client update, network change, policy change).
- Client used to connect (Remote Desktop app, browser, version).

## Likely category
AVD/Remote Desktop connectivity or session timeout issue (to confirm).

## Suggested first diagnostic step
Ask the user to note the exact time and any on-screen message at the next disconnect, and check whether the pattern (~10 min) suggests a network/idle timeout or client-side setting (to confirm).
