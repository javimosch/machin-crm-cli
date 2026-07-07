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

echo "== integration: $P passed, $F failed =="
[ "$F" -eq 0 ]
