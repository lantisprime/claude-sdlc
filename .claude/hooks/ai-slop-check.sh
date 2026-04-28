#!/usr/bin/env bash
# ai-slop-check.sh — PostToolUse hook for Edit/Write/MultiEdit.
# Scans markdown files under docs/ and rfcs/ for the six anti-pattern
# classes enumerated in sdlc-plugin/AGENT-RULES.md §12 "Writing and framing".
# Per RFC-006 Change 7. Maintainer-only — installed in .claude/hooks/, not
# shipped to consuming repos.
#
# Behavior: warn (always exit 0). Never auto-applies — proposals only.
#
# Closed pattern set: adding a seventh pattern class requires a follow-up RFC,
# not a quiet hook edit. Six classes:
#   1. Inflated metaphors
#   2. Manufactured persona
#   3. Formulaic triplets (flagged for human check — high false-positive rate)
#   4. False severity escalation
#   5. Unsupported compliance
#   6. Aspirational framing
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

FILE_PATH=$(printf '%s' "$INPUT" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 \
  | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
[ -n "$FILE_PATH" ] || exit 0

# Self-filter: only act on .md files under docs/ or rfcs/.
case "$FILE_PATH" in
    *.md) ;;
    *) exit 0 ;;
esac
case "$FILE_PATH" in
    */docs/*|*/rfcs/*) ;;
    *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

FILE_BASE="${FILE_PATH##*/}"

emit() {
    local lineno="$1" pclass="$2" matched="$3" fix="$4"
    echo "[ai-slop] WARN: ${FILE_BASE}:${lineno}: ${pclass} — \"${matched}\"" >&2
    echo "[ai-slop] PROPOSED FIX: ${fix}" >&2
}

# scan_pattern <pattern-class-label> <regex> <suggested-fix>
# Uses grep -inE; outputs one WARN per match. Pipe-failure-safe via || true.
scan_pattern() {
    local label="$1" regex="$2" fix="$3"
    local match lineno text
    while IFS=: read -r lineno text; do
        [ -z "$lineno" ] && continue
        # Trim leading whitespace from text; cap length to avoid spam.
        text=$(printf '%s' "$text" | sed -E 's/^[[:space:]]+//' | cut -c1-120)
        emit "$lineno" "$label" "$text" "$fix"
    done < <(grep -inE "$regex" "$FILE_PATH" 2>/dev/null || true)
}

# --- 1. Inflated metaphors ---
scan_pattern \
    "inflated metaphor" \
    '(trojan horse|velocity unlock|game[- ]changer|supercharge|unleash|revolutionize|transform how)' \
    "remove the metaphor or use a neutral synonym (e.g. 'enable', 'simplify', 'reduce')"

# --- 2. Manufactured persona ---
scan_pattern \
    "manufactured persona" \
    "(imagine you('?re| are) a|as your (senior|expert|trusted) [a-z]+|picture yourself as)" \
    "remove the persona framing; state the rule or instruction directly"

# --- 3. Formulaic triplets (X, Y, and Z) — flagged for human check ---
# Per RFC-006: high false-positive rate (legitimate lists also match);
# emit as a soft warning so the human can adjudicate.
scan_pattern \
    "formulaic triplet" \
    '\b[a-zA-Z]+,[[:space:]]+[a-zA-Z]+,?[[:space:]]+and[[:space:]]+[a-zA-Z]+\b' \
    "if this is rhetorical (not a real list), consider whether a single clear point would do"

# --- 4. False severity escalation ---
# Same-line co-occurrence of escalation words (critical/blocker/urgent) and
# de-escalation words (warning/advisory/nice-to-have/recommendation).
while IFS=: read -r lineno text; do
    [ -z "$lineno" ] && continue
    if printf '%s' "$text" | grep -qiE '(warning|advisory|nice-to-have|recommendation)'; then
        text=$(printf '%s' "$text" | sed -E 's/^[[:space:]]+//' | cut -c1-120)
        emit "$lineno" "false severity escalation" "$text" \
            "match the severity word to the actual severity (e.g. don't call a warning 'critical')"
    fi
done < <(grep -inE '\b(critical|blocker|urgent)\b' "$FILE_PATH" 2>/dev/null || true)

# --- 5. Unsupported compliance ---
# Compliance terms only OK when accompanied by a disclaiming qualifier on the
# same line (does not | not yet | out of scope | roadmap | future | aspirational).
while IFS=: read -r lineno text; do
    [ -z "$lineno" ] && continue
    if ! printf '%s' "$text" | grep -qiE '(does not|not yet|out of scope|roadmap|future|aspirational)'; then
        text=$(printf '%s' "$text" | sed -E 's/^[[:space:]]+//' | cut -c1-120)
        emit "$lineno" "unsupported compliance" "$text" \
            "add a qualifier (e.g. 'not yet', 'out of scope') or remove the claim — this plugin does not deliver SOC2/PCI/HIPAA/GDPR guarantees"
    fi
done < <(grep -inE '\b(SOC[- ]?2|PCI[- ]?DSS|HIPAA|GDPR-compliant)\b' "$FILE_PATH" 2>/dev/null || true)

# --- 6. Aspirational framing ---
scan_pattern \
    "aspirational framing" \
    '(will[[:space:]]+(revolutionize|transform|reshape)|industry-leading|best-in-class|cutting-edge)' \
    "ground the claim in a specific behavior (a hook, a skill, a template, an artifact) or remove"

exit 0
