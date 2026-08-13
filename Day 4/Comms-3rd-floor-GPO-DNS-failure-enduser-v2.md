# End-User Communication - 3rd Floor Finance OU Group Policy / DNS Issue

## Audience 1 - Non-Technical Executive (under 80 words)
Your team's access and data are safe. On the morning of March 15, three computers on the 3rd floor (Finance) briefly failed to pick up their standard network settings during startup, between 7:40 and 7:44 AM, due to a leftover network address from an overnight upgrade. The setting has been corrected. No action is needed from you unless someone on your team reports the same issue recurring.

## Audience 2 - Affected End-User Team, 3rd Floor Finance (under 100 words)
On the morning of March 15, between about 7:40 and 7:44 AM, three computers on our floor briefly failed to apply their normal network settings during startup because of a leftover setting from an overnight network upgrade — your data was never at risk. This has now been corrected. If your computer still shows signs of this issue (for example, trouble reaching shared network drives), please restart it; if the problem continues after restarting, contact the DWP Service Desk for help.

## Audience 3 - Engineer-to-Engineer Internal Note
No length limit; full technical detail for handoff/recurrence.

**Incident window:** 07:40-07:44 local, startup-time only, 2024-03-15.

**Scope:** 3 of 4 machines in OU=Finance, 3rd floor. Confirmed hostname in workstation-level evidence: DESKTOP-FB031. Unaffected comparison: DESKTOP-FB029 (manually reconfigured with correct DNS pre-migration). Server-side DHCP log comparison shows the same affected/unaffected pattern for FB055-FB057 (affected) vs. FB058 (unaffected, manually set) - hostname naming between workstation-level and server-level evidence has not been cross-confirmed as referring to the same machines; verify by IP/lease/MAC correlation before treating scope as fully closed.

**Root cause:** DHCP scope for the affected 3rd floor subnet(s) was not updated when the old DNS infrastructure was decommissioned overnight at 02:00 during the migration wave. Affected machines were therefore leased a dead DNS server address (10.10.3.250 per FB031 evidence; 172.16.5.5 per the FB055-FB057 server-log evidence), which prevented DNS resolution of the domain controller FINBRIDGE-DC01.finbridge.local, which in turn broke Netlogon secure-channel establishment and Group Policy processing.

**Failure chain (event evidence):**
- 07:40:08 - Netlogon Event 5719 (Error): secure channel to FINBRIDGE failed, no DC available, DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 / 07:40:11 - GroupPolicy Event 1058 (Error): failed to access SYSVOL gpt.ini, error 0x3 (path not found).
- 07:40:10 - GroupPolicy Event 1030 (Warning): cannot query list of GPOs, error 0x546.
- 07:40:12 / 07:44:01 - GroupPolicy Event 1129 (Error): GP processing failed, no network connectivity to a domain controller.
- 07:41:05 - DNS Client Events Event 1014 (Warning): name resolution for FINBRIDGE-DC01.finbridge.local timed out, no configured DNS server responded.
- 07:42:18 - DHCP Client Event 50036 (Information): IP 10.10.3.144 leased; DNS assigned 10.10.3.250 (decommissioned at 02:00; correct DNS is 10.10.0.10; scope not updated).
- Comparison: DESKTOP-FB029 leased 10.10.3.141 with correct DNS (10.10.0.10) at 07:40:05 and logged GroupPolicy Event 1500 (success) at 07:40:11.

No service-crash event (application error / service-stop-with-error) is present in the evidence provided - the documented failure mode is Group Policy processing failure and Netlogon secure-channel failure driven by DNS resolution failure, not a crash.

**Exact action taken:** Corrected the DHCP scope option(s) for the affected 3rd floor subnet(s) to reference DNS server 10.10.0.10 and removed the reference to the decommissioned DNS server(s) (10.10.3.250 / 172.16.5.5). Forced a DHCP lease renewal (`ipconfig /release` + `ipconfig /renew`, or reboot) on the known affected machines so they picked up the corrected DNS server immediately rather than waiting for natural lease expiry.

**Config detail:**
- Subnet: 3rd floor Finance (evidenced IPs in the 10.10.3.0/24 range).
- Old/decommissioned DNS server(s): 10.10.3.250 (FB031 evidence), 172.16.5.5 (FB055-FB057 server-log evidence) - decommissioned 02:00 / overnight 2024-03-14 respectively, as part of the migration wave.
- Correct/current DNS server: 10.10.0.10.
- DHCP scope option changed: DNS servers (option 6) for the affected scope, updated to 10.10.0.10.

**Verification step:** On each affected machine, confirm DHCP Client Event 50036 shows DNS 10.10.0.10 assigned, then run `gpupdate /force` and confirm a GroupPolicy Event 1500 (success) is logged - the same pattern already observed on DESKTOP-FB029 and, per server logs, FB058.

**Preventive action needed:**
1. Make DHCP scope validation (confirm no active scope still references a DNS server being retired) a mandatory, sign-off-gated step before decommissioning any DNS server in future migration waves.
2. Add fleet-wide monitoring/alerting on Netlogon Event 5719 and GroupPolicy Events 1058/1129 to catch DC-connectivity breaks within minutes instead of via user-reported symptoms.
3. Audit all DHCP scopes on subnets touched by this migration wave for any remaining references to decommissioned DNS servers (10.10.3.250, 172.16.5.5), not just the ones confirmed here.
4. Reconcile the hostname discrepancy between workstation-level evidence (FB031/FB029) and server-side DHCP log evidence (FB055-FB058) to confirm the true full scope of impact.
