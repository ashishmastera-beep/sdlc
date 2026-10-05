#!/usr/bin/env bash
# has-source.sh
# Prints has_source=true when force-app contains deployable metadata, false otherwise.
# (A fresh repo has only placeholders, and deploying an empty directory fails.)
set -euo pipefail
root="$(dirname "$0")/../../force-app"
count="$(find "$root" -type f \
  ! -name '.gitkeep' ! -name '.eslintrc.json' ! -name 'jsconfig.json' \
  ! -path '*/__tests__/*' 2>/dev/null | wc -l | tr -d ' ')"
val=$([[ "$count" -gt 0 ]] && echo true || echo false)
echo "has_source=$val ($count files)"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "has_source=$val" >> "$GITHUB_OUTPUT"; fi
