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

# ---- B3 file-level traceability warnings (PR-5) ----

# Helper: write a plan with In-scope files + a REQ reference.
add_plan_with_req() {
  local dir="$1" slug="${2:-test-task}"
  cat > "$dir/.claude/sdlc/plans/${slug}.md" <<'EOF'
# Plan: test-task

Classification: new-build
Reference: REQ-001

## In-scope files
- src/foo.js
- src/notfoo.js
- src/bar.ts

## Out-of-scope
- src/notinplan.go
EOF
}

# Helper: invoke the hook with a CLAUDE_TOOL_INPUT JSON envelope.
run_with_path() {
  local dir="$1" file_path="$2"
  run bash -c "cd '$dir' && CLAUDE_TOOL_INPUT='{\"file_path\":\"${file_path}\"}' '$HOOKS_DIR/work-item-validation.sh' 2>&1"
}

@test "B3: legacy invocation (CLAUDE_TOOL_INPUT empty) skips file-level check" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && unset CLAUDE_TOOL_INPUT && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: file in scope + plan has REQ → silent pass" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: file NOT in scope, plan has REQ → warns about scope only" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  run_with_path "$TEST_DIR" "src/notinplan.go"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
  [[ "$output" =~ "In-scope files" ]]
  [[ ! "$output" =~ "no REQ/TICKET/CR" ]]
}

@test "B3: file in scope, plan has NO REQ → warns about traceability only" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"  # plan-with-classification.md has src/foo.js + no REQ
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
  [[ "$output" =~ "no REQ/TICKET/CR" ]]
}

@test "B3: file NOT in scope, plan has NO REQ → both warnings" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run_with_path "$TEST_DIR" "src/never-mentioned.py"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "In-scope files" ]]
  [[ "$output" =~ "no REQ/TICKET/CR" ]]
}

@test "B3: .claude/sdlc/ path bypasses file-level check (escape hatch)" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  run_with_path "$TEST_DIR" ".claude/sdlc/plans/foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: generated file with mapped in-scope source + plan has REQ → silent pass" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  cat > "$TEST_DIR/config/tools.json" <<'EOF'
{
  "generated_files": [
    { "path": "package-lock.json", "generated_by": "src/foo.js" }
  ]
}
EOF
  run_with_path "$TEST_DIR" "package-lock.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: generated file whose generator is NOT in-scope → warns about scope" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  cat > "$TEST_DIR/config/tools.json" <<'EOF'
{
  "generated_files": [
    { "path": "build/api.ts", "generated_by": "schemas/never-mentioned.yaml" }
  ]
}
EOF
  run_with_path "$TEST_DIR" "build/api.ts"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "In-scope files" ]]
}

@test "B3: missing config/tools.json falls through to plain in-scope/REQ check" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  # No config/tools.json written.
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: bare basename does not falsely match a longer in-scope path" {
  # Plan has `src/foo.js` and `src/notfoo.js`. Editing `foo.js` (bare) must NOT
  # be treated as in-scope just because it is a substring of `src/notfoo.js`.
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  run_with_path "$TEST_DIR" "foo.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "In-scope files" ]]
}

@test "B3: jq-absent invocation uses grep/sed fallback for file_path extraction" {
  # Restricted PATH typically excludes jq (brew installs to /usr/local/bin or
  # /opt/homebrew/bin). Skip defensively if jq remains reachable.
  if PATH=/usr/bin:/bin command -v jq >/dev/null 2>&1; then
    skip "jq is reachable in /usr/bin or /bin — cannot test the no-jq fallback path"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_active_plan "$TEST_DIR"
  # plan-with-classification.md has src/foo.js in-scope and no REQ.
  # If grep/sed extracted the path correctly: no scope warning fires; REQ
  # warning still fires because the plan has no REQ. If extraction failed,
  # the file path would default to the raw JSON envelope and miss the
  # in-scope match → scope warning would also fire (test would fail).
  run bash -c "cd '$TEST_DIR' && PATH=/usr/bin:/bin CLAUDE_TOOL_INPUT='{\"file_path\":\"src/foo.js\"}' '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "is not listed" ]]
  [[ "$output" =~ "no REQ/TICKET/CR/ISSUE" ]]
}

# ---- B3 → block promotion (PR-8) ----

@test "B3-block: traceability table + file in table with REQ → silent pass" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: traceability table + file NOT in table → BLOCK" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/missing.js"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
  [[ "$output" =~ "Traceability" ]]
}

@test "B3-block: traceability table + file in table but ref empty → BLOCK" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/empty-ref.js"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
  [[ "$output" =~ "no REQ/TICKET/CR/ISSUE" ]]
}

@test "B3-block: traceability table absent → falls back to warn (back-compat)" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_req "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/notinplan.go"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "B3-block: enforcement.file_traceability=warn keeps warn even with table" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "warn"
  run_with_path "$TEST_DIR" "src/missing.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "B3-block: enforcement.file_traceability absent defaults to warn" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  # No config/tools.json written.
  run_with_path "$TEST_DIR" "src/missing.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
}

@test "B3-block: TICKET-style ref in traceability row → silent pass" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/bar.ts"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: generated file whose generator is in traceability table → pass" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  cat > "$TEST_DIR/config/tools.json" <<'EOF'
{
  "enforcement": { "file_traceability": "block" },
  "generated_files": [
    { "path": "package-lock.json", "generated_by": "src/foo.js" }
  ]
}
EOF
  run_with_path "$TEST_DIR" "package-lock.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: generated file whose generator is NOT in traceability → BLOCK" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  cat > "$TEST_DIR/config/tools.json" <<'EOF'
{
  "enforcement": { "file_traceability": "block" },
  "generated_files": [
    { "path": "build/api.ts", "generated_by": "schemas/never-mentioned.yaml" }
  ]
}
EOF
  run_with_path "$TEST_DIR" "build/api.ts"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}

@test "B3-block: .claude/sdlc/ path bypass still works in block mode" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" ".claude/sdlc/plans/foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: legacy invocation (no CLAUDE_TOOL_INPUT) still skips file-level" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "block"
  run bash -c "cd '$TEST_DIR' && unset CLAUDE_TOOL_INPUT && '$HOOKS_DIR/work-item-validation.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: header column renamed 'Path' is still skipped (not parsed as data)" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build

## Traceability

| Path | REQ/Ticket/CR | Change Type |
|---|---|---|
| src/foo.js | REQ-001 | modified |
EOF
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: separator row with alignment colons does not become a data row" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build

## Traceability

| File | REQ/Ticket/CR | Change Type |
|:---|:---:|---:|
| src/foo.js | REQ-001 | modified |
EOF
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3-block: warn mode + traceability row with empty ref still surfaces in-scope warn" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  add_plan_with_traceability "$TEST_DIR"
  set_traceability_mode "$TEST_DIR" "warn"
  # src/empty-ref.js is NOT in the In-scope files list of add_plan_with_traceability.
  run_with_path "$TEST_DIR" "src/empty-ref.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]]
  [[ "$output" =~ "In-scope files" ]]
}

@test "B3-block: block mode + plan without traceability section emits inactive-block hint" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build

## In-scope files
- src/foo.js
EOF
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "inactive until the section is added" ]]
}

@test "B3-block: traceability table with extra whitespace parses correctly" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build

## Traceability

|     File          |  REQ/Ticket/CR  |  Change Type  |
|-------------------|-----------------|---------------|
|   src/spaced.js   |    REQ-007      |    modified   |
EOF
  set_traceability_mode "$TEST_DIR" "block"
  run_with_path "$TEST_DIR" "src/spaced.js"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "B3: plan with no '## In-scope files' section warns about scope" {
  sdlc_workspace "$TEST_DIR"
  enable_workflow "$TEST_DIR"
  cat > "$TEST_DIR/.claude/sdlc/plans/test-task.md" <<'EOF'
# Plan: test-task

Classification: new-build
Reference: REQ-001

## Approach
Some prose only — no In-scope files heading.
EOF
  run_with_path "$TEST_DIR" "src/foo.js"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "In-scope files" ]]
  [[ ! "$output" =~ "no REQ/TICKET/CR/ISSUE" ]]
}
