#!/usr/bin/env bash
# skills/_shared/next-hint.sh
#
# Resolves next-step hints for user-facing skills. Called at the end of each
# skill's output by piping when|suggest pairs via stdin.
#
# Usage:
#   printf '%s\n' \
#     'when_condition|Suggest text shown to user' \
#     'another_condition|Another suggestion' \
#     | bash skills/_shared/next-hint.sh
#
# Prints "Next: <suggest>" for the first matching, unfaded condition.
# Prints nothing when suppressed, faded, or no condition matches.
#
# Suppressors (in order):
#   1. Non-TTY stdout (piped output, CI, scripts)
#   2. display.next_hints: "off" in config/tools.json
#   3. Fade-after-3: each distinct hint retires after 3 appearances (tracked in
#      .claude/sdlc/hints.jsonl)

set -euo pipefail

SDLC=".claude/sdlc"

# ── Suppressor 1: non-TTY ────────────────────────────────────────────────────
[ -t 1 ] || exit 0

# ── Suppressor 2: explicit opt-out ──────────────────────────────────────────
if [ -f "config/tools.json" ] && command -v python3 >/dev/null 2>&1; then
  if python3 -c "
import json, sys
try:
    d = json.load(open('config/tools.json'))
    sys.exit(0 if str(d.get('display', {}).get('next_hints', '')).lower() == 'off' else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
    exit 0
  fi
fi

# ── State helpers ─────────────────────────────────────────────────────────────

is_gate_signed() {
  # $1 = filename glob, e.g. "plan-*.md"
  local f
  f=$(find "$SDLC/gates" -maxdepth 1 -name "$1" 2>/dev/null | head -1)
  [ -n "$f" ] && grep -qE "^\- \*\*Signed at:\*\* [0-9]{4}" "$f" 2>/dev/null
}

active_gate_file() {
  find "$SDLC/gates" -maxdepth 1 -name "*.md" ! -name "scope-*.md" 2>/dev/null \
    | sort | tail -1
}

has_unsigned_plan() {
  find "$SDLC/plans" -maxdepth 1 -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null \
    | head -1 | grep -q .
}

all_signoffs_present() {
  local gate
  gate=$(active_gate_file)
  [ -z "$gate" ] && return 1
  grep -q "^## Required sign-offs" "$gate" 2>/dev/null || return 1
  local role pending=0
  while IFS= read -r role; do
    [ -z "$role" ] && continue
    if ! ls "$SDLC/sign-offs/"*"-${role}.md" 2>/dev/null | grep -q .; then
      pending=1
      break
    fi
  done < <(awk '/^## Required sign-offs/{f=1;next} f&&/^- /{gsub(/^- \*\*/,"");gsub(/\*\*.*/,"");print} f&&/^## /{exit}' "$gate" 2>/dev/null)
  [ "$pending" -eq 0 ]
}

pending_signoff_for_current_user() {
  local gate
  gate=$(active_gate_file)
  [ -z "$gate" ] && return 1
  grep -q "^## Required sign-offs" "$gate" 2>/dev/null || return 1
  local git_email user_role
  git_email=$(git config user.email 2>/dev/null || true)
  [ -z "$git_email" ] && return 1
  user_role=$(grep -rl "signer:.*$git_email" "$SDLC/sign-offs/" 2>/dev/null \
    | head -1 | sed 's/.*-\([^-]*\)\.md$/\1/' 2>/dev/null || true)
  [ -z "$user_role" ] && return 1
  ! ls "$SDLC/sign-offs/"*"-${user_role}.md" 2>/dev/null | grep -q .
}

phase_active_gate_unsigned() {
  local gate
  gate=$(active_gate_file)
  [ -z "$gate" ] && return 1
  ! grep -qE "^\- \*\*Signed at:\*\* [0-9]{4}" "$gate" 2>/dev/null
}

# ── Condition table ───────────────────────────────────────────────────────────

check_when() {
  case "$1" in
    no_active_work)
      ! has_unsigned_plan \
        && ! ls "$SDLC/gates/"*.md 2>/dev/null | grep -q . ;;
    plan_drafted_and_unsigned)
      has_unsigned_plan && ! is_gate_signed "plan-*.md" ;;
    plan_gate_signed)
      is_gate_signed "plan-*.md" ;;
    all_signoffs_present)
      all_signoffs_present ;;
    pending_signoff_for_current_user)
      pending_signoff_for_current_user ;;
    phase_active_gate_unsigned)
      phase_active_gate_unsigned ;;
    analyze_gate_signed)
      is_gate_signed "analyze-*.md" && ! is_gate_signed "design-*.md" ;;
    design_gate_signed)
      is_gate_signed "design-*.md" && ! is_gate_signed "build-*.md" ;;
    build_gate_signed)
      is_gate_signed "build-*.md" && ! is_gate_signed "test-*.md" ;;
    test_gate_signed)
      is_gate_signed "test-*.md" && ! is_gate_signed "deploy-*.md" ;;
    deploy_gate_signed)
      is_gate_signed "deploy-*.md" && ! is_gate_signed "support-*.md" ;;
    support_gate_signed)
      is_gate_signed "support-*.md" ;;
    always)
      true ;;
    *)
      false ;;
  esac
}

# ── Fade-after-3 ─────────────────────────────────────────────────────────────

HINTS_FILE="$SDLC/hints.jsonl"

hint_shown_count() {
  local key
  # Use first 50 chars of suggest as the key to avoid shell quoting issues
  key=$(printf '%s' "$1" | cut -c1-50)
  [ -f "$HINTS_FILE" ] \
    && grep -c "$key" "$HINTS_FILE" 2>/dev/null \
    || echo 0
}

record_hint() {
  mkdir -p "$SDLC"
  local escaped
  escaped=$(printf '%s' "$1" | sed 's/"/\\"/g')
  printf '{"hint":"%s","at":"%s"}\n' \
    "$escaped" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)" \
    >> "$HINTS_FILE"
}

# ── Main loop ────────────────────────────────────────────────────────────────

while IFS='|' read -r when suggest; do
  [ -z "$when" ] && continue
  if check_when "$when"; then
    count=$(hint_shown_count "$suggest")
    if [ "$count" -lt 3 ]; then
      printf '\nNext: %s\n' "$suggest"
      record_hint "$suggest"
    fi
    exit 0
  fi
done
