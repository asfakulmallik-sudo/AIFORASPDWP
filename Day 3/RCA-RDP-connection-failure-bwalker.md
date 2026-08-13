# Root Cause Analysis (RCA): RDP Connection Failure and Account Lockout (bwalker)

## Incident Summary
- Account: FINBRIDGE\bwalker
- Client source: 10.10.5.44
- Logon type: 10 (RemoteInteractive / RDP)
- Incident window reviewed: 2024-03-15 14:01:02 to 14:22:09 (approx. 21 minutes)
- Symptom: User reported an RDP connection failure. Logs show the client was repeatedly disconnected/rejected during authentication, the account was subsequently locked out, and a successful RDP logon eventually occurred ~16 minutes later.

> **Note on scope:** The provided logs show no service crash events (e.g., no Service Control Manager 7031/7034/7023 entries for Remote Desktop Services or TermService). The Remote Desktop listener remained available throughout the window — it accepted a new TCP connection (Event 131) and completed a successful logon (Event 4624) at the end of the sequence. The failure pattern in these logs is an **authentication/lockout issue**, not a service outage or crash. This RCA analyzes the connection failure and its most likely cause accordingly.

## Event ID Reference: What Each Log/Event Records

### System Log — Source: TermDD, Event ID 56 (Error) — Security Layer Protocol Error
Records a failure detected by the Terminal Server Device Driver (TermDD) at the RDP security/transport layer, where the protocol stream sent by the client did not conform to expectations, causing the server to forcibly disconnect the client. It includes the client IP address.

In this incident:
- Logged at 14:01:02 for client 10.10.5.44.
- Indicates the RDP session was torn down at the protocol/security-negotiation layer, before or during credential exchange, rather than during a stable, authenticated session.

### System Log — Source: RemoteDesktopServices-RdpCoreTS, Event ID 140 (Warning) — Connection Failed: Bad Credentials
Records that an incoming RDP connection attempt failed specifically because the user name or password supplied was not correct. It includes the client IP address. This is logged by the RDP Core Transport Service (RdpCoreTS), the modern component handling RDP protocol/session negotiation (including Network Level Authentication).

In this incident:
- Logged at 14:01:02 (same timestamp as the TermDD 56 event) for client 10.10.5.44.
- Confirms the protocol-layer disconnect (TermDD 56) coincided with a credential validation failure — the client's authentication attempt was rejected at the network level before a full interactive session was established.

### System Log — Source: RemoteDesktopServices-RdpCoreTS, Event ID 131 (Info) — New TCP Connection Accepted
Records that the RDP listener accepted a new incoming TCP connection from a client, identified by IP and source port. This is purely a transport-layer (TCP handshake) event — it does not indicate authentication success or failure, and it does not indicate anything about server health.

In this incident:
- Logged at 14:22:07 for client 10.10.5.44:52341.
- Shows the client initiated a fresh connection attempt roughly 16 minutes after the account was locked out, and that the RDP service was listening and accepting connections normally (i.e., the service itself was never down).

### Security Log — Event ID 4625 (Audit Failure) — Failed Logon
Records a failed authentication attempt. It includes the account name, failure reason, logon type, and source IP.

In this incident:
- Three occurrences: 14:01:04, 14:03:18, and 14:05:33.
- All are for account FINBRIDGE\bwalker, Logon Type 10 (RemoteInteractive, i.e., RDP), failure reason "Unknown username or bad password," from source IP 10.10.5.44.

### Security Log — Event ID 4740 (Audit Failure) — Account Locked Out
Records when an account is locked out after exceeding the configured bad-password attempt threshold. It includes the account name and the caller computer that triggered the lockout.

In this incident:
- Logged at 14:05:34, one second after the third 4625 failure.
- Account FINBRIDGE\bwalker was locked out; caller computer recorded as 10.10.5.44 (the RDP client itself is recorded as the source of the triggering attempt).

### Security Log — Event ID 4624 (Audit Success) — Successful Logon
Records a successful authentication/logon. It includes the account name, logon type, and source IP.

In this incident:
- Logged at 14:22:09, two seconds after the new TCP connection (Event 131) was accepted.
- FINBRIDGE\bwalker successfully authenticated via RDP (Logon Type 10) from 10.10.5.44, confirming the account was unlocked/reset and the correct credentials were used.

## Reconstructed Sequence of Events (Plain English)
1. At 14:01:02, bwalker's client (10.10.5.44) attempted an RDP connection, but it was rejected at the protocol/security layer — the client presented invalid credentials during the connection negotiation, and the server (TermDD) tore down the connection while RdpCoreTS logged the specific reason: incorrect user name or password.
2. At 14:01:04, this same failed attempt was recorded in the Security log as a formal failed logon (4625) for bwalker, Logon Type 10, bad password, from 10.10.5.44.
3. At 14:03:18, a second failed logon attempt occurred for bwalker from the same source, again due to bad password.
4. At 14:05:33, a third failed logon attempt occurred, same account, same reason, same source.
5. At 14:05:34 — immediately after the third failure — the account lockout threshold was reached and bwalker's account was locked out (4740), with 10.10.5.44 recorded as the triggering source.
6. For the next ~16 minutes (14:05:34 to 14:22:07), no further connection attempts are recorded, consistent with either the client pausing after repeated failures or the lockout duration/administrative unlock elapsing.
7. At 14:22:07, the client from 10.10.5.44 initiated a new RDP connection, and the server accepted the TCP connection normally (Event 131), showing the RDP service was healthy and listening throughout.
8. At 14:22:09, bwalker successfully authenticated (4624), confirming that by this point the account was no longer locked and the correct credentials were supplied, resolving the incident.

## Most Likely Cause of the RDP Connection Failure
**Most likely cause:** The user's RDP client was submitting an incorrect password (or stale/cached credentials) for account bwalker. Three consecutive bad-password attempts within about 4.5 minutes tripped the domain/local account lockout policy, which then blocked all further logon attempts — including any subsequent correct-password attempts — until the lockout window expired or was cleared. The initial "connection failure" the user experienced (TermDD 56 disconnect) was the direct result of this same bad-credential negotiation, not a separate service fault.

There is **no evidence of a Remote Desktop Services crash or outage** in the provided logs:
- No Service Control Manager error events (7031/7034/7023) are present for TermService/RDS.
- The RDP listener successfully accepted a new TCP connection (Event 131) at 14:22:07, well within the incident window — proving the service was up and reachable the entire time.
- The eventual successful logon (4624) at 14:22:09 further confirms the RDS stack was fully functional; only the specific account's credentials/lockout state were blocking access.

### Evidence from Events
- **Correlated protocol failure and bad-credential warning at the same timestamp (TermDD 56 and RdpCoreTS 140, both 14:01:02):** Shows the "connection failure" reported was, at its root, an authentication rejection rather than a network/service-layer problem.
- **Three 4625 failures for the same account, same logon type, same source, same failure reason, spaced a few minutes apart (14:01:04, 14:03:18, 14:05:33):** A consistent, repeated pattern pointing to the same incorrect credential being retried, not a transient or random glitch.
- **4740 lockout event immediately following the third 4625 (14:05:34):** Directly ties the repeated bad-password attempts to the account being locked, per lockout policy enforcement.
- **~16-minute gap with no logged activity, followed by a fresh TCP connection (131) and immediate success (4624) at 14:22:07–14:22:09:** Demonstrates the RDP service remained available and functioning; the only change between the failing attempts and the successful one was the account's lockout state and/or the credentials used.

## 5-Whys Analysis

### Problem Statement
The user (bwalker) was unable to establish an RDP connection from 10.10.5.44, experiencing a protocol-level disconnect followed by repeated authentication failures and an account lockout, before finally connecting successfully about 21 minutes later.

1. **Why did the RDP connection fail at 14:01:02?**
   - Because the client's credentials were rejected during authentication negotiation (RdpCoreTS 140: "user name or password is not correct"), causing the security layer to disconnect the session (TermDD 56).

2. **Why were the credentials rejected?**
   - Because an incorrect password (or username) was submitted for FINBRIDGE\bwalker, as confirmed by three consecutive Security log failures (4625) with failure reason "Unknown username or bad password," Logon Type 10, from 10.10.5.44.

3. **Why did the failed attempts continue and escalate to an account lockout?**
   - Because the same incorrect credentials were retried multiple times in quick succession (14:01:04, 14:03:18, 14:05:33) without a successful attempt in between, reaching the account lockout policy's bad-password threshold, which triggered lockout (4740) at 14:05:34.

4. **Why was the same incorrect credential retried multiple times instead of being corrected sooner?**
   - Most likely due to user error — such as a mistyped password, an outdated cached/remembered password, or Caps Lock/keyboard layout mismatch — combined with no immediate feedback loop warning the user they were nearing the lockout threshold before each retry.

5. **Why did this result in an extended ~16-minute access disruption rather than a quick recovery?**
   - Because once locked out, the account could not authenticate regardless of credential correctness until the lockout duration elapsed (or was cleared by an administrator) — the logs show no further attempts between 14:05:34 and 14:22:07, consistent with the user/client waiting out the lockout window rather than having a faster self-service unlock path.

## Root Cause
**Primary root cause:** Repeated incorrect password submissions for FINBRIDGE\bwalker during RDP logon from 10.10.5.44 triggered the account lockout policy, which blocked all further RDP access — including the initial protocol-layer disconnect the user perceived as a "connection failure" — until the lockout condition cleared and correct credentials were supplied.

**Contributing factors:**
- No client-side or user-facing warning of remaining logon attempts before lockout.
- No evidence of a faster self-service unlock/reset mechanism, resulting in an extended (~16-minute) access gap.
- Possible stale/cached credentials on the client at 10.10.5.44 causing automatic retry of the same invalid password.

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
- Confirm with bwalker whether the credential used was mistyped or a stale cached/remembered password, and have them update any saved RDP credentials on the client (10.10.5.44).
- Verify the account unlocked naturally after policy duration or confirm whether IT support unlocked it; document which occurred.

### Preventive Actions
- User guidance: instruct users to verify credentials (and clear cached RDP credentials via Credential Manager) before repeated retry attempts.
- Alerting: configure a lower-threshold alert (e.g., 2 consecutive 4625 failures with the same account/source within a short window) to notify the service desk before lockout occurs, enabling proactive outreach.
- Self-service: evaluate enabling self-service account unlock/password reset to reduce time-to-recovery for lockout events.
- Policy review: confirm the current lockout threshold (3 attempts observed here) and lockout duration align with organizational balance between security and usability; consider whether a short lockout duration would have reduced the ~16-minute gap.
- Client hygiene: review RDP client configuration on 10.10.5.44 for saved/cached credentials that may cause automatic repeated failed attempts.

## Confidence and Limitations
- **Confidence:** High that the connection failure and lockout were driven by repeated bad-password attempts, based on the direct correlation between TermDD 56, RdpCoreTS 140, and the three 4625 events, followed by 4740.
- **Confidence:** High that no service crash occurred, based on the absence of any Service Control Manager error events and the presence of a successful new connection (131) and logon (4624) within the same window.
- **Limitation:** The logs do not indicate whether the account unlocked automatically (lockout duration expiry) or via administrator action, nor do they confirm the exact cause of the repeated bad password (user typo vs. cached credential). Reviewing the domain controller's lockout duration policy and any helpdesk unlock activity (Event ID 4767) would confirm the recovery mechanism.

## Final Determination
The RDP "connection failure" was caused by FINBRIDGE\bwalker's client (10.10.5.44) repeatedly submitting an incorrect password, which was rejected at the protocol/security layer (TermDD 56, RdpCoreTS 140) and recorded as failed logons (4625 x3). This triggered an account lockout (4740) that blocked further access for approximately 16 minutes, after which a new connection with correct credentials succeeded (Event 131, then 4624). No evidence of a Remote Desktop Services crash or outage was found; the Remote Desktop service remained available throughout, and the root cause is attributed to repeated invalid credential submission leading to policy-driven account lockout.
