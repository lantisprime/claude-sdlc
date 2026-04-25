#!/usr/bin/env bash
# session-plan-check.sh — SessionStart hook. Surfaces in-flight SDLC work.
# Runs alongside env-detect.sh. Writes nothing. Blocks nothing. Exit 0 always.
set -euo pipefail

SDLC_DIR=".claude/sdlc"
PLANS="$SDLC_DIR/plans"
GATES="$SDLC_DIR/gates"
SIGNOFFS="$SDLC_DIR/sign-offs"
CONFIG="config/tools.json"

# Phase order — matches CLAUDE.md phase table. Update all three functions if phases change.
phase_order() {
  case "$1" in
    plan)    echo 1 ;;
    analyze) echo 2 ;;
    design)  echo 3 ;;
    build)   echo 4 ;;
    test)    echo 5 ;;
    deploy)  echo 6 ;;
    support) echo 7 ;;
    *)       echo 0 ;;
  esac
}

phase_command() {
  case "$1" in
    plan)    echo "/plan" ;;
    analyze) echo "/analyze" ;;
    design)  echo "/design" ;;
    build)   echo "/build" ;;
    test)    echo "/test" ;;
    deploy)  echo "/deploy" ;;
    support) echo "/support" ;;
    *)       echo "/plan" ;;
  esac
}

phase_for_order() {
  case "$1" in
    1) echo "plan" ;;
    2) echo "analyze" ;;
    3) echo "design" ;;
    4) echo "build" ;;
    5) echo "test" ;;
    6) echo "deploy" ;;
    7) echo "support" ;;
    *) echo "" ;;
  esac
}

# --- Helper: is a gate file signed? ---
is_signed() {
  grep -qE "^\- \*\*Signed at:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2}T" "$1" 2>/dev/null
}

# --- Helper: extract pending sign-off roles from a gate file ---
# Prints one role per line. Requires REQ-ID and sign-offs dir to exist for file check.
pending_roles_for_gate() {
  local gate_file="$1"
  local req_id
  req_id=$(grep -oE "REQ-[0-9]+" "$gate_file" 2>/dev/null | head -1 || true)

  while IFS= read -r role_line; do
    local role
    role=$(echo "$role_line" | sed 's/^[[:space:]]*-[[:space:]]*//')
    [ -z "$role" ] && continue
    if [ -n "$req_id" ] && [ -d "$SIGNOFFS" ]; then
      [ ! -f "$SIGNOFFS/${req_id}-${role}.md" ] && echo "$role"
    else
      echo "$role"
    fi
  done < <(awk '/^## Required sign-offs/{f=1;next} f && /^- /{print;next} f && /^##/{exit}' \
    "$gate_file" 2>/dev/null || true)
}

# --- Opt-out check for personalization hints ---
show_hints=true
if [ -f "$CONFIG" ]; then
  if grep -F '"session_signoff_hints"' "$CONFIG" 2>/dev/null | grep -q '"off"'; then
    show_hints=false
  fi
fi

# --- No plans directory or empty ---
if [ ! -d "$PLANS" ] || [ -z "$(ls -A "$PLANS" 2>/dev/null)" ]; then
  echo "[session] No active task. Run /start to begin."
  exit 0
fi

# --- Collect active plan slugs (exclude versioned files: *.v1.md, *.v2.md, etc.) ---
slug_count=0
slug_list=""
while IFS= read -r plan_file; do
  [ -f "$plan_file" ] || continue
  slug=$(basename "$plan_file" .md)
  slug_list="${slug_list}${slug} "
  slug_count=$((slug_count + 1))
done < <(find "$PLANS" -maxdepth 1 -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null | sort)

if [ "$slug_count" -eq 0 ]; then
  echo "[session] No active task. Run /start to begin."
  exit 0
fi

# --- Multiple active plans ---
if [ "$slug_count" -gt 1 ]; then
  slugs_display=$(echo "$slug_list" | sed 's/ $//' | tr ' ' ',')
  echo "[session] ${slug_count} active plans: ${slugs_display}. Run /status for detail."
  exit 0
fi

slug=$(echo "$slug_list" | tr -d ' ')

# --- Check plan gate ---
plan_gate="$GATES/plan-${slug}.md"
if [ ! -f "$plan_gate" ] || ! is_signed "$plan_gate"; then
  echo "[session] Plan '${slug}' drafted but not signed. Continue with /plan."
  exit 0
fi

# --- Scan downstream gates for this slug ---
# Track: highest unsigned gate, and highest signed gate with pending sign-offs.
best_unsigned_phase="" best_unsigned_num=0 best_unsigned_file=""
best_signoff_phase="" best_signoff_num=0 best_signoff_file=""
highest_signed_num=0

if [ -d "$GATES" ]; then
  while IFS= read -r gate_file; do
    [ -f "$gate_file" ] || continue
    base=$(basename "$gate_file" .md)
    # Skip scope gates and the plan gate itself
    case "$base" in scope-*|"plan-${slug}") continue ;; esac
    phase="${base%-${slug}}"
    num=$(phase_order "$phase")
    [ "$num" -gt 0 ] || continue

    if ! is_signed "$gate_file"; then
      if [ "$num" -gt "$best_unsigned_num" ]; then
        best_unsigned_num="$num"
        best_unsigned_phase="$phase"
        best_unsigned_file="$gate_file"
      fi
    else
      [ "$num" -gt "$highest_signed_num" ] && highest_signed_num="$num"
      # Check for pending sign-offs on this signed gate
      if grep -q "^## Required sign-offs" "$gate_file" 2>/dev/null; then
        pending=$(pending_roles_for_gate "$gate_file")
        if [ -n "$pending" ] && [ "$num" -gt "$best_signoff_num" ]; then
          best_signoff_num="$num"
          best_signoff_phase="$phase"
          best_signoff_file="$gate_file"
        fi
      fi
    fi
  done < <(find "$GATES" -maxdepth 1 -name "*-${slug}.md" 2>/dev/null)
fi

# --- State 4: sign-offs pending (blocks advancement; takes priority) ---
if [ -n "$best_signoff_file" ]; then
  pending=$(pending_roles_for_gate "$best_signoff_file")
  pending_csv=$(echo "$pending" | tr '\n' ',' | sed 's/,$//')

  # Personalization: match git user.email against historical signer: field
  if [ "$show_hints" = true ]; then
    user_email=$(git config user.email 2>/dev/null || true)
    if [ -n "$user_email" ] && [ -d "$SIGNOFFS" ]; then
      matched_role=""
      while IFS= read -r signoff_file; do
        [ -f "$signoff_file" ] || continue
        if grep -q "signer: ${user_email}" "$signoff_file" 2>/dev/null; then
          hist_role=$(grep "^role:" "$signoff_file" 2>/dev/null | sed 's/^role:[[:space:]]*//' | head -1 || true)
          [ -z "$hist_role" ] && continue
          # Only personalize when the historical role is actually pending on this gate
          if echo "$pending" | grep -qx "$hist_role"; then
            matched_role="$hist_role"
            break
          fi
        fi
      done < <(find "$SIGNOFFS" -maxdepth 1 -name "*.md" ! -path "*/.queue/*" 2>/dev/null)

      if [ -n "$matched_role" ]; then
        echo "[session] Likely awaiting your signature (${matched_role}) on ${slug} — based on past sign-offs."
        exit 0
      fi
    fi
  fi

  echo "[session] Sign-offs pending on ${slug}: ${pending_csv}. Run /status for detail."
  exit 0
fi

# --- State 3: highest unsigned downstream gate ---
if [ -n "$best_unsigned_file" ]; then
  cmd=$(phase_command "$best_unsigned_phase")
  echo "[session] Active: ${best_unsigned_phase}-${slug}. Next: ${cmd}."
  exit 0
fi

# --- All gates signed, no sign-offs pending: suggest next phase ---
next_num=$((highest_signed_num + 1))
next_phase=$(phase_for_order "$next_num")
if [ -n "$next_phase" ]; then
  cmd=$(phase_command "$next_phase")
  echo "[session] Plan '${slug}' through $(phase_for_order "$highest_signed_num"). Next: ${cmd}."
else
  echo "[session] Plan '${slug}' complete. Start a new task with /start."
fi

exit 0
