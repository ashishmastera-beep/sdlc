#!/usr/bin/env bash
# wip-gate.sh
# Moves approved specs into the build queue while builds in flight (In Build + PR Created) stay under limits.wip.
# Candidates: "Enrichment Approved", Approved Spec SHA set, Agent State Idle; oldest first.
# Each promoted card goes to "Ready for Build", Agent State=Queued, and a jira.build event is dispatched.
# Needs GH_TOKEN (contents:write) and GITHUB_REPOSITORY for the dispatch.
source "$(dirname "$0")/lib.sh"
require_env
here="$(dirname "$0")"
p="$(cfg .jira.projectKey)"; wip="$(cfg .limits.wip)"

in_flight="$(jira_search "project = $p AND status in (\"$(status_name inBuild)\", \"$(status_name prCreated)\")" status 100 | jq length)"
slots=$(( wip - in_flight ))
echo "WIP: ${in_flight}/${wip} builds in flight, ${slots} slot(s) free"
(( slots > 0 )) || exit 0

jql="project = $p AND status = \"$(status_name specApproved)\" AND $(cf approvedSpecSha) is not EMPTY AND $(cf agentState) = Idle ORDER BY updated ASC"
mapfile -t keys < <(jira_search "$jql" status "$slots" | jq -r '.[].key')
[[ ${#keys[@]} -gt 0 ]] || { echo "No approved specs waiting"; exit 0; }

for key in "${keys[@]}"; do
  "$here/transition.sh" "$key" "$(status_name readyForBuild)"
  "$here/set-field.sh" "$key" agentState Queued
  dispatch_event jira.build "$key"
done
