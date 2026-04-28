#!/usr/bin/env bats
# Tests for .claude/hooks/ai-slop-check.sh
# Per RFC-006 PR-4 — maintainer-only PostToolUse hook (warn, exit 0).
# One true-positive + one true-negative case per pattern class (12 cases).

setup() {
  TEST_DIR=$(mktemp -d)
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/ai-slop-check.sh"
  DOC_DIR="$TEST_DIR/docs"
  mkdir -p "$DOC_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

run_hook_for() {
  local file_path="$1"
  local payload
  payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$file_path")
  run bash -c "echo '$payload' | '$HOOK'"
}

write_doc() {
  local path="$1"; shift
  printf '%s\n' "$@" > "$path"
}

# -- Self-filter cases --

@test "non-md file path — exit 0 silently" {
  run_hook_for "/tmp/foo.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "md file outside docs/ or rfcs/ — exit 0 silently" {
  echo "this will revolutionize" > "$TEST_DIR/foo.md"
  run_hook_for "$TEST_DIR/foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-existent md file under docs/ — exit 0 silently" {
  run_hook_for "$DOC_DIR/missing.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# -- Class 1: Inflated metaphors --

@test "inflated metaphor (Trojan Horse) — warns" {
  write_doc "$DOC_DIR/foo.md" "This is a Trojan Horse for autonomy."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"inflated metaphor"* ]]
  [[ "$output" == *"PROPOSED FIX"* ]]
}

@test "no inflated metaphor — silent" {
  write_doc "$DOC_DIR/foo.md" "This enables autonomous workflows."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"inflated metaphor"* ]]
}

# -- Class 2: Manufactured persona --

@test "manufactured persona (Imagine you're a) — warns" {
  write_doc "$DOC_DIR/foo.md" "Imagine you're a senior engineer reviewing this."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manufactured persona"* ]]
}

@test "no manufactured persona — silent" {
  write_doc "$DOC_DIR/foo.md" "When reviewing this, check for X, Y, Z."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"manufactured persona"* ]]
}

# -- Class 3: Formulaic triplet --

@test "formulaic triplet (X, Y, and Z) — warns" {
  write_doc "$DOC_DIR/foo.md" "It is fast, reliable, and powerful."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"formulaic triplet"* ]]
}

@test "single-word claim — no triplet warning" {
  write_doc "$DOC_DIR/foo.md" "This is reliable."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"formulaic triplet"* ]]
}

# -- Class 4: False severity escalation --

@test "false severity escalation (critical warning) — warns" {
  write_doc "$DOC_DIR/foo.md" "This is a critical warning the user must see."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"false severity escalation"* ]]
}

@test "critical alone (no de-escalation word on same line) — silent" {
  write_doc "$DOC_DIR/foo.md" "This is a critical bug — patches cannot proceed."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"false severity escalation"* ]]
}

# -- Class 5: Unsupported compliance --

@test "unsupported compliance (SOC2 without qualifier) — warns" {
  write_doc "$DOC_DIR/foo.md" "This plugin provides SOC2 controls for production data."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unsupported compliance"* ]]
}

@test "compliance with qualifier (out of scope) — silent" {
  write_doc "$DOC_DIR/foo.md" "SOC2 certification is out of scope for this plugin."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unsupported compliance"* ]]
}

# -- Class 6: Aspirational framing --

@test "aspirational framing (will revolutionize) — warns" {
  write_doc "$DOC_DIR/foo.md" "This feature will revolutionize the workflow."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aspirational framing"* ]]
}

@test "concrete framing (cites specific behavior) — silent" {
  write_doc "$DOC_DIR/foo.md" "The new hook fires on PostToolUse for Edit/Write events."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"aspirational framing"* ]]
}

# -- Multi-class document --

@test "document with multiple slop classes — warns about each" {
  write_doc "$DOC_DIR/foo.md" \
    "This will revolutionize the workflow." \
    "Imagine you're a senior architect designing this." \
    "It is fast, reliable, and scalable."
  run_hook_for "$DOC_DIR/foo.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aspirational framing"* ]]
  [[ "$output" == *"manufactured persona"* ]]
  [[ "$output" == *"formulaic triplet"* ]]
}

# -- Hook never auto-applies (the file is unchanged after running) --

@test "hook does not modify the file" {
  write_doc "$DOC_DIR/foo.md" "This will revolutionize the workflow."
  local before_hash
  before_hash=$(shasum "$DOC_DIR/foo.md" | awk '{print $1}')
  run_hook_for "$DOC_DIR/foo.md"
  local after_hash
  after_hash=$(shasum "$DOC_DIR/foo.md" | awk '{print $1}')
  [ "$before_hash" = "$after_hash" ]
}
