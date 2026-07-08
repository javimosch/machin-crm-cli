# The outbound loop

The whole point of crm-cli is that a campaign lives *in* the CRM, not in a scratch file next to it. This page walks the full lifecycle, end to end.

```
crm ingest        →  contacts land (the sink)
crm queue-bulk     →  stage a channel-routed campaign (email + calls)
crm send            →  drip-send email over SMTP     ┐  both BYO
crm call             →  drip-dial cold-calls over Bland ┘
crm serve             →  webhook sink: Resend (opens/bounces/replies) + Bland (call outcomes) → the CRM
```

A lead goes **queued → sent/dispatched → opened/answered → replied** (or bounced / no-answer / suppressed) without leaving the CRM.

## 1. Get contacts in

Either one at a time (`crm add`) or in bulk from any lead source:
```sh
crm ingest '[{"name":"Bo","email":"bo@y.com","company":"Acme"},{"name":"Cy","phone":"0611223344"}]'
```

## 2. Stage a campaign

Route by channel at load time — email if the lead has an email, phone otherwise:
```sh
crm queue-bulk '[
  {"contact":"bo@y.com","channel":"email","subject":"Quick idea for Acme","body":"Hi Bo, ..."},
  {"contact":"0611223344","channel":"phone","body":"Hi, I'\''m calling about ..."}
]'
```

Read it back three ways, whichever fits the moment:
```sh
crm campaign --summary                    # counts by channel × status, at a glance
crm campaign --channel email               # full structured rows, joined with the contact
crm campaign --channel email --jsonl       # one send-ready payload per line
```
`--jsonl` is the contract for any external send glue: pipe it into a Resend batch script, a bland caller, or `> batch.jsonl` to inspect/backfill.

## 3. Send it

crm-cli sends both channels itself — no external mailer or dialer required:
```sh
export SMTP_HOST=smtp.resend.com SMTP_PORT=587 SMTP_FROM="you@yourdomain" SMTP_USER=resend SMTP_PASS=<resend-api-key>
crm send --dry-run       # ALWAYS do this first — see docs/safety-rails.md
crm send --limit 20      # drip-sends 20 (2s apart), marks each sent|error, logs a touch, advances stage
```
```sh
export BLAND_API_KEY=<your-bland-key>
crm call --dry-run
crm call --limit 20
```

If you're using different send glue instead (your own Resend batch script, `bland-cli`, whatever), mark each item sent yourself once it's out: `crm sent <outreach-id>`.

## 4. Get replies back — automatically

Run the webhook sink:
```sh
crm serve 8790
```

Expose it publicly (e.g. with [hotify-cli](https://github.com/javimosch/hotify-cli)) and register the URL in Resend → Webhooks. Set a shared secret so it verifies signatures:
```sh
export RESEND_WEBHOOK_SECRET=whsec_...
```

| Resend event | What crm-cli does |
|---|---|
| `email.opened` | logs an "opened" event (engagement) |
| `email.bounced` | logs it + `stage=lost` |
| `email.complained` | logs it + `stage=lost` (suppressed) |
| `email.received` (a reply) | logs `REPLY — <subject>` + `stage=replied` |

**Inbound replies** additionally need a Resend inbound domain (MX records → Resend) and your outreach's `reply-to` pointed at that address. For Bland, set `CRM_CALL_WEBHOOK` to `crm serve`'s public `/bland` URL when you dispatch — `crm call` sets it on every outbound call automatically if the env var is present, and the outcome (answered/voicemail/no-answer) logs itself the moment the call ends.

## 5. Follow up

Most replies come from touch 2 or 3, not touch 1. `crm followups` finds who's gone quiet and stages a bump for you:
```sh
crm followups --days 3                          # dry-run: who's due
crm followups --days 3 --queue \
  --subject "Re: quick note for {{company}}" \
  --body "Hi, bumping my last note — still relevant for {{company}}?"
crm send --limit 20                              # sends wave 2
```
It only selects contacts who are `contacted`, haven't replied, are past the day threshold, are under the touch cap, and don't already have something queued — so it's safe to run repeatedly.

## The compliance note

Cold-calling is more regulated than email (TCPA, Bloctel, calling hours) — `crm call` is BYO-Bland deliberately, so *you* own the account, consent, and opt-out list, not crm-cli. Every send/call checks the shared `suppress` list first (see [Safety rails](safety-rails.md)), and one `crm suppress <email|phone>` cancels queued outreach on either channel.
