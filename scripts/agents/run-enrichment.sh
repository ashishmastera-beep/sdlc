#!/usr/bin/env bash
# run-enrichment.sh KEY ISSUE_JSON
# Runs the enrichment agent (GitHub Copilot CLI) and validates its output, retrying once with the
# validator's findings. Run from the repository root on a clean checkout.
#
# Environment: COPILOT_GITHUB_TOKEN (or GITHUB_TOKEN with copilot-requests: write).
# Nothing else secret may be in the environment: the agent reads untrusted Jira text.
# Optional: COPILOT_MODEL, AGENT_LOG_DIR (transcripts and logs, uploaded as a run artifact).
set -euo pipefail
key="${1:?usage: run-enrichment.sh KEY ISSUE_JSON}"; issue="${2:?usage: run-enrichment.sh KEY ISSUE_JSON}"
[[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || { echo "invalid key" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"; cd "$root"
config="config/pipeline.json"
attempts="$(jq -r '.agents.enrich.maxAttempts // 2' "$config")"
logs="${AGENT_LOG_DIR:-$(mktemp -d)}"; mkdir -p "$logs"
today="$(date -u +%Y-%m-%d)"

# The issue file sits inside the workspace (the agent can only read the workspace) but is never committed.
mkdir -p .pipeline-input
cp "$issue" .pipeline-input/issue.json
grep -qx '.pipeline-input/' .git/info/exclude 2>/dev/null || echo '.pipeline-input/' >> .git/info/exclude

prompt="$(sed -e "s/{{KEY}}/${key}/g" -e "s/{{DATE}}/${today}/g" -e "s#{{ISSUE_JSON}}#.pipeline-input/issue.json#g" \
  .github/agent-prompts/enrichment.md)"

model_args=()
model="${COPILOT_MODEL:-$(jq -r '.agents.enrich.model // ""' "$config")}"
[[ -n "$model" ]] && model_args=(--model "$model")

# Tools: the agent may read and write files and run read-only shell commands. Anything that reaches the
# network, changes git state or deploys is denied, so untrusted story text cannot make it act outside specs/.
deny=(
  'shell(git push)' 'shell(git commit)' 'shell(git remote)' 'shell(git config)' 'shell(git reset)' 'shell(git checkout)'
  'shell(gh)' 'shell(curl)' 'shell(wget)' 'shell(ssh)' 'shell(scp)' 'shell(nc)'
  'shell(sf)' 'shell(sfdx)' 'shell(npm)' 'shell(npx)' 'shell(pip)' 'shell(python3 -m pip)'
  'shell(env)' 'shell(printenv)' 'shell(rm -rf)'
)
deny_args=(); for d in "${deny[@]}"; do deny_args+=(--deny-tool "$d"); done

# Preflight: catch the usual secret mistakes with a clear message before spending an agent run.
# Prints only token shape and the account login, never the token.
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

feedback=""
for attempt in $(seq 1 "$attempts"); do
  echo "::group::Enrichment agent, attempt ${attempt}/${attempts}"
  full="$prompt"
  if [[ -n "$feedback" ]]; then
    full+=$'\n\n## Fix these problems from your previous attempt\n\nThe validator rejected your output. Fix every item, keep everything else:\n\n'"$feedback"
  fi
  set +e
  copilot -p "$full" --allow-all-tools "${deny_args[@]}" "${model_args[@]}" --no-ask-user \
    --log-dir "$logs/attempt-${attempt}" --share "$logs/transcript-${attempt}.md" 2>&1 | tee "$logs/output-${attempt}.txt"
  rc=${PIPESTATUS[0]}
  set -e
  echo "::endgroup::"
  if [[ $rc -ne 0 ]]; then
    echo "::warning::Copilot CLI exited with code $rc on attempt ${attempt}"
    if grep -Eqi 'not authorized|unauthorized|401|403|no copilot|copilot requests|access to copilot' "$logs/output-${attempt}.txt"; then
      echo "::error::Copilot rejected the token. Check the COPILOT_GITHUB_TOKEN secret (fine-grained token with the 'Copilot Requests' permission) and that the account has a Copilot licence."
      exit 4
    fi
  fi
  if feedback="$(bash scripts/agents/check-enrichment.sh "$key")"; then
    echo "$feedback"
    exit 0
  fi
  echo "$feedback"
  # Undo anything the agent touched outside specs/<KEY>/ before retrying.
  git status --porcelain --untracked-files=all | while IFS= read -r line; do
    path="${line:3}"; [[ "$path" == "specs/$key/"* ]] && continue
    git checkout -- "$path" 2>/dev/null || rm -rf -- "$path"
  done
done
echo "::error::Enrichment output was still invalid after ${attempts} attempts."
exit 1
