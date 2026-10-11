#!/usr/bin/env bash
# run-build.sh KEY ROUND [FEEDBACK_FILE]
# One build round: runs the build agent (GitHub Copilot CLI) on the approved spec, then the local checks
# (check-build.sh), retrying once with the checker's findings. FEEDBACK_FILE (from a failed org validation in
# the previous round) is shown to the agent so it can fix the errors.
# Run from the repository root. Exit 0 = output passes local checks; 1 = still invalid; 4 = Copilot token problem.
#
# Environment: COPILOT_GITHUB_TOKEN only. No Salesforce or Jira credentials may be present: the agent can run
# shell commands. Optional: COPILOT_MODEL, AGENT_LOG_DIR, BASE_REF (default origin/main).
set -euo pipefail
key="${1:?usage: run-build.sh KEY ROUND [FEEDBACK_FILE]}"; round="${2:?}"; feedback_file="${3:-}"
[[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || { echo "invalid key" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"; cd "$root"
config="config/pipeline.json"
logs="${AGENT_LOG_DIR:-$(mktemp -d)}/round-${round}"; mkdir -p "$logs"
today="$(date -u +%Y-%m-%d)"

for v in SF_JWT_KEY SF_CLIENT_ID SF_USERNAME JIRA_API_TOKEN JIRA_USER GH_TOKEN; do
  [[ -z "${!v:-}" ]] || { echo "::error::$v must not be set while the build agent runs"; exit 2; }
done

mkdir -p .pipeline-input .pipeline-output
# Pipeline scratch files (agent inputs/outputs, deploy results, CLI caches) never count as agent changes.
for d in .pipeline-input/ .pipeline-output/ deploy-result.json .sf/ .sfdx/ code-analyzer.*; do
  grep -qx "$d" .git/info/exclude 2>/dev/null || echo "$d" >> .git/info/exclude
done

feedback_section=""
if [[ -n "$feedback_file" && -s "$feedback_file" ]]; then
  cp "$feedback_file" .pipeline-input/org-validation-errors.md
  feedback_section=$'- `.pipeline-input/org-validation-errors.md`: **your previous attempt failed validation in the Salesforce org.**\n  Fix every error listed there first; keep the parts that already worked.\n'
fi

render_prompt() {
  local extra="$1"
  awk -v key="$key" -v date="$today" -v fb="$feedback_section" '
    { gsub(/\{\{KEY\}\}/, key); gsub(/\{\{DATE\}\}/, date) }
    /\{\{FEEDBACK\}\}/ { printf "%s", fb; next }
    { print }' .github/agent-prompts/build.md
  if [[ -n "$extra" ]]; then
    printf '\n## Fix these problems from your previous attempt\n\nThe pipeline checker rejected your output. Fix every item, keep everything else:\n\n%s\n' "$extra"
  fi
}

model_args=()
model="${COPILOT_MODEL:-$(jq -r '.agents.build.model // ""' "$config")}"
[[ -n "$model" ]] && model_args=(--model "$model")

deny=(
  'shell(git push)' 'shell(git commit)' 'shell(git remote)' 'shell(git config)' 'shell(git reset)' 'shell(git checkout)'
  'shell(gh)' 'shell(curl)' 'shell(wget)' 'shell(ssh)' 'shell(scp)' 'shell(nc)'
  'shell(sf)' 'shell(sfdx)' 'shell(npm)' 'shell(npx)' 'shell(pip)' 'shell(python3 -m pip)'
  'shell(env)' 'shell(printenv)' 'shell(rm -rf)'
)
deny_args=(); for d in "${deny[@]}"; do deny_args+=(--deny-tool "$d"); done

source scripts/agents/copilot-preflight.sh

extra=""
for attempt in 1 2; do
  echo "::group::Build agent, round ${round}, attempt ${attempt}/2"
  set +e
  copilot -p "$(render_prompt "$extra")" --allow-all-tools "${deny_args[@]}" "${model_args[@]}" --no-ask-user \
    --log-dir "$logs/attempt-${attempt}" --share "$logs/transcript-${attempt}.md" 2>&1 | tee "$logs/output-${attempt}.txt"
  rc=${PIPESTATUS[0]}
  set -e
  echo "::endgroup::"
  if [[ $rc -ne 0 ]] && grep -Eqi 'authentication failed|bad credentials|not authorized|copilot requests' "$logs/output-${attempt}.txt"; then
    echo "::error::Copilot rejected the token (see the log above)."
    exit 4
  fi
  if extra="$(bash scripts/agents/check-build.sh "$key")"; then
    echo "$extra"
    exit 0
  fi
  echo "$extra"
  # Undo anything outside the allowed paths before retrying.
  git status --porcelain --untracked-files=all | while IFS= read -r line; do
    path="${line:3}"
    case "$path" in
      force-app/main/default/profiles/*) ;;
      force-app/*|"specs/$key/implementation-log.md") continue ;;
    esac
    git checkout -- "$path" 2>/dev/null || rm -rf -- "$path"
  done
done
echo "::error::Build output still fails the local checks after 2 attempts in round ${round}."
exit 1
