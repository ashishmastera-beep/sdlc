#!/usr/bin/env bash
# comment.sh KEY "text (newlines become paragraphs)" [URL]
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; text="${2:-}"; url="${3:-}"; require_key "$key"
[[ -n "$text" ]] || die "usage: comment.sh KEY \"text\" [url]"

jira_api POST "/rest/api/3/issue/${key}/comment" \
  "$(jq -cn --argjson b "$(adf_text "$text" "$url")" '{body: $b}')" >/dev/null
echo "$key: comment added"
