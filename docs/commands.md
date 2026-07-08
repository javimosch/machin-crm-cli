# Commands reference

Every command emits JSON on stdout (`{"ok":true,...}` on success, `{"ok":false,"error":"..."}` on stderr with a non-zero exit on failure). `crm help` (or `crm` with no args) prints this same surface as one JSON object — always in sync with the binary, so treat it as the source of truth if this page and the binary ever disagree.

`<contact>` anywhere below resolves by id, exact email, exact phone, or a name/company substring (most-recently-updated match wins on ambiguity). DB location: `$CRM_DB`, default `~/.crm-cli.db`.

## Contacts

### `crm add <name> [--company X] [--email X] [--phone X] [--source X] [--stage X]`
Upsert a contact. Dedups by exact email first, then exact phone. Existing fields are only overwritten if you pass a non-empty value — safe to call again with the same email to update just one field.
```sh
crm add "Alex Founder" --company Acme --email alex@acme.com --source manual
# {"ok":true,"created":true,"id":"a1b2c3d4e5f6...","name":"Alex Founder"}
```

### `crm log <contact> <channel> <summary> [--ref X] [--direction in|out]`
Append a touch to the timeline. `channel` is free-form (`email`, `call`, `note`, whatever fits). A `new` contact auto-advances to `contacted`.
```sh
crm log acme call "left a voicemail" --direction out
```

### `crm stage <contact> <new|contacted|replied|meeting|deal|won|lost>`
Set the pipeline stage directly. Undoable (see [Safety rails](safety-rails.md)).

### `crm next <contact> <action> [--due YYYY-MM-DD | --due "+4 days"]`
Set what's due next. `--due "+N days"` resolves relative to today. Undoable.
```sh
crm next acme "send proposal" --due "+3 days"
```

### `crm show <contact>`
The contact plus its full event timeline, oldest first.

### `crm list [--stage X]`
All contacts, optionally filtered by stage.

### `crm due`
Contacts whose `next_due` is today or earlier.

### `crm pipeline`
Contact counts grouped by stage.

### `crm ingest '<json>'`
Bulk-upsert an array of `{"name":...,"email":...,"phone":...,"source":...}` — the sink for any lead source (a scraper, another CLI, a spreadsheet export).
```sh
crm ingest '[{"name":"Bo","email":"bo@y.com"},{"name":"Cy","email":"cy@z.com","phone":"0611223344"}]'
# {"ok":true,"ingested":2,"added":2}
```

## Campaigns — see [The outbound loop](outbound-loop.md) for the full lifecycle

### `crm queue <contact> <email|phone> [--subject X] [--body X]`
Stage one outreach message.

### `crm queue-bulk '<json>'`
Load a whole channel-routed campaign: `[{"contact":"...","channel":"email|phone","subject":"...","body":"..."}]`.

### `crm campaign [--channel email|phone] [--status queued|sent] [--summary] [--jsonl]`
Read the campaign back. `--summary` = counts by channel×status. `--jsonl` = one send-ready payload per line (`{to,subject,body,outreach}` for email, `{phone,company,script,outreach}` for phone). Neither flag = the full structured rows as JSON.

### `crm followups [--days 3] [--max-touches 3] [--limit 200] [--queue --subject S --body B]`
Who's due a second touch: `stage=contacted`, last outbound email ≥ N days ago, never replied, under the touch cap, nothing already queued. `--queue` stages wave 2 with `{{name}}`/`{{company}}` substituted per contact.

### `crm sent <outreach-id>`
Manually mark a queued item sent (for external send glue that isn't `crm send`/`crm call`): logs the touch, advances `new` → `contacted`. Undoable.

## Sending — native, no external mailer/dialer needed

### `crm send [--limit N] [--dry-run]`
Drip-sends queued **email** outreach over SMTP. `--dry-run` previews who'd get it (and who'd be skipped as suppressed) with zero SMTP config, zero network calls, zero DB writes.
```sh
export SMTP_HOST=smtp.resend.com SMTP_PORT=587 SMTP_FROM="you@yourdomain" SMTP_USER=resend SMTP_PASS=<resend-api-key>
crm send --dry-run
crm send --limit 20
```

### `crm call [--limit N] [--dry-run]`
Drip-dials queued **phone** outreach as AI cold-calls via [Bland](https://bland.ai) (BYO key). Numbers auto-normalize to E.164. `--dry-run` needs no key and places no call.
```sh
export BLAND_API_KEY=<your-bland-key>
crm call --dry-run
crm call --limit 20
```

### `crm suppress <email|phone> [reason]` (alias `unsub`, `dnc`)
Never contact this address/number again; cancels any queued outreach to it. One list covers both channels. Undoable.

## Safety — see [Safety rails](safety-rails.md) for the full model

### `crm undo [--n N]`
Revert the last N `stage`/`next`/`sent`/`suppress`/`merge` operations, LIFO. `crm send`/`crm call` are **not** undoable — that's what `--dry-run` is for.

## Entity resolution — see [Entity resolution](entity-resolution.md) for the full model

### `crm dedup [--limit N]`
Read-only: candidate duplicate pairs (`same_email`, `same_phone`, `same_name_company`).

### `crm dedup --auto [--limit N]`
Executes the safe merges (`same_email`, `same_phone`) to convergence; `same_name_company` always stays manual.

### `crm merge <primary> <dupe>`
Combine `dupe` into `primary`: fields fill in where primary was blank, stage advances if `dupe` progressed further, events and outreach reassign, `dupe` is deleted. Undoable.

## Webhook sink

### `crm serve [port]`
Runs a small HTTP server (default port `8790`) with three routes:

| Route | What it's for |
|---|---|
| `GET /_health` | liveness check |
| `POST /resend` | Resend webhook: opens/bounces/complaints auto-log and auto-suppress; replies log `stage=replied` |
| `POST /bland` | Bland call-outcome webhook: correlates by the `metadata.outreach` tag set at dispatch, logs the outcome, completes the outreach |

Set `RESEND_WEBHOOK_SECRET=whsec_…` to verify the Svix signature (rejects forged requests); without it, requests are accepted unverified (fine for local dev, not for a public endpoint).

## Meta

### `crm version` (alias `-v`, `--version`)
The installed release.

### `crm update` (alias `selfupdate`)
Re-runs the installer to fetch the latest release in place.

### `crm help` (or no args)
This same command surface as one JSON object.
