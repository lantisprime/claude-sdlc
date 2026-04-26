#!/usr/bin/env bash
# Validates that every template has at least one markdown heading.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

echo "Validating template structure..."
while IFS= read -r -d '' f; do
  name=$(basename "$f")
  if ! grep -qE '^#{1,6} ' "$f"; then
    echo "FAIL [template] no heading found — $f" >&2
    fail=1
  else
    echo "OK   $name"
  fi
done < <(find "$REPO_ROOT/templates" -name "*.md" -print0)

exit "$fail"
