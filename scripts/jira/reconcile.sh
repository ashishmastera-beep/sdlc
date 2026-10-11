#!/usr/bin/env bash
# reconcile.sh
# Safety net, run every 15 minutes. Recovers cards whose event was lost or whose run died, then applies the WIP gate.
#   1. Queued in an agent stage for longer than reconcileQueuedAfterMinutes -> re-dispatch its event
#   2. Running, but the linked GitHub run is no longer running              -> re-dispatch (claim counts the attempt)
#   3. WIP gate                                                            -> promote approved specs to the build queue
# Needs JIRA_* and GH_TOKEN (contents:write, actions:read), GITHUB_REPOSITORY.
source "$(dirname "$0")/lib.sh"
require_env
here="$(dirname "$0")"
p="$(cfg .jira.projectKey)"
qmin="$(cfg .limits.reconcileQueuedAfterMinutes)"
state="$(cf agentState)"; run_f="$(field_id agentRun)"

# stage status -> event that runs it
declare -A EVENT=(
  ["$(status_name enrich)"]=jira.enrich
  ["$(status_name specApproved)"]=jira.spec_approved
  ["$(status_name readyForBuild)"]=jira.build
)
stages="$(printf '"%s",' "${!EVENT[@]}")"; stages="${stages%,}"

echo "== Queued for over ${qmin} minutes"
jira_search "project = $p AND status in ($stages) AND $state = Queued AND updated <= -${qmin}m" status 50 \
  | jq -r '.[] | "\(.key)\t\(.fields.status.name)"' | while IFS=$'\t' read -r key st; do
      dispatch_event "${EVENT[$st]}" "$key" || warn "$key: re-dispatch failed"
    done

echo "== Running with no live run"
jira_search "project = $p AND status in ($stages) AND $state = Running" "status,$run_f" 50 \
  | jq -r --arg r "$run_f" '.[] | "\(.key)\t\(.fields.status.name)\t\(.fields[$r] // "")"' \
  | while IFS=$'\t' read -r key st url; do
      run_status=unknown
      if [[ "$url" =~ /actions/runs/([0-9]+) ]]; then
        run_status="$(gh api "repos/${GITHUB_REPOSITORY:?}/actions/runs/${BASH_REMATCH[1]}" --jq .status 2>/dev/null || echo unknown)"
      fi
      case "$run_status" in
        in_progress|queued|waiting|requested|pending) echo "$key: run still $run_status" ;;
        *) echo "$key: run is '$run_status'; retrying"
           "$here/set-field.sh" "$key" agentState Queued >/dev/null && dispatch_event "${EVENT[$st]}" "$key" || warn "$key: retry failed" ;;
      esac
    done

echo "== WIP gate"
"$here/wip-gate.sh"
