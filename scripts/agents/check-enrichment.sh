#!/usr/bin/env bash
# check-enrichment.sh KEY
# Validates what the enrichment agent produced before anything is committed or written to Jira.
# Run from the repository root after the agent finishes. Exit 0 = valid; otherwise prints every problem.
set -uo pipefail
key="${1:-}"
[[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || { echo "error: invalid key '$key'" >&2; exit 2; }
dir="specs/$key"
problems=()
p() { problems+=("$*"); }

# 1. Only files under specs/<KEY>/ may change.
while IFS= read -r line; do
  path="${line:3}"; path="${path#\"}"; path="${path%\"}"
  [[ "$path" == *" -> "* ]] && path="${path##* -> }"
  [[ "$path" == "$dir/"* ]] || p "agent changed a file outside $dir/: $path"
done < <(git status --porcelain --untracked-files=all)

# 2. Required files exist and are not empty.
for f in functional.md technical.md test-plan.md implementation-log.md enrichment.md enrichment.json; do
  [[ -s "$dir/$f" ]] || p "missing or empty: $dir/$f"
done

# 3. enrichment.json shape.
if [[ -s "$dir/enrichment.json" ]]; then
  if ! jq -e . "$dir/enrichment.json" >/dev/null 2>&1; then
    p "enrichment.json is not valid JSON"
  else
    jq -e '.riskLevel | IN("Low","Medium","High")' "$dir/enrichment.json" >/dev/null || p "enrichment.json: riskLevel must be Low, Medium or High"
    jq -e '.blockingQuestions | type == "boolean"' "$dir/enrichment.json" >/dev/null || p "enrichment.json: blockingQuestions must be true or false"
    jq -e '.workType | type == "array" and length > 0' "$dir/enrichment.json" >/dev/null || p "enrichment.json: workType must be a non-empty list"
    jq -e '.summary | type == "string" and length > 0' "$dir/enrichment.json" >/dev/null || p "enrichment.json: summary is required"
  fi
fi

# 4. enrichment.md: required sections, size, no HTML.
if [[ -s "$dir/enrichment.md" ]]; then
  for h in "Business Context" "Scope" "Acceptance Criteria" "Technical Notes" "Open Questions"; do
    grep -Eq "^#{2,4} +$h *$" "$dir/enrichment.md" || p "enrichment.md: missing section '### $h'"
  done
  grep -Eq '^\* *AC[0-9]+' "$dir/enrichment.md" || p "enrichment.md: acceptance criteria must be listed as '* AC1: ...'"
  size="$(wc -c < "$dir/enrichment.md")"
  (( size <= 8000 )) || p "enrichment.md is ${size} characters; the limit is 8000"
  grep -Eiq '<(script|iframe|img|div|span|table)\b' "$dir/enrichment.md" && p "enrichment.md: HTML is not allowed"
fi

# 5. Specs are filled in, not left as template placeholders.
for f in functional.md technical.md test-plan.md; do
  [[ -s "$dir/$f" ]] || continue
  grep -q '<KEY>' "$dir/$f" && p "$f still contains the <KEY> placeholder"
  grep -Eq '^<(One or two sentences|Two or three sentences|Main scenario)' "$dir/$f" && p "$f still contains template placeholder text"
done
[[ -s "$dir/functional.md" ]] && ! grep -q 'AC1' "$dir/functional.md" && p "functional.md has no AC1"
[[ -s "$dir/test-plan.md" ]] && ! grep -q 'AC1' "$dir/test-plan.md" && p "test-plan.md does not map AC1 to a test"

# 6. No secrets.
if grep -rEq '(github_pat_|ghp_|gho_|ATATT|-----BEGIN [A-Z ]*PRIVATE KEY)' "$dir" 2>/dev/null; then
  p "a token or private key appears in $dir"
fi

if (( ${#problems[@]} )); then
  echo "Enrichment output for $key is not valid:"
  printf -- '- %s\n' "${problems[@]}"
  exit 1
fi
echo "Enrichment output for $key is valid."
