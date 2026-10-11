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

# --- Phase 5: Description = Original Story + AI Enrichment ---
md="$(mktemp)"; printf '### Business Context\n\nFirst pass.\n' > "$md"
"$scripts/set-description.sh" SDLC-1 "$md" "https://github.com/o/r/blob/spec/SDLC-1/" >/dev/null
desc() { state ".\"SDLC-1\".fields.description"; }
check "description gets both sections"   '[[ "$(desc | jq -r "[.content[] | select(.type==\"heading\") | .content[0].text] | join(\"|\")")" == "Original Story|AI Enrichment|Business Context" ]]'
check "original story text kept"         '[[ "$(desc)" == *"contract end date"* ]]'
printf '### Business Context\n\nSecond pass.\n' > "$md"
"$scripts/set-description.sh" SDLC-1 "$md" >/dev/null
check "rework replaces enrichment"       '[[ "$(desc)" == *"Second pass."* && "$(desc)" != *"First pass."* && "$(desc | grep -o "AI Enrichment" | wc -l)" -eq 1 ]]'
out="$("$scripts/get-issue.sh" SDLC-1)"
check "agent sees only the original"     '[[ "$(jq -r .description <<<"$out")" == *"contract end date"* && "$(jq -r .description <<<"$out")" != *"Second pass"* ]]'
check "set-description needs a file"     '! "$scripts/set-description.sh" SDLC-1 /nonexistent 2>/dev/null'

# --- Attachments: replace by file name ---
adir="$(mktemp -d)"; echo "v1" > "$adir/SDLC-1-Technical-Specification.pdf"; echo "r" > "$adir/SDLC-1-Research-Specification.pdf"
"$scripts/attach.sh" SDLC-1 "$adir/SDLC-1-Technical-Specification.pdf" "$adir/SDLC-1-Research-Specification.pdf" >/dev/null
check "attach uploads both files"        '[[ "$(state ".\"SDLC-1\".fields.attachment | length")" == 2 ]]'
echo "v2 longer" > "$adir/SDLC-1-Technical-Specification.pdf"
"$scripts/attach.sh" SDLC-1 "$adir/SDLC-1-Technical-Specification.pdf" >/dev/null
check "re-attach replaces same name"     '[[ "$(state "[.\"SDLC-1\".fields.attachment[] | select(.filename | test(\"Technical\"))] | length")" == 1 && "$(state ".\"SDLC-1\".fields.attachment | length")" == 2 ]]'
check "attach rejects missing file"      '! "$scripts/attach.sh" SDLC-1 /nonexistent.pdf 2>/dev/null'

# --- Pipeline comments are marked and hidden from the agent ---
"$scripts/comment.sh" SDLC-1 "Spec approved." "https://github.com/o/r/actions/runs/9" >/dev/null
check "pipeline comment is prefixed"     '[[ "$(state ".\"SDLC-1\".comments[-1].body.content[0].content[0].text")" == "🤖 SDLC pipeline: Spec approved." ]]'
out="$("$scripts/get-issue.sh" SDLC-1)"
curl -s -X POST "$JIRA_BASE_URL/rest/api/3/issue/SDLC-1/comment" -H "Content-Type: application/json" \
  -d '{"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"PO: use a 45-day window instead."}]}]}}' >/dev/null
out="$("$scripts/get-issue.sh" SDLC-1)"
check "people's comments still reach agent" '[[ "$(jq -r ".comments[].body" <<<"$out")" == *"45-day window"* ]]'
check "agent input has no pipeline notes" '[[ "$(jq "[.comments[] | select(.body | test(\"SDLC pipeline|actions/runs\"))] | length" <<<"$out")" == 0 ]]'

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
