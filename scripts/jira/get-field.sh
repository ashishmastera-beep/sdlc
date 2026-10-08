#!/usr/bin/env bash
# get-field.sh KEY FIELD_KEY
# Prints a pipeline field's value as plain text (option value for dropdowns, empty when unset).
# FIELD_KEY is a key from config/pipeline.json .jira.fields (e.g. approvedSpecSha, agentState).
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; fkey="${2:-}"; require_key "$key"
[[ -n "$fkey" ]] || die "usage: get-field.sh KEY FIELD_KEY"
get_field "$key" "$fkey" | jq -r 'if type == "object" then (.value // "") elif . == null then "" else tostring end'
