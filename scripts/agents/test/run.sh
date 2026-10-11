#!/usr/bin/env bash
# Offline tests for scripts/agents/check-enrichment.sh using a throwaway git repository.
# check_script is read inside check()'s eval strings.
# shellcheck disable=SC2034,SC2016
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; check_script="$here/../check-enrichment.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cd "$work" && git init -q && git config user.email t@t && git config user.name t
mkdir -p force-app && echo x > force-app/a.txt && git add -A && git commit -qm init
pass=0; fail=0
check() { if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

good() {
  rm -rf specs; mkdir -p specs/SDLC-9
  printf '# SDLC-9: x — Functional\n\n| AC1 | a | b | c |\n' > specs/SDLC-9/functional.md
  printf '# SDLC-9: x — Technical\n\nUses AccountService.\n' > specs/SDLC-9/technical.md
  printf '# SDLC-9: x — Test plan\n\n| T | m | AC1 | bulk |\n' > specs/SDLC-9/test-plan.md
  printf '# SDLC-9: implementation log\n\n- 2026-10-11 enrichment: spec written.\n' > specs/SDLC-9/implementation-log.md
  printf '_Generated._\n\n### Business Context\n\nx\n\n### Scope\n\n* In scope:\n    * y\n\n### Acceptance Criteria\n\n* AC1: Given a, when b, then c.\n\n### Technical Notes\n\nz\n\n### Open Questions\n\n* None.\n' > specs/SDLC-9/enrichment.md
  echo '{"workType":["Apex change"],"riskLevel":"Medium","blockingQuestions":false,"summary":"Adds a field."}' > specs/SDLC-9/enrichment.json
}

good;                                            check "valid output passes"            'bash "$check_script" SDLC-9'
good; echo y >> force-app/a.txt;                 check "edit outside specs fails"       '! bash "$check_script" SDLC-9'
git checkout -q force-app/a.txt
good; mkdir -p .github && echo x > .github/evil; check "new file outside specs fails"   '! bash "$check_script" SDLC-9'
rm -rf .github
good; rm specs/SDLC-9/technical.md;              check "missing file fails"             '! bash "$check_script" SDLC-9'
good; echo '{"workType":["x"],"riskLevel":"Huge","blockingQuestions":false,"summary":"s"}' > specs/SDLC-9/enrichment.json
                                                 check "bad risk level fails"           '! bash "$check_script" SDLC-9'
good; echo '{nope' > specs/SDLC-9/enrichment.json; check "invalid JSON fails"           '! bash "$check_script" SDLC-9'
good; sed -i '/Technical Notes/d' specs/SDLC-9/enrichment.md; check "missing section fails" '! bash "$check_script" SDLC-9'
good; echo 'token github_pat_ABC' >> specs/SDLC-9/technical.md; check "secret fails"     '! bash "$check_script" SDLC-9'
good; echo '<KEY>' >> specs/SDLC-9/technical.md; check "template placeholder fails"     '! bash "$check_script" SDLC-9'
good; head -c 9000 /dev/zero | tr '\0' a >> specs/SDLC-9/enrichment.md; check "oversize fails" '! bash "$check_script" SDLC-9'
check "bad key rejected"                         '! bash "$check_script" "../x"'

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
