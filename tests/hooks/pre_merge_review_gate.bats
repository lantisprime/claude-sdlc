#!/usr/bin/env bats
# Tests for .claude/hooks/pre-merge-review-gate.sh
# Per RFC-004 PR-3 — maintainer-only Stop hook (warn, exit 0).

setup() {
  TEST_DIR=$(mktemp -d)
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/pre-merge-review-gate.sh"

  # Initialize a fresh git repo in the test dir with main branch + base commit.
  git -C "$TEST_DIR" init -q -b main
  git -C "$TEST_DIR" config user.email "test@example.com"
  git -C "$TEST_DIR" config user.name "Test"
  echo "base" > "$TEST_DIR/base.txt"
  git -C "$TEST_DIR" add base.txt
  git -C "$TEST_DIR" commit -q -m "base"

  # Pre-create the artifact directory.
  mkdir -p "$TEST_DIR/.claude/sdlc/test"

  # Move onto a feature branch so HEAD~1 fallback resolves to the base commit.
  git -C "$TEST_DIR" checkout -q -b feature
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Convenience: commit one or more files on the feature branch.
commit_files() {
  local msg="$1"; shift
  for f in "$@"; do
    mkdir -p "$(dirname "$TEST_DIR/$f")"
    [ -e "$TEST_DIR/$f" ] || echo "x" > "$TEST_DIR/$f"
    git -C "$TEST_DIR" add "$f"
  done
  git -C "$TEST_DIR" commit -q -m "$msg"
}

run_hook() {
  CLAUDE_PROJECT_DIR="$TEST_DIR" run bash "$HOOK"
}

# -- 1. doc-only PRs bypass the gate --

@test "doc-only PR (markdown only) bypasses gate, exits 0, no warnings" {
  commit_files "docs" "README.md"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "doc-only PR (docs/ subdir) bypasses gate" {
  commit_files "docs" "docs/foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "doc-only PR (templates/, agents/, commands/, .github/) bypasses gate" {
  commit_files "mixed-doc" \
    "templates/foo.md" \
    "agents/bar.md" \
    "commands/baz.md" \
    ".github/workflows/qux.yml"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# -- 2. plan/gate exclusions are treated as code-PRs --

@test ".claude/sdlc/plans/ touched is treated as code-PR — warns about all four artifacts" {
  commit_files "plan" ".claude/sdlc/plans/foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"security artifact missing"* ]]
  [[ "$output" == *"code-quality artifact missing"* ]]
  [[ "$output" == *"test-adequacy artifact missing"* ]]
  [[ "$output" == *"dependency artifact missing"* ]]
}

@test ".claude/sdlc/gates/ touched is treated as code-PR — warns about all four artifacts" {
  commit_files "gate" ".claude/sdlc/gates/build-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"security artifact missing"* ]]
}

# -- 3. code PR with all artifacts present passes silently --

@test "code PR with all four artifacts present — exits 0, no warnings" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/security-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/code-quality-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/test-adequacy-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/dependency-review-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# -- 4. each individual missing artifact warns about that artifact only --

@test "code PR missing security artifact — warns about security only" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/code-quality-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/test-adequacy-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/dependency-review-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"security artifact missing"* ]]
  [[ "$output" != *"code-quality artifact missing"* ]]
  [[ "$output" != *"test-adequacy artifact missing"* ]]
  [[ "$output" != *"dependency artifact missing"* ]]
}

@test "code PR missing code-quality artifact — warns about code-quality only" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/security-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/test-adequacy-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/dependency-review-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"code-quality artifact missing"* ]]
  [[ "$output" != *"security artifact missing"* ]]
}

@test "code PR missing test-adequacy artifact — warns about test-adequacy only" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/security-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/code-quality-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/dependency-review-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-adequacy artifact missing"* ]]
  [[ "$output" != *"security artifact missing"* ]]
}

@test "code PR missing dependency artifact — warns about dependency only" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/security-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/code-quality-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/test-adequacy-review-foo.md"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"dependency artifact missing"* ]]
  [[ "$output" != *"security artifact missing"* ]]
}

@test "code PR missing all four — warns about all four" {
  commit_files "code" "foo.sh"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"security artifact missing"* ]]
  [[ "$output" == *"code-quality artifact missing"* ]]
  [[ "$output" == *"test-adequacy artifact missing"* ]]
  [[ "$output" == *"dependency artifact missing"* ]]
}

# -- 5. graceful degradation cases --

@test "missing .claude/sdlc/test/ directory treated as all artifacts missing" {
  commit_files "code" "foo.sh"
  rm -rf "$TEST_DIR/.claude/sdlc/test"
  run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"security artifact missing"* ]]
  [[ "$output" == *"dependency artifact missing"* ]]
}

@test "dependency-review with Verdict: not-applicable artifact counts as present" {
  commit_files "code" "foo.sh"
  touch "$TEST_DIR/.claude/sdlc/test/security-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/code-quality-review-foo.md"
  touch "$TEST_DIR/.claude/sdlc/test/test-adequacy-review-foo.md"
  cat > "$TEST_DIR/.claude/sdlc/test/dependency-review-foo.md" <<'ARTIFACT'
**Reviewer:** maintainer-dependency-reviewer
**Verdict:** not-applicable
ARTIFACT
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outside a git repo — exits 0 silently" {
  local non_repo
  non_repo=$(mktemp -d)
  CLAUDE_PROJECT_DIR="$non_repo" run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "$non_repo"
}
