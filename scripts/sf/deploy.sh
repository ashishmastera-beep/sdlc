#!/usr/bin/env bash
# deploy.sh MODE ALIAS [JOB_ID]
#   MODE=validate  check-only deploy of force-app with tests; prints job_id=<id>
#   MODE=deploy    real deploy of force-app with tests
#   MODE=quick     quick-deploy a previous validation (JOB_ID required)
# Writes the CLI's JSON result to deploy-result.json and a summary to the job summary.
set -uo pipefail
mode="${1:-}"; alias="${2:-}"; job="${3:-}"
cfg="$(dirname "$0")/../../config/pipeline.json"
level="$(jq -r '.salesforce.testLevel' "$cfg")"
out="deploy-result.json"
die() { echo "error: $*" >&2; exit 1; }
[[ -n "$alias" ]] || die "usage: deploy.sh validate|deploy|quick ALIAS [JOB_ID]"

case "$mode" in
  validate) sf project deploy validate --source-dir force-app --target-org "$alias" --test-level "$level" \
              --wait 90 --json > "$out"; rc=$? ;;
  deploy)   sf project deploy start --source-dir force-app --target-org "$alias" --test-level "$level" \
              --wait 90 --json > "$out"; rc=$? ;;
  quick)    [[ "$job" =~ ^0Af[A-Za-z0-9]{12,15}$ ]] || die "quick needs a deploy job id (0Af...)"
            sf project deploy quick --job-id "$job" --target-org "$alias" --wait 90 --json > "$out"; rc=$? ;;
  *) die "unknown mode '$mode'" ;;
esac

status="$(jq -r '.result.status // .name // "Unknown"' "$out" 2>/dev/null || echo Unknown)"
id="$(jq -r '.result.id // empty' "$out" 2>/dev/null)"
comps="$(jq -r '.result.numberComponentsDeployed // 0' "$out" 2>/dev/null)"
tests="$(jq -r '.result.numberTestsCompleted // 0' "$out" 2>/dev/null)"
tfail="$(jq -r '.result.numberTestErrors // 0' "$out" 2>/dev/null)"

summary="### Salesforce ${mode}: ${status}
- Org alias: \`${alias}\`
- Job id: \`${id:-n/a}\`
- Components: ${comps}, tests run: ${tests}, test failures: ${tfail}"

if [[ $rc -ne 0 ]]; then
  failures="$(jq -r '
    ((.result.details.componentFailures // []) | if type=="object" then [.] else . end
      | map("- component `\(.fullName)` (\(.componentType)): \(.problem)") | .[:20] | .[]),
    ((.result.details.runTestResult.failures // []) | if type=="object" then [.] else . end
      | map("- test `\(.name).\(.methodName)`: \(.message)") | .[:20] | .[]),
    (if (.message // "") != "" then "- \(.message)" else empty end)' "$out" 2>/dev/null)"
  summary="${summary}

**Failures**
${failures:-- see deploy-result.json}"
fi

echo "$summary"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then echo "$summary" >> "$GITHUB_STEP_SUMMARY"; fi
if [[ -n "${GITHUB_OUTPUT:-}" && -n "$id" ]]; then echo "job_id=$id" >> "$GITHUB_OUTPUT"; fi
exit $rc
