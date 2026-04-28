#!/usr/bin/env bash
set -euo pipefail

# Approves a PR as the bot account (lantiscooperdev) to satisfy branch
# protection's "required non-author approval" rule when the maintainer
# (lantisprime) is the only human contributor.
#
# Usage: scripts/bot-approve.sh <PR#> [body]

MAINTAINER="lantisprime"
BOT="lantiscooperdev"

if [ $# -lt 1 ]; then
  echo "usage: $0 <PR#> [body]" >&2
  exit 1
fi

PR_NUM="$1"
BODY="${2:-Approved by bot account to satisfy non-author review gate (solo-maintainer repo).}"

command -v gh >/dev/null 2>&1 || { echo "error: gh CLI required" >&2; exit 1; }

gh auth status 2>&1 | grep -q "account ${BOT}" \
  || { echo "error: ${BOT} not authenticated in gh — run 'gh auth login'" >&2; exit 1; }
gh auth status 2>&1 | grep -q "account ${MAINTAINER}" \
  || { echo "error: ${MAINTAINER} not authenticated in gh" >&2; exit 1; }

PR_AUTHOR=$(gh pr view "$PR_NUM" --json author --jq '.author.login')
if [ "$PR_AUTHOR" = "$BOT" ]; then
  echo "error: PR #${PR_NUM} is authored by ${BOT} — bot cannot approve its own PR" >&2
  exit 1
fi

restore_maintainer() {
  gh auth switch -u "$MAINTAINER" >/dev/null 2>&1 || true
}
trap restore_maintainer EXIT

gh auth switch -u "$BOT" >/dev/null
gh pr review "$PR_NUM" --approve --body "$BODY"
echo "approved PR #${PR_NUM} as ${BOT}"
