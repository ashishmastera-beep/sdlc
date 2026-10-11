#!/usr/bin/env bash
# retrieve-context.sh KEY ALIAS
# Gives the build agent read-only copies of existing org metadata the approved spec touches, so it edits the
# real thing instead of guessing (the repo does not hold every org component yet). Today: the page layouts of
# every object named in specs/KEY/technical.md, plus which layout each profile uses.
# Writes .pipeline-input/org/{layouts/,README.md}. Never fails the build: problems become warnings.
set -uo pipefail
key="${1:?usage: retrieve-context.sh KEY ALIAS}"; alias="${2:?}"
[[ "$key" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || { echo "invalid key" >&2; exit 2; }
tech="specs/$key/technical.md"
out=".pipeline-input/org"; mkdir -p "$out/layouts"
readme="$out/README.md"
printf '# Org context for %s (read-only)\n\nRetrieved from the org before the build. Copy what you change into force-app/; never edit files here.\n\n' "$key" > "$readme"

# Objects named in the spec: objects/<Obj>/ paths, layouts/<Obj>-..., and <Obj>.<Field>__c API names.
mapfile -t objects < <(
  { grep -oE 'objects/[A-Za-z0-9_]+/' "$tech" | cut -d/ -f2
    grep -oE 'layouts/[A-Za-z0-9_]+-' "$tech" | sed -E 's#layouts/##; s#-$##'
    grep -oE '\b[A-Z][A-Za-z0-9_]*\.[A-Za-z0-9_]+__c\b' "$tech" | cut -d. -f1
  } 2>/dev/null | sort -u)
if (( ${#objects[@]} == 0 )); then
  echo "No objects named in $tech; nothing to retrieve." | tee -a "$readme"; exit 0
fi
echo "Objects in the spec: ${objects[*]}"

layouts_json="$(sf org list metadata --metadata-type Layout --target-org "$alias" --json 2>/dev/null)" \
  || { echo "::warning::could not list layouts in the org"; echo "Layouts could not be listed." >> "$readme"; exit 0; }

printf '## Page layouts\n\n| Object | Layout | File |\n| --- | --- | --- |\n' >> "$readme"
# Org metadata names are URL-encoded ("Account-Account %28Sales%29 Layout"), which is also the source-format file
# name. The CLI usually wants that form; some versions want the decoded one, so both are tried.
decode() { python3 -I -c 'import sys, urllib.parse as u; print(u.unquote(sys.argv[1]))' "$1"; }
count=0
for obj in "${objects[@]}"; do
  mapfile -t names < <(jq -r --arg o "$obj-" '.result // [] | if type=="object" then [.] else . end
                         | .[] | .fullName | select(startswith($o))' <<<"$layouts_json" | sort | head -10)
  for encoded in "${names[@]}"; do
    name="$(decode "$encoded")"
    tmp="$(mktemp -d)"
    # Metadata-API format retrieve (zip, unzipped): the layout XML is the same as source format.
    res=""; ok=false
    for member in "$encoded" "$name"; do
      if res="$(sf project retrieve start --metadata "Layout:${member}" --target-org "$alias" \
                  --target-metadata-dir "$tmp" --unzip --json 2>&1)" \
         && [[ -n "$(find "$tmp" -name '*.layout' | head -1)" ]]; then ok=true; break; fi
      [[ "$encoded" == "$name" ]] && break
    done
    if $ok; then
      file="$(find "$tmp" -name '*.layout' | head -1)"
      if [[ -n "$file" ]]; then
        cp "$file" "$out/layouts/${encoded}.layout-meta.xml"
        printf '| %s | %s | `layouts/%s.layout-meta.xml` |\n' "$obj" "$name" "$encoded" >> "$readme"
        count=$((count + 1))
      else
        echo "::warning::layout '$name' retrieved but no file found"
      fi
    else
      msg="$(jq -r '.message // empty' <<<"$res" 2>/dev/null)"
      echo "::warning::could not retrieve layout '$name': ${msg:-${res:0:300}}"
    fi
    rm -rf "$tmp"
  done
done
echo "Retrieved $count layout(s)."

# Which layout each profile sees (best effort; needs the Tooling API).
printf '\n## Layout assignments (profile -> layout)\n\n' >> "$readme"
for obj in "${objects[@]}"; do
  q="SELECT Profile.Name, Layout.Name FROM ProfileLayout WHERE TableEnumOrId = '${obj}' AND RecordTypeId = null ORDER BY Layout.Name"
  if res="$(sf data query --use-tooling-api --query "$q" --target-org "$alias" --json 2>/dev/null)"; then
    jq -r --arg o "$obj" '.result.records // [] | group_by(.Layout.Name)[]
      | "- \($o): **\(.[0].Layout.Name)** used by \(map(.Profile.Name) | join(", "))"' <<<"$res" >> "$readme"
  else
    echo "- $obj: assignments unavailable" >> "$readme"
  fi
done
cat "$readme"
