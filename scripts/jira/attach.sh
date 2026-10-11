#!/usr/bin/env bash
# attach.sh KEY FILE...
# Attaches files to the issue. An existing attachment with the same file name is replaced (deleted first),
# so re-running enrichment or approval never piles up duplicate versions.
source "$(dirname "$0")/lib.sh"
require_env; key="${1:-}"; require_key "$key"; shift
(( $# )) || die "usage: attach.sh KEY FILE..."

existing="$(jira_api GET "/rest/api/3/issue/${key}?fields=attachment" | jq -c '[.fields.attachment[]? | {id, filename}]')"

for file in "$@"; do
  [[ -f "$file" ]] || die "no such file: $file"
  name="$(basename "$file")"
  size="$(wc -c < "$file")"
  (( size <= 10485760 )) || die "$name is larger than 10 MB"
  while IFS= read -r id; do
    [[ -n "$id" ]] && jira_api DELETE "/rest/api/3/attachment/${id}" >/dev/null && echo "$key: replaced old $name"
  done < <(jq -r --arg n "$name" '.[] | select(.filename == $n) | .id' <<<"$existing")

  tmp="$(mktemp)"
  code="$(curl -sS -X POST -u "${JIRA_USER}:${JIRA_API_TOKEN}" \
    -H "X-Atlassian-Token: no-check" -H "Accept: application/json" \
    --retry 3 --retry-delay 2 --retry-all-errors --max-time 120 \
    -F "file=@${file};filename=${name}" -o "$tmp" -w "%{http_code}" \
    "${JIRA_BASE_URL%/}/rest/api/3/issue/${key}/attachments")" || { rm -f "$tmp"; die "upload failed: $name"; }
  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    body="$(cat "$tmp")"; rm -f "$tmp"; die "upload of $name returned HTTP $code: ${body:0:300}"
  fi
  rm -f "$tmp"
  echo "$key: attached $name"
done
