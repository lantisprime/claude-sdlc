#!/usr/bin/env bash
set -euo pipefail

PLUGIN_JSON=".claude-plugin/plugin.json"

# Dependencies
command -v jq >/dev/null 2>&1 || { echo "error: jq is required (brew install jq)"; exit 1; }
[ -f "$PLUGIN_JSON" ] || { echo "error: $PLUGIN_JSON not found; run from repo root"; exit 1; }

DRY_RUN=false
SKIP_TESTS=false
SKIP_TAG=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --skip-tests)  SKIP_TESTS=true ;;
    --skip-tag)    SKIP_TAG=true ;;
    *) echo "error: unknown flag: $arg"; exit 1 ;;
  esac
done

VERSION=$(jq -r '.version' "$PLUGIN_JSON")
ARCHIVE="dist/sdlc-plugin-v${VERSION}.tar.gz"

# Exclusion list — two sources kept separate intentionally:
# 1. devFiles in plugin.json: repo-specific dev files (docs, tests, scripts, etc.)
# 2. INFRA_EXCLUDES: universal infrastructure files — never appropriate for any consumer
#    (kept hardcoded here so they don't require maintainer upkeep in plugin.json)
DEV_FILES=()
while IFS= read -r line; do DEV_FILES+=("$line"); done < <(jq -r '.devFiles[]' "$PLUGIN_JSON")
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

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    if ! is_excluded "$rel"; then
      local dest="$tmp_dir/$rel"
      mkdir -p "$(dirname "$dest")"
      cp "$file" "$dest"
    fi
  done < <(find . -not -path './.git/*' -type f -print0)

  tar czf "$ARCHIVE" -C "$tmp_dir" .
  rm -rf "$tmp_dir"
  echo "--- Archive created: $ARCHIVE"
}

release_branch() {
  echo "--- Publishing release branch"
  local tmp_dir tmp_repo origin_url
  tmp_dir=$(mktemp -d)
  tmp_repo=$(mktemp -d)
  origin_url=$(git remote get-url origin)

  # Copy distributable files to tmp_dir
  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    if ! is_excluded "$rel"; then
      local dest="$tmp_dir/$rel"
      mkdir -p "$(dirname "$dest")"
      cp "$file" "$dest"
    fi
  done < <(find . -not -path './.git/*' -type f -print0)

  # Build release branch in an isolated repo — avoids touching the working tree
  # (required for CI worktree environments where in-place orphan checkout fails)
  git -C "$tmp_repo" init
  git -C "$tmp_repo" config user.name "$(git config user.name)"
  git -C "$tmp_repo" config user.email "$(git config user.email)"
  git -C "$tmp_repo" checkout -b release
  cp -r "$tmp_dir/." "$tmp_repo/"
  git -C "$tmp_repo" add -A
  git -C "$tmp_repo" commit -m "release: v${VERSION}"
  git -C "$tmp_repo" remote add origin "$origin_url"
  git -C "$tmp_repo" push --force origin release

  rm -rf "$tmp_dir" "$tmp_repo"
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

if $SKIP_TAG; then
  echo "--- Skipping tag (--skip-tag)"
else
  tag_release
fi

echo "Done — v${VERSION} packaged and released."
