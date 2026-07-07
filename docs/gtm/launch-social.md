# crmd / crm-cli launch — social copy (LinkedIn skipped)

Links:
- Post: https://blog.intrane.fr/the-crm-that-maintains-itself
- Product (hosted): https://crmd.intrane.fr
- Repo (free OSS): https://github.com/javimosch/machin-crm-cli

---

## X / Twitter — single post (primary)

Every CRM dies of stale data.

Not because the software is bad — because keeping it current is data entry, and nobody does data entry.

So I built the CRM you never open: an agent runs it, cold-mail + cold-calls send themselves, replies & call outcomes log themselves.

One binary. Open source. 👇
https://blog.intrane.fr/the-crm-that-maintains-itself

## X / Twitter — thread (alt, more reach)

1/ Every CRM you've used was accurate for about a week.

Then someone stopped logging calls and it became a graveyard. Keeping a CRM current is data entry — the work nobody wants.

So I built the opposite: the CRM you never open.

2/ crm-cli has no UI at all. Its primary user is an *agent*, not a person.

JSON in, JSON out, exit codes. Your agent drives it, your outreach tools feed it, the reply webhook updates it.

It stays current because nobody has to keep it current.

3/ The whole outbound loop is one binary:

ingest → queue → send (cold-mail, SMTP) + call (cold-calls, Bland) → serve (a webhook that auto-logs replies AND call outcomes, auto-suppresses bounces)

Email and phone, both self-tracking, both bring-your-own.

4/ It found its own first customers.

I pointed my lead engine (grepapi) at prospection agencies → 78 verified → one `crm ingest` → all staged, channel-routed, ready to send. The tools speak JSON to each other; I just state intent.

5/ Free & open source (local, your data, one SQLite file). Hosted from €19/mo if you want it always-on without running the ops.

Written in machin — one small static binary, no runtime, no node_modules.

https://crmd.intrane.fr

---

## Hacker News — Show HN

Title:
  Show HN: An agent-first CRM that maintains itself (one binary, open source)

URL: https://blog.intrane.fr/the-crm-that-maintains-itself

First comment:
  Every CRM I've used was accurate for about a week, then went stale — because
  keeping it current is data entry and nobody does data entry. The whole category
  optimizes the wrong thing: a human clicking in a browser.

  So crm-cli has no UI. The primary user is an agent (Claude Code, etc.): JSON on
  stdout, structured errors on stderr, semantic exit codes, `help-json`. The agent
  drives it, the outreach tools feed it, and a webhook auto-logs replies and call
  outcomes. The whole outbound loop — ingest → cold-mail (SMTP) + cold-calls
  (Bland) → reply/outcome sink — is one static binary over SQLite.

  It's written in machin (a small language that compiles through C to one native
  binary, ~108 KB, no runtime). Free and OSS; there's a hosted version for people
  who don't want to run the always-on daemon.

  Honest caveats: it's new and it's one person + agents; the hosted tier is
  deliberately BYO-sending (I don't run a warmed sending fleet); the interface is
  the CLI on purpose. Happy to answer anything.

  Repo: https://github.com/javimosch/machin-crm-cli

---

## Reddit

### r/selfhosted
Title: I built a local-first, single-binary CRM that an AI agent runs — free & open source
Body:
  Every CRM dies of stale data because keeping it current is data entry. So I built
  one with no UI — the primary user is an agent. It's a single ~108 KB native binary
  over SQLite (no Docker, no runtime, your data stays local). The whole outbound loop
  is built in: ingest leads → drip cold-mail over SMTP + AI cold-calls over Bland →
  a webhook that auto-logs replies and call outcomes and auto-suppresses bounces.
  Bring your own SMTP + Bland keys. Free and open source; there's a hosted version
  if you'd rather not run the always-on webhook yourself.
  Repo: https://github.com/javimosch/machin-crm-cli · Write-up: https://blog.intrane.fr/the-crm-that-maintains-itself

### r/commandline (shorter)
Title: crm-cli — an agent-first CRM in one static binary (JSON I/O, exit codes, help-json)
Body:
  A CRM whose driver is a program, not a human — so it can't go stale. JSON in/out,
  semantic exit codes, self-describing. One binary over SQLite; ingest → cold-mail +
  cold-calls → reply/outcome webhook sink. Free & OSS.
  https://github.com/javimosch/machin-crm-cli

---

## Bluesky / Mastodon

Every CRM dies of stale data — because keeping it current is data entry, and nobody does data entry.

So I built the CRM you never open: an agent runs it, cold-mail + cold-calls send themselves, replies log themselves. One static binary, open source.

https://blog.intrane.fr/the-crm-that-maintains-itself
