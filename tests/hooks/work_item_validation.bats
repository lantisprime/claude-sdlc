#!/usr/bin/env bats
load '../helpers/fixture'

setup() {
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "exits 0 silently when .enabled is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when plans directory does not exist" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  rmdir "$TEST_DIR/.claude/sdlc/plans"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "exits 0 when plans directory is empty" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "passes when plan has Classification: new-build" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "blocks when plan missing Classification" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_no_classification "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "blocks CR plan when sign-off file is absent" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_cr_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "passes CR plan when sign-off file exists" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_cr_plan "$TEST_DIR"
  mkdir -p "$TEST_DIR/.claude/sdlc/sign-offs"
  touch "$TEST_DIR/.claude/sdlc/sign-offs/CR-001.md"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
}
