#!/usr/bin/env bash
# org-validate.sh ALIAS FEEDBACK_FILE [BASE_REF]   (BASE_REF defaults to WORKTREE: the uncommitted agent output)
# Check-only deploy of force-app to the org with tests (scripts/sf/deploy.sh validate), then the coverage gate
# on changed classes. On failure, writes the errors as Markdown to FEEDBACK_FILE for the next agent round.
# Exit 0 = valid. Run from the repository root with the Salesforce CLI already logged in as ALIAS.
set -uo pipefail
alias="${1:?usage: org-validate.sh ALIAS FEEDBACK_FILE [BASE_REF]}"; feedback="${2:?}"; base="${3:-WORKTREE}"
: > "$feedback"

summary="$(bash scripts/sf/deploy.sh validate "$alias")"; rc=$?
echo "$summary"
if [[ $rc -ne 0 ]]; then
  { echo "# Org validation failed (check-only deploy with tests)"; echo; echo "$summary"; } > "$feedback"
  exit 1
fi

if ! cov="$(node scripts/sf/coverage-check.js deploy-result.json "$base" 2>&1)"; then
  echo "$cov"
  { echo "# Code coverage below the minimum"; echo; echo "The deployment validated, but:"; echo; echo '```'; echo "$cov"; echo '```'
    echo; echo "Add or extend @IsTest classes so every changed class reaches the minimum."; } > "$feedback"
  exit 1
fi
echo "$cov"
echo "Org validation passed."
