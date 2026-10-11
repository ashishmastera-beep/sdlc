#!/usr/bin/env bash
# Offline tests for scripts/agents/check-enrichment.sh using a throwaway git repository.
# check_script is read inside check()'s eval strings.
# shellcheck disable=SC2034,SC2016
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; check_script="$here/../check-enrichment.sh"; build_check="$here/../check-build.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cd "$work" && git init -q && git config user.email t@t && git config user.name t
mkdir -p force-app && echo x > force-app/a.txt && git add -A && git commit -qm init
pass=0; fail=0
check() { if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

good() {
  rm -rf specs; mkdir -p specs/SDLC-9
  printf '# SDLC-9: x — Research\n\nFound AccountService.\n' > specs/SDLC-9/research.md
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
good; rm specs/SDLC-9/research.md;               check "missing research fails"         '! bash "$check_script" SDLC-9'
good; echo '{"workType":["x"],"riskLevel":"Huge","blockingQuestions":false,"summary":"s"}' > specs/SDLC-9/enrichment.json
                                                 check "bad risk level fails"           '! bash "$check_script" SDLC-9'
good; echo '{nope' > specs/SDLC-9/enrichment.json; check "invalid JSON fails"           '! bash "$check_script" SDLC-9'
good; sed -i '/Technical Notes/d' specs/SDLC-9/enrichment.md; check "missing section fails" '! bash "$check_script" SDLC-9'
good; echo 'token github_pat_ABC' >> specs/SDLC-9/technical.md; check "secret fails"     '! bash "$check_script" SDLC-9'
good; echo '<KEY>' >> specs/SDLC-9/technical.md; check "template placeholder fails"     '! bash "$check_script" SDLC-9'
good; head -c 9000 /dev/zero | tr '\0' a >> specs/SDLC-9/enrichment.md; check "oversize fails" '! bash "$check_script" SDLC-9'
check "bad key rejected"                         '! bash "$check_script" "../x"'

# --- check-build.sh ---
rm -rf specs .github; git checkout -q -- . 2>/dev/null; git clean -qfd
mkdir -p specs/SDLC-9 && printf '| AC1 |\n| AC2 |\n' > specs/SDLC-9/functional.md
printf '| Date | Stage |\n| --- | --- |\n| d | Enrichment |\n' > specs/SDLC-9/implementation-log.md
mkdir -p force-app/main/default/layouts && cat > force-app/main/default/layouts/.keep <<<''
git add -A && git commit -qm spec
printf '.pipeline-input/\n.pipeline-output/\n' >> .git/info/exclude
L='<?xml version="1.0" encoding="UTF-8"?><Layout xmlns="http://soap.sforce.com/2006/04/metadata"><layoutSections><layoutColumns><layoutItems><field>Name</field></layoutItems><layoutItems><field>Phone</field></layoutItems></layoutColumns></layoutSections></Layout>'
built() {
  git checkout -q -- . ; git clean -qfd -e .pipeline-input
  mkdir -p force-app/main/default/objects/Account/fields .pipeline-output .pipeline-input/org/layouts
  echo '<?xml version="1.0" encoding="UTF-8"?><CustomField xmlns="http://soap.sforce.com/2006/04/metadata"><fullName>X__c</fullName></CustomField>' \
    > force-app/main/default/objects/Account/fields/X__c.field-meta.xml
  echo '| 2026-10-11 | Build | Agent 2 | built | build PR |' >> specs/SDLC-9/implementation-log.md
  printf '## Acceptance criteria\n| AC1 | x | t |\n| AC2 | y | t |\n' > .pipeline-output/pr.md
  echo "$L" > .pipeline-input/org/layouts/Account-Account\ Layout.layout-meta.xml
}
built;                                                  check "build: valid output passes"        'bash "$build_check" SDLC-9'
built; echo x > README.md;                              check "build: file outside paths fails"   '! bash "$build_check" SDLC-9'
built; mkdir -p force-app/main/default/profiles; echo '<a/>' > force-app/main/default/profiles/Admin.profile-meta.xml
                                                        check "build: profile change fails"       '! bash "$build_check" SDLC-9'
built; echo '| x | y |' > specs/SDLC-9/functional.md;   check "build: spec edit fails"            '! bash "$build_check" SDLC-9'
built; sed -i '3d' specs/SDLC-9/implementation-log.md;  check "build: log rewrite fails"          '! bash "$build_check" SDLC-9'
built; echo '<CustomField><broken>' > force-app/main/default/objects/Account/fields/X__c.field-meta.xml
                                                        check "build: bad XML fails"              '! bash "$build_check" SDLC-9'
built; mkdir -p force-app/main/default/classes; printf 'public class Svc {}' > force-app/main/default/classes/Svc.cls; echo '<a/>' > force-app/main/default/classes/Svc.cls-meta.xml
                                                        check "build: Apex without test fails"    '! bash "$build_check" SDLC-9'
printf '@IsTest private class SvcTest {}' > force-app/main/default/classes/SvcTest.cls; echo '<a/>' > force-app/main/default/classes/SvcTest.cls-meta.xml
                                                        check "build: Apex with test passes"      'bash "$build_check" SDLC-9'
built; mkdir -p force-app/main/default/classes; printf "@IsTest class T { Id a = '001000000000001AAA'; }" > force-app/main/default/classes/T.cls; echo '<a/>' > force-app/main/default/classes/T.cls-meta.xml
                                                        check "build: hard-coded Id fails"        '! bash "$build_check" SDLC-9'
built; sed -i '/AC2/d' .pipeline-output/pr.md;          check "build: PR missing AC2 fails"       '! bash "$build_check" SDLC-9'
built; echo "${L/<field>Phone<\/field>/}" > "force-app/main/default/layouts/Account-Account Layout.layout-meta.xml"
                                                        check "build: layout dropping a field fails" '! bash "$build_check" SDLC-9'
built; echo "${L/<field>Phone<\/field>/<field>Phone<\/field></layoutItems><layoutItems><field>X__c<\/field>}" > "force-app/main/default/layouts/Account-Account Layout.layout-meta.xml"
                                                        check "build: layout adding a field passes" 'bash "$build_check" SDLC-9'
built; rm -rf force-app/main/default/objects;           check "build: no metadata fails"          '! bash "$build_check" SDLC-9'

echo; echo "$pass passed, $fail failed"; [[ $fail -eq 0 ]]
