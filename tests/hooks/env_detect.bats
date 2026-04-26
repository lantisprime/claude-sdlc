#!/usr/bin/env bats
load '../helpers/fixture'

setup() {
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "writes env.json on every run" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/.claude/sdlc/env.json" ]
}

@test "detects .git and sets vcs to git" {
  sdlc_workspace "$TEST_DIR"
  init_git_repo "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q '"vcs": "git"' "$TEST_DIR/.claude/sdlc/env.json"
}

@test "sets vcs to null when .git is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q '"vcs": null' "$TEST_DIR/.claude/sdlc/env.json"
}

@test "prints install prompt when .enabled is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "claude-sdlc is installed" ]]
}

@test "prints suspended message when .suspended marker exists" {
  sdlc_workspace "$TEST_DIR"
  suspend_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "suspended" ]]
}

@test "sets config_corrupted to true for invalid JSON and emits LAYER-3 when enabled" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cp "$REPO_ROOT/tests/hooks/fixtures/tools-corrupted.json" "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q '"config_corrupted": true' "$TEST_DIR/.claude/sdlc/env.json"
  [[ "$output" =~ "LAYER-3" ]]
}

@test "sets config_corrupted to false for valid JSON" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cp "$REPO_ROOT/tests/hooks/fixtures/tools-valid.json" "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/env-detect.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q '"config_corrupted": false' "$TEST_DIR/.claude/sdlc/env.json"
}
