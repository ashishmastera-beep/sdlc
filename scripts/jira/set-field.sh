#!/usr/bin/env bash
# set-field.sh KEY FIELD_KEY VALUE
# FIELD_KEY is a key from config/pipeline.json .jira.fields (e.g. agentState, specPr, agentAttempts).
# Use an empty VALUE to clear the field.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; fkey="${2:-}"; value="${3-}"; require_key "$key"
[[ -n "$fkey" ]] || die "usage: set-field.sh KEY FIELD_KEY VALUE"
fid="$(field_id "$fkey")" || die "unknown field key '$fkey'"

case "$fkey" in
  agentState|riskLevel)
    if [[ -n "$value" ]] && [[ "$fkey" == agentState ]]; then
      jq -e --arg v "$value" '.jira.agentStates | index($v)' "$PIPELINE_CONFIG" >/dev/null \
        || die "agentState must be one of: $(jq -r '.jira.agentStates | join(", ")' "$PIPELINE_CONFIG")"
    fi
    val="$(jq -cn --arg v "$value" 'if $v == "" then null else {value: $v} end')" ;;
  agentAttempts)
    [[ -z "$value" || "$value" =~ ^[0-9]+$ ]] || die "agentAttempts must be a whole number"
    val="$(jq -cn --arg v "$value" 'if $v == "" then null else ($v | tonumber) end')" ;;
  *)
    val="$(jq -cn --arg v "$value" 'if $v == "" then null else $v end')" ;;
esac

jira_api PUT "/rest/api/3/issue/${key}?notifyUsers=false" \
  "$(jq -cn --arg f "$fid" --argjson v "$val" '{fields: {($f): $v}}')" >/dev/null
echo "$key: $fkey set"
