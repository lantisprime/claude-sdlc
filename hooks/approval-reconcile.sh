#!/usr/bin/env bash
# approval-reconcile.sh — Stop hook.
# For every gate file that has a ## Required sign-offs block, checks that a
# sign-off file exists in .claude/sdlc/sign-offs/ for each required role.
# Also warns when a sign-off's gate_hash no longer matches the current gate content.
# Regenerates APPROVALS.md at the git root when the sign-offs directory is newer.
# Always exits 0 (warn, never block — per RFC §3.3).

set -euo pipefail
[ -f ".claude/sdlc/.enabled" ] || exit 0

GATES_DIR=".claude/sdlc/gates"
SIGNOFFS_DIR=".claude/sdlc/sign-offs"

[ -d "$GATES_DIR" ] || exit 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Compute sha256 of gate content ABOVE the ## Required sign-offs heading.
gate_hash() {
  local gate_file="$1"
  awk '/^## Required sign-offs/{exit} {print}' "$gate_file" \
    | shasum -a 256 2>/dev/null | awk '{print $1}' \
    || sha256sum "$gate_file" | awk '{print $1}'
}

# Parse a frontmatter field value from a markdown file.
frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { if (++fence == 2) exit }
    fence == 1 && $0 ~ "^" f ":" { sub("^" f ":[ \t]*", ""); print; exit }
  ' "$file"
}

# Parse ## Required sign-offs roles from a gate file (one per line).
required_roles() {
  local gate_file="$1"
  awk '
    /^## Required sign-offs/ { in_section=1; next }
    in_section && /^## /     { exit }
    in_section && /^- /      { sub(/^- /, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }
  ' "$gate_file"
}

# Portable directory mtime as Unix epoch (macOS + Linux).
dir_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Sync one local sign-off file to the share. Newer ISO timestamp wins.
# If remote is newer: write .local.conflict.md + .remote.conflict.md locally.
sync_signoff() {
  local src="$1" dst="$2"
  local src_name src_ts dst_ts
  src_name=$(basename "$src")

  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    echo "[approval-reconcile] pushed $src_name to share" >&2
    return 0
  fi

  src_ts=$(frontmatter_field "$src" "timestamp")
  dst_ts=$(frontmatter_field "$dst" "timestamp")

  if [ "$src_ts" = "$dst_ts" ]; then
    return 0
  fi

  # Timestamps differ in either direction → preserve both; human resolves (RFC §6.7)
  cp "$src" "${src%.md}.local.conflict.md"
  cp "$dst" "${src%.md}.remote.conflict.md"
  echo "[approval-reconcile] CONFLICT: $src_name — versions differ; see .local.conflict.md / .remote.conflict.md" >&2
  return 1
}

# Sync one local sign-off file to a git staging area.
# Any timestamp mismatch (either direction) produces conflict files locally — RFC §6.7.
# Returns 0 if the file was staged for push, 1 otherwise.
sync_signoff_git() {
  local src="$1" dst="$2"
  local src_name src_ts dst_ts
  src_name=$(basename "$src")

  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    echo "[approval-reconcile] staged $src_name for git push" >&2
    return 0
  fi

  src_ts=$(frontmatter_field "$src" "timestamp")
  dst_ts=$(frontmatter_field "$dst" "timestamp")

  [ "$src_ts" = "$dst_ts" ] && return 1

  # Timestamps differ in either direction → preserve both; human resolves
  cp "$src" "${src%.md}.local.conflict.md"
  cp "$dst" "${src%.md}.remote.conflict.md"
  echo "[approval-reconcile] CONFLICT: $src_name — versions differ; see .local.conflict.md / .remote.conflict.md" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

# Locate git root (APPROVALS.md lives there). Skip generation outside git.
GIT_ROOT=""
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  GIT_ROOT=$(git rev-parse --show-toplevel)
fi
APPROVALS_FILE="${GIT_ROOT:+$GIT_ROOT/APPROVALS.md}"

# Temp files for APPROVALS.md sections (cleaned up on exit).
OPEN_TMP=$(mktemp)
CLOSED_TMP=$(mktemp)
_git_tmpdir=""
trap 'rm -f "$OPEN_TMP" "$CLOSED_TMP"; [ -n "$_git_tmpdir" ] && rm -rf "$_git_tmpdir"' EXIT

QUEUE_DIR=".queue"
FOUND_GATES=0
NEEDS_REGEN=0
found_warnings=0

# ---------------------------------------------------------------------------
# Tier 1: Network share transport (sync before reconciliation loop)
# ---------------------------------------------------------------------------

_share_path=""
if command -v jq >/dev/null 2>&1 && [ -f "config/tools.json" ]; then
  _share_path=$(jq -r '.approvals.share_path // empty' config/tools.json 2>/dev/null || true)
fi

if [ -n "$_share_path" ] && [ "$_share_path" != "null" ]; then
  _share_signoffs="$_share_path/sign-offs"
  _share_reachable=0

  # Write-probe: `test -d` alone passes on stale NFS mounts; touch+rm confirms real I/O
  if command -v timeout >/dev/null 2>&1; then
    _probe="$_share_path/.claude-probe"
    if timeout 5 test -d "$_share_path" 2>/dev/null && \
       timeout 5 touch "$_probe" 2>/dev/null && \
       timeout 5 rm -f "$_probe" 2>/dev/null; then
      _share_reachable=1
    fi
  else
    _probe="$_share_path/.claude-probe"
    if test -d "$_share_path" 2>/dev/null && \
       touch "$_probe" 2>/dev/null && \
       rm -f "$_probe" 2>/dev/null; then
      _share_reachable=1
    fi
  fi

  if [ "$_share_reachable" -eq 1 ]; then
    mkdir -p "$_share_signoffs"

    # --- Queue drain: retry sign-offs that failed to reach the share last run ---
    if [ -d "$QUEUE_DIR" ]; then
      while IFS= read -r -d '' qf; do
        so_name=$(basename "${qf%.network-share}")
        so_src="$SIGNOFFS_DIR/$so_name"
        if [ -f "$so_src" ]; then
          sync_signoff "$so_src" "$_share_signoffs/$so_name" && rm -f "$qf"
        else
          rm -f "$qf"  # stale queue entry — source sign-off no longer exists
        fi
      done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.network-share" -print0 2>/dev/null)
    fi

    # --- Outbox: push local sign-offs to share (newer local wins) ---
    if [ -d "$SIGNOFFS_DIR" ]; then
      while IFS= read -r -d '' sf; do
        sync_signoff "$sf" "$_share_signoffs/$(basename "$sf")"
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
    fi

    # --- Inbox: pull new remote sign-offs not yet present locally ---
    while IFS= read -r -d '' rf; do
      so_name=$(basename "$rf")
      so_local="$SIGNOFFS_DIR/$so_name"
      if [ ! -f "$so_local" ]; then
        cp "$rf" "$so_local"
        echo "[approval-reconcile] pulled $so_name from share" >&2
      fi
    done < <(find "$_share_signoffs" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)

  else
    # Share unreachable — queue local sign-offs so they sync on the next run
    echo "[approval-reconcile] WARN: share unreachable ($_share_path) — queuing local sign-offs" >&2
    if [ -d "$SIGNOFFS_DIR" ]; then
      mkdir -p "$QUEUE_DIR"
      while IFS= read -r -d '' sf; do
        so_name=$(basename "$sf")
        qf="$QUEUE_DIR/$so_name.network-share"
        [ -f "$qf" ] || touch "$qf"
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Tier 2: Git transport (sync before reconciliation loop)
# Auth (SSH key, credential helper, GIT_ASKPASS, etc.) must be configured
# out-of-band — this hook does not manage credentials.
# Shallow clone limitation: concurrent pushes can cause push-ancestry failures;
# pull --rebase before push handles the common case, but does not cover
# force-pushed remotes. Re-queue on any failure; the next run retries.
# ---------------------------------------------------------------------------

_git_repo=""
if command -v jq >/dev/null 2>&1 && [ -f "config/tools.json" ]; then
  _git_repo=$(jq -r '.approvals.git_repo // empty' config/tools.json 2>/dev/null || true)
fi

if [ -n "$_git_repo" ] && [ "$_git_repo" != "null" ]; then
  _git_reachable=0
  _git_outbox_files=""

  if command -v git >/dev/null 2>&1; then
    _git_tmpdir=$(mktemp -d)
    if timeout 30 git clone --depth=1 --quiet "$_git_repo" "$_git_tmpdir" 2>/dev/null; then
      _git_reachable=1
    else
      rm -rf "$_git_tmpdir"
      _git_tmpdir=""
    fi
  fi

  if [ "$_git_reachable" -eq 1 ]; then
    git -C "$_git_tmpdir" config user.email "approval-reconcile@localhost"
    git -C "$_git_tmpdir" config user.name "approval-reconcile"

    # --- Queue drain: retry sign-offs that failed to push last run ---
    if [ -d "$QUEUE_DIR" ]; then
      while IFS= read -r -d '' qf; do
        so_name=$(basename "${qf%.git-transport}")
        so_src="$SIGNOFFS_DIR/$so_name"
        if [ -f "$so_src" ]; then
          if sync_signoff_git "$so_src" "$_git_tmpdir/$so_name"; then
            _git_outbox_files="$_git_outbox_files $so_name"
          fi
          rm -f "$qf"
        else
          rm -f "$qf"  # stale queue entry
        fi
      done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.git-transport" -print0 2>/dev/null)
    fi

    # --- Outbox: stage local sign-offs for push ---
    if [ -d "$SIGNOFFS_DIR" ]; then
      while IFS= read -r -d '' sf; do
        if sync_signoff_git "$sf" "$_git_tmpdir/$(basename "$sf")"; then
          _git_outbox_files="$_git_outbox_files $(basename "$sf")"
        fi
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" \
                 -not -name ".gitkeep" -not -name "*.conflict.md" -print0 2>/dev/null)
    fi

    # --- Inbox: pull remote sign-offs not yet present locally ---
    while IFS= read -r -d '' rf; do
      so_name=$(basename "$rf")
      so_local="$SIGNOFFS_DIR/$so_name"
      if [ ! -f "$so_local" ]; then
        cp "$rf" "$so_local"
        echo "[approval-reconcile] pulled $so_name from git" >&2
      fi
    done < <(find "$_git_tmpdir" -maxdepth 1 -name "*.md" \
               -not -name ".gitkeep" -not -name "README.md" \
               -not -name "*.conflict.md" -print0 2>/dev/null)

    # --- Commit + push only if outbox contributed files ---
    if [ -n "${_git_outbox_files## }" ]; then
      _now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      _hostname=$(hostname 2>/dev/null || echo "unknown")
      git -C "$_git_tmpdir" add -A
      git -C "$_git_tmpdir" commit -q -m "sign-off sync [$_hostname] $_now_iso" 2>/dev/null || true

      _push_ok=0
      if timeout 30 git -C "$_git_tmpdir" pull --rebase --quiet 2>/dev/null && \
         timeout 30 git -C "$_git_tmpdir" push --quiet 2>/dev/null; then
        _push_ok=1
        echo "[approval-reconcile] pushed sign-off(s) to git" >&2
      fi

      if [ "$_push_ok" -eq 0 ]; then
        echo "[approval-reconcile] WARN: git push failed — re-queuing for next run" >&2
        mkdir -p "$QUEUE_DIR"
        for _so in $_git_outbox_files; do
          [ -z "$_so" ] && continue
          _qf="$QUEUE_DIR/$_so.git-transport"
          [ -f "$_qf" ] || touch "$_qf"
        done
      fi
    fi

  else
    # Git transport unreachable — queue local sign-offs
    echo "[approval-reconcile] WARN: git transport unreachable ($_git_repo) — queuing local sign-offs" >&2
    if [ -d "$SIGNOFFS_DIR" ]; then
      mkdir -p "$QUEUE_DIR"
      while IFS= read -r -d '' sf; do
        so_name=$(basename "$sf")
        qf="$QUEUE_DIR/$so_name.git-transport"
        [ -f "$qf" ] || touch "$qf"
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Tier 3: MCP connector transport (sync before reconciliation loop)
# Connector operation contract is deferred (RFC §3.7). When approvals.mcp.connector
# is set, sign-offs are queued as .mcp entries and Claude is prompted to sync via
# the named connector. Actual MCP calls are Claude's responsibility after reading
# the hook output. Queue entries persist until the connector confirms sync and
# removes them.
# ---------------------------------------------------------------------------

_mcp_connector=""
if command -v jq >/dev/null 2>&1 && [ -f "config/tools.json" ]; then
  _mcp_connector=$(jq -r '.approvals.mcp.connector // empty' config/tools.json 2>/dev/null || true)
fi

if [ -n "$_mcp_connector" ] && [ "$_mcp_connector" != "null" ]; then
  _mcp_queued=0

  # Queue any sign-offs not yet marked for MCP sync
  if [ -d "$SIGNOFFS_DIR" ]; then
    mkdir -p "$QUEUE_DIR"
    while IFS= read -r -d '' sf; do
      so_name=$(basename "$sf")
      qf="$QUEUE_DIR/$so_name.mcp"
      [ -f "$qf" ] || touch "$qf"
    done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" \
               -not -name ".gitkeep" -not -name "*.conflict.md" -print0 2>/dev/null)
  fi

  # Drain: count pending MCP sync entries and emit prompt for Claude
  if [ -d "$QUEUE_DIR" ]; then
    while IFS= read -r -d '' qf; do
      _mcp_queued=$(( _mcp_queued + 1 ))
    done < <(find "$QUEUE_DIR" -maxdepth 1 -name "*.mcp" -print0 2>/dev/null)
  fi

  if [ "$_mcp_queued" -gt 0 ]; then
    echo "[approval-reconcile] MCP connector '$_mcp_connector' configured — $_mcp_queued sign-off(s) queued for MCP transport. Connector contract is deferred; check your MCP connector docs for sync semantics." >&2
  fi
fi

# ---------------------------------------------------------------------------
# Step 1: check for leftover merge markers in existing APPROVALS.md
# ---------------------------------------------------------------------------

if [ -n "$APPROVALS_FILE" ] && [ -f "$APPROVALS_FILE" ]; then
  if grep -qE '^(<{7}|={7}|>{7})' "$APPROVALS_FILE" 2>/dev/null; then
    echo "[approval-reconcile] APPROVALS.md has leftover merge markers — will regenerate" >&2
    NEEDS_REGEN=1
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: main reconciliation loop
# ---------------------------------------------------------------------------

while IFS= read -r -d '' gate_file; do
  roles=$(required_roles "$gate_file")
  [ -z "$roles" ] && continue

  FOUND_GATES=1
  gate_name=$(basename "$gate_file" .md)
  current_hash=$(gate_hash "$gate_file")
  header_printed=0
  all_signed=1
  missing_role_list=""
  entry_lines=""

  print_header() {
    if [ "$header_printed" -eq 0 ]; then
      echo "[approval-reconcile] Gate: $gate_name" >&2
      header_printed=1
      found_warnings=1
    fi
  }

  while IFS= read -r role; do
    [ -z "$role" ] && continue

    matched_file=""
    matched_signer=""
    matched_date=""
    hash_mismatch=0

    if [ -d "$SIGNOFFS_DIR" ]; then
      while IFS= read -r -d '' sf; do
        sf_gate_ref=$(frontmatter_field "$sf" "gate_ref")
        sf_role=$(frontmatter_field "$sf" "role")
        sf_gate_ref="${sf_gate_ref#./}"
        gate_file_norm="${gate_file#./}"

        if [ "$sf_role" = "$role" ] && [ "$sf_gate_ref" = "$gate_file_norm" ]; then
          matched_file="$sf"
          matched_signer=$(frontmatter_field "$sf" "signer")
          matched_date=$(frontmatter_field "$sf" "timestamp" | cut -c1-10)
          sf_hash=$(frontmatter_field "$sf" "gate_hash")
          sf_hash="${sf_hash#sha256:}"
          if [ -n "$sf_hash" ] && [ "$sf_hash" != "$current_hash" ]; then
            hash_mismatch=1
          fi
          break
        fi
      done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
    fi

    if [ -z "$matched_file" ]; then
      all_signed=0
      missing_role_list="${missing_role_list}${missing_role_list:+, }$role"
      entry_lines="${entry_lines}  - [ ] $role — (pending)\n"
    else
      entry_lines="${entry_lines}  - [x] $role — $matched_signer — $matched_date\n"
      if [ "$hash_mismatch" -eq 1 ]; then
        print_header
        echo "  ⚠ gate content changed since $role signed — $(basename "$matched_file")" >&2
      fi
    fi
  done <<< "$roles"

  # Stderr warnings for missing roles
  if [ -n "$missing_role_list" ]; then
    print_header
    # shellcheck disable=SC2086
    for r in ${missing_role_list//,/ }; do
      [ -z "$r" ] && continue
      echo "  ✗ missing sign-off: $r" >&2
    done
  fi

  if [ "$header_printed" -eq 1 ]; then
    echo "  Sign-off template: templates/sign-off-multi.md → $SIGNOFFS_DIR/<REQ-ID>-<role>.md" >&2
  fi

  # Collect into APPROVALS.md sections
  if [ "$all_signed" -eq 1 ]; then
    {
      echo "- $gate_name — all sign-offs received"
      printf "%b" "$entry_lines"
    } >> "$CLOSED_TMP"
  else
    {
      echo "- $gate_name — waiting on: $missing_role_list"
      printf "%b" "$entry_lines"
    } >> "$OPEN_TMP"
  fi

done < <(find "$GATES_DIR" -name "*.md" -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Step 3: orphan sign-off detection
# ---------------------------------------------------------------------------

if [ -d "$SIGNOFFS_DIR" ]; then
  while IFS= read -r -d '' sf; do
    sf_gate_ref=$(frontmatter_field "$sf" "gate_ref")
    [ -z "$sf_gate_ref" ] && continue
    sf_gate_ref="${sf_gate_ref#./}"
    if [ ! -f "$sf_gate_ref" ]; then
      echo "[approval-reconcile] Orphan sign-off: $(basename "$sf") — gate_ref '$sf_gate_ref' not found" >&2
      found_warnings=1
    fi
  done < <(find "$SIGNOFFS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Step 4: APPROVALS.md mtime check + generation
# ---------------------------------------------------------------------------

[ "$FOUND_GATES" -eq 0 ] && exit 0
[ -z "$GIT_ROOT" ]        && exit 0

# Compare sign-offs dir mtime against the epoch embedded in APPROVALS.md.
if [ "$NEEDS_REGEN" -eq 0 ]; then
  signoffs_mtime=$(dir_mtime "$SIGNOFFS_DIR")
  if [ -f "$APPROVALS_FILE" ]; then
    stored_epoch=$(grep -m1 '<!-- generated-epoch:' "$APPROVALS_FILE" \
                   | grep -o '[0-9][0-9]*' | head -1 || echo 0)
    stored_epoch="${stored_epoch:-0}"
    if [ "$signoffs_mtime" -gt "$stored_epoch" ]; then
      NEEDS_REGEN=1
    fi
  else
    NEEDS_REGEN=1
  fi
fi

if [ "$NEEDS_REGEN" -eq 1 ]; then
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NOW_EPOCH=$(date +%s)

  {
    echo "# Approvals"
    echo ""
    echo "> Generated from \`.claude/sdlc/sign-offs/\` by \`approval-reconcile.sh\`. Do not edit by hand."
    echo "> Last generated: $NOW_ISO"
    echo ">"
    echo "> **On git merge conflict:** accept either side. The reconciler regenerates from"
    echo "> \`sign-offs/\` on its next run and warns if it detects leftover merge markers."
    echo ""
    echo "<!-- generated-epoch: $NOW_EPOCH -->"
    echo ""
    echo "## Open"
    echo ""
    if [ -s "$OPEN_TMP" ]; then
      cat "$OPEN_TMP"
    else
      echo "*(none)*"
    fi
    echo ""
    echo "## Closed"
    echo ""
    if [ -s "$CLOSED_TMP" ]; then
      cat "$CLOSED_TMP"
    else
      echo "*(none)*"
    fi
  } > "$APPROVALS_FILE"

  echo "[approval-reconcile] APPROVALS.md regenerated at $APPROVALS_FILE" >&2
fi

exit 0
