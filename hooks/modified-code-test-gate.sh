#!/usr/bin/env bash
# modified-code-test-gate.sh — Stop hook.
# Warns if modified functions don't have a corresponding test update in the same session.
set -euo pipefail
if [ -f ".claude/sdlc/.suspended" ]; then
  echo "[SDLC] Workflow suspended — modified-code-test check is paused." >&2
  exit 0
fi
[ -f ".claude/sdlc/.enabled" ] || exit 0

command -v git >/dev/null 2>&1 || exit 0
[ -d .git ] || exit 0

# Non-test files touched
SRC_CHANGED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
SRC_CHANGED=$(echo "$SRC_CHANGED" | sort -u \
  | grep -vE '(^|/)(test|tests|spec|__tests__)(/|s?\.)' \
  | grep -v '^\.claude/sdlc/' || true)

TEST_CHANGED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
TEST_CHANGED=$(echo "$TEST_CHANGED" | sort -u \
  | grep -E '(^|/)(test|tests|spec|__tests__)(/|s?\.)' || true)

if [ -n "$SRC_CHANGED" ] && [ -z "$TEST_CHANGED" ]; then
  echo "[test-gate] WARN: source files changed but no test files touched this session." >&2
  echo "[test-gate] The Build phase requires unit tests for modified functions. Add or update them." >&2
fi

exit 0
