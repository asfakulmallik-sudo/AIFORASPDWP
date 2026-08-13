# Incident Communication Pack - 3rd Floor Finance OU Group Policy / DNS Issue

## Audience 1 - Non-Technical Executive
Some computers on the 3rd floor (Finance team) briefly had trouble picking up their standard settings this morning during startup, between about 7:40 and 7:44 AM. This was caused by a leftover configuration setting from an overnight network upgrade, which pointed a small number of machines to an address that had just been retired. No data was lost or at risk, and one comparison machine in the same team was unaffected the whole time. The network team is correcting the underlying setting so this does not recur.

## Audience 2 - Affected End-User Team (3rd Floor Finance)
Between about 7:40 and 7:44 AM, a small number of 3rd floor Finance machines were unable to fully apply standard network settings during startup. This was traced to those machines being pointed at a network address (DNS server) that was retired overnight as part of a planned upgrade; a related setting on the network side had not yet been updated to match. Your data was not affected. If your machine is still showing signs of this (for example, unable to reach shared network drives), please restart it once the network team confirms the fix is in place, or contact the DWP Service Desk if issues continue.

## Audience 3 - Engineer-to-Engineer Internal Note
No user data at risk; issue was DNS/Group Policy processing only, no service crash observed in evidence.

Fact set (same incident facts):
- Incident window: 07:40-07:44 local, startup-time only, 2024-03-15.
- Impact: 3 of 4 machines in OU=Finance, Floor 3. Confirmed hostname in workstation-level evidence: DESKTOP-FB031. Unaffected comparison: DESKTOP-FB029 (manually reconfigured pre-migration).
- Server-side DHCP log comparison: FB055-FB057 affected (DNS 172.16.5.5), FB058 unaffected (DNS 10.10.0.10, manually set). Note: hostname naming between workstation-level and server-level evidence has not been cross-confirmed as the same machines - verify before closing scope.
- Root cause: DHCP scope for the Floor 3 subnet(s) was not updated when old DNS infrastructure was decommissioned overnight at 02:00 during the migration wave, so affected machines were leased a dead DNS server (10.10.3.250 per FB031 evidence; 172.16.5.5 per FB055-FB057 server-log evidence).
- Failure chain: dead DNS server assigned by DHCP (Event 50036) -> DNS resolution timeout for FINBRIDGE-DC01.finbridge.local (Event 1014) -> Netlogon secure channel failure (Event 5719) -> Group Policy SYSVOL/GPO-list/overall processing failures (Events 1058, 1030, 1129).
- Verification step for recovery: Event 50036 showing DNS 10.10.0.10 assigned, followed by GroupPolicy Event 1500 (success) - same pattern already confirmed on FB029.

Action taken / required:
1. Correct the DHCP scope option(s) for the affected Floor 3 subnet(s) to reference 10.10.0.10 instead of the decommissioned DNS servers.
2. Force DHCP lease renewal (or reboot) on the known affected machines.
3. Confirm recovery via `gpupdate /force` and check for GroupPolicy Event 1500.
4. Confirm the full list of the 3 affected Finance-OU machines and reconcile against the FB055-FB058 server-log naming before closing scope.

Preventive action needed (carry forward from RCA):
1. Mandatory DHCP scope validation/sign-off before decommissioning any DNS server in future migration waves.
2. Fleet-wide alerting on Netlogon Event 5719 and GroupPolicy Events 1058/1129.
3. Full audit of DHCP scopes on all subnets touched by this migration wave.
