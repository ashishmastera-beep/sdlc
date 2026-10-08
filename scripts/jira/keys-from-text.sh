#!/usr/bin/env bash
# keys-from-text.sh < text
# Prints the unique Jira keys of this project (config .jira.projectKey) found in stdin, one per line.
# Used to find which cards a merge or a release touched, from commit messages and PR titles.
set -euo pipefail
cfg="$(dirname "$0")/../../config/pipeline.json"
project="$(jq -er '.jira.projectKey' "$cfg")"
grep -oE "\\b${project}-[0-9]+\\b" | sort -u -t- -k2,2n || true
