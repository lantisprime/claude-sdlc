#!/usr/bin/env bash
# token-tracker.sh — Stop hook. Parses the current session's Claude Code
# transcript, aggregates per-call `usage` into SDLC phase buckets using gate
# file mtimes as boundaries, and writes raw token counts to
# .claude/sdlc/token-log.json (snapshot) and token-history.jsonl (rolling).
#
# Records raw dimensions only: input, output, cache_creation, cache_read.
# Pricing/cost models live in a separate reporting layer.
#
# Non-blocking: always exits 0. Silently no-ops when disabled, when jq is
# missing, when the transcript cannot be resolved, or when no usage entries
# are found.
set -euo pipefail
[ -f ".claude/sdlc/.enabled" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

CONFIG=".claude/sdlc/config/tools.json"
[ -f "$CONFIG" ] || CONFIG="config/tools.json"
if [ -f "$CONFIG" ]; then
  ENABLED=$(jq -r '.token_tracking.enabled // false' "$CONFIG" 2>/dev/null || echo false)
  [ "$ENABLED" = "true" ] || exit 0
else
  exit 0
fi

OUT_DIR=".claude/sdlc"
[ -d "$OUT_DIR" ] || exit 0

# Resolve transcript path. Stop hooks receive {session_id, transcript_path}
# on stdin; fall back to newest JSONL under the project's session dir.
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat || true)
fi

TRANSCRIPT=""
if [ -n "$STDIN_JSON" ]; then
  TRANSCRIPT=$(printf '%s' "$STDIN_JSON" | jq -r '.transcript_path // empty' 2>/dev/null || true)
fi

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  SLUG=$(pwd | sed 's|/|-|g')
  SESSION_DIR="$HOME/.claude/projects/$SLUG"
  if [ -d "$SESSION_DIR" ]; then
    TRANSCRIPT=$(find "$SESSION_DIR" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null \
      | xargs -0 ls -t 2>/dev/null | head -n 1 || true)
  fi
fi

[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Collect gate boundaries: "<epoch>\t<phase>", sorted by mtime ascending.
GATES_DIR="$OUT_DIR/gates"
GATES_TSV=""
if [ -d "$GATES_DIR" ]; then
  GATES_TSV=$(find "$GATES_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null \
    | while IFS= read -r f; do
        base=$(basename "$f" .md)
        phase=${base%%-*}
        mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
        printf '%s\t%s\n' "$mtime" "$phase"
      done \
    | sort -n || true)
fi

# Derive task slug from the most recent gate filename (best effort).
TASK_SLUG=$(
  if [ -d "$GATES_DIR" ]; then
    find "$GATES_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null \
      | xargs ls -t 2>/dev/null | head -n 1 \
      | sed 's|.*/||; s|\.md$||; s|^[^-]*-||' || true
  fi
)
[ -n "$TASK_SLUG" ] || TASK_SLUG="unknown-task"

# Extract {ts_epoch, in, out, cc, cr} per transcript line that has a usage object.
# Usage may sit at .usage or .message.usage depending on record type.
USAGE_TSV=$(
  jq -r '
    . as $r
    | ($r.message.usage // $r.usage // empty) as $u
    | select($u != null)
    | ($r.timestamp // $r.message.timestamp // "") as $ts
    | ($ts | if . == "" then 0 else (fromdateiso8601? // 0) end) as $epoch
    | [$epoch,
       ($u.input_tokens // 0),
       ($u.output_tokens // 0),
       ($u.cache_creation_input_tokens // 0),
       ($u.cache_read_input_tokens // 0)]
    | @tsv
  ' "$TRANSCRIPT" 2>/dev/null || true
)

[ -n "$USAGE_TSV" ] || exit 0

# Attribute each usage entry to a phase bucket, then aggregate.
# Phase order assumed: plan, analyze, design, build, test, deploy, support, docs.
SUMMARY=$(
  {
    printf 'GATES\n%s\nUSAGE\n%s\n' "$GATES_TSV" "$USAGE_TSV"
  } | awk -F'\t' '
    BEGIN { mode=""; ng=0 }
    /^GATES$/ { mode="G"; next }
    /^USAGE$/ { mode="U"; next }
    mode=="G" && NF==2 { gm[ng]=$1; gp[ng]=$2; ng++; next }
    mode=="U" && NF==5 {
      epoch=$1; inp=$2; out=$3; cc=$4; cr=$5
      phase=""
      for (i=0; i<ng; i++) {
        if (epoch <= gm[i]) { phase=gp[i]; break }
      }
      if (phase=="") phase = (ng>0 ? "docs" : "unattributed")
      I[phase]+=inp; O[phase]+=out; CC[phase]+=cc; CR[phase]+=cr
      TI+=inp; TO+=out; TCC+=cc; TCR+=cr
    }
    END {
      printf "{\"phases\":{"
      first=1
      for (p in I) {
        if (!first) printf ","; first=0
        printf "\"%s\":{\"input\":%d,\"output\":%d,\"cache_creation\":%d,\"cache_read\":%d}",
               p, I[p], O[p], CC[p], CR[p]
      }
      printf "},\"totals\":{\"input\":%d,\"output\":%d,\"cache_creation\":%d,\"cache_read\":%d}}",
             TI+0, TO+0, TCC+0, TCR+0
    }
  '
)

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SNAPSHOT=$(printf '%s' "$SUMMARY" | jq --arg slug "$TASK_SLUG" --arg at "$NOW" --arg tr "$TRANSCRIPT" \
  '. + {task_slug:$slug, completed_at:$at, transcript:$tr}')

printf '%s\n' "$SNAPSHOT" | jq '.' > "$OUT_DIR/token-log.json" 2>/dev/null || true
printf '%s\n' "$SNAPSHOT" >> "$OUT_DIR/token-history.jsonl" 2>/dev/null || true

echo "[token-tracker] wrote $OUT_DIR/token-log.json (task=$TASK_SLUG)" >&2
exit 0
