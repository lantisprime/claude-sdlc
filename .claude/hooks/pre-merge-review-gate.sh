#!/usr/bin/env bash
# pre-merge-review-gate.sh — Stop hook for maintainer pre-merge review gate.
# Per RFC-004 + sdlc-plugin/AGENT-RULES.md §14.
# Maintainer-only — installed in .claude/hooks/, not shipped to consuming repos.
#
# Behavior: warn (exit 0). Detects whether the current diff is doc-only;
# for non-doc PRs, warns once per missing review artifact in .claude/sdlc/test/.
set -euo pipefail

# Stop hooks receive event JSON on stdin. We don't need it; read and discard
# so we don't break a pipe upstream.
[ -t 0 ] || cat > /dev/null 2>/dev/null || true

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Must be in a git repo; gracefully degrade otherwise.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Determine the diff base. Fallback chain:
#   origin/main → main → HEAD~1
if git show-ref --verify --quiet refs/remotes/origin/main; then
    BASE="origin/main"
elif git show-ref --verify --quiet refs/heads/main; then
    BASE="main"
elif git rev-parse --verify --quiet HEAD~1 >/dev/null; then
    BASE="HEAD~1"
else
    exit 0  # No base to diff against (single-commit repo).
fi

CHANGED_FILES=$(git diff --name-only "${BASE}...HEAD" 2>/dev/null || true)
[ -n "$CHANGED_FILES" ] || exit 0  # No changes to gate.

# Doc-only canonical glob (per RFC-004 + AGENT-RULES.md §14).
# A PR is doc-only when EVERY changed file matches a doc pattern AND none
# match the .claude/sdlc/plans/ or .claude/sdlc/gates/ exclusions.
is_doc_only() {
    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        case "$f" in
            .claude/sdlc/plans/*|.claude/sdlc/gates/*)
                return 1  # Substantive governance file — treat as code-PR.
                ;;
            *.md|docs/*|templates/*|agents/*|commands/*|.github/*)
                continue  # Doc pattern — keep checking other files.
                ;;
            *)
                return 1  # Non-doc file found.
                ;;
        esac
    done <<< "$CHANGED_FILES"
    return 0
}

if is_doc_only; then
    exit 0  # Doc-only PR — review gate bypassed.
fi

# Non-doc PR — verify all four review artifacts exist in .claude/sdlc/test/.
TEST_DIR="${PROJECT_DIR}/.claude/sdlc/test"

artifact_present() {
    local pattern="$1"
    [ -d "$TEST_DIR" ] || return 1
    # shellcheck disable=SC2086
    compgen -G "${TEST_DIR}/${pattern}" >/dev/null
}

warn_missing() {
    local label="$1"
    local agent="$2"
    echo "[pre-merge-review] WARN: ${label} artifact missing in .claude/sdlc/test/ — run ${agent} per AGENT-RULES.md §14" >&2
}

artifact_present "security-review-*.md"      || warn_missing "security"      "maintainer-security-reviewer"
artifact_present "code-quality-review-*.md"  || warn_missing "code-quality"  "maintainer-code-quality-reviewer"
artifact_present "test-adequacy-review-*.md" || warn_missing "test-adequacy" "maintainer-test-adequacy-reviewer"
artifact_present "dependency-review-*.md"    || warn_missing "dependency"    "maintainer-dependency-reviewer"

exit 0
