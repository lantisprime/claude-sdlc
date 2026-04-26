#!/usr/bin/env bats
# @integration — requires git. Skipped when not in a git repo context.
load '../helpers/fixture'

setup() {
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "exits 0 when .suspended marker is set" {
  sdlc_workspace "$TEST_DIR"
  suspend_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/diff-scope-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "suspended" ]]
}

@test "exits 0 when .enabled is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/diff-scope-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when no .git directory exists" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/diff-scope-check.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "@integration: passes when modified file is in plan scope" {
  if [[ "$(uname)" == "Darwin" ]]; then skip "find -printf not supported on macOS"; fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  init_git_repo "$TEST_DIR"
  mkdir -p "$TEST_DIR/src"
  echo "initial" > "$TEST_DIR/src/foo.js"
  git -C "$TEST_DIR" add . && git -C "$TEST_DIR" commit -q -m "init"
  echo "changed" >> "$TEST_DIR/src/foo.js"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/diff-scope-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "WARN" ]]
}

@test "@integration: warns when modified file is not in plan scope" {
  if [[ "$(uname)" == "Darwin" ]]; then skip "find -printf not supported on macOS"; fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  init_git_repo "$TEST_DIR"
  mkdir -p "$TEST_DIR/src"
  echo "initial" > "$TEST_DIR/src/bar.js"
  git -C "$TEST_DIR" add . && git -C "$TEST_DIR" commit -q -m "init"
  echo "changed" >> "$TEST_DIR/src/bar.js"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/diff-scope-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}
