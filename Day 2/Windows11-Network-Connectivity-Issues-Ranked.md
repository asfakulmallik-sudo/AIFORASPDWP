# Windows 11 Network Connectivity Issues — Ranked by Frequency

Ranked from most common to least common, with fixes and preventive actions.

## 1. Wi-Fi driver / adapter issues (most common)
- **Symptoms:** Wi-Fi drops intermittently, adapter not detected, slow/unstable connection.
- **Fix:** Update or roll back the Wi-Fi driver via Device Manager/Windows Update; disable/re-enable the adapter; run the Windows Network Troubleshooter.
- **Preventive action:** Keep drivers updated via a managed patching process; standardise driver versions across the device fleet.

## 2. Incorrect Wi-Fi credentials / saved profile corruption
- **Symptoms:** "Can't connect to this network," repeated password prompts, connects then drops.
- **Fix:** Forget the network and reconnect with correct credentials; remove and recreate the Wi-Fi profile.
- **Preventive action:** Use certificate/SSO-based enterprise Wi-Fi (e.g. 802.1X) instead of static passwords where possible.

## 3. IP configuration issues (DHCP failure, IP conflict, APIPA address)
- **Symptoms:** Limited connectivity, no internet access, device gets a 169.254.x.x address.
- **Fix:** Run `ipconfig /release` and `ipconfig /renew`; `ipconfig /flushdns`; restart the DHCP client service.
- **Preventive action:** Ensure adequate DHCP scope size; monitor for scope exhaustion; use static reservations for critical devices.

## 4. VPN client issues (split tunnelling, expired certs, client crash)
- **Symptoms:** VPN connects but no access to internal resources; VPN fails to establish; frequent disconnects.
- **Fix:** Restart the VPN client/service; reinstall or update the VPN client; check certificate validity.
- **Preventive action:** Automate certificate renewal; keep VPN client version standardised and patched.

## 5. DNS resolution failures
- **Symptoms:** Internet/intranet sites unreachable by name but reachable by IP.
- **Fix:** `ipconfig /flushdns`; change/reset DNS server settings; verify DNS server reachability.
- **Preventive action:** Use redundant, monitored internal DNS servers; push DNS settings via group policy/Intune rather than manual entry.

## 6. Group Policy / Conditional Access blocking network access
- **Symptoms:** Device connects to Wi-Fi/VPN but is blocked from specific internal resources; compliance-related access denial.
- **Fix:** Check device compliance status in Intune; review applicable Conditional Access policies; resync device compliance.
- **Preventive action:** Regularly audit Conditional Access and compliance policies for unintended scope; communicate policy changes in advance.

## 7. Network adapter disabled or in airplane mode
- **Symptoms:** No available networks shown at all.
- **Fix:** Turn off airplane mode; enable the network adapter in Device Manager/Settings.
- **Preventive action:** User awareness/training; lock down airplane mode toggle via policy if not needed.

## 8. Physical/hardware faults (damaged NIC, faulty cable, dock/port failure)
- **Symptoms:** Ethernet port not recognised, intermittent physical disconnects, no link light.
- **Fix:** Test with a different cable/port/dock; replace faulty hardware.
- **Preventive action:** Periodic hardware health checks; asset refresh cycles for ageing hardware.

## 9. Firmware/BIOS-level network issues
- **Symptoms:** Network adapter missing after OS update, inconsistent behaviour not resolved by driver updates.
- **Fix:** Update BIOS/firmware to the latest supported version; check vendor advisories.
- **Preventive action:** Include firmware updates in the standard patching/imaging process.

## 10. Third-party security software conflicts (firewall/antivirus blocking traffic)
- **Symptoms:** Connectivity works after disabling third-party firewall/AV, or specific ports/protocols blocked.
- **Fix:** Review firewall/AV rules; temporarily disable to confirm conflict, then create an appropriate exclusion/rule.
- **Preventive action:** Standardise on approved security software with pre-validated rule sets; test rule changes before wide rollout.

## 11. Proxy misconfiguration
- **Symptoms:** Browser/apps can't reach the internet or internal sites, works on some apps but not others.
- **Fix:** Check and correct proxy settings (manual/PAC file); clear proxy cache.
- **Preventive action:** Deploy proxy settings centrally via policy rather than manual configuration.

## 12. Corrupted network stack (Winsock/TCP-IP corruption) (least common)
- **Symptoms:** Persistent connectivity issues not resolved by any of the above, "no internet" despite valid IP/DNS.
- **Fix:** Reset the network stack: `netsh winsock reset` and `netsh int ip reset`, then restart the device.
- **Preventive action:** Avoid unauthorised network-related software installs/uninstalls that can corrupt the stack; keep OS builds patched.

> Note: Ranking reflects general/typical service desk experience, not DWP-specific incident data — Need to confirm against DWP's own incident history for an accurate ranking.
