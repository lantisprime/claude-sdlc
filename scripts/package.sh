#!/usr/bin/env bash
set -euo pipefail

PLUGIN_JSON=".claude-plugin/plugin.json"

# Dependencies
command -v jq >/dev/null 2>&1 || { echo "error: jq is required (brew install jq)"; exit 1; }
[ -f "$PLUGIN_JSON" ] || { echo "error: $PLUGIN_JSON not found; run from repo root"; exit 1; }

DRY_RUN=false
SKIP_TESTS=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --skip-tests)  SKIP_TESTS=true ;;
    *) echo "error: unknown flag: $arg"; exit 1 ;;
  esac
done

VERSION=$(jq -r '.version' "$PLUGIN_JSON")
ARCHIVE="dist/sdlc-plugin-v${VERSION}.tar.gz"

# Exclusion list — two sources kept separate intentionally:
# 1. devFiles in plugin.json: repo-specific dev files (docs, tests, scripts, etc.)
# 2. INFRA_EXCLUDES: universal infrastructure files — never appropriate for any consumer
#    (kept hardcoded here so they don't require maintainer upkeep in plugin.json)
mapfile -t DEV_FILES < <(jq -r '.devFiles[]' "$PLUGIN_JSON")
INFRA_EXCLUDES=(".git" ".github" "config/tools.json" "dist" ".DS_Store" ".claude")

is_excluded() {
  local path="$1"
  for entry in "${DEV_FILES[@]}"; do
    # Strip trailing slash for comparison
    local stripped="${entry%/}"
    [[ "$path" == "$stripped" || "$path" == "$stripped/"* ]] && return 0
  done
  for entry in "${INFRA_EXCLUDES[@]}"; do
    local stripped="${entry%/}"
    [[ "$path" == "$stripped" || "$path" == "$stripped/"* ]] && return 0
  done
  return 1
}

build_manifest() {
  echo "=== Distribution manifest (v${VERSION}) ==="
  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    is_excluded "$rel" || echo "  $rel"
  done < <(find . -not -path './.git/*' -type f -print0 | sort -z)
  echo "==="
}

validate() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "warn: claude CLI not found — skipping plugin validate (expected in CI)"
    return 0
  fi
  echo "--- Running claude plugin validate"
  claude plugin validate
}

run_tests() {
  echo "--- Running test suite"
  tests/run.sh --integration
}

create_archive() {
  echo "--- Creating archive: $ARCHIVE"
  mkdir -p dist
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    if ! is_excluded "$rel"; then
      local dest="$tmp_dir/$rel"
      mkdir -p "$(dirname "$dest")"
      cp "$file" "$dest"
    fi
  done < <(find . -not -path './.git/*' -type f -print0)

  tar czf "$ARCHIVE" -C "$tmp_dir" .
  echo "--- Archive created: $ARCHIVE"
}

release_branch() {
  echo "--- Publishing release branch"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  # Copy distributable files to temp dir
  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    if ! is_excluded "$rel"; then
      local dest="$tmp_dir/$rel"
      mkdir -p "$(dirname "$dest")"
      cp "$file" "$dest"
    fi
  done < <(find . -not -path './.git/*' -type f -print0)

  # Force-push clean release branch — this is intentional; never push to release manually
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout --orphan release-tmp
  git rm -rf . --quiet
  cp -r "$tmp_dir/." .
  git add -A
  git commit -m "release: v${VERSION}"
  git branch -f release release-tmp
  git checkout "$current_branch"
  git branch -D release-tmp
  git push --force-with-lease origin release
  echo "--- Release branch updated"
}

tag_release() {
  echo "--- Tagging v${VERSION}"
  git tag "v${VERSION}"
  git push origin "v${VERSION}"
}

if $DRY_RUN; then
  echo "DRY RUN — no files will be written"
  build_manifest
  exit 0
fi

validate

if ! $SKIP_TESTS; then
  run_tests
fi

build_manifest
create_archive
release_branch
tag_release

echo "Done — v${VERSION} packaged and released."
