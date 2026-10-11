#!/usr/bin/env bash
# check-build.sh KEY
# Local checks on what the build agent produced, before anything is committed or sent to the org.
# Run from the repository root (working tree = agent output on top of the base commit).
# Exit 0 = valid; otherwise prints every problem (this text is fed back to the agent).
set -uo pipefail
key="${1:-}"
[[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || { echo "error: invalid key '$key'" >&2; exit 2; }
spec="specs/$key"; log="$spec/implementation-log.md"
problems=()
p() { problems+=("$*"); }

# 1. Only allowed paths changed.
changed=()
while IFS= read -r line; do
  path="${line:3}"; path="${path#\"}"; path="${path%\"}"
  [[ "$path" == *" -> "* ]] && path="${path##* -> }"
  changed+=("$path")
  case "$path" in
    force-app/main/default/profiles/*) p "profiles must not be changed (grant access with a permission set): $path" ;;
    force-app/*|"$log") ;;
    *) p "file outside the allowed paths was changed: $path (only force-app/ and $log may change)" ;;
  esac
done < <(git status --porcelain --untracked-files=all)

app_changes=0
for f in "${changed[@]}"; do [[ "$f" == force-app/* ]] && app_changes=$((app_changes + 1)); done
(( app_changes > 0 )) || p "no metadata was created or changed under force-app/"

# 2. Implementation log: append-only, with a Build entry.
if git cat-file -e "HEAD:$log" 2>/dev/null; then
  before="$(git show "HEAD:$log")"
  now="$(cat "$log" 2>/dev/null)"
  [[ "$now" == "$before"* ]] || p "$log was edited above the end; only append a new row"
  [[ "${now#"$before"}" == *"| Build |"* ]] || p "$log needs one new row: | <date> | Build | Agent 2 | <entry> | build PR |"
else
  p "$log is missing from the approved spec"
fi

# 3. Every changed XML file is well formed; every Apex class has its -meta.xml.
for f in "${changed[@]}"; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.xml)
      python3 -I -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$f" 2>/dev/null || p "not well-formed XML: $f" ;;
    *.cls|*.trigger)
      [[ -f "$f-meta.xml" ]] || p "missing $f-meta.xml" ;;
  esac
done

# 4. Apex changes come with tests; no hard-coded record IDs.
code_changed=0; tests_changed=0
for f in "${changed[@]}"; do
  [[ -f "$f" && ( "$f" == *.cls || "$f" == *.trigger ) ]] || continue
  if grep -qi '@IsTest' "$f"; then tests_changed=$((tests_changed + 1)); else code_changed=$((code_changed + 1)); fi
  grep -Eq "'(001|003|005|006|00Q|00D|500|012)[A-Za-z0-9]{12}([A-Za-z0-9]{3})?'" "$f" && p "hard-coded record ID in $f"
done
(( code_changed == 0 || tests_changed > 0 )) || p "Apex code changed but no @IsTest class was added or changed"

# 5. Layouts copied from the org keep everything they had.
for f in "${changed[@]}"; do
  [[ "$f" == force-app/main/default/layouts/*.layout-meta.xml && -f "$f" ]] || continue
  orig=".pipeline-input/org/layouts/$(basename "$f")"
  [[ -f "$orig" ]] || continue
  missing="$(python3 -I - "$orig" "$f" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"m": "http://soap.sforce.com/2006/04/metadata"}
def fields(p):
    return {e.text for e in ET.parse(p).getroot().iter("{%s}field" % ns["m"])}
print(" ".join(sorted(fields(sys.argv[1]) - fields(sys.argv[2]))))
PY
)"
  [[ -z "$missing" ]] || p "layout $f dropped fields that are in the org version: $missing"
done

# 6. PR description maps every acceptance criterion.
pr=".pipeline-output/pr.md"
if [[ ! -s "$pr" ]]; then
  p "missing $pr (the pull request description)"
else
  grep -q '^## Acceptance criteria' "$pr" || p "$pr needs an '## Acceptance criteria' table"
  for ac in $(grep -oE '\bAC[0-9]+\b' "$spec/functional.md" 2>/dev/null | sort -uV); do
    grep -q "\b$ac\b" "$pr" || p "$pr does not cover $ac"
  done
fi

# 7. No secrets.
for f in "${changed[@]}" "$pr"; do
  [[ -f "$f" ]] || continue
  grep -Eq '(github_pat_|ghp_|gho_|ATATT|-----BEGIN [A-Z ]*PRIVATE KEY|00D[A-Za-z0-9]{12}![A-Za-z0-9_.]{20,})' "$f" \
    && p "a token, session id or private key appears in $f"
done

if (( ${#problems[@]} )); then
  echo "Build output for $key is not valid:"
  printf -- '- %s\n' "${problems[@]}"
  exit 1
fi
echo "Build output for $key passes the local checks (${app_changes} metadata file(s) changed)."
