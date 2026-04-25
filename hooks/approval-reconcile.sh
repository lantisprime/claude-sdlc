#!/usr/bin/env bash
# approval-reconcile.sh — Stop hook.
# For every gate file that has a ## Required sign-offs block, checks that a
# sign-off file exists in .claude/sdlc/sign-offs/ for each required role.
# Also warns when a sign-off's gate_hash no longer matches the current gate content.
# Regenerates APPROVALS.md at the git root when the sign-offs directory is newer.
# Always exits 0 (warn, never block — per RFC §3.3).

set -euo pipefail

GATES_DIR=".claude/sdlc/gates"
SIGNOFFS_DIR=".claude/sdlc/sign-offs"

[ -d "$GATES_DIR" ] || exit 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Compute sha256 of gate content ABOVE the ## Required sign-offs heading.
gate_hash() {
  local gate_file="$1"
  awk '/^## Required sign-offs/{exit} {print}' "$gate_file" \
    | shasum -a 256 2>/dev/null | awk '{print $1}' \
    || sha256sum "$gate_file" | awk '{print $1}'
}

# Parse a frontmatter field value from a markdown file.
frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { if (++fence == 2) exit }
    fence == 1 && $0 ~ "^" f ":" { sub("^" f ":[ \t]*", ""); print; exit }
  ' "$file"
}

# Parse ## Required sign-offs roles from a gate file (one per line).
required_roles() {
  local gate_file="$1"
  awk '
    /^## Required sign-offs/ { in_section=1; next }
    in_section && /^## /     { exit }
    in_section && /^- /      { sub(/^- /, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }
  ' "$gate_file"
}

# Portable directory mtime as Unix epoch (macOS + Linux).
dir_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

# Locate git root (APPROVALS.md lives there). Skip generation outside git.
GIT_ROOT=""
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  GIT_ROOT=$(git rev-parse --show-toplevel)
fi
APPROVALS_FILE="${GIT_ROOT:+$GIT_ROOT/APPROVALS.md}"

# Temp files for APPROVALS.md sections (cleaned up on exit).
OPEN_TMP=$(mktemp)
CLOSED_TMP=$(mktemp)
trap 'rm -f "$OPEN_TMP" "$CLOSED_TMP"' EXIT

FOUND_GATES=0
NEEDS_REGEN=0
found_warnings=0

# ---------------------------------------------------------------------------
# Step 1: check for leftover merge markers in existing APPROVALS.md
# ---------------------------------------------------------------------------

if [ -n "$APPROVALS_FILE" ] && [ -f "$APPROVALS_FILE" ]; then
  if grep -qE '^(<{7}|={7}|>{7})' "$APPROVALS_FILE" 2>/dev/null; then
    echo "[approval-reconcile] APPROVALS.md has leftover merge markers — will regenerate" >&2
    NEEDS_REGEN=1
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: main reconciliation loop
# ---------------------------------------------------------------------------

while IFS= read -r -d '' gate_file; do
  roles=$(required_roles "$gate_file")
  [ -z "$roles" ] && continue

  FOUND_GATES=1
  gate_name=$(basename "$gate_file" .md)
  current_hash=$(gate_hash "$gate_file")
  header_printed=0
  all_signed=1
  missing_role_list=""
  entry_lines=""

  print_header() {
    if [ "$header_printed" -eq 0 ]; then
      echo "[approval-reconcile] Gate: $gate_name" >&2
      header_printed=1
      found_warnings=1
    fi
  }

  while IFS= read -r role; do
    [ -z "$role" ] && continue

    matched_file=""
    matched_signer=""
    matched_date=""
    hash_mismatch=0

    if [ -d "$SIGNOFFS_DIR" ]; then
      while IFS= read -r -d '' sf; do
        sf_gate_ref=$(frontmatter_field "$sf" "gate_ref")
        sf_role=$(frontmatter_field "$sf" "role")
        sf_gate_ref="${sf_gate_ref#./}"
        gate_file_norm="${gate_file#./}"

        if [ "$sf_role" = "$role" ] && [ "$sf_gate_ref" = "$gate_file_norm" ]; then
          matched_file="$sf"
          matched_signer=$(frontmatter_field "$sf" "signer")
          matched_date=$(frontmatter_field "$sf" "timestamp" | cut -c1-10)
          sf_hash=$(frontmatter_field "$sf" "gate_hash")
          sf_hash="${sf_hash#sha256:}"
          if [ -n "$sf_hash" ] && [ "$sf_hash" != "$current_hash" ]; then
            hash_mismatch=1
          fi
          break
        fi
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
    fi

    if [ -z "$matched_file" ]; then
      all_signed=0
      missing_role_list="${missing_role_list}${missing_role_list:+, }$role"
      entry_lines="${entry_lines}  - [ ] $role — (pending)\n"
    else
      entry_lines="${entry_lines}  - [x] $role — $matched_signer — $matched_date\n"
      if [ "$hash_mismatch" -eq 1 ]; then
        print_header
        echo "  ⚠ gate content changed since $role signed — $(basename "$matched_file")" >&2
      fi
    fi
  done <<< "$roles"

  # Stderr warnings for missing roles
  if [ -n "$missing_role_list" ]; then
    print_header
    # shellcheck disable=SC2086
    for r in ${missing_role_list//,/ }; do
      [ -z "$r" ] && continue
      echo "  ✗ missing sign-off: $r" >&2
    done
  fi

  if [ "$header_printed" -eq 1 ]; then
    echo "  Sign-off template: templates/sign-off-multi.md → $SIGNOFFS_DIR/<REQ-ID>-<role>.md" >&2
  fi

  # Collect into APPROVALS.md sections
  if [ "$all_signed" -eq 1 ]; then
    {
      echo "- $gate_name — all sign-offs received"
      printf "%b" "$entry_lines"
    } >> "$CLOSED_TMP"
  else
    {
      echo "- $gate_name — waiting on: $missing_role_list"
      printf "%b" "$entry_lines"
    } >> "$OPEN_TMP"
  fi

done < <(find "$GATES_DIR" -name "*.md" -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Step 3: orphan sign-off detection
# ---------------------------------------------------------------------------

if [ -d "$SIGNOFFS_DIR" ]; then
  while IFS= read -r -d '' sf; do
    sf_gate_ref=$(frontmatter_field "$sf" "gate_ref")
    [ -z "$sf_gate_ref" ] && continue
    sf_gate_ref="${sf_gate_ref#./}"
    if [ ! -f "$sf_gate_ref" ]; then
      echo "[approval-reconcile] Orphan sign-off: $(basename "$sf") — gate_ref '$sf_gate_ref' not found" >&2
      found_warnings=1
    fi
  done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Step 4: APPROVALS.md mtime check + generation
# ---------------------------------------------------------------------------

[ "$FOUND_GATES" -eq 0 ] && exit 0
[ -z "$GIT_ROOT" ]        && exit 0

# Compare sign-offs dir mtime against the epoch embedded in APPROVALS.md.
if [ "$NEEDS_REGEN" -eq 0 ]; then
  signoffs_mtime=$(dir_mtime "$SIGNOFFS_DIR")
  if [ -f "$APPROVALS_FILE" ]; then
    stored_epoch=$(grep -m1 '<!-- generated-epoch:' "$APPROVALS_FILE" \
                   | grep -o '[0-9][0-9]*' | head -1 || echo 0)
    stored_epoch="${stored_epoch:-0}"
    if [ "$signoffs_mtime" -gt "$stored_epoch" ]; then
      NEEDS_REGEN=1
    fi
  else
    NEEDS_REGEN=1
  fi
fi

if [ "$NEEDS_REGEN" -eq 1 ]; then
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NOW_EPOCH=$(date +%s)

  {
    echo "# Approvals"
    echo ""
    echo "> Generated from \`.claude/sdlc/sign-offs/\` by \`approval-reconcile.sh\`. Do not edit by hand."
    echo "> Last generated: $NOW_ISO"
    echo ">"
    echo "> **On git merge conflict:** accept either side. The reconciler regenerates from"
    echo "> \`sign-offs/\` on its next run and warns if it detects leftover merge markers."
    echo ""
    echo "<!-- generated-epoch: $NOW_EPOCH -->"
    echo ""
    echo "## Open"
    echo ""
    if [ -s "$OPEN_TMP" ]; then
      cat "$OPEN_TMP"
    else
      echo "*(none)*"
    fi
    echo ""
    echo "## Closed"
    echo ""
    if [ -s "$CLOSED_TMP" ]; then
      cat "$CLOSED_TMP"
    else
      echo "*(none)*"
    fi
  } > "$APPROVALS_FILE"

  echo "[approval-reconcile] APPROVALS.md regenerated at $APPROVALS_FILE" >&2
fi

exit 0
