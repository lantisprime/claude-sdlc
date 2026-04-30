#!/usr/bin/env bash
set -euo pipefail

# Posts a substantive --comment-state review on a PR using the bot account
# (lantiscooperdev), so findings appear in the PR's Reviews tab WITHOUT
# satisfying the "non-author review" gate. Routine flow — agent runs this
# automatically after `gh pr create`.
#
# For approval (BREAK-GLASS only — never routine), see scripts/bot-approve.sh.
#
# Usage: scripts/bot-review.sh <PR#> <body>

MAINTAINER="lantisprime"
BOT="lantiscooperdev"

if [ $# -lt 2 ]; then
  echo "usage: $0 <PR#> <body>" >&2
  echo "       body must be substantive — checks performed, suggestions, risks, verdict." >&2
  exit 1
fi

PR_NUM="$1"
BODY="$2"

command -v gh >/dev/null 2>&1 || { echo "error: gh CLI required" >&2; exit 1; }

gh auth status 2>&1 | grep -q "account ${BOT}" \
  || { echo "error: ${BOT} not authenticated in gh — run 'gh auth login'" >&2; exit 1; }
gh auth status 2>&1 | grep -q "account ${MAINTAINER}" \
  || { echo "error: ${MAINTAINER} not authenticated in gh" >&2; exit 1; }

PR_AUTHOR=$(gh pr view "$PR_NUM" --json author --jq '.author.login')
if [ "$PR_AUTHOR" = "$BOT" ]; then
  echo "error: PR #${PR_NUM} is authored by ${BOT} — bot cannot review its own PR" >&2
  exit 1
fi

restore_maintainer() {
  gh auth switch -u "$MAINTAINER" >/dev/null 2>&1 || true
}
trap restore_maintainer EXIT

gh auth switch -u "$BOT" >/dev/null
gh pr review "$PR_NUM" --comment --body "$BODY"
echo "comment-review posted on PR #${PR_NUM} as ${BOT}"
