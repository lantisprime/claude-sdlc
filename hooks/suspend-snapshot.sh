#!/usr/bin/env bash
# suspend-snapshot.sh — Governance snapshot for /suspend + re-enable verification.
#
# suspend mode: hash governance + in-scope source files, encrypt (AES-256 via openssl),
#               store key in config/tools.local.json, write snapshot to
#               .claude/sdlc/.suspension-snapshot.enc.
#
# verify  mode: decrypt snapshot, two-pass compare (stat then sha256), classify
#               changes by severity, emit plan-keyed JSON to stdout.
#
# Usage:
#   suspend-snapshot.sh suspend   → creates snapshot; exits 0 on success, 1 on error
#   suspend-snapshot.sh verify    → writes diff JSON to stdout; exits 0 always
#
# Requires python3 (used for JSON work — already a repo dependency via env-detect.sh).
set -euo pipefail

SDLC_DIR=".claude/sdlc"
SNAPSHOT="${SDLC_DIR}/.suspension-snapshot.enc"
META_LOCAL="config/tools.local.json"
CONFIG="config/tools.json"
PLANS="${SDLC_DIR}/plans"
GATES="${SDLC_DIR}/gates"
SIGNOFFS="${SDLC_DIR}/sign-offs"

# --- Utilities ---

require_python3() {
  command -v python3 >/dev/null 2>&1 || {
    echo "[suspend-snapshot] ERROR: python3 is required for snapshot operations. Install python3 and retry." >&2
    exit 1
  }
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

file_mtime() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

file_size() {
  wc -c < "$1" | tr -d ' '
}

extract_req_id() {
  grep -oE '\*\*Reference:\*\*[[:space:]]*REQ-[0-9]+' "$1" 2>/dev/null \
    | grep -oE 'REQ-[0-9]+' | head -1 \
    || grep -oE 'REQ-[0-9]+' "$1" 2>/dev/null | head -1 \
    || echo ""
}

parse_inscope_files() {
  awk '/^## In-scope files/{f=1;next} f && /^- /{gsub(/^[[:space:]]*-[[:space:]]*/,"",$0); print $1; next} f && /^##/{exit}' "$1" 2>/dev/null
}

ensure_gitignored() {
  local path="$1"
  local gi=".gitignore"
  [ -d .git ] || return 0
  if [ -f "$gi" ] && grep -qF "$path" "$gi" 2>/dev/null; then
    return 0
  fi
  echo "$path" >> "$gi"
  echo "[suspend-snapshot] Added $path to .gitignore" >&2
}

# --- Suspend mode ---

do_suspend() {
  require_python3

  # Refuse if tools.local.json is git-tracked (key would be exposed)
  if git ls-files --error-unmatch "$META_LOCAL" 2>/dev/null; then
    echo "[suspend-snapshot] ERROR: $META_LOCAL is tracked by git. Cannot safely store the suspension key." >&2
    echo "Add $META_LOCAL to .gitignore before running /suspend." >&2
    exit 1
  fi

  # Check openssl — offer plain fallback with explicit confirmation
  use_openssl=false
  if command -v openssl >/dev/null 2>&1; then
    use_openssl=true
  else
    echo "" >&2
    echo "[SDLC] WARNING: openssl not found. Snapshot will use plain SHA-256 manifest." >&2
    echo "Tamper detection is weaker — changes to governance files may go undetected." >&2
    printf "Continue with weakened integrity check? [Y/n] " >&2
    read -r answer </dev/tty
    case "${answer:-Y}" in
      [nN]*) echo "Suspend aborted. Workflow remains enabled." >&2; exit 0 ;;
    esac
  fi

  mkdir -p "$SDLC_DIR"
  local suspended_at
  suspended_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build TSV file list: category<TAB>path<TAB>req_id
  local tmp_tsv
  tmp_tsv=$(mktemp)

  # Global governance files
  for f in "${SDLC_DIR}/scope.md" "$CONFIG"; do
    [ -f "$f" ] || continue
    printf "governance\t%s\t_global\n" "$f" >> "$tmp_tsv"
  done

  # Per-REQ governance files (plans, gates, sign-offs)
  for dir in "$PLANS" "$GATES" "$SIGNOFFS"; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      req=$(extract_req_id "$f")
      [ -z "$req" ] && req="_unknown"
      printf "governance\t%s\t%s\n" "$f" "$req" >> "$tmp_tsv"
    done < <(find "$dir" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
  done

  # Source files from active (non-versioned) plans
  if [ -d "$PLANS" ]; then
    while IFS= read -r plan_file; do
      [ -f "$plan_file" ] || continue
      req=$(extract_req_id "$plan_file")
      [ -z "$req" ] && req="_unknown"
      while IFS= read -r src; do
        [ -z "$src" ] && continue
        [ -f "$src" ] || continue
        printf "source\t%s\t%s\n" "$src" "$req" >> "$tmp_tsv"
      done < <(parse_inscope_files "$plan_file")
    done < <(find "$PLANS" -maxdepth 1 -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null | sort)
  fi

  # Build manifest JSON via python3
  local tmp_manifest
  tmp_manifest=$(mktemp)

  python3 - "$suspended_at" "$use_openssl" < "$tmp_tsv" > "$tmp_manifest" <<'PYEOF'
import sys, json, hashlib, os

def sha256_of(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

suspended_at = sys.argv[1]
use_openssl = sys.argv[2] == "true"

governance, source = [], []
for line in sys.stdin:
    parts = line.rstrip('\n').split('\t', 2)
    if len(parts) != 3:
        continue
    category, path, req_id = parts
    if not os.path.isfile(path):
        continue
    try:
        sha = sha256_of(path)
        size = os.path.getsize(path)
        mtime = int(os.path.getmtime(path))
    except OSError:
        continue
    entry = {"path": path, "sha256": sha, "size": size, "mtime": mtime, "req_id": req_id}
    (governance if category == "governance" else source).append(entry)

print(json.dumps({
    "suspended_at": suspended_at,
    "encrypted": use_openssl,
    "governance": governance,
    "source": source,
}, indent=2))
PYEOF

  rm -f "$tmp_tsv"

  # Encrypt or write plain
  if [ "$use_openssl" = true ]; then
    local key
    key=$(openssl rand -hex 32)
    openssl enc -aes-256-cbc -pbkdf2 \
      -k "$key" -in "$tmp_manifest" -out "$SNAPSHOT" 2>/dev/null
    rm -f "$tmp_manifest"
    _write_meta "$key" "aes256" "$suspended_at"
  else
    mv "$tmp_manifest" "$SNAPSHOT"
    _write_meta "" "plain" "$suspended_at"
  fi

  ensure_gitignored "$META_LOCAL"
  echo "[suspend-snapshot] Snapshot saved to $SNAPSHOT"
}

_write_meta() {
  local key="$1" format="$2" ts="$3"
  mkdir -p "$(dirname "$META_LOCAL")"
  python3 - "$META_LOCAL" "$key" "$format" "$ts" <<'PYEOF'
import sys, json, os

meta_path, key, fmt, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {}
if os.path.isfile(meta_path):
    try:
        with open(meta_path) as f:
            data = json.load(f)
    except Exception:
        pass  # corrupt — start fresh, preserve nothing
data["suspension_key"] = key
data["suspension_format"] = fmt
data["suspended_at"] = ts
with open(meta_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
}

# --- Verify mode ---

do_verify() {
  require_python3

  if [ ! -f "$SNAPSHOT" ]; then
    echo '{"error":"no_snapshot","plans":{},"clean_plan_count":0}'
    exit 0
  fi

  if [ ! -f "$META_LOCAL" ]; then
    echo '{"error":"no_meta","degraded":true,"plans":{},"clean_plan_count":0}'
    exit 0
  fi

  # Read metadata
  local meta_out key format suspended_at
  meta_out=$(python3 - "$META_LOCAL" <<'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    print(d.get("suspension_key", ""))
    print(d.get("suspension_format", "plain"))
    print(d.get("suspended_at", ""))
except Exception:
    print(""); print("plain"); print("")
PYEOF
)
  key=$(echo "$meta_out"  | sed -n '1p')
  format=$(echo "$meta_out" | sed -n '2p')
  suspended_at=$(echo "$meta_out" | sed -n '3p')

  local tmp_manifest degraded=false
  tmp_manifest=$(mktemp)

  if [ "$format" = "aes256" ]; then
    if [ -z "$key" ]; then
      echo "[SDLC] WARNING: Snapshot key not found. Tamper detection is degraded." >&2
      printf "Continue with plain-manifest fallback? [Y/n] " >&2
      read -r ans </dev/tty
      case "${ans:-Y}" in
        [nN]*) echo '{"error":"key_missing_refused"}'; rm -f "$tmp_manifest"; exit 0 ;;
      esac
      degraded=true
      cp "$SNAPSHOT" "$tmp_manifest" 2>/dev/null || true
    else
      # Check 90-day expiry
      if [ -n "$suspended_at" ]; then
        local age_days=0
        age_days=$(python3 - "$suspended_at" <<'PYEOF'
import sys
from datetime import datetime, timezone
try:
    ts = datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00'))
    print(int((datetime.now(timezone.utc) - ts).total_seconds() / 86400))
except Exception:
    print(0)
PYEOF
)
        if [ "$age_days" -gt 90 ] 2>/dev/null; then
          echo "[SDLC] WARNING: Snapshot key is ${age_days} days old (90-day limit). Tamper detection is degraded." >&2
          printf "Continue with weakened integrity check? [Y/n] " >&2
          read -r ans </dev/tty
          case "${ans:-Y}" in
            [nN]*) echo '{"error":"key_expired_refused"}'; rm -f "$tmp_manifest"; exit 0 ;;
          esac
          degraded=true
        fi
      fi

      if [ "$degraded" = false ]; then
        if ! openssl enc -aes-256-cbc -pbkdf2 -d \
          -k "$key" -in "$SNAPSHOT" -out "$tmp_manifest" 2>/dev/null; then
          echo "[SDLC] WARNING: Snapshot decryption failed. Tamper detection is degraded." >&2
          printf "Continue with plain-manifest comparison only? [Y/n] " >&2
          read -r ans </dev/tty
          case "${ans:-Y}" in
            [nN]*) echo '{"error":"decryption_failed_refused"}'; rm -f "$tmp_manifest"; exit 0 ;;
          esac
          degraded=true
          cp "$SNAPSHOT" "$tmp_manifest" 2>/dev/null || true
        fi
      else
        cp "$SNAPSHOT" "$tmp_manifest" 2>/dev/null || true
      fi
    fi
  else
    cp "$SNAPSHOT" "$tmp_manifest"
  fi

  # Two-pass compare + plan-keyed output via python3
  python3 - "$tmp_manifest" "$degraded" <<'PYEOF'
import sys, json, hashlib, os

manifest_path = sys.argv[1]
degraded = sys.argv[2] == "true"

def sha256_of(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception:
    print(json.dumps({"error": "manifest_parse_failed", "plans": {}, "clean_plan_count": 0}))
    sys.exit(0)

all_entries = manifest.get("governance", []) + manifest.get("source", [])

# Pass 1 (stat): flag entries where size or mtime differ
s1 = []
for e in all_entries:
    path = e["path"]
    if not os.path.exists(path):
        # Deleted file — skip stat, mark immediately
        s1.append((e, "deleted"))
        continue
    try:
        cur_size = os.path.getsize(path)
        cur_mtime = int(os.path.getmtime(path))
    except OSError:
        s1.append((e, "unreadable"))
        continue
    if cur_size != e["size"] or cur_mtime != e["mtime"]:
        s1.append((e, "candidate"))

# Pass 2 (sha256): confirm which candidates actually changed
s2 = []
for e, status in s1:
    if status in ("deleted", "unreadable"):
        s2.append((e, status))
        continue
    try:
        cur_sha = sha256_of(e["path"])
    except OSError:
        s2.append((e, "unreadable"))
        continue
    if cur_sha != e["sha256"]:
        s2.append((e, "modified"))

# Check for new governance files not in manifest (HIGH)
manifest_paths = {e["path"] for e in all_entries}
gov_dirs = [".claude/sdlc/plans", ".claude/sdlc/gates", ".claude/sdlc/sign-offs",
            ".claude/sdlc/scope.md", "config/tools.json"]
for gdir in gov_dirs:
    if os.path.isfile(gdir) and gdir not in manifest_paths:
        s2.append(({"path": gdir, "sha256": "", "size": 0, "mtime": 0, "req_id": "_global"}, "new"))
    elif os.path.isdir(gdir):
        for fn in os.listdir(gdir):
            fp = os.path.join(gdir, fn)
            if fp not in manifest_paths and fn.endswith(".md"):
                req = "_unknown"
                try:
                    with open(fp) as f:
                        for line in f:
                            import re
                            m = re.search(r'REQ-\d+', line)
                            if m:
                                req = m.group(); break
                except Exception:
                    pass
                s2.append(({"path": fp, "sha256": "", "size": 0, "mtime": 0, "req_id": req}, "new"))

# Group S2 by req_id
plan_changes = {}   # req_id -> list of change dicts
global_changes = [] # _global req_id entries

for e, status in s2:
    req_id = e.get("req_id", "_unknown")
    cur_size = None
    if status not in ("deleted", "unreadable", "new"):
        try:
            cur_size = os.path.getsize(e["path"])
        except OSError:
            pass
    change = {
        "path": e["path"],
        "category": "governance" if e in manifest.get("governance", []) or e.get("req_id") == "_global" else "source",
        "status": status,
        "old_size": e["size"],
        "new_size": cur_size,
    }
    # Reclassify category based on which list the entry came from
    in_gov = any(g["path"] == e["path"] for g in manifest.get("governance", []))
    change["category"] = "governance" if in_gov or status == "new" else "source"

    if req_id == "_global":
        global_changes.append(change)
    else:
        plan_changes.setdefault(req_id, []).append(change)

# Compute severity per req_id
def compute_severity(changes):
    for c in changes:
        if c["category"] == "governance":
            return "HIGH"
        if c["status"] == "deleted":
            return "HIGH"
    # Source-only: apply drift threshold (>20% size or >5 files)
    source_changes = [c for c in changes if c["category"] == "source"]
    if len(source_changes) > 5:
        return "HIGH"
    for c in source_changes:
        old = c["old_size"] or 0
        new = c["new_size"] or 0
        if old > 0 and abs(new - old) / old > 0.20:
            return "HIGH"
    return "LOW"

# Build output
plans_out = {}
clean_plan_count = 0

# Count all req_ids seen in manifest governance entries
all_req_ids = {e["req_id"] for e in manifest.get("governance", []) + manifest.get("source", [])}
all_req_ids.discard("_global")
all_req_ids.discard("_unknown")

for req_id in all_req_ids:
    changes = plan_changes.get(req_id, [])
    if not changes:
        clean_plan_count += 1
        continue
    sev = compute_severity(changes)
    plans_out[req_id] = {
        "changed_files": changes,
        "severity": sev,
        "revert_candidates": [c["path"] for c in changes],
    }

# _global changes affect all active plans — surface as HIGH on each
if global_changes:
    for req_id in all_req_ids:
        if req_id not in plans_out:
            plans_out[req_id] = {"changed_files": [], "severity": "HIGH", "revert_candidates": []}
        plans_out[req_id]["changed_files"].extend(global_changes)
        plans_out[req_id]["severity"] = "HIGH"
        plans_out[req_id]["revert_candidates"].extend(c["path"] for c in global_changes)

# Cap warning: if _global changed and >20 active plans, note it
cap_warning = None
if global_changes and len(all_req_ids) > 20:
    cap_warning = (f"scope.md or tools.json changed — re-examination capped at 20 most-recently-modified "
                   f"active plans ({len(all_req_ids)} total). Offer explicit expansion.")

print(json.dumps({
    "plans": plans_out,
    "clean_plan_count": clean_plan_count,
    "degraded": degraded,
    "cap_warning": cap_warning,
}, indent=2))
PYEOF

  rm -f "$tmp_manifest"
}

# --- Dispatch ---

case "${1:-}" in
  suspend) do_suspend ;;
  verify)  do_verify  ;;
  *)
    echo "Usage: $0 suspend | verify" >&2
    exit 1
    ;;
esac
