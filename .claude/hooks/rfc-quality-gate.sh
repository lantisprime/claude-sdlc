#!/usr/bin/env bash
# rfc-quality-gate.sh — PostToolUse hook for Edit/Write/MultiEdit.
# Runs status-driven grep checks on RFC files in docs/rfcs/.
# Per RFC-006 Change 1. Maintainer-only — installed in .claude/hooks/, not
# shipped to consuming repos.
#
# Behavior: warn (exit 0). Always exits 0; warnings go to stderr with the
# [rfc-gate] WARN: prefix.
set -euo pipefail

# Read PostToolUse JSON from stdin and extract the file_path.
# We avoid jq (not always installed) and use a small grep/sed instead.
INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

FILE_PATH=$(printf '%s' "$INPUT" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 \
  | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
[ -n "$FILE_PATH" ] || exit 0

# Self-filter: only act on files under docs/rfcs/ that are RFC files.
case "$FILE_PATH" in
    */docs/rfcs/*.md) ;;
    *) exit 0 ;;
esac
case "$FILE_PATH" in
    */TEMPLATE.md|*/README.md|*/pending-analysis.md) exit 0 ;;
    */docs/rfcs/notes/*) exit 0 ;;
    */docs/rfcs/archived/*) exit 0 ;;
esac

# Gracefully exit if the file no longer exists.
[ -f "$FILE_PATH" ] || exit 0

warn() {
    echo "[rfc-gate] WARN: $*" >&2
}

# --- Common checks (all statuses) ---

for heading in '## AI context' '## Problem' '## Proposal' '## Alternatives considered'; do
    if ! grep -qxF "$heading" "$FILE_PATH"; then
        warn "${FILE_PATH##*/}: required heading missing — '${heading}'"
    fi
done

LAST_MOD=$(grep -E '^last_modified:[[:space:]]*' "$FILE_PATH" | head -1 | sed -E 's/^last_modified:[[:space:]]*//')
TODAY=$(date -u +%Y-%m-%d)
if [ -n "$LAST_MOD" ] && [ "$LAST_MOD" != "$TODAY" ]; then
    warn "${FILE_PATH##*/}: last_modified ($LAST_MOD) does not match today ($TODAY) — bump it on edit"
fi

# --- Status-driven checks ---

STATUS=$(grep -E '^status:[[:space:]]*' "$FILE_PATH" | head -1 | sed -E 's/^status:[[:space:]]*//' | tr -d '"')
[ -n "$STATUS" ] || exit 0

case "$STATUS" in
    accepted)
        # Second-opinion decision must be 'proceed', not absent or 'revise first'.
        if ! grep -q '^## Second opinion' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status accepted but '## Second opinion' section is missing"
        elif grep -q '\*\*Decision:\*\*[[:space:]]*revise first' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status accepted but '**Decision:** revise first' is recorded — flip to 'proceed' or revert status"
        elif ! grep -q '\*\*Decision:\*\*[[:space:]]*proceed' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status accepted but '## Second opinion' lacks '**Decision:** proceed'"
        fi

        # Implementation plan must be non-stub: ### PR-N subheading or non-_example_ row.
        if ! grep -q '^## Implementation plan' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status accepted but '## Implementation plan' section is missing"
        else
            PLAN_BODY=$(awk '/^## Implementation plan/{flag=1; next} /^## /{flag=0} flag' "$FILE_PATH")
            if echo "$PLAN_BODY" | grep -qE '^### PR-[0-9]'; then
                : # ok — has PR-N subheading
            elif echo "$PLAN_BODY" | grep -qE '^\| [0-9]+ \|' && ! echo "$PLAN_BODY" | grep -q '_example'; then
                : # ok — table format with non-example rows (legacy RFCs)
            else
                warn "${FILE_PATH##*/}: status accepted but '## Implementation plan' looks like a stub (no '### PR-N' subheadings or only example rows)"
            fi
        fi
        ;;

    implemented)
        # Implementation table must have at least one non-placeholder row.
        if ! grep -q '^## Implementation' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status implemented but '## Implementation' section is missing"
        else
            # Look for at least one data row (after the |--- separator) that
            # is not the abc1234 placeholder.
            if ! awk '
                /^## Implementation$/ { in_impl=1; next }
                /^## / { in_impl=0 }
                in_impl && /^\|[ -]*-+/ { after_sep=1; next }
                in_impl && after_sep && /^\| / && !/abc1234/ { found=1; exit }
                END { exit (found ? 0 : 1) }
            ' "$FILE_PATH"; then
                warn "${FILE_PATH##*/}: status implemented but '## Implementation' table has only placeholder rows ('abc1234') or no data rows"
            fi
        fi
        ;;

    deferred)
        if ! grep -q '^## Deferral note' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status deferred but '## Deferral note' section is missing"
        else
            # Pipe failure-safe (set -o pipefail + grep no-match = non-zero).
            BODY=$(awk '/^## Deferral note/{flag=1; next} /^## /{flag=0} flag' "$FILE_PATH" 2>/dev/null \
                   | grep -vE '^>|^[[:space:]]*$' 2>/dev/null | head -3 || true)
            [ -n "$BODY" ] || warn "${FILE_PATH##*/}: '## Deferral note' is empty — populate reason and unpark conditions"
        fi
        ;;

    withdrawn)
        if ! grep -q '^## Withdrawal note' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status withdrawn but '## Withdrawal note' section is missing"
        else
            BODY=$(awk '/^## Withdrawal note/{flag=1; next} /^## /{flag=0} flag' "$FILE_PATH" 2>/dev/null \
                   | grep -vE '^>|^[[:space:]]*$' 2>/dev/null | head -3 || true)
            [ -n "$BODY" ] || warn "${FILE_PATH##*/}: '## Withdrawal note' is empty — populate reason"
        fi
        ;;

    superseded)
        if ! grep -qE '^superseded_by:[[:space:]]*RFC-' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status superseded but 'superseded_by:' frontmatter is missing or unset"
        fi
        if ! grep -q '^## Supersession note' "$FILE_PATH"; then
            warn "${FILE_PATH##*/}: status superseded but '## Supersession note' section is missing"
        else
            BODY=$(awk '/^## Supersession note/{flag=1; next} /^## /{flag=0} flag' "$FILE_PATH" 2>/dev/null \
                   | grep -vE '^>|^[[:space:]]*$' 2>/dev/null | head -3 || true)
            [ -n "$BODY" ] || warn "${FILE_PATH##*/}: '## Supersession note' is empty — point to the superseding RFC"
        fi
        ;;

    draft)
        : # Draft RFCs only get the common checks above.
        ;;

    *)
        warn "${FILE_PATH##*/}: unknown status '$STATUS' — expected one of draft|accepted|deferred|implemented|withdrawn|superseded"
        ;;
esac

exit 0
