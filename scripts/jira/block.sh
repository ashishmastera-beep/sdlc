#!/usr/bin/env bash
# block.sh KEY "reason" [RUN_URL]
# Sets Agent State=Failed, comments the reason (and run link), and moves the issue to Blocked.
# Each step is attempted even if an earlier one fails, so a human always gets the signal.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; reason="${2:-}"; run_url="${3:-}"; require_key "$key"
[[ -n "$reason" ]] || die "usage: block.sh KEY \"reason\" [run_url]"
here="$(dirname "$0")"; rc=0

"$here/set-field.sh" "$key" agentState Failed || rc=1
"$here/comment.sh" "$key" "Pipeline blocked: ${reason}" "$run_url" || rc=1
"$here/transition.sh" "$key" "$(status_name blocked)" || rc=1
exit "$rc"
