#!/usr/bin/env bash
# Validates that artifact counts on disk match the machine-readable block in
# docs/references/_repo-context.md, and that all command files appear in README.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTEXT_FILE="$REPO_ROOT/docs/references/_repo-context.md"
README="$REPO_ROOT/README.md"
fail=0

echo "Validating docs sync..."

# ── Parse expected counts from _repo-context.md ──────────────────────────────

if [ ! -f "$CONTEXT_FILE" ]; then
  echo "FAIL _repo-context.md not found at $CONTEXT_FILE" >&2
  exit 1
fi

parse_count() {
  local key="$1"
  grep -o "${key}=[0-9]*" "$CONTEXT_FILE" | head -1 | cut -d= -f2
}

exp_skills=$(parse_count "skills")
exp_commands=$(parse_count "commands")
exp_hooks=$(parse_count "hooks")
exp_templates=$(parse_count "templates")
exp_agents=$(parse_count "agents")

if [ -z "$exp_skills" ] || [ -z "$exp_commands" ] || [ -z "$exp_hooks" ] || \
   [ -z "$exp_templates" ] || [ -z "$exp_agents" ]; then
  echo "FAIL _repo-context.md missing validate-counts block (expected skills=N commands=N hooks=N templates=N agents=N)" >&2
  exit 1
fi

# ── Count artifacts on disk ───────────────────────────────────────────────────

count_skills=$(find "$REPO_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
count_commands=$(find "$REPO_ROOT/commands" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
count_hooks=$(find "$REPO_ROOT/hooks" -maxdepth 1 -name "*.sh" | wc -l | tr -d ' ')
count_templates=$(find "$REPO_ROOT/templates" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
count_agents=$(find "$REPO_ROOT/agents" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')

# ── Compare ───────────────────────────────────────────────────────────────────

check() {
  local label="$1" disk="$2" expected="$3"
  if [ "$disk" -eq "$expected" ]; then
    echo "OK   $label: $disk"
  else
    echo "FAIL $label: disk=$disk expected=$expected — update _repo-context.md validate-counts block" >&2
    fail=1
  fi
}

check "skills"    "$count_skills"    "$exp_skills"
check "commands"  "$count_commands"  "$exp_commands"
check "hooks"     "$count_hooks"     "$exp_hooks"
check "templates" "$count_templates" "$exp_templates"
check "agents"    "$count_agents"    "$exp_agents"

# ── Check command files are listed in README.md ───────────────────────────────

if [ ! -f "$README" ]; then
  echo "WARN README.md not found — skipping command table check" >&2
else
  missing_in_readme=0
  while IFS= read -r cmd_file; do
    cmd_name=$(basename "$cmd_file" .md)
    if ! grep -q "/$cmd_name" "$README" 2>/dev/null; then
      echo "FAIL /$cmd_name not found in README.md command table" >&2
      missing_in_readme=1
    fi
  done < <(find "$REPO_ROOT/commands" -maxdepth 1 -name "*.md" | sort)

  if [ "$missing_in_readme" -eq 0 ]; then
    echo "OK   all commands listed in README.md"
  else
    fail=1
  fi
fi

exit "$fail"
