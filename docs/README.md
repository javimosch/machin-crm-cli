# crm-cli documentation

Technical, human-facing docs for **crm-cli** — the agent-first CRM. If you're an agent, `crm help` is the source of truth (it's always in sync with the binary you're running). These pages are for the human at the keyboard who wants to actually understand what's going on before pointing an agent at it.

- **[Quickstart](quickstart.md)** — install, your first few commands, five minutes to a working CRM.
- **[Commands reference](commands.md)** — every command, grouped by what it's for, with real examples and exact JSON shapes.
- **[The outbound loop](outbound-loop.md)** — how campaigns actually work: stage → send/call → get replies back automatically.
- **[Safety rails](safety-rails.md)** — `--dry-run` and `crm undo`, and exactly what is and isn't reversible.
- **[Entity resolution](entity-resolution.md)** — finding and merging duplicate contacts, including the automated loop.
- **[Architecture](architecture.md)** — the schema, the audit trail, and the design decisions behind them, for anyone extending or self-hosting this.
- **[Changelog](changelog.html)** — what shipped, month by month.

## The 30-second pitch

Every CRM dies of stale data because keeping it current is data entry, and nobody does data entry. crm-cli has no UI at all — its primary user is an agent. JSON on stdout, structured errors on stderr, semantic exit codes. Your agent drives it; your outreach tools feed it; a webhook sink updates it when someone replies. See the [project README](../README.md) for the full pitch and the hosted version, [crmd](https://crmd.intrane.fr).

## Where to actually start

If you're setting this up for the first time: [Quickstart](quickstart.md). If you already have it installed and want the full command surface: [Commands reference](commands.md). If you're about to run a real campaign: read [The outbound loop](outbound-loop.md) and [Safety rails](safety-rails.md) first — the second one exists because mistakes with real cold outreach are expensive to undo by hand.
