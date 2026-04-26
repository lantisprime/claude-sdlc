#!/usr/bin/env bash
# env-detect.sh — Detect integrations and write .claude/sdlc/env.json.
# Runs once per session (SessionStart). Skills read the output to decide fallbacks.
set -euo pipefail

SDLC_DIR=".claude/sdlc"
mkdir -p "$SDLC_DIR"
ENV_FILE="$SDLC_DIR/env.json"
CONFIG="config/tools.json"

# --- Integration detection ---
vcs="null"
if [ -d .git ]; then vcs="\"git\""; fi

issue_tracker="null"
if git remote -v 2>/dev/null | grep -qi "github.com"; then issue_tracker="\"github\"";
elif git remote -v 2>/dev/null | grep -qi "gitlab"; then issue_tracker="\"gitlab\"";
elif git remote -v 2>/dev/null | grep -qi "bitbucket"; then issue_tracker="\"bitbucket\""; fi

ci="null"
if [ -d .github/workflows ]; then ci="\"github-actions\"";
elif [ -f .gitlab-ci.yml ]; then ci="\"gitlab-ci\"";
elif [ -f .circleci/config.yml ]; then ci="\"circleci\"";
elif [ -f Jenkinsfile ]; then ci="\"jenkins\""; fi

# --- Config layer detection ---
config_corrupted="false"
if [ -f "$CONFIG" ]; then
  if ! python3 -c "import sys,json; json.load(open('$CONFIG'))" 2>/dev/null && \
     ! node -e "JSON.parse(require('fs').readFileSync('$CONFIG','utf8'))" 2>/dev/null; then
    config_corrupted="true"
  fi
fi

cat > "$ENV_FILE" <<JSON
{
  "vcs": $vcs,
  "issue_tracker": $issue_tracker,
  "ci": $ci,
  "observability": null,
  "ux_tool": null,
  "artifact_format_fallback": "markdown",
  "config_corrupted": $config_corrupted,
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

echo "[env-detect] wrote $ENV_FILE"

# --- Activation state messages (RFC §4.3) ---
if [ -f "$SDLC_DIR/.suspended" ]; then
  echo "[SDLC] Workflow suspended. Run /start to re-enable."
  exit 0
fi

if [ ! -f "$SDLC_DIR/.enabled" ]; then
  echo "[SDLC] claude-sdlc is installed. To enable the SDLC workflow, run /start."
  exit 0
fi

# Enabled: surface config warnings only.
if [ -f "$CONFIG" ] && [ "$config_corrupted" = "false" ]; then
  if grep -qE '"command":\s*null' "$CONFIG" 2>/dev/null; then
    echo "[env-detect] WARN: some tool commands in config/tools.json are null. Commands that need them will auto-prompt for config when you run them."
  fi
fi

# Layer 3: config is unparseable — instruct Claude to refuse Edit/Write.
if [ "$config_corrupted" = "true" ]; then
  echo "[SDLC] LAYER-3: config/tools.json exists but is not valid JSON. Refuse Edit/Write tool calls and instruct the user to run /configure to rebuild the config (a backup will be saved as config/tools.json.bak)."
fi

exit 0
