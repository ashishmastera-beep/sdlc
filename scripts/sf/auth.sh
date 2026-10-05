#!/usr/bin/env bash
# auth.sh ROLE
# Logs the Salesforce CLI in to the org for ROLE (agent | qa | production) with the JWT bearer flow.
# The org alias is taken from config/pipeline.json (.orgs.<role>.alias) and printed as alias=<alias>.
#
# Required environment (GitHub secrets):
#   SF_CLIENT_ID   consumer key of the External Client App
#   SF_USERNAME    CI user's username
#   SF_JWT_KEY     PEM private key matching the certificate uploaded to the app
set -euo pipefail
role="${1:-}"
cfg="$(dirname "$0")/../../config/pipeline.json"
die() { echo "error: $*" >&2; exit 1; }

[[ "$role" =~ ^(agent|qa|uat|production)$ ]] || die "usage: auth.sh agent|qa|uat|production"
for v in SF_CLIENT_ID SF_USERNAME SF_JWT_KEY; do [[ -n "${!v:-}" ]] || die "$v is not set (add it as a GitHub secret)"; done

alias="$(jq -er ".orgs.${role}.alias" "$cfg")"
url="$(jq -er ".orgs.${role}.instanceUrl" "$cfg")"
[[ "$url" =~ ^https://[A-Za-z0-9.-]+\.salesforce\.com$ ]] || die "instanceUrl for $role is not a Salesforce https URL: $url"

keydir="$(mktemp -d)"; trap 'rm -rf "$keydir"' EXIT
( umask 077; printf '%s\n' "$SF_JWT_KEY" > "$keydir/server.key" )

sf org login jwt \
  --client-id "$SF_CLIENT_ID" \
  --jwt-key-file "$keydir/server.key" \
  --username "$SF_USERNAME" \
  --instance-url "$url" \
  --alias "$alias" >/dev/null

echo "Logged in to $role ($url) as alias '$alias'"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "alias=$alias" >> "$GITHUB_OUTPUT"; fi
