#!/usr/bin/env bash
# Offline tests for scripts/jira/*.sh against a local mock Jira. Exit 0 = all passed.
# Variables below are read inside check()'s eval strings.
# shellcheck disable=SC2034
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; scripts="$here/.."; root="$here/../../.."
port=$((20000 + RANDOM % 20000))
python3 "$here/mock_jira.py" "$port" "$root/config/pipeline.json" & mock=$!
trap 'kill $mock 2>/dev/null' EXIT
for _ in $(seq 50); do curl -s "http://127.0.0.1:$port/" >/dev/null 2>&1 && break; sleep 0.1; done

export JIRA_BASE_URL="http://127.0.0.1:$port" JIRA_USER=test JIRA_API_TOKEN=test
unset GITHUB_OUTPUT GH_TOKEN
pass=0; fail=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
state() { curl -s -X DELETE "$JIRA_BASE_URL/" | jq -r "$1"; }

out="$("$scripts/get-issue.sh" SDLC-1)"
check "get-issue returns summary"        '[[ "$(jq -r .summary <<<"$out")" == "Add contract end date to Account" ]]'
check "get-issue flattens description"   '[[ "$(jq -r .description <<<"$out")" == *"contract end date"* ]]'
check "get-issue reads risk level"       '[[ "$(jq -r .riskLevel <<<"$out")" == "Low" ]]'

check "rejects bad key"                  '! "$scripts/get-issue.sh" "SDLC-1;rm" 2>/dev/null'
check "rejects missing issue"            '! "$scripts/get-issue.sh" SDLC-999 2>/dev/null'

g="$("$scripts/guard.sh" SDLC-1 "Enrichment In Progress")"
check "guard proceeds in expected status" '[[ "$g" == *"proceed=true"* ]]'
g="$("$scripts/guard.sh" SDLC-1 "Ready for Build")"
check "guard skips stale event"          '[[ "$g" == *"proceed=false"* && "$g" == *stale* ]]'

"$scripts/claim.sh" SDLC-1 "https://github.com/x/y/actions/runs/1" >/dev/null
check "claim sets Running"               '[[ "$(state ".\"SDLC-1\".fields.customfield_10109.value")" == Running ]]'
check "claim increments attempts"        '[[ "$(state ".\"SDLC-1\".fields.customfield_10110")" == 1 ]]'
check "claim records run URL"            '[[ "$(state ".\"SDLC-1\".fields.customfield_10111")" == *runs/1 ]]'

"$scripts/transition.sh" SDLC-1 "Enrichment Completed" >/dev/null
check "transition by status name"        '[[ "$(state ".\"SDLC-1\".status")" == "Enrichment Completed" ]]'
check "transition is idempotent"         '"$scripts/transition.sh" SDLC-1 "Enrichment Completed" >/dev/null'
check "transition refuses invalid jump"  '! "$scripts/transition.sh" SDLC-1 "Released" 2>/dev/null'

"$scripts/set-field.sh" SDLC-1 specPr "https://github.com/x/y/pull/7" >/dev/null
check "set-field URL"                    '[[ "$(state ".\"SDLC-1\".fields.customfield_10113")" == *pull/7 ]]'
check "set-field rejects bad agentState" '! "$scripts/set-field.sh" SDLC-1 agentState Sleeping 2>/dev/null'
check "set-field rejects bad number"     '! "$scripts/set-field.sh" SDLC-1 agentAttempts two 2>/dev/null'

"$scripts/release.sh" SDLC-1 --reset-attempts >/dev/null
check "release sets Idle and resets"     '[[ "$(state ".\"SDLC-1\".fields.customfield_10109.value")" == Idle && "$(state ".\"SDLC-1\".fields.customfield_10110")" == 0 ]]'

"$scripts/set-field.sh" SDLC-1 agentAttempts 3 >/dev/null
"$scripts/claim.sh" SDLC-1 "https://github.com/x/y/actions/runs/2" >/dev/null 2>&1; rc=$?
check "claim blocks over the limit"      '[[ $rc -eq 3 && "$(state ".\"SDLC-1\".status")" == Blocked ]]'
check "block sets Failed"                '[[ "$(state ".\"SDLC-1\".fields.customfield_10109.value")" == Failed ]]'
check "block leaves a comment"           '[[ "$(state ".\"SDLC-1\".comments | length")" -ge 1 ]]'

"$scripts/comment.sh" SDLC-1 $'line one\nline two' "https://example.com" >/dev/null
check "comment builds ADF paragraphs"    '[[ "$(state ".\"SDLC-1\".comments[-1].body.content | length")" == 3 ]]'

# --- Phase 4: keys, sync, WIP gate, reconciler (fake gh records dispatches) ---
fakebin="$(mktemp -d)"; dlog="$fakebin/dispatches.log"; : > "$dlog"
cat > "$fakebin/gh" <<FAKE
#!/usr/bin/env bash
if [[ "\$*" == *"/dispatches"* ]]; then cat >> "$dlog"; echo >> "$dlog"; exit 0; fi
if [[ "\$*" == *"/actions/runs/"* ]]; then echo completed; exit 0; fi
exit 1
FAKE
chmod +x "$fakebin/gh"; export PATH="$fakebin:$PATH" GITHUB_REPOSITORY=x/y GH_TOKEN=t

k="$(printf 'Merge pull request #2 from x/fix/SDLC-2-smoke\n\nSDLC-2: thing, also SDLC-10 and OTHER-3\n' | "$scripts/keys-from-text.sh" | tr '\n' ' ')"
check "keys-from-text finds project keys only" '[[ "$k" == "SDLC-2 SDLC-10 " ]]'

"$scripts/wip-gate.sh" >/dev/null
check "wip-gate promotes the oldest approved spec" '[[ "$(state ".\"SDLC-3\".status")" == "Ready for Build" && "$(state ".\"SDLC-3\".fields.customfield_10109.value")" == Queued ]]'
check "wip-gate respects the WIP limit"        '[[ "$(state ".\"SDLC-4\".status")" == "Enrichment Approved" ]]'
check "wip-gate dispatches jira.build"         'grep -q "\"event_type\":\"jira.build\".*SDLC-3" "$dlog"'

"$scripts/sync-keys.sh" --from "PR Created" --to "Approved" SDLC-6 SDLC-5 >/dev/null 2>&1
check "sync-keys moves matching cards"         '[[ "$(state ".\"SDLC-6\".status")" == Approved ]]'
check "sync-keys leaves other cards alone"     '[[ "$(state ".\"SDLC-5\".status")" == "In Build" ]]'
"$scripts/sync-keys.sh" --to "Deployed,Released" --comment "Released v1" SDLC-7 >/dev/null 2>&1
check "sync-keys walks multiple statuses"      '[[ "$(state ".\"SDLC-7\".status")" == Released && "$(state ".\"SDLC-7\".comments | length")" == 1 ]]'
"$scripts/sync-keys.sh" --to "Deployed,Released" SDLC-7 >/dev/null 2>&1; rc=$?
check "sync-keys is idempotent"                '[[ $rc -eq 0 && "$(state ".\"SDLC-7\".status")" == Released ]]'
out="$(JIRA_API_TOKEN='' "$scripts/sync-keys.sh" --to Approved SDLC-6 2>&1)"; rc=$?
check "sync-keys skips cleanly without Jira"   '[[ $rc -eq 0 && "$out" == *"not configured"* ]]'

"$scripts/set-field.sh" SDLC-4 agentState Running >/dev/null
"$scripts/set-field.sh" SDLC-4 agentRun "https://github.com/x/y/actions/runs/99" >/dev/null
: > "$dlog"; "$scripts/reconcile.sh" >/dev/null 2>&1
check "reconcile re-dispatches lost Queued"    'grep -q "jira.build.*SDLC-8" "$dlog"'
check "reconcile retries a dead Running run"   'grep -q "jira.spec_approved.*SDLC-4" "$dlog" && [[ "$(state ".\"SDLC-4\".fields.customfield_10109.value")" == Queued ]]'
rm -rf "$fakebin"

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
