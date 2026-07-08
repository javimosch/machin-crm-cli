# Entity resolution — finding and merging duplicate contacts

`crm add`'s built-in dedup is exact-match only: the same email string, or the same phone string. That catches the obvious case (re-running `crm ingest` on the same list twice) but misses the common real-world one — contacts arriving from different sources with cosmetic differences:

- `Bob@X.com` vs `bob@x.com` — casing
- `0611223344` vs `+33 6 11 22 33 44` vs `06 11 22 33 44` — phone formatting
- The exact same person/company, entered twice with no email or phone overlap at all

`crm dedup` finds these; `crm merge` fixes them.

## Finding candidates: `crm dedup`

Read-only. Three independent rules, each deterministic (no fuzzy/ML matching — an agent-first tool needs matches it can explain, not ones it has to trust):

| Rule | What it matches | Confidence |
|---|---|---|
| `same_email` | Same address, differing only in case/whitespace | Exact identity |
| `same_phone` | Same number once normalized to E.164 | Exact identity |
| `same_name_company` | Same normalized name **and** company, no email/phone overlap needed | Judgment call |

```sh
crm dedup
# {"ok":true,"candidates":[
#   {"primary":"a1b2...","primary_name":"Bob","dupe":"c3d4...","dupe_name":"Bobby",
#    "reason":"same_email","key":"bob@x.com"},
#   ...
# ]}
```

`primary` is always the earlier-inserted contact (by insertion order, so it's deterministic even for two contacts created in the same second) — the one that survives if you merge. A group of 3+ duplicates emits multiple pairs; merge them one at a time and re-run `crm dedup`, since earlier pairs can go stale once an id in them no longer exists.

## Merging a pair: `crm merge <primary> <dupe>`

```sh
crm merge acme-primary acme-dupe
# {"ok":true,"primary":"a1b2...","merged":"c3d4..."}
```

What happens:
- **Fields** — `primary`'s value wins wherever it's non-empty; blanks fill in from `dupe`. If both have a value and they differ, `dupe`'s is dropped (not merged as a list — the schema doesn't support multiple emails per contact).
- **Stage** — `primary`'s stage is kept, *unless* it's still `new` and `dupe` has progressed further, in which case `dupe`'s stage is adopted.
- **Events and outreach** — every touch and every staged campaign item under `dupe` moves to `primary`.
- **A merge-log touch** is added to `primary`'s timeline.
- **`dupe` is deleted.**

It's fully undoable — `crm undo` restores `primary`'s fields and stage, moves the events/outreach back, removes the merge-log touch, and re-inserts `dupe` exactly as it was (same id).

One caveat worth knowing: if both `primary` and `dupe` had pending campaign items, merging can leave two queued outreach rows under one contact (crm-cli doesn't try to intelligently dedup *those*). Check `crm campaign` after a merge, before your next `crm send`/`crm call`.

## The agent-facing loop: `crm dedup --auto`

An agent shouldn't have to eyeball every candidate pair. `--auto` executes the two **exact-identity** rules — `same_email` and `same_phone` — in a loop until nothing's left, and reports what it did:

```sh
crm dedup --auto
# {"ok":true,"auto_merged":2,
#  "merges":[{"primary":"a1b2...","merged":"c3d4...","merged_name":"Bobby","reason":"same_email"}, ...],
#  "needs_review":[{"primary":"...","dupe":"...","reason":"same_name_company","key":"same co"}]}

crm dedup --auto --limit 10   # cap how many pairs one call merges (default 200)
```

**`same_name_company` never auto-merges — by design.** Two distinct real businesses can legitimately share a name and company (franchise locations, common business names). Auto-merging on that rule would eventually corrupt real data, so it always comes back in `needs_review` for a human or an agent to look at and merge manually with `crm merge`.

Every auto-merge is an ordinary operation on the same audit trail as a manual merge (tagged `dedup-auto` instead of `merge`, so you can tell them apart) — `crm undo` reverses one exactly the same way. Nothing `--auto` does is riskier or less reversible than doing it by hand; it's just faster for the cases that don't need a judgment call.
