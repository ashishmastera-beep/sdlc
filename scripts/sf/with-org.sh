#!/usr/bin/env bash
# with-org.sh ROLE COMMAND [ARGS...]
# Logs in to the org for ROLE (scripts/sf/auth.sh), runs COMMAND with ORG_ALIAS set, then always logs out and
# deletes the CLI's stored credentials. Use it so no Salesforce session is left on the runner for a later step
# (the build agent runs shell commands between org steps).
set -uo pipefail
role="${1:?usage: with-org.sh ROLE COMMAND [ARGS...]}"; shift
here="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
  sf org logout --all --no-prompt >/dev/null 2>&1 || true
  rm -rf "$HOME/.sf" "$HOME/.sfdx" 2>/dev/null || true
}
trap cleanup EXIT

GITHUB_OUTPUT='' bash "$here/auth.sh" "$role" || exit 1
ORG_ALIAS="$(jq -r ".orgs.${role}.alias" "$here/../../config/pipeline.json")"
export ORG_ALIAS
"$@"
