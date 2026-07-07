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

## Install
```sh
curl -fsSL https://raw.githubusercontent.com/javimosch/machin-crm-cli/master/install.sh | sh
```
Downloads the prebuilt binary (no compiler needed), verifies it runs on your box, and falls
back to build-from-source otherwise. Then:
```sh
crm version     # the installed release
crm update      # self-update to the latest release (honors CRM_BIN_DIR)
```
Prebuilt is `linux-x64` (glibc ≥ 2.35, needs `libssl3` + `libsqlite3`; Ubuntu 22.04+/Debian 12+).
Older glibc / musl / macOS / arm64 auto-fall-back to source (needs `machin` + a C compiler + git).
Hosted, always-on version: **[crmd.intrane.fr](https://crmd.intrane.fr)**.

## Build from source
`./build.sh`  →  `./crm`  (needs `machin` on PATH + a C compiler)

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
crm queue <contact> <email|phone> [--subject --body]   # stage one outreach
crm queue-bulk '<json>'       # load a whole channel-routed campaign (array of {contact,channel,subject,body})
crm campaign [--channel email|phone] [--status queued|sent]   # the staged campaign as JSON
crm followups [--days 3 --max-touches 3] [--queue --subject S --body B]   # who is due a bump; --queue stages wave 2
crm sent <outreach-id>        # mark sent + log the touch + advance the contact to contacted
```
`<contact>` resolves by id, exact email, or a name/company substring. DB at `$CRM_DB`
(default `~/.crm-cli.db`).

## Campaigns live in the CRM (`queue` → read → `sent`)
The CRM owns the outbound campaign, not a scratch file. Route by channel at load time
(cold-mail if the lead has an email, phone otherwise); then an operator/agent **reads it back**
three ways — digest, structured, or send-ready — and any glue (grepapi/bland/Resend) sends from it:
```
crm queue-bulk '[{"contact":"a@b.fr","channel":"email","subject":"…","body":"…"}, …]'   # load

crm campaign --summary                     # DIGEST: counts by channel × status, at a glance
crm campaign [--channel email|phone]       # STRUCTURED: full rows joined w/ contact (JSON)
crm campaign --channel email --jsonl       # SEND-READY: one payload/line → {to,subject,body,outreach}
crm campaign --channel phone --jsonl       #            → {phone,company,script,outreach}

crm sent <outreach-id>                     # after each send: marks sent, logs a touch, stage→contacted
```
`--jsonl` is the send-glue contract: pipe it straight into a Resend batch / bland caller, or
`> batch.jsonl` to backfill a file.

### Follow-ups — `crm followups` (the second half of a campaign)
Most cold-email replies come from touches 2-3; `followups` selects who is **due a bump** —
`stage=contacted`, last outbound email ≥ N days ago, never replied (no inbound event), under the
touch cap, nothing already queued — and with `--queue` stages wave 2 as ordinary outreach that
`crm send` drip-sends. `{{name}}`/`{{company}}` are substituted per contact:
```
crm followups --days 3                        # dry-run: the candidates as JSON
crm followups --days 3 --queue \
  --subject "Re: quick note for {{company}}" \
  --body "Hi, bumping my last note — still relevant for {{company}}?"
crm send --limit 20                           # drip wave 2
```
Copy is the caller's job; the CRM owns the who/when (and never double-queues or bumps a replier).

### Sending, natively — `crm send` (email over SMTP)
crm-cli sends cold-email itself — no external mailer. It drip-sends the queued **email** outreach
over SMTP (point it at Resend, or any relay), respects a suppression list, appends an unsubscribe
footer, and on each send logs a touch + advances the contact's stage:
```
export SMTP_HOST=smtp.resend.com SMTP_PORT=587 SMTP_FROM="you@yourdomain"
export SMTP_USER=resend SMTP_PASS=<resend-api-key>          # Resend's SMTP; or any relay
crm send --limit 20        # → drip-sends 20 queued emails (2s apart), marks sent|error
crm suppress <email>       # never email again + cancels its queued outreach (alias: unsub)
```
### Calling, natively — `crm call` (AI cold-calls over Bland)
The twin of `crm send`, for the phone channel. It drip-dispatches the queued **phone** outreach as
AI voice calls through [Bland](https://bland.ai) — bring your own `BLAND_API_KEY` — and the call
outcome comes back through the same webhook sink:
```
export BLAND_API_KEY=<your-bland-key>       # BYO — you own the account + the compliance
export CRM_CALL_WEBHOOK=https://crm.you.dev/bland   # where Bland posts the outcome
export BLAND_LANG=fr CRM_COUNTRY_CODE=33     # optional: language + E.164 country default
crm call --limit 20        # → dials 20 queued numbers (the call script is the outreach body)
crm suppress <phone>       # DNC: never call again + cancels queued (alias dnc)
```
Numbers are normalized to E.164, `crm serve` receives the outcome on `POST /bland` (answered /
voicemail / no-answer) and logs it as a touch. **Cold-calling is more regulated than email**
(TCPA, Bloctel, calling hours) — BYO-Bland means *you* own the account, consent, and opt-out list.

### The whole outbound loop, one binary
```
crm ingest        →  contacts land (the sink)
crm queue-bulk    →  stage a channel-routed campaign (email + calls)
crm send          →  drip-send email over SMTP     ┐  both BYO
crm call          →  drip-dial cold-calls over Bland ┘
crm serve         →  webhook sink: Resend (opens/bounces/replies, auto-suppress)
                                 + Bland (call outcomes) → the CRM
```
A lead goes **queued → sent/dispatched → opened/answered → replied** (or bounced / no-answer /
suppressed) without leaving the CRM. Email *and* phone, both self-tracking, both BYO. Local-first
and single-binary today; the same shape lifts to a hosted multi-tenant service.

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
