# Workspaces — running multiple isolated CRMs from one binary

If you run more than one product — several micro-SaaS, several clients, whatever — you don't want their contacts, campaigns, or DNC lists anywhere near each other. crm-cli has **no account/tenant concept in the schema at all**: it's a stateless CLI over one SQLite file. Workspaces are a thin, deliberately simple layer on top of that fact: a named convention for keeping multiple *completely separate* files, so isolation is structural, not filtered.

## The mechanism

```sh
crm workspace create acme        # {"ok":true,"workspace":"acme","created":true,"path":"~/.crmd/workspaces/acme.db"}
crm workspace list               # {"ok":true,"workspaces":["acme","beta"]}

crm add "Lead" --email lead@x.com --workspace acme
crm list --workspace beta
```

`--workspace <slug>` (or `$CRM_WORKSPACE`) on **any** command resolves to `~/.crmd/workspaces/<slug>.db` instead of the default `~/.crm-cli.db`. Two workspaces are two different files — full isolation by construction, not by a `WHERE workspace=?` filter that could someday have a missed clause and leak data between them.

**Precedence**: `$CRM_DB` (an explicit path) always wins if set, regardless of `--workspace`. Then `--workspace`/`$CRM_WORKSPACE`. Then the original single-file default. Nothing about existing usage changes if you never touch workspaces.

**Flag position matters** — `--workspace` goes *after* the subcommand, exactly like every other flag in this CLI (`crm add ... --workspace acme`, not `crm --workspace acme add ...`). The binary catches the common mistake and tells you so directly if you get it backwards.

**Workspace names are validated strictly**: lowercase letters, digits, hyphens only, 1–64 chars, no leading/trailing hyphen. This isn't cosmetic — a workspace name becomes a filesystem path component, so `crm workspace create ../../etc/passwd` is rejected outright rather than silently doing something dangerous.

## What's isolated per workspace

Everything — contacts, events, outreach, the suppress/DNC list, the undo audit trail. If a workspace was Acme's, and Acme unsubscribed someone, that suppression has zero effect on Beta's workspace. This matters for compliance, not just tidiness: different products are arguably different senders under CAN-SPAM/GDPR, so per-workspace suppression is the safer default.

## What this is *not* (yet)

This is Phase 1 of the multi-workspace story — a local convenience layer, free on the OSS binary. It does **not** solve:
- **Cross-tenant name collisions.** If you're a hosted crmd customer, your workspace names only need to be unique *for you* — the hosted backend scopes storage by account, not by a flat global workspace registry (see `docs/architecture.md` for the design). That's a hosted-backend feature, not something this local flag needs to worry about.
- **Remote/hosted access.** `--workspace` resolves a *local* file path. It doesn't talk to any server. crmd's hosted tier (always-on webhook + managed backups) is a separate thing layered on top of this same file-per-workspace convention, not yet built.
- **Cross-workspace reporting.** There's no `crm list --all-workspaces`. Each workspace is genuinely a separate CRM; if you want an aggregate view across all your micro-SaaS, that's a future feature, not this one.
