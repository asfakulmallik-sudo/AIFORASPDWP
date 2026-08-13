# Triage: Copilot Support Tickets

Default assumption: non-Copilot cause (permissions, indexing, licensing, sensitivity labels, or external sharing limits) unless evidence rules these out. Genuine Copilot fault is treated as a last resort, not a first guess.

---

## Ticket 1 — Finance lead: Copilot won't summarise the Q3 board pack in SharePoint. "It's right there, I can see it myself."

**Likely cause (ranked):**
1. Data indexing lag (file is new/recently modified/recently uploaded and hasn't been crawled yet).
2. Permissions/access boundary (user's *personal* view access may differ from the identity/permission Copilot's Graph connector evaluates, e.g. access via a sharing link rather than direct/group permission).
3. Sensitivity label restriction (board pack may carry a label with encryption/permissions that block AI processing).
4. Genuine Copilot fault.

**Fastest check:** Check the file's modified/uploaded date and confirm how the user's access was granted (direct permission vs. link vs. inherited) — recent files and link-based access are the two most common blockers.

**Is this actually a Copilot bug?** Unclear — needs the file's age/indexing status and the exact access method confirmed before it can be ruled in or out.

---

## Ticket 2 — New hire (started yesterday): Copilot in Outlook seems to know nothing about my recent emails.

**Likely cause (ranked):**
1. Data indexing lag (mailbox/content newly provisioned; initial indexing for a new mailbox typically takes time).
2. License/client prerequisite issue (Copilot licence assignment may not have fully propagated yet for a brand-new account).
3. Permissions/access boundary (unlikely for own mailbox, but worth a quick confirm).
4. Genuine Copilot fault.

**Fastest check:** Confirm the exact account creation/licence assignment timestamp and how long indexing has had to run — for a one-day-old account this is expected, not a fault.

**Is this actually a Copilot bug?** No, most likely — brand-new accounts routinely have indexing/licence propagation delays; evidence points away from a bug.

---

## Ticket 3 — HR manager: Asked Copilot in Word to pull data from a sensitive salary review spreadsheet, got "I don't have access to that content."

**Likely cause (ranked):**
1. Sensitivity label restriction (label config commonly blocks AI/Copilot processing on highly sensitive content by design).
2. Permissions/access boundary (may have access via a route Copilot doesn't honour, e.g. shared-with-me vs. direct grant).
3. License/client prerequisite issue.
4. Genuine Copilot fault.

**Fastest check:** Check the sensitivity label applied to the spreadsheet and its associated permissions/content-processing settings — this message is the expected behaviour for restricted labels.

**Is this actually a Copilot bug?** No — this is the documented/expected message when a sensitivity label blocks AI access to protected content, not a fault.

---

## Ticket 4 — Sales rep: Copilot in Teams can't find a client contract shared with her via a guest link from another org.

**Likely cause (ranked):**
1. Guest/external sharing limitation (Copilot generally has restricted or no ability to index/search content shared externally via guest access).
2. Data indexing lag (if the external tenant's sharing was very recent).
3. Permissions/access boundary.
4. Genuine Copilot fault.

**Fastest check:** Confirm the file's origin (external tenant, guest link) and whether it resides in the user's own tenant's indexed locations, or only in the external org's SharePoint/OneDrive.

**Is this actually a Copilot bug?** No — Copilot's grounding is scoped to the user's tenant content; cross-tenant guest-shared files are a known limitation, not a bug.

---

## Ticket 5 — IT admin: Copilot suddenly stopped working for the whole Finance team this morning, was fine yesterday.

**Likely cause (ranked):**
1. License/client prerequisite issue (bulk licence change, expiry, or group/policy assignment change affecting the whole team at once).
2. Permissions/access boundary (a Conditional Access, group membership, or policy change applied overnight to Finance).
3. Data indexing lag (less likely to affect an entire team simultaneously, but possible after a content/library-wide change).
4. Genuine Copilot fault (only plausible if this correlates with a known Microsoft 365 service incident affecting many tenants).

**Fastest check:** Check the Microsoft 365 Admin Center Service Health dashboard for any active Copilot/M365 incident, then check for any overnight licence, Conditional Access, or policy change scoped to the Finance group.

**Is this actually a Copilot bug?** Unclear — a sudden, team-wide, same-morning failure is the one pattern that could indicate a genuine service-side fault, but an admin-side change (licence/policy) is equally or more likely and must be ruled out first via Service Health and change logs.

---

## Ticket 6 — Manager: Copilot found and summarised a file I don't remember ever opening, from a folder I forgot I had access to.

**Likely cause (ranked):**
1. Permissions/access boundary (user does have legitimate access, e.g. via a group or inherited folder permission, they simply weren't aware of it).
2. Genuine Copilot fault — not applicable; this is expected behaviour, not a fault.

**Fastest check:** Check the folder's permission list/sharing settings to confirm the user (directly or via group membership) has legitimate access — Copilot only surfaces content the user is already permitioned to see.

**Is this actually a Copilot bug?** No — Copilot only returns results the requesting user already has permission to access; this is expected (if surprising) behaviour reflecting existing access, not a fault.

---

## Ticket 7 — Analyst: Copilot gives generic answers, doesn't seem to use any of our internal SharePoint content at all.

**Likely cause (ranked):**
1. Data indexing lag (content not yet indexed/crawled, e.g. new site, recently migrated content, or crawl paused/blocked).
2. Permissions/access boundary (user may lack access to the relevant SharePoint sites/libraries, so nothing is available to ground on).
3. License/client prerequisite issue (wrong client version, or Copilot not enabled for SharePoint/Graph connector in the tenant).
4. Genuine Copilot fault.

**Fastest check:** Check whether the analyst has confirmed access to the relevant SharePoint sites and whether search (not just Copilot) returns those files at all — if normal SharePoint search also fails, it's an indexing/permissions issue, not Copilot-specific.

**Is this actually a Copilot bug?** Unclear — needs confirmation of site access and whether standard SharePoint search surfaces the same content; if search also fails, the cause is indexing/permissions, not Copilot.

---

## Ticket 8 — Executive assistant: Copilot in Outlook can't see a shared mailbox's calendar that she manages on behalf of her director.

**Likely cause (ranked):**
1. Permissions/access boundary (Copilot in Outlook typically only operates against the signed-in user's own mailbox, not delegated/shared mailboxes, regardless of delegate permissions).
2. License/client prerequisite issue (shared mailbox access model may not support Copilot grounding).
3. Data indexing lag.
4. Genuine Copilot fault.

**Fastest check:** Confirm whether the request was made while working directly in the shared mailbox context versus the user's own mailbox — Copilot's support for shared/delegated mailboxes is limited by design.

**Is this actually a Copilot bug?** No — Copilot in Outlook is generally scoped to the signed-in user's own mailbox; lack of visibility into a delegated shared mailbox is a known product limitation, not a fault.
