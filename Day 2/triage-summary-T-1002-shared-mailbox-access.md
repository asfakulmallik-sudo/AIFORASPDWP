# Triage Summary

## Ticket reference
T-1002

## Summary (one line)
Finance user cannot open a shared mailbox after a migration.

## Impact (who/how many/ business urgency)
- Affected user: one Finance user reported (to confirm).
- Scope: one shared mailbox reported (to confirm).
- Business impact: user cannot access the shared mailbox, which may affect Finance team workflows (to confirm).
- Business urgency: to confirm.

## Known facts
- The user cannot open a shared mailbox.
- The issue began after a migration.

## Missing information to gather
- User name, contact details, and the name/address of the shared mailbox.
- Details of the migration (what was migrated, when, and by whom).
- Exact error message or behaviour when trying to open the mailbox (e.g. "add mailbox" fails, mailbox missing, access denied).
- Whether the mailbox is accessed via Outlook desktop, Outlook web, or both.
- Whether the user has access to their own primary mailbox normally.
- Whether other users who need this shared mailbox are also affected.
- Whether the user's permissions to the shared mailbox were re-applied after migration.
- Any recent password, MFA, or account changes.

## Likely category
Exchange/Microsoft 365 mailbox permissions or migration issue (to confirm).

## Suggested first diagnostic step
Confirm the exact error message when the user attempts to open the shared mailbox, then check whether the user's permissions on that mailbox were retained post-migration (to confirm).
