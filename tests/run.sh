#!/usr/bin/env bash
# Test runner for claude-sdlc. Runs structural validators + bats hook tests.
# Usage:
#   tests/run.sh              — unit tests only (no @integration)
#   tests/run.sh --integration — include @integration tests
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
integration=false
[[ "${1:-}" == "--integration" ]] && integration=true

fail=0
pass=0

separator() { printf '%0.s─' {1..60}; echo; }

# --- Structural validators ---
separator
echo "STRUCTURAL VALIDATORS"
separator

for script in \
  "$TESTS_DIR/plugin/validate_manifest.sh" \
  "$TESTS_DIR/skills/validate_frontmatter.sh" \
  "$TESTS_DIR/templates/validate_structure.sh"
do
  chmod +x "$script"
  if bash "$script"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
  echo
done

# --- Bats hook tests ---
separator
echo "HOOK TESTS (bats)"
separator

if ! command -v bats >/dev/null 2>&1; then
  echo "WARN: bats not found — skipping hook tests."
  echo "Install with: brew install bats-core  OR  npm install -g bats"
else
  bats_files=()
  while IFS= read -r -d '' f; do
    # Skip @integration files unless --integration flag is set
    if [[ "$integration" == false ]] && grep -q '@integration' "$f" 2>/dev/null; then
      echo "SKIP (integration) $(basename "$f")"
      continue
    fi
    bats_files+=("$f")
  done < <(find "$TESTS_DIR/hooks" -name "*.bats" -print0 | sort -z)

  if [ "${#bats_files[@]}" -gt 0 ]; then
    if bats "${bats_files[@]}"; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
    fi
  fi
fi

# --- Summary ---
separator
total=$((pass + fail))
echo "Results: $pass/$total suites passed"
separator

exit "$fail"
