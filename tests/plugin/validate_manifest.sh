#!/usr/bin/env bash
# Validates .claude-plugin/plugin.json: valid JSON and required fields present.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"
fail=0

echo "Validating plugin manifest..."

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL plugin.json not found at $MANIFEST" >&2
  exit 1
fi

# Valid JSON check
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null; then
    echo "FAIL plugin.json is not valid JSON" >&2
    fail=1
  else
    echo "OK   valid JSON"
  fi
elif command -v node >/dev/null 2>&1; then
  if ! node -e "JSON.parse(require('fs').readFileSync('$MANIFEST','utf8'))" 2>/dev/null; then
    echo "FAIL plugin.json is not valid JSON" >&2
    fail=1
  else
    echo "OK   valid JSON"
  fi
else
  echo "WARN no JSON parser available (python3 or node required)" >&2
fi

# Required fields
for field in name version description; do
  if ! grep -q "\"$field\"" "$MANIFEST"; then
    echo "FAIL plugin.json missing required field: $field" >&2
    fail=1
  else
    echo "OK   field: $field"
  fi
done

# Version format: semver-like (N.N.N)
version=$(grep '"version"' "$MANIFEST" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "FAIL plugin.json version '$version' is not a valid semver (N.N.N)" >&2
  fail=1
else
  echo "OK   version: $version"
fi

exit "$fail"
