#!/usr/bin/env bats
load '../helpers/fixture'

setup() {
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "exits 0 when config/tools.json is absent" {
  sdlc_workspace "$TEST_DIR"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/secret-scan.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "exits 0 when secret_scanner command is null" {
  sdlc_workspace "$TEST_DIR"
  cp "$REPO_ROOT/tests/hooks/fixtures/tools-valid.json" "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/secret-scan.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "exits 0 when secret_scanner key is absent from tools.json" {
  sdlc_workspace "$TEST_DIR"
  echo '{"formatter":{"command":null}}' > "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/secret-scan.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "passes when configured scanner exits 0" {
  sdlc_workspace "$TEST_DIR"
  echo '{"secret_scanner":{"command":"true"}}' > "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/secret-scan.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "blocks when configured scanner exits non-zero" {
  sdlc_workspace "$TEST_DIR"
  echo '{"secret_scanner":{"command":"false"}}' > "$TEST_DIR/config/tools.json"
  run bash -c "cd '$TEST_DIR' && '$HOOKS_DIR/secret-scan.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "BLOCK" ]]
}
