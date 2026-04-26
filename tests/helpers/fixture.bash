#!/usr/bin/env bash
# Shared fixture helpers for bats hook tests.
# Load with: load '../helpers/fixture'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/hooks"

# Create the minimal .claude/sdlc/ workspace layout in a given directory.
sdlc_workspace() {
  local dir="$1"
  mkdir -p "$dir/.claude/sdlc/plans"
  mkdir -p "$dir/.claude/sdlc/gates"
  mkdir -p "$dir/.claude/sdlc/sign-offs"
  mkdir -p "$dir/config"
}

# Write the .enabled marker.
enable_workflow() {
  touch "$1/.claude/sdlc/.enabled"
}

# Write the .suspended marker (also requires .enabled to have been written).
suspend_workflow() {
  touch "$1/.claude/sdlc/.enabled"
  touch "$1/.claude/sdlc/.suspended"
}

# Copy the "active plan" fixture into the workspace, touching it to update mtime.
add_active_plan() {
  local dir="$1" slug="${2:-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/plan-with-classification.md" \
     "$dir/.claude/sdlc/plans/${slug}.md"
  touch "$dir/.claude/sdlc/plans/${slug}.md"
}

# Copy a plan with Classification: change-request.
add_cr_plan() {
  local dir="$1" slug="${2:-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/plan-change-request.md" \
     "$dir/.claude/sdlc/plans/${slug}.md"
  touch "$dir/.claude/sdlc/plans/${slug}.md"
}

# Copy a plan that has no Classification line.
add_plan_no_classification() {
  local dir="$1" slug="${2:-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/plan-no-classification.md" \
     "$dir/.claude/sdlc/plans/${slug}.md"
  touch "$dir/.claude/sdlc/plans/${slug}.md"
}

# Copy a versioned plan (*.v1.md) — should not satisfy plan-gate or work-item checks.
add_versioned_plan() {
  local dir="$1" slug="${2:-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/plan-with-classification.md" \
     "$dir/.claude/sdlc/plans/${slug}.v1.md"
}

# Add a signed gate file for a given phase + slug.
add_signed_gate() {
  local dir="$1" phase="${2:-plan}" slug="${3:-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/gate-signed.md" \
     "$dir/.claude/sdlc/gates/${phase}-${slug}.md"
}

# Add a scope gate (gates/scope-<slug>.md).
add_scope_gate() {
  local dir="$1" slug="${2:-project}"
  cp "$REPO_ROOT/tests/hooks/fixtures/gate-signed.md" \
     "$dir/.claude/sdlc/gates/scope-${slug}.md"
}

# Add a gate file that has a ## Required sign-offs block.
add_gate_with_signoffs() {
  local dir="$1" gate_name="${2:-build-test-task}"
  cp "$REPO_ROOT/tests/hooks/fixtures/gate-with-required-signoffs.md" \
     "$dir/.claude/sdlc/gates/${gate_name}.md"
}

# Add a sign-off file that matches a gate + role.
add_signoff() {
  local dir="$1" gate_path="$2" role="$3" name="${4:-REQ-001-${role}}"
  mkdir -p "$dir/.claude/sdlc/sign-offs"
  cat > "$dir/.claude/sdlc/sign-offs/${name}.md" <<EOF
---
gate_ref: ${gate_path}
role: ${role}
signer: juan.delacruz@acme.com
timestamp: 2026-04-26T10:00:00Z
gate_hash: abc123def456
---

# Sign-off: ${role}
EOF
}

# Init a minimal git repo in the given directory.
init_git_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
}
