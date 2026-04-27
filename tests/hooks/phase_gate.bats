#!/usr/bin/env bats
load '../helpers/fixture'

setup() {
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: invoke phase-gate.sh in PreToolUse mode (CLAUDE_TOOL_INPUT set).
run_pretool() {
  local dir="$1" file_path="${2:-src/foo.py}"
  run bash -c "cd '$dir' && CLAUDE_TOOL_INPUT='{\"file_path\":\"${file_path}\"}' '$HOOKS_DIR/phase-gate.sh' 2>&1"
}

# Helper: invoke phase-gate.sh in Stop mode (CLAUDE_TOOL_INPUT unset).
run_stop() {
  local dir="$1"
  run bash -c "cd '$dir' && unset CLAUDE_TOOL_INPUT && '$HOOKS_DIR/phase-gate.sh' 2>&1"
}

@test "PreToolUse: exits 0 silently when .enabled is absent" {
  sdlc_workspace "$TEST_DIR"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "PreToolUse: exits 0 with notice when .suspended is set" {
  sdlc_workspace "$TEST_DIR"
  suspend_workflow "$TEST_DIR"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "suspended" ]]
}

@test "PreToolUse: allows edits to .claude/sdlc/ artifacts (repair escape hatch)" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  run_pretool "$TEST_DIR" ".claude/sdlc/plans/test-task.md"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: exits 0 when no active plan exists" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: warns when active plan has no Phase field" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "PreToolUse: warns when Phase field has invalid value" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "invalid-phase"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "PreToolUse: passes when Phase is plan (first phase)" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "plan"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: passes when Phase is docs (cross-cutting)" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "docs"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: passes when Phase=analyze and plan gate present" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "analyze"
  add_signed_gate "$TEST_DIR" "plan" "test-task"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: blocks when Phase=analyze and plan gate missing (source file)" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "analyze"
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "PreToolUse: warns (not blocks) when Phase=analyze, gate missing, .md outside .claude/sdlc/" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "analyze"
  run_pretool "$TEST_DIR" "docs/notes.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "PreToolUse: passes when Phase=build and design gate present" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  add_signed_gate "$TEST_DIR" "design" "test-task"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: blocks when Phase=build, design gate missing, .ts file" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  run_pretool "$TEST_DIR" "src/api.ts"
  [ "$status" -eq 2 ]
}

@test "PreToolUse: passes when Phase=support and deploy gate present" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  add_signed_gate "$TEST_DIR" "deploy" "test-task"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: passes when Phase=support and support-transition gate present" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  add_signed_gate "$TEST_DIR" "support-transition" "test-task"
  run_pretool "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: blocks when Phase=deploy, test gate missing, .json config" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "deploy"
  run_pretool "$TEST_DIR" "config/prod.json"
  [ "$status" -eq 2 ]
}

@test "Stop: warns when no recent gate update" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  run_stop "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "INFO" ]]
}

@test "Stop: silent when a recent gate exists" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_signed_gate "$TEST_DIR" "plan" "test-task"
  run_stop "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "PreToolUse: parses 'Active Phase' form (bold list bullet) and passes when prior gate present" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build
- **Active Phase:** build

## In-scope files
- src/foo.js
EOF
  add_signed_gate "$TEST_DIR" "design" "test-task"
  run_pretool "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
}

@test "PreToolUse: parses 'Active Phase' form (plain) and blocks when prior gate missing" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build
Active Phase: analyze

## In-scope files
- src/foo.js
EOF
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}
