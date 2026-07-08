# Quickstart

Five minutes: install, add a contact, log a touch, see the timeline.

## 1. Install

```sh
curl -fsSL https://raw.githubusercontent.com/javimosch/machin-crm-cli/master/install.sh | sh
```

This downloads a prebuilt binary and verifies it actually runs on your machine before trusting it. If it doesn't (older glibc, musl/Alpine, macOS, arm64), it falls back to building from source automatically — which needs [machin](https://github.com/javimosch/machin) (the installer fetches it too) and a C compiler.

```sh
crm version     # confirm it installed
```

If `crm` isn't found, the installer told you which `PATH` line to add — usually `export PATH="$HOME/.local/bin:$PATH"`.

## 2. Where your data lives

One SQLite file, `~/.crm-cli.db` by default. Override with `$CRM_DB` if you want a different location, or multiple separate CRMs (e.g. one per campaign):

```sh
export CRM_DB=~/my-project.db
```

Nothing leaves your machine unless you deliberately point `crm send`/`crm call`/`crm serve` at external services.

## 3. Add a contact and log a touch

```sh
crm add "Alex Founder" --company "Acme" --email alex@acme.com
# {"ok":true,"created":true,"id":"a1b2c3...","name":"Alex Founder"}

crm log alex@acme.com email "sent an intro" --direction out
# {"ok":true,"event":"...","contact":"a1b2c3...","channel":"email"}
```

`log` bumps a `new` contact to `contacted` automatically — that's the whole point: the CRM reacts to what happened, instead of you separately updating a status field.

## 4. See what you've got

```sh
crm show alex@acme.com     # the contact + its full event timeline
crm list                    # every contact
crm pipeline                 # counts by stage
crm due                      # next steps due today or overdue
```

`<contact>` anywhere in the CLI resolves by id, exact email, exact phone, or a name/company substring — so `crm show acme` and `crm show alex@acme.com` both work.

## 5. What's next

- Bulk-load leads from another tool: `crm ingest '[{...}]'` — see [Commands reference](commands.md#ingest).
- Stage and run an actual outreach campaign: [The outbound loop](outbound-loop.md).
- Before you run anything that sends real email or places real calls: [Safety rails](safety-rails.md) — `--dry-run` first, always.
