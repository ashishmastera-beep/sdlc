#!/usr/bin/env bash
# Shared helpers for Jira REST calls. Source this file; do not run it.
#
# Required environment:
#   JIRA_BASE_URL   e.g. https://ashishmastera.atlassian.net
#   JIRA_USER       service account email
#   JIRA_API_TOKEN  service account API token
# Optional:
#   PIPELINE_CONFIG path to config/pipeline.json (default: repo root config)

set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_CONFIG="${PIPELINE_CONFIG:-${_lib_dir}/../../config/pipeline.json}"

die() { echo "error: $*" >&2; exit 1; }

require_env() {
  local v
  for v in JIRA_BASE_URL JIRA_USER JIRA_API_TOKEN; do
    [[ -n "${!v:-}" ]] || die "$v is not set"
  done
  command -v jq >/dev/null || die "jq is required"
  command -v curl >/dev/null || die "curl is required"
}

# Validates a Jira key like SDLC-12 so it is safe to put in URLs.
require_key() {
  [[ "${1:-}" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || die "invalid issue key: '${1:-}'"
}

# cfg <jq path>, e.g. cfg '.jira.fields.agentState'
cfg() { jq -er "$1" "$PIPELINE_CONFIG"; }

field_id() { cfg ".jira.fields.$1"; }
status_name() { cfg ".jira.statuses.$1.name"; }

# jira_api METHOD PATH [JSON_BODY]
# Prints the response body. Retries transient failures; fails on any non-2xx.
jira_api() {
  local method="$1" path="$2" body="${3:-}" out code tmp
  tmp="$(mktemp)"
  local args=(-sS -X "$method" -u "${JIRA_USER}:${JIRA_API_TOKEN}"
    -H "Accept: application/json" -H "Content-Type: application/json"
    --retry 3 --retry-delay 2 --retry-all-errors --max-time 30
    -o "$tmp" -w "%{http_code}")
  [[ -n "$body" ]] && args+=(--data "$body")
  code="$(curl "${args[@]}" "${JIRA_BASE_URL%/}${path}")" || { rm -f "$tmp"; die "request failed: $method $path"; }
  out="$(cat "$tmp")"; rm -f "$tmp"
  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    die "$method $path returned HTTP $code: ${out:0:500}"
  fi
  printf '%s' "$out"
}

# current_status KEY -> status name
current_status() {
  jira_api GET "/rest/api/3/issue/$1?fields=status" | jq -r '.fields.status.name'
}

# get_field KEY FIELD_KEY -> raw JSON value of a configured custom field
get_field() {
  local fid; fid="$(field_id "$2")"
  jira_api GET "/rest/api/3/issue/$1?fields=$fid" | jq -c --arg f "$fid" '.fields[$f]'
}

# adf_text TEXT [URL] -> ADF document JSON: one paragraph per line, optional link paragraph.
adf_text() {
  local text="$1" url="${2:-}"
  jq -cn --arg t "$text" --arg u "$url" '
    { type: "doc", version: 1,
      content: (
        ($t | split("\n") | map(select(length > 0))
            | map({type: "paragraph", content: [{type: "text", text: .}]}))
        + (if $u == "" then [] else
            [{type: "paragraph", content: [{type: "text", text: $u, marks: [{type: "link", attrs: {href: $u}}]}]}]
          end)
      ) }'
}

# gh_output NAME VALUE -> writes a step output when running in GitHub Actions
gh_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
  echo "$1=$2"
}
