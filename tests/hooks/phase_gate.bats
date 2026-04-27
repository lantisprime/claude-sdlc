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

# ---- B2 placeholder validation (PR-4) ----

# Helper: write a deploy gate with signer/timestamp/work-item filled or unfilled.
# Usage: write_deploy_gate <dir> <slug> <signer> <timestamp> <work-item> <ack>
write_deploy_gate() {
  local dir="$1" slug="$2" signer="$3" timestamp="$4" work_item="$5" ack="$6"
  cat > "$dir/.claude/sdlc/gates/deploy-${slug}.md" <<EOF
# Phase Gate: deploy-${slug}

- **Phase:** deploy
- **Task:** ${slug}
- **Signed by:** ${signer}
- **Signed at:** ${timestamp}
- **Work-item reference:** ${work_item}

## Acknowledgment

${ack}

## Confirmation

I have reviewed the phase outputs and approve advancing to the next phase.
EOF
}

write_fix_fast_gate() {
  local dir="$1" slug="$2" signer="$3" timestamp="$4" work_item="$5" ack="$6"
  cat > "$dir/.claude/sdlc/gates/fix-fast-${slug}.md" <<EOF
# Phase Gate: fix-fast-${slug}

- **Phase:** plan
- **Task:** ${slug}
- **Signed by:** ${signer}
- **Signed at:** ${timestamp}
- **Work-item reference:** ${work_item}

## Acknowledgment

${ack}

## Confirmation

I have reviewed the phase outputs and approve advancing to the next phase.
EOF
}

@test "B2: Phase=support, deploy gate with all fields filled passes" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  write_deploy_gate "$TEST_DIR" "test-task" "juan.delacruz@acme.com" "2026-04-27T10:00:00Z" "https://github.com/org/repo/issues/42" "Verified canary, rollback ready, monitoring on."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 0 ]
}

@test "B2: Phase=support, deploy gate with <signer> placeholder blocks" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  write_deploy_gate "$TEST_DIR" "test-task" "<signer>" "2026-04-27T10:00:00Z" "REQ-001" "Verified."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
  [[ "$output" =~ "Signed by" ]]
}

@test "B2: Phase=support, deploy gate with multiple unfilled fields lists all" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  write_deploy_gate "$TEST_DIR" "test-task" "<signer>" "<timestamp>" "REQ-001" "<acknowledgment>"
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Signed by" ]]
  [[ "$output" =~ "Signed at" ]]
  [[ "$output" =~ "Acknowledgment" ]]
}

@test "B2: Phase=support, deploy gate with ___ in timestamp blocks" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  write_deploy_gate "$TEST_DIR" "test-task" "juan.delacruz@acme.com" "____" "REQ-001" "Verified."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Signed at" ]]
}

@test "B2: Phase=support, deploy gate with TODO in work-item blocks" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  write_deploy_gate "$TEST_DIR" "test-task" "juan.delacruz@acme.com" "2026-04-27T10:00:00Z" "TODO" "Verified."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Work-item reference" ]]
}

@test "B2: Phase=build, fix-fast gate with all fields filled passes" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  write_fix_fast_gate "$TEST_DIR" "test-task" "juan.delacruz@acme.com" "2026-04-27T10:00:00Z" "REQ-002" "Validated mini-gate."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 0 ]
}

@test "B2: Phase=build, fix-fast gate with <signer> placeholder blocks" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  write_fix_fast_gate "$TEST_DIR" "test-task" "<signer>" "2026-04-27T10:00:00Z" "REQ-002" "Validated."
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "fix-fast gate" ]]
  [[ "$output" =~ "Signed by" ]]
}

@test "B2: Phase=build, design gate (non-deploy/non-fix-fast) is not scanned" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "build"
  cat > "$TEST_DIR/.claude/sdlc/gates/design-test-task.md" <<'EOF'
# Phase Gate: design-test-task

- **Phase:** design
- **Signed by:** <signer>

## Acknowledgment

<acknowledgment>
EOF
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 0 ]
}

@test "B2: case-mismatched field name (Signed By with capital B) still detects placeholder" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  cat > "$TEST_DIR/.claude/sdlc/gates/deploy-test-task.md" <<'EOF'
# Phase Gate: deploy-test-task

- **Phase:** deploy
- **Signed By:** <signer>
- **Signed At:** 2026-04-27T10:00:00Z
- **Work-Item Reference:** REQ-001

## Acknowledgment

Verified.

## Confirmation

I have reviewed the phase outputs and approve advancing to the next phase.
EOF
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Signed by" ]]
}

@test "B2: multi-line HTML comment in Acknowledgment doesn't mask placeholder below" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_phase "$TEST_DIR" "support"
  cat > "$TEST_DIR/.claude/sdlc/gates/deploy-test-task.md" <<'EOF'
# Phase Gate: deploy-test-task

- **Phase:** deploy
- **Signed by:** juan.delacruz@acme.com
- **Signed at:** 2026-04-27T10:00:00Z
- **Work-item reference:** REQ-001

## Acknowledgment

<!-- Multi-line guidance:
  fill in your raw sign-off message
  describing what you verified -->
<acknowledgment>

## Confirmation

I have reviewed the phase outputs and approve advancing to the next phase.
EOF
  run_pretool "$TEST_DIR" "src/foo.py"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Acknowledgment" ]]
}
