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

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
