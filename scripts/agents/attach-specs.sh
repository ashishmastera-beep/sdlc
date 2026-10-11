#!/usr/bin/env bash
# attach-specs.sh KEY SPEC_DIR STATUS [SUBTITLE]
# Renders the spec documents listed in config/pipeline.json (agents.jiraAttachments) to PDF and attaches them
# to the Jira card as "<KEY>-<Title>.pdf", replacing earlier versions with the same name.
#   STATUS   shown as a badge on the first page, e.g. "Draft – pending review" or "Approved – spec 1a2b3c"
# Needs node + marked (agents.markedVersion), Chrome/Chromium, and the Jira environment for attach.sh.
set -euo pipefail
key="${1:?usage: attach-specs.sh KEY SPEC_DIR STATUS [SUBTITLE]}"; dir="${2:?}"; status="${3:?}"; subtitle="${4:-}"
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
out="$(mktemp -d)"; trap 'rm -rf "$out"' EXIT

files=()
while IFS=$'\t' read -r file title; do
  src="$dir/$file"
  if [[ ! -s "$src" ]]; then echo "::warning::$src not found; not attached"; continue; fi
  pdf="$out/${key}-${title// /-}.pdf"
  node "$here/render-pdf.mjs" "$src" "$pdf" --title "$key $title" --status "$status" --subtitle "$subtitle"
  files+=("$pdf")
done < <(jq -r '.agents.jiraAttachments[] | [.file, .title] | @tsv' "$root/config/pipeline.json")

(( ${#files[@]} )) || { echo "::warning::no spec documents to attach"; exit 0; }
bash "$root/scripts/jira/attach.sh" "$key" "${files[@]}"
