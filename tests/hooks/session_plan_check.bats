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
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prompts to run /plan when no plans exist" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/plan" ]]
}

@test "prompts to run /plan when plans dir is empty" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/plan" ]]
}

@test "treats versioned-only plans as no active plans" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_versioned_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/plan" ]]
}

@test "reports multiple active plans when slug count > 1" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR" "task-alpha"
  add_active_plan "$TEST_DIR" "task-beta"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "active plans" ]]
}

@test "surfaces unsigned plan gate for single active plan" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR" "test-task"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test-task" ]]
}

@test "suggests next phase when plan gate is signed" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR" "test-task"
  add_signed_gate "$TEST_DIR" "plan" "test-task"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/session-plan-check.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/analyze" ]]
}
