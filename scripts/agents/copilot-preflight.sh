#!/usr/bin/env bash
# copilot-preflight.sh — source this before running Copilot CLI (needs $logs set to a writable dir).
# Catches the usual COPILOT_GITHUB_TOKEN mistakes with a clear message before spending an agent run,
# strips stray whitespace/quotes, and exits 4 when the token cannot work. Prints only the token's shape
# and the account login, never the token.
: "${logs:?set logs to a writable directory before sourcing copilot-preflight.sh}"
if [[ -z "${COPILOT_GITHUB_TOKEN:-}" ]]; then
  echo "::error::The COPILOT_GITHUB_TOKEN secret is not set. Add a fine-grained token with the 'Copilot Requests' permission (docs/enrichment-agent.md)."
  exit 4
fi
if [[ -n "${COPILOT_GITHUB_TOKEN:-}" ]]; then
  t="$COPILOT_GITHUB_TOKEN"
  trimmed="$(printf '%s' "$t" | tr -d '[:space:]"'"'")"
  if [[ "$trimmed" != "$t" ]]; then
    echo "::warning::COPILOT_GITHUB_TOKEN contains spaces, line breaks or quotes; using it with those removed. Re-save the secret without them."
    t="$trimmed"
  fi
  if [[ "$t" == Bearer* ]]; then
    echo "::error::COPILOT_GITHUB_TOKEN starts with 'Bearer'. Save only the token itself (github_pat_...) in this secret; 'Bearer ' belongs only in the Jira rules."
    exit 4
  fi
  case "$t" in
    github_pat_*) ;;
    ghp_*) echo "::error::COPILOT_GITHUB_TOKEN is a classic token (ghp_...). Copilot CLI needs a fine-grained token (github_pat_...) with the 'Copilot Requests' permission."; exit 4 ;;
    ghs_*|ghu_*|gho_*) ;;  # app / OAuth tokens (e.g. the workflow token fallback)
    *) echo "::error::COPILOT_GITHUB_TOKEN does not look like a GitHub token (expected github_pat_..., ${#t} characters found)."; exit 4 ;;
  esac
  code="$(curl -sS -o "$logs/whoami.json" -w '%{http_code}' -H "Authorization: Bearer $t" -H "Accept: application/vnd.github+json" https://api.github.com/user || echo 000)"
  if [[ "$code" == 401 ]]; then
    echo "::error::GitHub does not recognise COPILOT_GITHUB_TOKEN (401 Bad credentials): it was deleted, expired, regenerated, or mis-pasted. Create a new fine-grained token and paste it into the secret again."
    exit 4
  elif [[ "$code" == 200 ]]; then
    echo "Copilot token belongs to: $(jq -r .login "$logs/whoami.json")"
  else
    echo "::warning::Could not check COPILOT_GITHUB_TOKEN (HTTP $code); continuing."
  fi
  rm -f "$logs/whoami.json"
  export COPILOT_GITHUB_TOKEN="$t"
fi

