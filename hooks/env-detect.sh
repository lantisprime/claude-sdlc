#!/usr/bin/env bash
# env-detect.sh — Detect integrations and write .claude/sdlc/env.json.
# Runs once per session (SessionStart). Skills read the output to decide fallbacks.
set -euo pipefail

SDLC_DIR=".claude/sdlc"
mkdir -p "$SDLC_DIR"
ENV_FILE="$SDLC_DIR/env.json"

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

cat > "$ENV_FILE" <<JSON
{
  "vcs": $vcs,
  "issue_tracker": $issue_tracker,
  "ci": $ci,
  "observability": null,
  "ux_tool": null,
  "artifact_format_fallback": "markdown",
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

echo "[env-detect] wrote $ENV_FILE"
exit 0
