# Root Cause Analysis (RCA)

## Incident Title
3rd Floor Finance OU — Group Policy Not Applying (Stale DHCP-Assigned DNS Server)

## Incident Status
Resolved (pending confirmation of DHCP scope correction and lease renewal on remaining affected machines)

## Incident Date
2024-03-15

## Resolution Time
Not confirmed in evidence provided — recovery on comparison machines (FB029/FB058) shows the corrected state, but no timestamped resolution event for FB031 or the other two affected Finance-OU machines was supplied.

## Executive Summary
On 2024-03-15, 3 of 4 Windows machines in the Finance OU (Floor 3), including DESKTOP-FB031, failed to process Group Policy during startup between approximately 07:40 and 07:44. Investigation shows the affected machines were assigned a decommissioned DNS server by DHCP, which prevented them from resolving or reaching a domain controller. The DHCP scope for the affected subnet(s) had not been updated when the old DNS servers were decommissioned overnight (02:00) as part of a migration wave. A comparison machine (DESKTOP-FB029) that had been manually pre-configured with the correct DNS server processed Group Policy successfully, confirming DNS assignment as the differentiating factor.

## Scope and Impact
- Affected population: 3 of 4 machines in OU=Finance, Floor 3. Only one affected hostname (DESKTOP-FB031) is confirmed in the workstation-level evidence provided; the other two affected machines are not individually identified in this evidence.
- Unaffected comparison machine: DESKTOP-FB029 (same OU), manually reconfigured with correct DNS before the migration wave.
- Server-side DHCP logs additionally reference FB055-FB057 (affected, assigned 172.16.5.5) and FB058 (unaffected, manually set to 10.10.0.10). The evidence provided does not confirm whether these are the same machines as FB031/FB029 under different naming, or a separate but similarly-affected set — this should be verified before closing out scope definitively.
- Impact: affected machines could not process Group Policy at startup and could not establish a Netlogon secure channel to the domain, which would affect domain-dependent functionality until connectivity was restored.

## Supporting Evidence

### Failure Evidence — DESKTOP-FB031 (07:40-07:44)
- 07:40:02 - Service Control Manager Event 7036 (Information)
  - Network Location Awareness service entered running state (local network stack up only).
- 07:40:08 - Netlogon Event 5719 (Error)
  - Unable to set up a secure channel to domain FINBRIDGE — no domain controller available.
  - DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 - GroupPolicy Event 1058 (Error)
  - Failed to access `\\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\gpt.ini`. Error 0x3 (path not found).
- 07:40:10 - GroupPolicy Event 1030 (Warning)
  - Cannot query list of Group Policy objects. Error 0x546.
- 07:40:11 - GroupPolicy Event 1058 (Error)
  - Same SYSVOL access failure repeated.
- 07:40:12 - GroupPolicy Event 1129 (Error)
  - Group Policy failed — no network connectivity to a domain controller.
- 07:41:05 - DNS Client Events Event 1014 (Warning)
  - Name resolution for FINBRIDGE-DC01.finbridge.local timed out; no configured DNS server responded.
- 07:42:18 - DHCP Client Event 50036 (Information)
  - IP 10.10.3.144 leased from 10.10.0.1. DNS assigned: 10.10.3.250 — the old DNS server, decommissioned at 02:00 in the migration wave. Correct new DNS server is 10.10.0.10; the DHCP scope for this subnet was not updated.
- 07:44:01 - GroupPolicy Event 1129 (Error)
  - Group Policy processing failed again — no DC connectivity.

### Comparison Evidence — DESKTOP-FB029 (unaffected, same OU)
- 07:40:05 - DHCP Client Event 50036 (Information)
  - IP 10.10.3.141 leased. DNS assigned: 10.10.0.10 (correct, current DNS server).
- 07:40:11 - GroupPolicy Event 1500 (Information)
  - Group Policy settings processed successfully. Annotated as manually reconfigured before the migration wave.

### Server-Side DHCP Log Comparison
- FB055-FB057: DNS assigned 172.16.5.5 — Floor 3 local DNS, decommissioned overnight on 2024-03-14.
- FB058: DNS assigned 10.10.0.10 — central DNS, manually set before migration; unaffected.
- Server logs attribute root cause to the DHCP scope for the Floor 3 subnet still referencing the old DNS server.

## Evidence Conclusion
The event chain on DESKTOP-FB031 shows a Netlogon secure-channel failure and repeated Group Policy processing failures, all attributing the cause to no domain-controller connectivity. The DHCP lease event on the same machine reveals it was handed a decommissioned DNS server address. The unaffected comparison machine (FB029) received the correct DNS server and processed Group Policy successfully at nearly the same timestamp, isolating DNS assignment as the differentiating variable. No event in the evidence provided shows a service crash (application/service-stop-with-error event); the documented failure mode is Group Policy processing failure and Netlogon secure-channel failure, both driven by DNS resolution failure.

## Detailed Timeline (Local Time)
- 07:40:02 - Event 7036: NLA service running (FB031).
- 07:40:05 - Event 50036: FB029 leases IP, correct DNS (10.10.0.10).
- 07:40:08 - Event 5719: FB031 Netlogon secure channel failure, DNS query for DC returned no response.
- 07:40:09 - Event 1058: FB031 GPO SYSVOL access failure (0x3).
- 07:40:10 - Event 1030: FB031 cannot query GPO list (0x546).
- 07:40:11 - Event 1058: FB031 repeat SYSVOL access failure.
- 07:40:11 - Event 1500: FB029 Group Policy processed successfully.
- 07:40:12 - Event 1129: FB031 GP failed, no DC connectivity.
- 07:41:05 - Event 1014: FB031 DNS resolution timeout for DC FQDN.
- 07:42:18 - Event 50036: FB031 leases IP, DNS assigned is the decommissioned 10.10.3.250.
- 07:44:01 - Event 1129: FB031 GP failed again, no DC connectivity.

## Root Cause Statement
Group Policy failed to process on affected 3rd Floor Finance-OU machines because DHCP assigned them a decommissioned DNS server (10.10.3.250 on the subnet evidenced by FB031; 172.16.5.5 per the server-side comparison for FB055-FB057), preventing DNS resolution of the domain controller FINBRIDGE-DC01.finbridge.local and, in turn, breaking Netlogon secure-channel establishment and Group Policy SYSVOL access. This occurred because the DHCP scope for the affected Floor 3 subnet(s) was not updated to reflect the new DNS server (10.10.0.10) when the old DNS infrastructure was decommissioned overnight at 02:00 during the migration wave.

## 5 Whys Analysis
1. Why did Group Policy fail to apply on DESKTOP-FB031 and two other Finance-OU machines?
- Because Group Policy could not reach a domain controller (Events 1058, 1030, 1129 all attribute failure to no DC connectivity/SYSVOL access).

2. Why could the machines not reach a domain controller?
- Because Netlogon could not establish a secure channel, and the DNS query for the domain controller's FQDN (FINBRIDGE-DC01.finbridge.local) returned no response (Event 5719), later confirmed as a full resolution timeout (Event 1014).

3. Why did DNS resolution for the domain controller fail?
- Because the affected machines were using DNS server 10.10.3.250, which had been decommissioned at 02:00 that same night and could no longer answer queries (Event 50036 at 07:42:18).

4. Why were the machines using a decommissioned DNS server?
- Because DHCP assigned it to them as part of their lease — the DHCP scope for the Floor 3 subnet still listed the old DNS server as an option.

5. Why did the DHCP scope still list the decommissioned DNS server?
- Because the DHCP scope for this subnet was not updated to the new DNS server (10.10.0.10) when the old DNS infrastructure was retired during the migration wave — confirmed directly in the event annotation and corroborated by the server-side DHCP log comparison, which shows the same unupdated-scope pattern for FB055-FB057 against the Floor 3 local DNS server (172.16.5.5).

## Resolution Actions Applied
Not confirmed by the evidence provided. Recommended next actions (see Triage document, Top 10 Solutions) are: correct the DHCP scope DNS option(s) for the affected subnet(s), force lease renewal on affected machines, and validate Group Policy processing succeeds (Event 1500) afterward. This RCA does not assume these actions have already been completed, as no corresponding success/recovery event for FB031 (or the other two affected machines) was supplied.

## Verification of Recovery
Not yet evidenced for the affected machines. Verification should require, at minimum: a DHCP Client Event 50036 on each affected machine showing DNS 10.10.0.10 assigned, and a subsequent GroupPolicy Event 1500 (success) — the same pattern already observed on DESKTOP-FB029.

## Preventive Actions
1. Require DHCP scope validation (no references to a DNS server being retired) as a mandatory, sign-off-gated step before decommissioning any DNS server in future migration waves.
2. Add monitoring/alerting on Netlogon Event 5719 and GroupPolicy Events 1058/1129 fleet-wide to catch DC-connectivity breaks within minutes rather than through user-reported symptoms.
3. Audit all DHCP scopes on subnets touched by this migration wave for any remaining references to decommissioned DNS servers (10.10.3.250, 172.16.5.5), not just the one confirmed above.
4. Confirm the hostname discrepancy between the workstation-level evidence (FB031/FB029) and the server-side DHCP comparison (FB055-FB058) to ensure full scope of impact is accurately understood, rather than assumed.

## Ownership
- Incident owner: DWP Engineering
- Network/DHCP scope correction: Network/Infrastructure team (owner not specified in evidence provided)
