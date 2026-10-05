#!/usr/bin/env bash
# release.sh KEY [--reset-attempts]
# Marks a successful stage: Agent State=Idle. With --reset-attempts, also sets Agent Attempts to 0
# (use when a stage completes so the next stage starts with a fresh retry budget).
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; require_key "$key"

fields="$(jq -cn --arg s "$(field_id agentState)" --arg a "$(field_id agentAttempts)" --arg reset "${2:-}" \
  '{fields: ({($s): {value: "Idle"}} + (if $reset == "--reset-attempts" then {($a): 0} else {} end))}')"
jira_api PUT "/rest/api/3/issue/${key}?notifyUsers=false" "$fields" >/dev/null
echo "$key: released"
