#!/usr/bin/env bash
# Integration tests — the DB-backed command business rules, driven through the built
# binary against a throwaway CRM_DB (the real agent-facing contract). State assertions
# that don't map cleanly to JSON use sqlite3 directly.
set -uo pipefail
cd "$(dirname "$0")/.."
CRM=./crm
[ -x "$CRM" ] || { echo "build first: ./build.sh"; exit 1; }
export CRM_DB="$(mktemp -u /tmp/crm-it-XXXXXX.db)"
trap 'rm -f "$CRM_DB"' EXIT
P=0; F=0
ok(){    if [ "$2" = "$3" ]; then P=$((P+1)); else F=$((F+1)); echo "FAIL: $1 — got [$3] want [$2]"; fi; }
okre(){  if printf '%s' "$3" | grep -qE "$2"; then P=$((P+1)); else F=$((F+1)); echo "FAIL: $1 — [$3] !~ /$2/"; fi; }
q(){ sqlite3 "$CRM_DB" "$1"; }

# --- add + dedup -----------------------------------------------------------
r=$($CRM add Al --email a@x.com --phone 0611 --company Acme)
ok "add creates"              true  "$(jq -r .created <<<"$r")"
ID=$(jq -r .id <<<"$r")
r=$($CRM add "Al Renamed" --email a@x.com)
ok "add dedup by email"       false "$(jq -r .created <<<"$r")"
ok "  ...same id"             "$ID" "$(jq -r .id <<<"$r")"
r=$($CRM add "Al Phone" --phone 0611)
ok "add dedup by phone"       "$ID" "$(jq -r .id <<<"$r")"

# --- log advances new->contacted + appends a touch -------------------------
$CRM add Bo --email b@y.com >/dev/null
$CRM log b@y.com email "sent intro" >/dev/null
ok "log advances new->contacted" contacted "$($CRM show b@y.com | jq -r '.contact[0].stage')"
ok "log appends an event"        1 "$(q "SELECT COUNT(*) FROM events e JOIN contacts c ON c.id=e.contact_id WHERE c.email='b@y.com'")"

# --- stage + relative due date ---------------------------------------------
$CRM stage b@y.com meeting >/dev/null
ok "stage set"                meeting "$($CRM show b@y.com | jq -r '.contact[0].stage')"
r=$($CRM next b@y.com "call back" --due "+4 days")
okre "next resolves +N days -> YYYY-MM-DD" '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$(jq -r .next_due <<<"$r")"

# --- ingest (bulk sink) ----------------------------------------------------
r=$($CRM ingest '[{"name":"Cy","email":"c@z.com"},{"name":"Di","email":"d@z.com","phone":"0622"}]')
ok "ingest added 2"           2 "$(jq -r .added <<<"$r")"

# --- queue-bulk + campaign read-back ---------------------------------------
$CRM queue-bulk '[{"contact":"c@z.com","channel":"email","subject":"S","body":"B"},{"contact":"d@z.com","channel":"phone","body":"call"}]' >/dev/null
ok "campaign summary: email queued=1" 1 "$($CRM campaign --summary | jq -r '.summary[]|select(.channel=="email" and .status=="queued").n')"
ok "campaign summary: phone queued=1" 1 "$($CRM campaign --summary | jq -r '.summary[]|select(.channel=="phone" and .status=="queued").n')"
ok "campaign --jsonl send-ready"      c@z.com "$($CRM campaign --channel email --jsonl | jq -r .to)"

# --- sent marks + advances stage -------------------------------------------
OID=$($CRM campaign --channel email | jq -r '.campaign[0].id')
$CRM sent "$OID" >/dev/null
ok "sent -> outreach status sent" sent      "$(q "SELECT status FROM outreach WHERE id='$OID'")"
ok "sent -> stage contacted"      contacted "$($CRM show c@z.com | jq -r '.contact[0].stage')"

# --- suppress cancels a queued outreach + records the address --------------
$CRM add Ed --email e@z.com >/dev/null
$CRM queue e@z.com email --subject S --body B >/dev/null
$CRM suppress e@z.com bounce >/dev/null
ok "suppress cancels queued outreach" suppressed "$(q "SELECT status FROM outreach WHERE contact_id=(SELECT id FROM contacts WHERE email='e@z.com')")"
ok "suppress records the address"     1 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='e@z.com'")"
ok "suppress(email) leaves no phantom '+' row" 0 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='+'")"

# =====================  SAFETY RAILS: crm undo  =====================

# --- undo reverts a stage change --------------------------------------------
$CRM add Fi --email fi@z.com >/dev/null
$CRM stage fi@z.com meeting >/dev/null
ok "stage set before undo"    meeting "$($CRM show fi@z.com | jq -r '.contact[0].stage')"
$CRM undo >/dev/null
ok "undo reverts stage"       new     "$($CRM show fi@z.com | jq -r '.contact[0].stage')"

# --- undo reverts `next` --------------------------------------------------
$CRM next fi@z.com "call back" --due "+4 days" >/dev/null
ok "next set before undo"    1 "$([ -n "$($CRM show fi@z.com | jq -r '.contact[0].next_action')" ] && echo 1 || echo 0)"
$CRM undo >/dev/null
ok "undo reverts next_action" "" "$($CRM show fi@z.com | jq -r '.contact[0].next_action')"

# --- undo reverts `sent`: outreach status, the logged touch, and the stage flip
$CRM add Gi --email gi@z.com >/dev/null   # stage=new
$CRM queue gi@z.com email --subject SS --body BB >/dev/null
OID2=$($CRM campaign --channel email --status queued | jq -r '.campaign[]|select(.email=="gi@z.com").id')
EVBEFORE=$(q "SELECT COUNT(*) FROM events")
$CRM sent "$OID2" >/dev/null
ok "sent -> outreach status sent" sent      "$(q "SELECT status FROM outreach WHERE id='$OID2'")"
ok "sent -> stage contacted"      contacted "$($CRM show gi@z.com | jq -r '.contact[0].stage')"
$CRM undo >/dev/null
ok "undo reverts outreach status" queued "$(q "SELECT status FROM outreach WHERE id='$OID2'")"
ok "undo reverts stage"           new    "$($CRM show gi@z.com | jq -r '.contact[0].stage')"
ok "undo removes the logged touch" "$EVBEFORE" "$(q "SELECT COUNT(*) FROM events")"

# --- undo reverts suppress: un-suppresses + restores the cancelled outreach -
$CRM add Hi --email hi@z.com >/dev/null
$CRM queue hi@z.com email --subject S --body B >/dev/null
$CRM suppress hi@z.com bounce >/dev/null
$CRM undo >/dev/null
ok "undo un-suppresses"           0 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='hi@z.com'")"
ok "undo restores cancelled outreach to queued" queued "$(q "SELECT status FROM outreach WHERE contact_id=(SELECT id FROM contacts WHERE email='hi@z.com')")"

# --- an idempotent (already-suppressed) suppress call records NO new op, so a
# single undo reaches back to the ORIGINAL suppress, fully reverting it -------
$CRM add Ji --email ji@z.com >/dev/null
$CRM suppress ji@z.com r1 >/dev/null
$CRM suppress ji@z.com r2 >/dev/null   # no-op: already suppressed, nothing new to record
$CRM undo >/dev/null
ok "idempotent re-suppress -> one undo fully reverts" 0 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='ji@z.com'")"

# --- two DISTINCT suppress ops are independent: one undo reverts only the LAST
$CRM add Ki --email ki@z.com >/dev/null
$CRM suppress ki@z.com r1 >/dev/null
$CRM add Li --email li@z.com >/dev/null
$CRM suppress li@z.com r2 >/dev/null
$CRM undo >/dev/null
ok "LIFO: earlier distinct op untouched" 1 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='ki@z.com'")"
ok "LIFO: latest distinct op reverted"   0 "$(q "SELECT COUNT(*) FROM suppress WHERE addr='li@z.com'")"

# --- undo --n 2 reverts two ops in one call ---------------------------------
$CRM add Mi --email mi@z.com >/dev/null
$CRM stage mi@z.com meeting >/dev/null
$CRM stage mi@z.com deal >/dev/null
$CRM undo --n 2 >/dev/null
ok "undo --n 2 reverts both" new "$($CRM show mi@z.com | jq -r '.contact[0].stage')"

# --- undo with nothing to undo is a clean no-op (forced-empty trail: other
# earlier ops in this script are deliberately left un-undone as independence
# checks, so the trail isn't naturally empty here) --------------------------
q "DELETE FROM audit"
r=$($CRM undo)
ok "undo with empty trail -> undone:0" 0 "$(jq -r .undone <<<"$r")"

# =====================  SAFETY RAILS: send/call --dry-run  =====================

# --- send --dry-run needs no SMTP env, touches no network, changes no DB ----
unset SMTP_HOST SMTP_FROM SMTP_PORT SMTP_USER SMTP_PASS
$CRM add Ni --email ni@z.com >/dev/null
$CRM queue ni@z.com email --subject DrySubj --body DryBody >/dev/null
r=$($CRM send --dry-run)
ok "send --dry-run reports dry_run"       true "$(jq -r .dry_run <<<"$r")"
ok "send --dry-run includes the new item" send "$(jq -r '.preview[]|select(.to=="ni@z.com").action' <<<"$r")"
ok "send --dry-run leaves it queued"      queued "$(q "SELECT status FROM outreach WHERE contact_id=(SELECT id FROM contacts WHERE email='ni@z.com')")"

# --- send --dry-run correctly flags a suppressed recipient as skipped ------
$CRM add Oi --email oi@z.com >/dev/null
$CRM suppress oi@z.com premarked >/dev/null
$CRM queue oi@z.com email --subject S --body B >/dev/null
r=$($CRM send --dry-run)
ok "send --dry-run flags suppressed" skip_suppressed "$(jq -r '.preview[]|select(.to=="oi@z.com").action' <<<"$r")"

# --- call --dry-run needs no BLAND_API_KEY, normalizes to E.164, no dial ----
unset BLAND_API_KEY BLAND_URL
$CRM add Pi --phone "09 80 80 80 35" >/dev/null
$CRM queue Pi phone --body "ring ring" >/dev/null
r=$($CRM call --dry-run)
ok "call --dry-run reports dry_run"    true          "$(jq -r .dry_run <<<"$r")"
ok "call --dry-run normalizes E.164"   +33980808035  "$(jq -r '.preview[]|select(.company=="Pi").to' <<<"$r")"
ok "call --dry-run leaves it queued"   queued        "$(q "SELECT status FROM outreach WHERE contact_id=(SELECT id FROM contacts WHERE phone='09 80 80 80 35')")"

# --- followups selection rules ---------------------------------------------
# a due candidate: contacted, an outbound email aged >N days, no reply, nothing queued
mkdue(){ $CRM add "$1" --email "$2" >/dev/null; $CRM log "$2" email intro >/dev/null
         q "UPDATE events SET ts=strftime('%s','now')-10*86400 WHERE contact_id=(SELECT id FROM contacts WHERE email='$2')"; }
mkdue Fo f@z.com
ok "followups selects a due contact" f@z.com "$($CRM followups --days 3 | jq -r '.followups[]|select(.email=="f@z.com").email')"
# a replier is excluded
mkdue Gh g@z.com
$CRM log g@z.com email "they replied" --direction in >/dev/null
ok "followups excludes repliers" "" "$($CRM followups --days 3 | jq -r '.followups[]|select(.email=="g@z.com").email')"
# a recently-contacted one (touch today) is excluded by the age gate
$CRM add Hi --email h@z.com >/dev/null; $CRM log h@z.com email intro >/dev/null
ok "followups excludes too-recent"  "" "$($CRM followups --days 3 | jq -r '.followups[]|select(.email=="h@z.com").email')"
# --queue stages wave 2 (and then it's no longer 'due' because it now has a queued outreach)
r=$($CRM followups --days 3 --queue --subject "Re: {{company}}" --body "bump {{name}}")
ok "followups --queue stages >=1" 1 "$([ "$(jq -r .queued <<<"$r")" -ge 1 ] && echo 1 || echo 0)"
ok "  ...f now has a queued wave-2 outreach" 1 "$(q "SELECT COUNT(*) FROM outreach WHERE status='queued' AND contact_id=(SELECT id FROM contacts WHERE email='f@z.com')")"
ok "  ...and is no longer 'due'" "" "$($CRM followups --days 3 | jq -r '.followups[]|select(.email=="f@z.com").email')"

# =====================  ENTITY RESOLUTION: crm dedup / crm merge  =====================

# --- dedup: same_email (case/whitespace diff) -------------------------------
$CRM add DupA1 --email "Dup@Case.com" --company "Case Co" >/dev/null
$CRM add DupA2 --email "dup@case.com" >/dev/null
ok "dedup finds same_email pair" dup@case.com "$($CRM dedup | jq -r '.candidates[]|select(.reason=="same_email" and .key=="dup@case.com").key')"

# --- dedup: same_phone (formatting-only diff `add` misses) ------------------
$CRM add DupB1 --phone "0611223344" >/dev/null
$CRM add DupB2 --phone "+33 6 11 22 33 44" >/dev/null
ok "dedup finds same_phone pair (E.164)" +33611223344 "$($CRM dedup | jq -r '.candidates[]|select(.reason=="same_phone" and .key=="+33611223344").key')"

# --- dedup: same_name_company (no email/phone overlap needed) --------------
$CRM add "  Dup Name  " --company "Dup Co" >/dev/null
$CRM add "dup name" --company "DUP CO" >/dev/null
ok "dedup finds same_name_company pair" "dup co" "$($CRM dedup | jq -r '.candidates[]|select(.reason=="same_name_company" and .key=="dup co").key')"

# --- dedup does NOT flag genuinely distinct contacts ------------------------
$CRM add Distinct1 --email d1@z.com >/dev/null
$CRM add Distinct2 --email d2@z.com >/dev/null
ok "dedup ignores distinct contacts" "" "$($CRM dedup | jq -r '.candidates[]|select(.primary_name=="Distinct1" or .dupe_name=="Distinct1")')"

# --- REGRESSION: --limit applies PER RULE, not as one shared budget across all
# three (a real bug caught by the load test: a rule with lots of matches — e.g.
# same_email — silently starved same_phone/same_name_company out of the report
# entirely once a single shared counter hit the limit first). Give same_email
# more pairs than a tiny --limit, and confirm same_phone still gets reported.
for i in 1 2 3; do
  $CRM add "LimE${i}a" --email "lim${i}@starve.com" >/dev/null
  $CRM add "LimE${i}b" --email "LIM${i}@STARVE.COM" >/dev/null
done
$CRM add LimP1a --phone "0688990011" >/dev/null
$CRM add LimP1b --phone "+33 6 88 99 00 11" >/dev/null
r=$($CRM dedup --limit 2)
ok "starvation: capped same_email at the limit" 2 "$(jq -r '[.candidates[]|select(.reason=="same_email")]|length' <<<"$r")"
# (leftover same_phone pairs may exist from earlier read-only `dedup` sections in this
# shared-state script — assert OUR specific pair is present, not an exact global count)
ok "starvation: same_phone still reported (not starved)" same_phone "$(jq -r '.candidates[]|select(.dupe_name=="LimP1b").reason' <<<"$r")"

# --- dedup primary/dupe ordering is deterministic (earlier-inserted wins) ---
r=$($CRM dedup | jq -r '.candidates[]|select(.reason=="same_email" and .key=="dup@case.com")')
ok "dedup primary is the earlier-inserted (DupA1)" DupA1 "$(jq -r .primary_name <<<"$r")"
ok "dedup dupe is the later-inserted (DupA2)"       DupA2 "$(jq -r .dupe_name <<<"$r")"

# --- merge: fields fill from dupe, stage adopts if primary was 'new', events
# + outreach reassign, dupe deleted ------------------------------------------
$CRM add MPrimary --email mp@z.com --phone 0699 >/dev/null   # stage=new, no company
$CRM add MDupe --company "Merge Co" >/dev/null
DID=$($CRM show MDupe | jq -r '.contact[0].id')
$CRM log "$DID" call "left a voicemail" >/dev/null            # -> dupe stage=contacted
$CRM queue "$DID" phone --body "ring" >/dev/null               # dupe has queued outreach
PID=$($CRM show MPrimary | jq -r '.contact[0].id')
$CRM merge "$PID" "$DID" >/dev/null
ok "merge adopts dupe's company (primary's was blank)" "Merge Co" "$(q "SELECT company FROM contacts WHERE id='$PID'")"
ok "merge adopts dupe's stage (primary was 'new')"     contacted  "$(q "SELECT stage FROM contacts WHERE id='$PID'")"
ok "merge keeps primary's own phone (non-blank wins)"  0699       "$(q "SELECT phone FROM contacts WHERE id='$PID'")"
ok "merge deletes the dupe row"                        0          "$(q "SELECT COUNT(*) FROM contacts WHERE id='$DID'")"
ok "merge reassigns dupe's events to primary"          1          "$(q "SELECT COUNT(*) FROM events WHERE contact_id='$PID' AND channel='call'")"
ok "merge reassigns dupe's outreach to primary"        1          "$(q "SELECT COUNT(*) FROM outreach WHERE contact_id='$PID'")"

# --- merge rejects merging a contact into itself ----------------------------
r=$($CRM merge "$PID" "$PID" 2>&1); ec=$?
ok "merge self-merge is rejected (non-zero exit)" 1 "$([ $ec -ne 0 ] && echo 1 || echo 0)"

# --- merge is fully undoable: fields, stage, events, outreach, and the dupe
# row itself all come back exactly as they were --------------------------
$CRM undo >/dev/null
ok "undo restores primary's company to blank"  "" "$(q "SELECT company FROM contacts WHERE id='$PID'")"
ok "undo restores primary's stage to new"       new "$(q "SELECT stage FROM contacts WHERE id='$PID'")"
ok "undo re-inserts the dupe row"               "Merge Co" "$(q "SELECT company FROM contacts WHERE id='$DID'")"
ok "undo moves the event back to dupe"          1 "$(q "SELECT COUNT(*) FROM events WHERE contact_id='$DID' AND channel='call'")"
ok "undo moves the outreach back to dupe"       1 "$(q "SELECT COUNT(*) FROM outreach WHERE contact_id='$DID'")"
ok "undo removes the merge-log touch"           0 "$(q "SELECT COUNT(*) FROM events WHERE contact_id='$PID' AND channel='system'")"

# =====================  AGENT-FACING AUTO-DEDUP LOOP: crm dedup --auto  =====================

# --- auto-merges same_email and same_phone, but NEVER same_name_company ----
$CRM add AutoE1 --email "Auto@Case.com" --company "Auto Co" >/dev/null
$CRM add AutoE2 --email "auto@case.com" >/dev/null
$CRM add AutoP1 --phone "0622334455" >/dev/null
$CRM add AutoP2 --phone "+33 6 22 33 44 55" >/dev/null
$CRM add AutoN1 --company "Franchise Co" >/dev/null
$CRM add AutoN2 --company "FRANCHISE CO" >/dev/null
r=$($CRM dedup --auto)
# (leftover same_email/same_phone pairs may exist from earlier read-only `dedup` sections that
# were never merged — assert our two specific pairs, not an exact global count)
ok "auto_merged >= 2" 1 "$([ "$(jq -r '.auto_merged' <<<"$r")" -ge 2 ] && echo 1 || echo 0)"
ok "auto-merged pair tagged same_email" same_email "$(jq -r '.merges[]|select(.merged_name=="AutoE2").reason' <<<"$r")"
ok "auto-merged pair tagged same_phone" same_phone "$(jq -r '.merges[]|select(.merged_name=="AutoP2").reason' <<<"$r")"
ok "same_name_company surfaced in needs_review, not merged" 1 "$(jq -r '[.needs_review[]|select(.reason=="same_name_company")]|length' <<<"$r")"
ok "same_name_company pair NOT deleted (both still exist)" 2 "$(q "SELECT COUNT(*) FROM contacts WHERE company='Franchise Co' OR company='FRANCHISE CO'")"

# --- auto-merged pairs are ordinary, fully undoable ops (tagged dedup-auto) -
r=$($CRM dedup --auto)   # a fresh no-op call this time (nothing left to auto-merge)
ok "second auto-merge call finds nothing left" 0 "$(jq -r '.auto_merged' <<<"$r")"
LASTAUDITCMD=$(q "SELECT cmd FROM audit ORDER BY rowid DESC LIMIT 1")
ok "the merge op is tagged dedup-auto (distinguishable from manual)" dedup-auto "$LASTAUDITCMD"
BEFORE_UNDO=$(q "SELECT COUNT(*) FROM contacts")
$CRM undo >/dev/null
AFTER_UNDO=$(q "SELECT COUNT(*) FROM contacts")
ok "undo reverses an auto-merge (contact count +1)" 1 "$((AFTER_UNDO - BEFORE_UNDO))"

# --- --limit caps how many pairs a single --auto call merges ---------------
$CRM add LimA1 --email "Lim@Cap.com" >/dev/null
$CRM add LimA2 --email "lim@cap.com" >/dev/null
$CRM add LimB1 --email "Lim2@Cap.com" >/dev/null
$CRM add LimB2 --email "lim2@cap.com" >/dev/null
BEFORE_LIM=$(q "SELECT COUNT(*) FROM contacts")
r=$($CRM dedup --auto --limit 1)
ok "--limit 1 merges exactly one pair" 1 "$(jq -r '.auto_merged' <<<"$r")"
AFTER_LIM=$(q "SELECT COUNT(*) FROM contacts")
ok "--limit 1 leaves the second pair unmerged" 1 "$((BEFORE_LIM - AFTER_LIM))"

# =====================  STDIN INPUT: crm ingest -  /  crm queue-bulk -  =====================
# crm ingest/queue-bulk pass their JSON payload as an argv argument, which Linux caps at
# MAX_ARG_STRLEN (~128 KiB per arg) — confirmed empirically (a load test) to break real ingest
# calls around 1,100-1,300 typical contacts, with no workaround before this. `-` reads the
# payload from stdin instead, sidestepping the OS ceiling entirely.

# --- ingest - reads from stdin, behaves identically to the argv form -------
r=$(echo '[{"name":"StdinA","email":"stdina@z.com"}]' | $CRM ingest -)
ok "ingest - reads from stdin" 1 "$(jq -r .added <<<"$r")"
ok "ingest - contact actually landed" StdinA "$($CRM show stdina@z.com | jq -r '.contact[0].name')"

# --- queue-bulk - reads from stdin too --------------------------------------
$CRM add StdinB --email stdinb@z.com >/dev/null
r=$(echo '[{"contact":"stdinb@z.com","channel":"email","subject":"S","body":"B"}]' | $CRM queue-bulk -)
ok "queue-bulk - reads from stdin" 1 "$(jq -r .queued <<<"$r")"
ok "queue-bulk - outreach actually landed" queued "$(q "SELECT status FROM outreach WHERE contact_id=(SELECT id FROM contacts WHERE email='stdinb@z.com')")"

# --- the plain argv form still works unchanged for everyone not using '-' --
r=$($CRM ingest '[{"name":"ArgvStill","email":"argvstill@z.com"}]')
ok "ingest (argv form) still works" 1 "$(jq -r .added <<<"$r")"

# =====================  PAGINATION: crm list  =====================
# The old `crm list` silently capped at 500 with no total/returned/offset/limit metadata — an
# agent enumerating a >500-contact table saw only the newest 500 with zero signal anything was
# missing. Seed enough contacts to force a second page and check the metadata + full coverage.
for i in $(seq 1 30); do $CRM add "Pg${i}" --email "pg${i}@page.com" >/dev/null; done
TOTAL_NOW=$(q "SELECT COUNT(*) FROM contacts")
r=$($CRM list --limit 10)
ok "list reports total (not silently missing)" "$TOTAL_NOW" "$(jq -r .total <<<"$r")"
ok "list respects --limit" 10 "$(jq -r .returned <<<"$r")"
ok "list --limit caps contacts array too" 10 "$(jq -r '.contacts|length' <<<"$r")"
r2=$($CRM list --limit 10 --offset 10)
ok "list --offset advances the page" 10 "$(jq -r .offset <<<"$r2")"
ok "list page 1 and page 2 don't overlap" "" "$(comm -12 <(jq -r '.contacts[].id' <<<"$r" | sort) <(jq -r '.contacts[].id' <<<"$r2" | sort))"

# =====================  REGRESSION: suppress_set (batched, not per-row) =====================
# send/call --dry-run's suppression check moved from one SQL query per outreach row to one
# fetch-all-suppressed-addresses-once set (measured: 3.60min -> ~1s for a few thousand items).
# Confirm the SET correctly flags MULTIPLE simultaneously-suppressed addresses in one call, not
# just a single one — the thing that would break if the batching introduced an off-by-one or
# only-checks-the-last-suppressed-address bug.
$CRM add MultiA --email multia@bat.com >/dev/null
$CRM add MultiB --email multib@bat.com >/dev/null
$CRM add MultiC --email multic@bat.com >/dev/null
$CRM suppress multia@bat.com >/dev/null
$CRM suppress multib@bat.com >/dev/null
echo '[{"contact":"multia@bat.com","channel":"email","subject":"S","body":"B"},{"contact":"multib@bat.com","channel":"email","subject":"S","body":"B"},{"contact":"multic@bat.com","channel":"email","subject":"S","body":"B"}]' | $CRM queue-bulk - >/dev/null
r=$($CRM send --dry-run)
ok "batched suppress: first suppressed address flagged"  skip_suppressed "$(jq -r '.preview[]|select(.to=="multia@bat.com").action' <<<"$r")"
ok "batched suppress: second suppressed address flagged" skip_suppressed "$(jq -r '.preview[]|select(.to=="multib@bat.com").action' <<<"$r")"
ok "batched suppress: non-suppressed address unaffected"  send            "$(jq -r '.preview[]|select(.to=="multic@bat.com").action' <<<"$r")"

# =====================  WORKSPACES: crm workspace / --workspace  =====================
# $CRM_DB (exported above, for the WHOLE script) always wins over --workspace per dbpath()'s
# precedence, so this needs its own isolated subshell: unset CRM_DB, use a fake $HOME so real
# workspace files never touch the developer's actual ~/.crmd/workspaces/.
(
  unset CRM_DB
  FAKEHOME=$(mktemp -d /tmp/crm-it-home-XXXXXX)
  export HOME="$FAKEHOME"
  trap 'rm -rf "$FAKEHOME"' EXIT
    wsok(){ if [ "$2" = "$3" ]; then echo "WSOK"; else echo "WSFAIL: $1 — got [$3] want [$2]"; fi; }

  r=$("$CRM" workspace list); wsok "workspace list starts empty" '[]' "$(jq -c .workspaces <<<"$r")"
  r=$("$CRM" workspace create acme); wsok "workspace create reports created:true" true "$(jq -r .created <<<"$r")"
  r=$("$CRM" workspace create acme); wsok "workspace create is idempotent (created:false 2nd time)" false "$(jq -r .created <<<"$r")"
  r=$("$CRM" workspace create "../../etc/passwd" 2>&1); wsok "workspace create rejects path traversal" true "$([ "$(jq -r .ok <<<"$r" 2>/dev/null)" = "false" ] && echo true || echo false)"

  "$CRM" add "AcmeLead" --email lead@acme.com --workspace acme >/dev/null
  "$CRM" add "BetaLead" --email lead@beta.com --workspace beta >/dev/null
  wsok "acme workspace sees only its own contact" AcmeLead "$("$CRM" list --workspace acme | jq -r '.contacts[0].name')"
  wsok "beta workspace sees only its own contact" BetaLead "$("$CRM" list --workspace beta | jq -r '.contacts[0].name')"
  wsok "acme workspace total is 1 (not leaking beta's contact)" 1 "$("$CRM" list --workspace acme | jq -r .total)"

  r=$("$CRM" workspace list); wsok "workspace list now shows both" '["acme","beta"]' "$(jq -c '.workspaces|sort' <<<"$r")"

  echo "$FAKEHOME/.crmd/workspaces/acme.db exists: $([ -f "$FAKEHOME/.crmd/workspaces/acme.db" ] && echo yes || echo no)" | grep -q "yes" && echo "WSOK" || echo "WSFAIL: acme.db file not on disk where expected"
) > /tmp/ws-subshell-$$.log 2>&1
WSPASS=$(grep -c '^WSOK$' /tmp/ws-subshell-$$.log)
WSFAILN=$(grep -c '^WSFAIL' /tmp/ws-subshell-$$.log)
if [ "$WSFAILN" -gt 0 ]; then grep '^WSFAIL' /tmp/ws-subshell-$$.log; fi
P=$((P + WSPASS)); F=$((F + WSFAILN))
rm -f /tmp/ws-subshell-$$.log

echo "== integration: $P passed, $F failed =="
[ "$F" -eq 0 ]
