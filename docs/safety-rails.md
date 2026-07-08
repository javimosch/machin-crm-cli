# Safety rails

An agent drives this CRM unsupervised. That's the whole point — but it means mistakes need a way back, and irreversible actions (an email sent, a call placed) need a way to preview them first. Two independent mechanisms cover this.

## `--dry-run`: preview before an irreversible action

`crm send` and `crm call` are the two commands that reach outside the CRM — once they run, an email is in someone's inbox or a phone has rung. Both support `--dry-run`, which composes the exact same preview (including the suppression check, and E.164 normalization for calls) with:
- no credentials required (no `SMTP_HOST`/`SMTP_FROM`, no `BLAND_API_KEY`)
- no network call
- no database writes

```sh
crm send --dry-run
# {"ok":true,"dry_run":true,"would_send":3,"would_skip":1,
#  "preview":[{"to":"bo@y.com","subject":"...","action":"send"},
#             {"to":"suppressed@x.com","subject":"...","action":"skip_suppressed"}, ...]}

crm call --dry-run
# {"ok":true,"dry_run":true,"would_call":2,"would_skip":0,
#  "preview":[{"to":"+33611223344","company":"Acme","action":"call"}, ...]}
```

Run `--dry-run` before every real batch, especially the first one against a new list.

## `crm undo`: reverting a mistake

Everything else that mutates the database — `stage`, `next`, `sent`, `suppress`, `merge` — is undoable. Under the hood, each of these writes an entry to an `audit` table: a full before-snapshot of every row it touched, grouped by one operation id.

```sh
crm stage acme lost      # ...wrong contact
crm undo                  # reverts the last operation
crm undo --n 3            # reverts the last 3, LIFO
```

What `undo` actually does, per entry in the operation it's reverting:
- **updated a row** → restores it to its exact pre-mutation state (including things you might not think of, like `crm sent`'s stage bump)
- **inserted a row** → deletes it (e.g. the touch that `crm sent` logged, or a suppress-list entry that didn't exist before)
- **deleted a row** → re-inserts it exactly as it was, same id (this is how undoing a `crm merge` brings the duplicate back)

A few things worth knowing:

- **Idempotent calls don't pollute the undo stack.** If you `crm suppress` an address that's already suppressed, nothing changes, so nothing is recorded — a subsequent `crm undo` correctly reaches back to the call that actually suppressed it, not a no-op.
- **Independent operations don't interfere.** If you suppress contact A, then separately suppress contact B, one `crm undo` reverts only B; A stays suppressed.
- **Consuming an operation deletes its trail** — so `undo` can't itself be undone. There's no redo.
- **`crm send` and `crm call` are explicitly NOT undoable.** An email already landed in an inbox, or a phone already rang — there's no database write that fixes that. This is exactly why `--dry-run` exists: it's the safety net *before* the irreversible step, since there isn't one after.

## Why two mechanisms, not one

They cover different failure modes. `--dry-run` prevents you from sending the wrong thing in the first place. `undo` fixes a wrong *record* of something that already happened correctly in the database (staged the wrong contact, suppressed the wrong number, merged the wrong pair). Neither one substitutes for the other — a `--dry-run` mistake never happens because nothing ran; an `undo` mistake means the mutation ran but was wrong, and now it's un-wrong.
