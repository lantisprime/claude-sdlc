#!/usr/bin/env bash
# approval-reconcile.sh — Stop hook.
# For every gate file that has a ## Required sign-offs block, checks that a
# sign-off file exists in .claude/sdlc/sign-offs/ for each required role.
# Also warns when a sign-off's gate_hash no longer matches the current gate content.
# Always exits 0 (warn, never block — per RFC §3.3).

set -euo pipefail

GATES_DIR=".claude/sdlc/gates"
SIGNOFFS_DIR=".claude/sdlc/sign-offs"

[ -d "$GATES_DIR" ] || exit 0

# Compute sha256 of gate content ABOVE the ## Required sign-offs heading.
# If the heading is absent, hash the whole file.
gate_hash() {
  local gate_file="$1"
  awk '/^## Required sign-offs/{exit} {print}' "$gate_file" \
    | shasum -a 256 2>/dev/null | awk '{print $1}' \
    || sha256sum "$gate_file" | awk '{print $1}'
}

# Parse a frontmatter field value from a markdown file.
# Usage: frontmatter_field <file> <field>
frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { if (++fence == 2) exit }
    fence == 1 && $0 ~ "^" f ":" { sub("^" f ":[ \t]*", ""); print; exit }
  ' "$file"
}

# Parse ## Required sign-offs roles from a gate file.
# Returns one role per line; empty if section is absent.
required_roles() {
  local gate_file="$1"
  awk '
    /^## Required sign-offs/ { in_section=1; next }
    in_section && /^## /     { exit }
    in_section && /^- /      { sub(/^- /, ""); print }
  ' "$gate_file"
}

found_warnings=0

while IFS= read -r -d '' gate_file; do
  roles=$(required_roles "$gate_file")
  [ -z "$roles" ] && continue

  gate_name=$(basename "$gate_file" .md)
  current_hash=$(gate_hash "$gate_file")
  header_printed=0

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
    hash_mismatch=0

    if [ -d "$SIGNOFFS_DIR" ]; then
      while IFS= read -r -d '' sf; do
        sf_gate_ref=$(frontmatter_field "$sf" "gate_ref")
        sf_role=$(frontmatter_field "$sf" "role")

        # Normalise gate_ref: strip leading ./ for comparison
        sf_gate_ref="${sf_gate_ref#./}"
        gate_file_norm="${gate_file#./}"

        if [ "$sf_role" = "$role" ] && [ "$sf_gate_ref" = "$gate_file_norm" ]; then
          matched_file="$sf"
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
      print_header
      echo "  ✗ missing sign-off: $role" >&2
    elif [ "$hash_mismatch" -eq 1 ]; then
      print_header
      echo "  ⚠ gate content changed since $role signed — $(basename "$matched_file")" >&2
    fi
  done <<< "$roles"

  if [ "$header_printed" -eq 1 ]; then
    echo "  Sign-off template: templates/sign-off-multi.md → $SIGNOFFS_DIR/<REQ-ID>-<role>.md" >&2
  fi

done < <(find "$GATES_DIR" -name "*.md" -print0 2>/dev/null)

exit 0
