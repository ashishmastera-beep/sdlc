#!/usr/bin/env bash
# claim.sh KEY RUN_URL
# Marks the issue as being worked on by this run: Agent State=Running, Agent Run=RUN_URL, Agent Attempts+1.
# If attempts already reached limits.maxAgentAttempts, blocks the issue instead and exits 3.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; run_url="${2:-}"; require_key "$key"
[[ "$run_url" =~ ^https:// ]] || die "usage: claim.sh KEY RUN_URL"

max="$(cfg '.limits.maxAgentAttempts')"
attempts="$(get_field "$key" agentAttempts | jq -r 'if . == null then 0 else floor end')"

if (( attempts >= max )); then
  "$(dirname "$0")/block.sh" "$key" "Stopped after ${attempts} automatic attempts (limit ${max}). Reset Agent Attempts to 0 and move the card back to retry." "$run_url"
  exit 3
fi

fields="$(jq -cn \
  --arg s "$(field_id agentState)" --arg r "$(field_id agentRun)" --arg a "$(field_id agentAttempts)" \
  --arg url "$run_url" --argjson n "$((attempts + 1))" \
  '{fields: {($s): {value: "Running"}, ($r): $url, ($a): $n}}')"
jira_api PUT "/rest/api/3/issue/${key}?notifyUsers=false" "$fields" >/dev/null
echo "$key: claimed (attempt $((attempts + 1))/${max})"
