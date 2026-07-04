# crm-cli — the agent-first CRM

A local-first, single-binary CRM (MFL/machin over SQLite). It is the **sink** for the
outreach machine ([grepapi](../grepapi) / bland / resend): every contact and every touch
lands here as **two tables — contacts + their event timeline**. The primary user is an
**agent**: JSON on stdout, structured errors on stderr, semantic exit codes, no UI tax.

## Why
Every CRM dies of stale data because humans won't do data entry. This one is written to be
driven by an agent and auto-fed by the outreach tools — so it stays current with ~zero
manual effort. The wedge isn't "self-maintaining" (table stakes); it's **agent-first**.

## Build
`./build.sh`  →  `./crm`  (needs `machin` on PATH)

## Commands
```
crm add <name> [--company --email --phone --source --stage]   # upsert (by email)
crm log <contact> <channel> <summary> [--ref --direction in|out]   # append a touch
crm stage <contact> <new|contacted|replied|meeting|deal|won|lost>
crm next <contact> <action> [--due 2026-07-08 | --due "+4 days"]
crm show <contact>            # contact + full timeline
crm list [--stage X]
crm due                       # next steps due today / overdue
crm pipeline                  # counts by stage
crm ingest '<json>'           # bulk upsert from grepapi leads (the sink)
```
`<contact>` resolves by id, exact email, or a name/company substring. DB at `$CRM_DB`
(default `~/.crm-cli.db`).

## Pairs with grepapi
grepapi owns **top-of-funnel leads**; crm-cli owns **post-engagement relationships**. The
handoff is *"they engaged."* The `grepapi-call` / `grepapi-email` glue logs each touch here.
