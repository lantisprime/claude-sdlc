#!/usr/bin/env bats
# Regression tests for scripts/package.sh.
#
# Covers the four CI bugs hit during the v1.2.0 release:
#
#   Bug 1 — mapfile (bash 4+) failed on macOS system bash 3.2
#            Fix: replaced mapfile with while-read loop
#            Test: run --dry-run with system bash; must exit 0
#
#   Bug 2 — git identity not set when release_branch() called git commit
#            Fix: added "Configure git identity" step to release.yml (global)
#            Test: verify release.yml contains the global config step
#
#   Bug 3 — in-place orphan branch checkout failed in GitHub Actions worktree
#            Fix: replaced with isolated /tmp repo; working tree never touched
#            Test: grep confirms git checkout --orphan is absent from script
#
#   Bug 4 — package.sh tried to create a tag that already existed in CI
#            Fix: added --skip-tag flag; release.yml passes it
#            Test: --skip-tag accepted without error; release.yml uses it

PACKAGE_SH="$BATS_TEST_DIRNAME/../../scripts/package.sh"
WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/release.yml"

# ── Fixture ───────────────────────────────────────────────────────────────

setup() {
  FIXTURE=$(mktemp -d)
  mkdir -p "$FIXTURE/.claude-plugin"
  cat > "$FIXTURE/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "test-plugin",
  "version": "0.0.1",
  "_devFiles_comment": "test",
  "devFiles": ["CLAUDE.md", "docs/", "tests/", "scripts/"]
}
JSON
  # Distributable files — must appear in manifest
  touch "$FIXTURE/README.md"
  touch "$FIXTURE/LICENSE"
  mkdir -p "$FIXTURE/skills/plan"
  touch "$FIXTURE/skills/plan/SKILL.md"

  # devFiles — must NOT appear in manifest
  touch "$FIXTURE/CLAUDE.md"
  mkdir -p "$FIXTURE/docs" && touch "$FIXTURE/docs/guide.md"
  mkdir -p "$FIXTURE/tests" && touch "$FIXTURE/tests/test.bats"
  mkdir -p "$FIXTURE/scripts" && touch "$FIXTURE/scripts/package.sh"

  # Infra exclusions — must NOT appear in manifest
  mkdir -p "$FIXTURE/.github/workflows" && touch "$FIXTURE/.github/workflows/release.yml"
  mkdir -p "$FIXTURE/dist" && touch "$FIXTURE/dist/old.tar.gz"
}

teardown() {
  rm -rf "$FIXTURE"
}

# ── Syntax ────────────────────────────────────────────────────────────────

@test "script passes bash -n syntax check" {
  run bash -n "$PACKAGE_SH"
  [ "$status" -eq 0 ]
}

# ── Bug 1: bash 3.2 compatibility (mapfile) ───────────────────────────────

@test "Bug 1 — dry-run runs without error on system bash (bash 3.x compat)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
}

@test "Bug 1 — script contains no mapfile calls" {
  run grep -n "mapfile" "$PACKAGE_SH"
  [ "$status" -eq 1 ]  # grep exits 1 when no match
}

# ── Bug 3: no in-place orphan checkout ────────────────────────────────────

@test "Bug 3 — release_branch does not use in-place git checkout --orphan" {
  run grep "git checkout --orphan" "$PACKAGE_SH"
  [ "$status" -eq 1 ]  # grep exits 1 when no match
}

# ── Bug 4: --skip-tag flag ────────────────────────────────────────────────

@test "Bug 4 — --skip-tag flag accepted without error" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run --skip-tag"
  [ "$status" -eq 0 ]
  [[ "$output" != *"error: unknown flag"* ]]
}

@test "Bug 4 — release.yml calls package.sh with --skip-tag" {
  run grep "package.sh.*--skip-tag" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ── Bug 2: git identity in workflow ───────────────────────────────────────

@test "Bug 2 — release.yml sets git user.name globally before Package step" {
  run grep "git config --global user.name" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "Bug 2 — release.yml sets git user.email globally before Package step" {
  run grep "git config --global user.email" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ── Flag parsing ──────────────────────────────────────────────────────────

@test "--skip-tests flag accepted without error" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run --skip-tests"
  [ "$status" -eq 0 ]
  [[ "$output" != *"error: unknown flag"* ]]
}

@test "unknown flag exits 1 with error message" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --badflags 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "error: unknown flag" ]]
}

# ── Missing dependency ─────────────────────────────────────────────────────

@test "exits 1 with error message when jq is not in PATH" {
  # Build a PATH that excludes any directory containing a jq binary
  local safe_path=""
  while IFS= read -r d; do
    [[ -f "$d/jq" ]] && continue
    safe_path+="${d}:"
  done < <(echo "$PATH" | tr ':' '\n')

  run bash -c "cd '$FIXTURE' && PATH='$safe_path' bash '$PACKAGE_SH' --dry-run 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "jq is required" ]]
}

# ── Manifest correctness ──────────────────────────────────────────────────

@test "dry-run manifest includes distributable files" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "README.md" ]]
  [[ "$output" =~ "LICENSE" ]]
  [[ "$output" =~ "skills/plan/SKILL.md" ]]
}

@test "dry-run manifest excludes CLAUDE.md (devFiles)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"CLAUDE.md"* ]]
}

@test "dry-run manifest excludes docs/ (devFiles)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"docs/guide.md"* ]]
}

@test "dry-run manifest excludes tests/ (devFiles)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"tests/test.bats"* ]]
}

@test "dry-run manifest excludes scripts/ (devFiles)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"scripts/package.sh"* ]]
}

@test "dry-run manifest excludes .github/ (infra)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *".github"* ]]
}

@test "dry-run manifest excludes dist/ (infra)" {
  run bash -c "cd '$FIXTURE' && bash '$PACKAGE_SH' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" != *"dist/old.tar.gz"* ]]
}
