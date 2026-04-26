#!/usr/bin/env bash
# Validates that every SKILL.md and agent .md has required frontmatter fields.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

check_file() {
  local file="$1" label="$2"
  if ! grep -q '^name:' "$file"; then
    echo "FAIL [$label] missing 'name:' in frontmatter — $file" >&2
    fail=1
  fi
  if ! grep -q '^description:' "$file"; then
    echo "FAIL [$label] missing 'description:' in frontmatter — $file" >&2
    fail=1
  fi
}

echo "Validating skill frontmatter..."
while IFS= read -r -d '' f; do
  check_file "$f" "skill"
done < <(find "$REPO_ROOT/skills" -name "SKILL.md" -print0)

echo "Validating agent frontmatter..."
while IFS= read -r -d '' f; do
  check_file "$f" "agent"
done < <(find "$REPO_ROOT/agents" -name "*.md" -print0)

if [ "$fail" -eq 0 ]; then
  skill_count=$(find "$REPO_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
  agent_count=$(find "$REPO_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
  echo "OK — $skill_count skills, $agent_count agents all have name + description"
fi

exit "$fail"
