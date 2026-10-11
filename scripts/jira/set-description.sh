#!/usr/bin/env bash
# set-description.sh KEY ENRICHMENT_MD [LINK_BASE]
# Rewrites the issue Description as "Original Story" (kept exactly as written) + divider + "AI Enrichment"
# (from ENRICHMENT_MD). Re-running replaces the AI Enrichment section; it never appends a second one.
# LINK_BASE turns repo-relative links into GitHub URLs, e.g. https://github.com/OWNER/REPO/blob/spec/SDLC-12/
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; md="${2:-}"; base="${3:-}"; require_key "$key"
[[ -f "$md" ]] || die "usage: set-description.sh KEY ENRICHMENT_MD [LINK_BASE]"
command -v node >/dev/null || die "node is required"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
jira_api GET "/rest/api/3/issue/${key}?fields=description" | jq '.fields.description' > "$tmp/current.json"
node "$(dirname "$0")/description.mjs" build --description "$tmp/current.json" --enrichment "$md" \
  ${base:+--link-base "$base"} > "$tmp/new.json"

# Jira rejects descriptions over 32,767 characters of ADF text; fail clearly instead of with a 400.
size="$(wc -c < "$tmp/new.json")"
(( size < 120000 )) || die "description too large (${size} bytes of ADF); shorten enrichment.md"

jira_api PUT "/rest/api/3/issue/${key}?notifyUsers=false" \
  "$(jq -c '{fields: {description: .}}' "$tmp/new.json")" >/dev/null
echo "$key: description updated (Original Story + AI Enrichment)"
