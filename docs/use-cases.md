# Use cases — beyond cold outreach

crm-cli is built as the sink for an outbound machine, but its primitives (contacts, events, next actions, due dates) work well for anything that has a lifecycle and needs a follow-up. This page collects real patterns used in production.

## 1. Track product distribution channels as leads

Every launch has a checklist of directories, registries, PRs, and integrations. Instead of a static todo list, model each channel as a synthetic contact in a dedicated workspace. You get an audit trail, staged pipeline, and `crm due` reminders.

### Example workspace

```sh
crm workspace create peage-distribution
```

### Example contacts

| Channel | Name | Email | Company | Stage |
|---|---|---|---|---|
| Directory PR | `awesome-mcp-servers PR #10381` | `pr-10381@awesome-mcp-servers.local` | `awesome-mcp-servers` | `contacted` |
| Directory listing | `Glama MCP Directory` | `peage-mcp@glama.local` | `glama` | `contacted` |
| Registry | `Official MCP Registry` | `peage-mcp@mcp-registry.local` | `modelcontextprotocol` | `won` |

The email is synthetic — it is only a handle for `crm log` and `crm next`. The company field holds the real platform name. `source` is typically `product-launch`.

### Logging touches

```sh
crm log pr-10381@awesome-mcp-servers.local email \
  "Resolved merge conflict and force-pushed clean rebase" \
  --ref "https://github.com/punkpeye/awesome-mcp-servers/pull/10381#issuecomment-5066093268" \
  --direction out
```

`--ref` can be a URL, a comment ID, an issue number, or anything that lets a future agent find the context.

### Setting follow-ups

```sh
D=$(date -d "+3 days" +%Y-%m-%d)
crm next pr-10381@awesome-mcp-servers.local \
  "check merge status / nudge maintainer if still open" \
  --due "$D"
```

`crm due` will surface it when the day arrives.

### Why this works

- **Same tool, more signal.** Your real outreach and your distribution pipeline share `crm due` and `crm pipeline`.
- **Nothing falls through cracks.** A directory submission that needs a 7-day re-check becomes a `contacted` contact with a `next_due` date.
- **Handoff-friendly.** The next agent runs `crm show pr-10381@awesome-mcp-servers.local` and sees the full history.

## 2. Run a two-step cold email / call campaign

See [The outbound loop](outbound-loop.md) for the canonical flow: `queue` → `send`/`call` → replies auto-land via webhook. Use `followups` to stage wave 2 for non-responders.

## 3. Manage a hiring or vendor pipeline

Replace the email with `candidate-jane-doe@roles.acme.local` or `vendor-stripe@partners.acme.local`. Stages map naturally: `contacted` → `replied` → `meeting` → `deal` → `won`/`lost`.

## 4. Track support escalations

Add a contact per high-priority ticket: `ticket-4821@support.acme.local`. Log every update, set `next` for the promised follow-up time, and use `inbound` to archive reply bodies beyond Resend's 30-day window.

## 5. Multi-product isolation

`--workspace` (or `$CRM_WORKSPACE`) keeps each product or client in a separate SQLite file. See [Workspaces](workspaces.md). A common setup:

```
peage-gtm          # human leads for peage
peage-distribution # directories, PRs, registries for peage
crmd-gtm           # human leads for crmd
intrane-gtm        # agency/consulting leads
```

## Pattern checklist

When adding any non-human lead:

1. Pick or create a `<product>-distribution` workspace.
2. `add` a contact with a descriptive name and a synthetic email.
3. `log` every meaningful touch with a `--ref`.
4. `next` a concrete follow-up with a `--due` date.
5. Check `crm due` daily or wire it into a digest.
