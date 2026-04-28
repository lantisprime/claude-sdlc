#!/usr/bin/env bats
# Tests for .claude/hooks/rfc-quality-gate.sh
# Per RFC-006 PR-3 — maintainer-only PostToolUse hook (warn, exit 0).

setup() {
  TEST_DIR=$(mktemp -d)
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/rfc-quality-gate.sh"
  RFC_DIR="$TEST_DIR/docs/rfcs"
  mkdir -p "$RFC_DIR/notes" "$RFC_DIR/archived"
  TODAY=$(date -u +%Y-%m-%d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Convenience: send a PostToolUse-style JSON payload to the hook with a file_path.
run_hook_for() {
  local file_path="$1"
  local payload
  payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$file_path")
  run bash -c "echo '$payload' | '$HOOK'"
}

# Convenience: write a minimal RFC body with the required headings.
write_minimal_rfc() {
  local path="$1" status="$2" last_mod="${3:-$TODAY}"
  cat > "$path" <<EOF
---
rfc_id: RFC-099
slug: test
title: Test RFC
status: $status
champion: juan.delacruz@acme.com
created: 2026-04-28
last_modified: $last_mod
---

## AI context

One sentence. Two sentence. Three sentence.

## Problem

A problem.

## Proposal

A proposal.

## Alternatives considered

Some alternatives.
EOF
}

# -- 1. Self-filter cases --

@test "empty stdin — exit 0 silently" {
  run bash -c "echo '' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "file_path outside docs/rfcs/ — exit 0 silently" {
  run_hook_for "/tmp/foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "TEMPLATE.md — exit 0 silently" {
  touch "$RFC_DIR/TEMPLATE.md"
  run_hook_for "$RFC_DIR/TEMPLATE.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "README.md — exit 0 silently" {
  touch "$RFC_DIR/README.md"
  run_hook_for "$RFC_DIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pending-analysis.md — exit 0 silently" {
  touch "$RFC_DIR/pending-analysis.md"
  run_hook_for "$RFC_DIR/pending-analysis.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "notes/ subdir — exit 0 silently" {
  touch "$RFC_DIR/notes/foo.md"
  run_hook_for "$RFC_DIR/notes/foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "archived/ subdir — exit 0 silently (errata-only territory)" {
  touch "$RFC_DIR/archived/RFC-001-foo.md"
  run_hook_for "$RFC_DIR/archived/RFC-001-foo.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-existent file — exit 0 silently" {
  run_hook_for "$RFC_DIR/RFC-999-missing.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# -- 2. Common checks (any status) --

@test "draft RFC with all required headings + today's last_modified — silent" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "draft"
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing required heading — warns about that heading" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "draft"
  # Strip out '## Problem' line (BSD sed compatible).
  awk '!/^## Problem$/' "$RFC_DIR/RFC-099-test.md" > "$RFC_DIR/RFC-099-test.md.new"
  mv "$RFC_DIR/RFC-099-test.md.new" "$RFC_DIR/RFC-099-test.md"
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required heading missing"* ]]
  [[ "$output" == *"## Problem"* ]]
}

@test "last_modified mismatched to today — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "draft" "2020-01-01"
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"last_modified"* ]]
  [[ "$output" == *"does not match today"* ]]
}

# -- 3. Accepted-status checks --

@test "accepted with Decision: proceed + ### PR-N plan — no plan/decision warning" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "accepted"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation plan

### PR-1 — _example: hooks/example.sh_

**Before:** none

**After:** new script

## Second opinion

**Decision:** proceed
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Second opinion"* ]]
  [[ "$output" != *"Implementation plan"* ]]
}

@test "accepted with Decision: revise first — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "accepted"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation plan

### PR-1 — _example: foo.sh_

## Second opinion

**Decision:** revise first
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"revise first"* ]]
}

@test "accepted with no Second opinion section — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "accepted"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation plan

### PR-1 — foo.sh
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Second opinion"* ]]
  [[ "$output" == *"missing"* ]]
}

@test "accepted with stub Implementation plan (no PR-N) — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "accepted"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation plan

> Populate this section when the RFC moves to \`accepted\`.

## Second opinion

**Decision:** proceed
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Implementation plan"* ]]
  [[ "$output" == *"stub"* ]]
}

# -- 4. Implemented-status checks --

@test "implemented with only abc1234 placeholder — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "implemented"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation

| PR / Commit | What |
|---|---|
| \`abc1234\` | — |
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"placeholder"* ]]
}

@test "implemented with real PR row — no warning" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "implemented"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Implementation

| PR / Commit | What |
|---|---|
| #36 \`6ea420f\` | shipped agents |
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"placeholder"* ]]
  [[ "$output" != *"Implementation"* ]]
}

# -- 5. Deferred / Withdrawn / Superseded --

@test "deferred with empty Deferral note — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "deferred"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Deferral note

> Populate only if status changes to \`deferred\`.
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deferral note"* ]]
  [[ "$output" == *"empty"* ]]
}

@test "deferred with populated Deferral note — no warning" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "deferred"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Deferral note

Reason: dependency X is not ready. Unpark when X is implemented.
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Deferral note"* ]]
}

@test "withdrawn with empty Withdrawal note — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "withdrawn"
  cat >> "$RFC_DIR/RFC-099-test.md" <<EOF

## Withdrawal note

> Populate only if status changes to \`withdrawn\`.
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Withdrawal note"* ]]
}

@test "superseded with no superseded_by + no Supersession note — warns about both" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "superseded"
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"superseded_by"* ]]
  [[ "$output" == *"Supersession note"* ]]
}

@test "superseded with both fields populated — silent" {
  cat > "$RFC_DIR/RFC-099-test.md" <<EOF
---
rfc_id: RFC-099
slug: test
title: Test RFC
status: superseded
champion: juan.delacruz@acme.com
created: 2026-04-28
last_modified: $TODAY
superseded_by: RFC-100-new
---

## AI context

x.

## Problem

x.

## Proposal

x.

## Alternatives considered

x.

## Supersession note

Replaced by RFC-100 because reasons.
EOF
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"superseded"* ]]
  [[ "$output" != *"Supersession note"* ]]
}

@test "unknown status — warns" {
  write_minimal_rfc "$RFC_DIR/RFC-099-test.md" "fooblar"
  run_hook_for "$RFC_DIR/RFC-099-test.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown status"* ]]
  [[ "$output" == *"fooblar"* ]]
}
