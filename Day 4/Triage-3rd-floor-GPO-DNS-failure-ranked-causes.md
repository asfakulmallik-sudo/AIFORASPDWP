# Triage: 3rd Floor Finance OU — Group Policy Not Applying (3 of 4 Machines)

Date: 2024-03-15
Scope: DESKTOP-FB031 (primary evidence machine), comparison machine DESKTOP-FB029, and DHCP server logs referencing FB055-FB058.
Startup window reviewed: 07:40-07:55.

## 1. What Each Event Log Entry Records

| Time | Source | Event ID | Level | What this event records |
|---|---|---|---|---|
| 07:40:02 | Service Control Manager | 7036 | Information | A Windows service changed state (started/stopped). Here it records that the Network Location Awareness (NLA) service reached the Running state — this only confirms the local network stack initialized, not that any remote host (e.g., a domain controller) is reachable. |
| 07:40:08 | Netlogon | 5719 | Error | Records that the computer could not establish a secure channel to a domain controller for the named domain. This is the core Netlogon health signal for domain trust/connectivity; the accompanying text states no domain controller was available and that the DNS query for the DC's FQDN returned no response. |
| 07:40:09 | GroupPolicy | 1058 | Error | Records that Group Policy processing failed while trying to read a specific GPO's `gpt.ini` file from a SYSVOL UNC path, along with a Win32 error code. Error code 0x3 = "The system cannot find the path specified," meaning the client could not resolve/reach the path at all (not a permissions issue). |
| 07:40:10 | GroupPolicy | 1030 | Warning | Records failure to query/enumerate the list of Group Policy Objects that apply to the computer, with an associated error code (0x546). This means the client could not even determine which GPOs it should be processing. |
| 07:40:11 | GroupPolicy | 1058 | Error | Same event type/meaning as the 07:40:09 entry — a repeated attempt with the same SYSVOL access failure. |
| 07:40:12 | GroupPolicy | 1129 | Error | Records that overall Group Policy processing failed because there was no network connectivity to any domain controller. This event also documents that Group Policy will automatically log a success event once connectivity is restored (no manual reset needed once the underlying issue clears). |
| 07:41:05 | DNS Client Events | 1014 | Warning | Records that a specific DNS name resolution query timed out because none of the DNS servers configured on the client responded. This narrows the failure to name resolution specifically, rather than routing or firewall. |
| 07:42:18 | DHCP Client | 50036 | Information | Records a successful DHCP lease acquisition: the IP address assigned, the DHCP server that issued it, and the DNS server(s) handed to the client as part of the lease. This is the event that reveals which DNS server the machine was actually told to use. |
| 07:44:01 | GroupPolicy | 1129 | Error | Same event type/meaning as 07:40:12 — Group Policy processing failed again due to no domain controller connectivity, recorded after the DHCP lease above. |
| 07:40:05 (FB029) | DHCP Client | 50036 | Information | Same event type as above, but on the comparison machine — records the DNS server it received. |
| 07:40:11 (FB029) | GroupPolicy | 1500 | Information | Records that Group Policy processing completed successfully for that computer — the "healthy" counterpart to the 1058/1129 failures on FB031. |

## 2. Sequence of Events in Plain English

1. DESKTOP-FB031 boots and its network stack comes up normally (NLA running at 07:40:02).
2. Within seconds, Netlogon tries to contact a domain controller for FINBRIDGE and fails — it cannot even resolve `FINBRIDGE-DC01.finbridge.local` by DNS, so no secure channel can be set up (07:40:08).
3. Because there is no reachable domain controller, Group Policy immediately fails twice trying to read GPO files from SYSVON and once trying to list applicable GPOs at all (07:40:09-07:40:11).
4. Group Policy logs a summary failure confirming the underlying reason: no network connectivity to any domain controller (07:40:12).
5. About a minute later, the DNS client itself times out trying to resolve the domain controller's name, confirming none of the machine's configured DNS servers answered (07:41:05).
6. Two minutes after boot, the machine renews its DHCP lease and is handed DNS server 10.10.3.250 — which the DHCP scope still lists, but which was actually decommissioned overnight at 02:00 as part of the migration wave. The correct, current DNS server for this subnet is 10.10.0.10, but the DHCP scope was never updated to reflect that change (07:42:18).
7. With a dead DNS server still in effect, Group Policy processing fails again at 07:44:01 for the same reason as before.
8. By contrast, DESKTOP-FB029 — in the same OU — requested its lease slightly earlier (07:40:05) and was handed the correct DNS server, 10.10.0.10. Group Policy on FB029 completed successfully six seconds later (07:40:11), because it could resolve and reach the domain controller normally. The log notes FB029 had been manually reconfigured before the migration wave.
9. Server-side DHCP logs show the same pattern at fleet scale: machines FB055-FB057 were handed 172.16.5.5 (a Floor 3 local DNS server decommissioned the night before, 2024-03-14), while FB058 had 10.10.0.10 manually set beforehand and was unaffected.

## 3. Most Likely Cause of the Failure, With Evidence

**Most likely cause:** Group Policy failed to apply on the affected Floor 3 Finance-OU machines because they could not resolve or reach a domain controller. This was caused by those machines being handed a decommissioned DNS server address by DHCP, since the DHCP scope for the Floor 3 subnet was not updated when the old DNS infrastructure was retired during the overnight migration wave.

Supporting evidence, in order of the causal chain:
- **DHCP handed out a dead DNS server:** Event 50036 (07:42:18) on FB031 shows DNS server 10.10.3.250 was assigned — explicitly noted as decommissioned at 02:00 the same night, with the DHCP scope not updated.
- **DNS resolution failed as a direct result:** Event 1014 (07:41:05) shows the DNS query for `FINBRIDGE-DC01.finbridge.local` timed out with no response from any configured DNS server.
- **Loss of DNS resolution broke domain trust communication:** Event 5719 (07:40:08, Netlogon) explicitly states no domain controller was available and ties this directly to the failed DNS query for the DC's FQDN.
- **Group Policy failed as a downstream consequence of no DC connectivity:** Events 1058, 1030, and 1129 all fail for the same root reason — inability to reach SYSVOL/a domain controller, with 1129 explicitly stating "no network connectivity to a domain controller."
- **Control-group comparison confirms DNS is the differentiator:** FB029, which received the correct DNS server (10.10.0.10) at 07:40:05, processed Group Policy successfully at 07:40:11 (Event 1500) — the only material difference between FB029 and FB031 in the evidence provided is which DNS server each machine was handed.
- **Server-side DHCP logs corroborate at a broader scale:** FB055-FB057 received the old Floor 3 local DNS server (172.16.5.5, decommissioned 2024-03-14 overnight); FB058, manually pre-set to 10.10.0.10, was unaffected — the same pattern as FB031 vs. FB029.

**Important clarification on terminology:** No log entry provided shows a Windows *service crashing* (e.g., no application-error/service-stop-with-error-code event for Netlogon, the Group Policy service, or DNS Client). The evidenced failure mode is Group Policy **processing failure** and Netlogon **secure-channel failure**, both caused by name-resolution failure — not a service crash. This distinction is called out explicitly so the RCA is not built on an assumption not supported by the evidence.

## 4. Detailed Analysis — Confirmed Facts vs. Gaps (Nothing Assumed)

**Confirmed by the evidence provided:**
- FB031 was assigned DNS server 10.10.3.250, a server decommissioned at 02:00 that same night.
- FB031's DNS resolution for the domain controller FQDN failed, and Netlogon/Group Policy failed as a result.
- FB029 was assigned the correct DNS server (10.10.0.10) and processed Group Policy successfully.
- FB029 was manually reconfigured before the migration wave (per the log annotation) — this is why it was unaffected, not because it is a fundamentally different machine type.
- Server-side DHCP logs show FB055-FB057 received a different decommissioned DNS server (172.16.5.5, Floor 3 local DNS) than FB031 did (10.10.3.250). Both are described as "decommissioned," but they are not the same server address.
- FB058 was manually pre-configured with 10.10.0.10 and unaffected, consistent with the FB031/FB029 pattern.
- The DHCP scope for the affected subnet(s) was not updated to remove/replace the decommissioned DNS server option.

**Gaps / inconsistencies in the evidence that should not be papered over with assumptions:**
- The workstation-level logs reference **DESKTOP-FB031** and **DESKTOP-FB029**, while the server-side DHCP comparison references **FB055-FB057** and **FB058** — these are different hostname ranges. The evidence provided does not establish that FB031 is one of FB055-FB057, or that FB029 is FB058. They may be the same population described two different ways, or they may be separate but similarly-affected sets of machines. This should be confirmed against the DHCP server logs directly (by IP/lease/MAC correlation) rather than assumed.
- The incident header states "3 of 4 machines on OU=Finance affected," but only one affected hostname (FB031) and one unaffected hostname (FB029) are shown in the workstation-level log excerpt. The identities of the other two affected machines are not confirmed in the evidence provided.
- It is not confirmed from this evidence alone whether the Floor 3 subnet has one DHCP scope or multiple scopes (the log references both 10.10.3.250 and 172.16.5.5 as "old" DNS servers for what appears to be the same floor) — this should be verified in the DHCP server configuration rather than assumed to be a single scope.
- No evidence is provided confirming exactly when the DHCP scope option was (or will be) corrected, or whether affected machines will need a manual lease renewal/reboot versus resolving automatically on next natural renewal.

## 5. Top 10 Candidate Solutions (Ranked — Do #1 First)

1. **Update the DHCP scope option(s) for the Floor 3 / Finance subnet(s) to remove the decommissioned DNS server addresses (10.10.3.250, 172.16.5.5) and replace them with the correct DNS server (10.10.0.10).** This is the direct root-cause fix and remediates the issue for every currently- and future-affected machine at once, without needing per-machine intervention. **Do this first.**
2. Force an immediate DHCP lease renewal (`ipconfig /release` then `ipconfig /renew`, or a reboot) on the known affected machines right after the scope fix, so they don't have to wait for natural lease expiry to pick up the corrected DNS server.
3. As a temporary stop-gap only (while the scope fix is being validated), manually set the correct DNS server (10.10.0.10) on the affected machines — mirroring the workaround already in place on FB029/FB058 — then run `gpupdate /force` to confirm recovery.
4. After connectivity is restored, run `gpupdate /force` on the affected machines and confirm a GroupPolicy Event 1500 (success) is logged, matching the pattern seen on FB029.
5. Audit every DHCP scope tied to subnets touched by the migration wave for any remaining references to decommissioned DNS servers, so other floors/subnets are caught proactively instead of via user-reported outages.
6. Add monitoring/alerting on Netlogon Event 5719 and GroupPolicy Events 1058/1129 fleet-wide, so any future DC-connectivity break caused by infrastructure changes is caught within minutes instead of via help desk tickets.
7. Establish a pre-decommission checklist that requires validating all DHCP scopes (and confirming no active leases still reference the server being retired) before an old DNS/DC server is powered off.
8. Temporarily shorten the DHCP lease time on affected subnets during future migration windows, so corrected scope options propagate to clients faster if a similar gap is missed again.
9. Verify redundancy/reachability of the new DNS server (10.10.0.10) from all affected subnets, not just the subnets where FB029/FB058 happened to be manually pre-configured, to rule out a secondary reachability issue once DHCP is corrected.
10. Update the migration runbook/process so that "update DHCP scope DNS options" is a mandatory, sign-off-gated step tied to any DNS server decommissioning — a governance fix to prevent this class of incident recurring on future migration waves.
