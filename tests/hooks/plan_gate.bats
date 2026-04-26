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
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks when plans directory does not exist" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  rmdir "$TEST_DIR/.claude/sdlc/plans"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "blocks when plans dir contains only versioned files" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_versioned_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "warns when active plan exists but scope.md is absent" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "warns when scope.md exists but no scope gate is signed" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  touch "$TEST_DIR/.claude/sdlc/scope.md"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "passes cleanly with active plan, scope.md, and scope gate" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  touch "$TEST_DIR/.claude/sdlc/scope.md"
  add_scope_gate "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='src/foo.js' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "allows edits to SDLC artifacts regardless of plan state" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && CLAUDE_TOOL_INPUT='.claude/sdlc/plans/foo.md' '$HOOKS_DIR/plan-gate.sh' 2>&1"
  [ "$status" -eq 0 ]
}
