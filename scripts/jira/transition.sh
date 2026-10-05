#!/usr/bin/env bash
# transition.sh KEY "Target Status Name"
# Moves the issue to the named status using whichever transition leads there.
# Idempotent: exits 0 without change if the issue is already in that status.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; target="${2:-}"; require_key "$key"
[[ -n "$target" ]] || die "usage: transition.sh KEY \"Target Status\""

now="$(current_status "$key")"
if [[ "$now" == "$target" ]]; then echo "$key already in '$target'"; exit 0; fi

tid="$(jira_api GET "/rest/api/3/issue/${key}/transitions" \
  | jq -r --arg t "$target" '[.transitions[] | select(.to.name == $t)][0].id // empty')"
[[ -n "$tid" ]] || die "$key: no transition from '$now' to '$target'"

jira_api POST "/rest/api/3/issue/${key}/transitions" "$(jq -cn --arg id "$tid" '{transition: {id: $id}}')" >/dev/null
echo "$key: '$now' -> '$target'"
