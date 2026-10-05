#!/usr/bin/env bash
# guard.sh KEY "Expected Status"
# Decides whether a pipeline event should run. Writes proceed=true|false (and reason=...) to GITHUB_OUTPUT.
#   - stale event: the issue is no longer in the expected status
#   - already running: Agent State is Running and the linked GitHub run is still in progress
# Needs GH_TOKEN for the in-progress check (actions: read).
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; expected="${2:-}"; require_key "$key"
[[ -n "$expected" ]] || die "usage: guard.sh KEY \"Expected Status\""

state_f="$(field_id agentState)"; run_f="$(field_id agentRun)"
issue="$(jira_api GET "/rest/api/3/issue/${key}?fields=status,${state_f},${run_f}")"
status="$(jq -r '.fields.status.name' <<<"$issue")"
state="$(jq -r --arg f "$state_f" '.fields[$f].value // "Idle"' <<<"$issue")"
run_url="$(jq -r --arg f "$run_f" '.fields[$f] // ""' <<<"$issue")"

if [[ "$status" != "$expected" ]]; then
  gh_output proceed false; gh_output reason "stale: status is '$status', expected '$expected'"; exit 0
fi

if [[ "$state" == "Running" && "$run_url" =~ /actions/runs/([0-9]+) ]]; then
  run_id="${BASH_REMATCH[1]}"
  if command -v gh >/dev/null && [[ -n "${GH_TOKEN:-}" ]]; then
    run_status="$(gh api "repos/${GITHUB_REPOSITORY:?}/actions/runs/${run_id}" --jq .status 2>/dev/null || echo unknown)"
    if [[ "$run_status" == "in_progress" || "$run_status" == "queued" || "$run_status" == "waiting" ]]; then
      gh_output proceed false; gh_output reason "already running: run ${run_id} is ${run_status}"; exit 0
    fi
  fi
fi

gh_output proceed true; gh_output reason "ok"
