#!/usr/bin/env bats
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
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "suspended" ]]
}

@test "exits 0 silently when .enabled is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when gates directory does not exist" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  rmdir "$TEST_DIR/.claude/sdlc/gates"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "exits 0 when no gate has Required sign-offs block" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_signed_gate "$TEST_DIR" "plan" "test-task"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "warns about missing sign-offs for required roles" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_gate_with_signoffs "$TEST_DIR" "build-test-task"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "missing sign-off" ]]
}

@test "reports all sign-offs present and regenerates APPROVALS.md in git repo" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  init_git_repo "$TEST_DIR"
  add_gate_with_signoffs "$TEST_DIR" "build-test-task"
  local gate_path=".claude/sdlc/gates/build-test-task.md"
  add_signoff "$TEST_DIR" "$gate_path" "tech-lead" "REQ-001-tech-lead"
  add_signoff "$TEST_DIR" "$gate_path" "qa-lead"   "REQ-001-qa-lead"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/APPROVALS.md" ]
}

@test "warns about orphan sign-off whose gate_ref does not exist" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_signoff "$TEST_DIR" ".claude/sdlc/gates/nonexistent-task.md" "tech-lead" "REQ-orphan-tech-lead"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/approval-reconcile.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Orphan" ]]
}
