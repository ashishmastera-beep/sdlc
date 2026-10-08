#!/usr/bin/env bash
# sync-keys.sh --to "Status A[,Status B]" [--from "Status X[,Status Y]"] [--comment TEXT] [--url URL] [--set FIELD=VALUE] KEY...
# Mirrors GitHub events onto Jira cards. For each KEY:
#   - skips it unless its current status is one of --from (when given)
#   - walks it through the --to statuses in order (e.g. "Deployed,Released"), skipping ones already passed
#   - optionally sets one pipeline field and adds a comment
# Never fails the calling workflow: Jira problems become warnings, so a deploy is never marked red because of Jira.
# Exits 0 without doing anything when Jira credentials are not configured.
source "$(dirname "$0")/lib.sh"
set +e
here="$(dirname "$0")"

to=""; from=""; comment=""; url=""; setkv=""; keys=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) to="$2"; shift 2 ;;
    --from) from="$2"; shift 2 ;;
    --comment) comment="$2"; shift 2 ;;
    --url) url="$2"; shift 2 ;;
    --set) setkv="$2"; shift 2 ;;
    *) keys+=("$1"); shift ;;
  esac
done
[[ -n "$to" ]] || die "usage: sync-keys.sh --to \"Status\" [--from ...] KEY..."

if ! jira_configured; then echo "::notice::Jira credentials not configured; skipping Jira sync"; exit 0; fi
require_env
[[ ${#keys[@]} -gt 0 ]] || { echo "No Jira keys to sync"; exit 0; }

IFS=',' read -r -a targets <<<"$to"
IFS=',' read -r -a sources <<<"$from"
order=()
while IFS= read -r s; do order+=("$s"); done < <(jq -r '.jira.statuses[].name' "$PIPELINE_CONFIG")
idx() { local i; for i in "${!order[@]}"; do [[ "${order[$i]}" == "$1" ]] && { echo "$i"; return; }; done; echo -1; }

for key in "${keys[@]}"; do
  if ! [[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then warn "skipping invalid key '$key'"; continue; fi
  now="$(current_status "$key" 2>/dev/null)" || { warn "$key: not found or not readable in Jira"; continue; }
  if [[ ${#sources[@]} -gt 0 ]]; then
    ok=false; for s in "${sources[@]}"; do [[ "$now" == "$s" ]] && ok=true; done
    if ! $ok; then echo "$key: in '$now', not in [$from]; left as is"; continue; fi
  fi
  for t in "${targets[@]}"; do
    # skip targets the card has already passed (workflow order), so re-runs are harmless
    if [[ "$now" == "$t" ]] || { [[ "$now" != "$(status_name blocked)" ]] && (( $(idx "$now") > $(idx "$t") )); }; then continue; fi
    if "$here/transition.sh" "$key" "$t"; then now="$t"; else warn "$key: could not move from '$now' to '$t'"; break; fi
  done
  if [[ -n "$setkv" ]]; then "$here/set-field.sh" "$key" "${setkv%%=*}" "${setkv#*=}" || warn "$key: could not set ${setkv%%=*}"; fi
  if [[ -n "$comment" ]]; then "$here/comment.sh" "$key" "$comment" "$url" >/dev/null || warn "$key: could not comment"; fi
done
exit 0
