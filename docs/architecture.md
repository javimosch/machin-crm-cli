# Architecture

For anyone extending, self-hosting, or just wanting to understand what's actually happening under the JSON.

## The shape

One static binary ([machin](https://github.com/javimosch/machin)/MFL, compiled through C) over one SQLite file. No server process required for the core CRUD — `crm serve` is opt-in, only needed for the webhook sink. The source is split:

- `src/core.src` — pure, side-effect-free helpers (`e164`, `esc`, `flagv`, `has_flag`, `merge_field`, `merge_stage`, `version_str`). No database, no network, no `exit`. This split exists specifically so these can be unit-tested without a `main()` colliding with `crm.src`'s.
- `src/crm.src` — everything else: the schema, every command, the webhook handlers.
- `framework/machweb.src`, `framework/smtp.src` — vendored machin framework modules (HTTP server, SMTP client), composed in at build time by `build.sh`.

## The schema

Four tables, deliberately kept small:

```sql
contacts(id, name, company, email, phone, source, stage, next_action, next_due, created, updated)
events(id, contact_id, channel, direction, summary, ref, ts)
outreach(id, contact_id, channel, subject, body, status, created, sent_at, error)
suppress(addr, reason, ts)
```

**Two tables by design** was the original principle — `contacts` + `events` is the whole CRM; `outreach` and `suppress` were added later, only once real dogfooding forced them (a campaign needed somewhere to live; a DNC list needed somewhere to live). No `deals`, no `tasks` table — those get added only when the same forcing function shows up, not speculatively.

`stage` is a plain string, not an enum with a rigid lifecycle — `new → contacted → replied → meeting → deal → won/lost` is the convention, not an enforced state machine. Nothing stops you from setting an arbitrary value; `crm pipeline` will just show it as its own bucket.

## The audit trail

A fifth table backs `crm undo`:

```sql
audit(id, op_id, ts, cmd, tbl, row_id, action, before)
```

Every reversible mutation (`stage`, `next`, `sent`, `suppress`, `merge`/`dedup --auto`) writes one row **per table-row it touches**, all sharing one `op_id` — so a command that touches multiple rows (`crm sent` updates `outreach`, inserts an `events` row, and updates `contacts`) undoes as a single atomic-feeling operation, even though it's three separate audit entries.

`action` is one of:
- **`update`** — `before` is a full snapshot of the row (the raw query result, a one-element JSON array) captured *before* the mutation. Undoing replays the snapshot's values back with a plain `UPDATE`.
- **`insert`** — `before` is empty. Undoing is a `DELETE` by id (or by `addr` for the `suppress` table, which has no `id` column).
- **`delete`** — `before` is a full snapshot captured before the row was deleted. Undoing is a fresh `INSERT` with the original id.

`crm merge` additionally uses two narrower `tbl` values — `events_reassign` and `outreach_reassign` — whose `before` is just `{"contact_id": "<original>"}`, not a full row snapshot. This matters: a merge moves an event's `contact_id` without touching any of its other columns, and undoing it should only move `contact_id` back, not risk clobbering something else that changed on that row in the meantime. Reassignment gets its own minimal, targeted undo rather than reusing the full-row restore.

`crm undo [--n N]` finds the last N distinct `op_id`s (by `MAX(rowid)`, so it's insertion-order-correct even if timestamps collide within the same second), replays each entry's inverse, then deletes the consumed `op_id`'s rows — which is *why* undo can't itself be undone, and why independent earlier operations are untouched by a later one's undo (they're simply different `op_id` groups).

**Why `crm send`/`crm call` aren't in this system:** they cause a real external side effect (an email delivered, a phone ringing) that no database write can take back. Wiring them into the audit trail would create a false sense of safety — `--dry-run` is the actual safety mechanism there, applied *before* the irreversible step instead of pretending to undo it after.

## Design principles, made concrete

- **Agent-first, not "also has an API."** The CLI *is* the interface. Every command is JSON in, JSON out, structured errors on stderr, semantic exit codes (`80` = bad usage/args, `90` = not found, `100` = external dependency missing/failed). There is no human GUI, and per the project's positioning, there never will be — the wedge is that a CRM driven by a program can't go stale the way one driven by a human does.
- **Deterministic over clever.** `crm dedup`'s three rules are plain string normalization and E.164 comparison — no fuzzy/Levenshtein matching, no ML. An agent needs to be able to explain *why* two contacts matched; "the model thought they were 87% similar" isn't debuggable. This is a deliberate v1 scope cut, not an oversight — see `docs/entity-resolution.md`.
- **BYO everything external.** SMTP creds, Bland's API key, the sending domain — all bring-your-own. crm-cli never touches your reputation, your cost, or (for calling specifically) your regulatory exposure. It's ops, not a rented account.
- **Pure logic is extracted and tested; DB-backed logic is tested against the real binary.** `src/core.src` + `test/core_test.src` cover anything that doesn't need a database. `test/integration.sh` drives the actual compiled `./crm` against a throwaway SQLite file and asserts on real state — because the promise made to an agent (and to a human reading this doc) is about the compiled binary's behavior, not an abstraction of it.
- **Releases are gated, not vibes.** `./release.sh vX.Y.Z` refuses to build or publish if `./test.sh` is red, or if `version_str()` in `src/core.src` doesn't match the tag. See the project README's "Release" section.
- **Fetch a lookup table once, not once per row.** `dedup_scan()` (§ Entity resolution) and `suppress_set()` are the same pattern applied twice: a per-row `SELECT` inside a loop is an easy first draft, but it turns an O(n) operation into n individual round-trips. Both were caught by a real load test (`crm dedup`/`crm dedup --auto` at 10k contacts; `send`/`call --dry-run`'s suppression check at scale — the latter measured at 3.60 minutes for 8,053 items, later implicated in a genuine host disk-I/O incident during testing) and fixed the same way: fetch the whole table into an in-memory set/map once per command, then do O(1) lookups against it.
