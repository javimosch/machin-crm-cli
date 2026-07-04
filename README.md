# crm-cli — the agent-first CRM

A local-first, single-binary CRM (MFL/[machin](https://github.com/javimosch/machin) over
SQLite). It is the **sink** for an outreach machine (any lead-gen / calling / email tool):
every contact and every touch lands here as **two tables — contacts + their event
timeline**. The primary user is an **agent**: JSON on stdout, structured errors on stderr,
semantic exit codes, no UI tax.

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

## Webhook sink — `crm serve` (auto-log replies, opens, bounces)
crm-cli can receive **Resend webhooks** and update itself, so even *inbound* signals log with
zero effort:
```
crm serve 8790          # POST /resend  +  GET /_health
```
| Resend event | What crm-cli does |
|---|---|
| `email.opened` | logs an "opened" event (engagement) |
| `email.bounced` | logs it + sets the contact `stage=lost` |
| `email.complained` | logs the complaint + `stage=lost` (suppress) |
| `email.received` (a reply) | logs `REPLY — <subject>` + `stage=replied` |

**Security:** set `RESEND_WEBHOOK_SECRET=whsec_…` and crm-cli verifies the Svix signature on
every request (rejects unsigned/forged ones). Without it, requests are accepted (local dev).

**Deploy (local-first):** run `crm serve`, expose it publicly with
[hotify-cli](https://github.com/javimosch/hotify-cli) (e.g. `crm.you.dev`), and register the
URL in Resend → Webhooks. Event webhooks (opens/bounces/complaints) work immediately.
**Inbound replies** additionally need a Resend **inbound domain** (MX records → Resend) and
your outreach `reply-to` pointed at that address — then replies flow through the webhook.

## Pairs with a lead engine
Your lead engine owns **top-of-funnel leads**; crm-cli owns **post-engagement
relationships**. The handoff is *"they engaged."* Have your calling / email glue shell out to
`crm add` + `crm log` after each touch — the CRM then self-populates with zero data entry.
(Built to pair with [machin](https://github.com/javimosch/machin)-based outreach tools.)
