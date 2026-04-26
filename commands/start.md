---
description: Activate the SDLC workflow (opt-in), re-enable after suspension, or start a new task when already enabled. On fresh install — auto-detects repo/CI/stack/tracker (≤3 prompts), creates .enabled, takes a one-sentence task description, and auto-generates scope.md and a draft plan. On re-enable — verifies the suspension snapshot, shows governance/source changes per active plan, proposes REQ supersession if needed. On already-enabled — hands off to /plan.
---

Invoke the `start` skill. The skill reads the marker state and routes accordingly:

- **Fresh install** (`.enabled` absent, `.suspended` absent): Step 0 auto-detects config, Step 1 creates `.enabled`, Step 2 takes a one-sentence task description, Step 3 auto-generates `scope.md` and a draft plan, Step 4 shows the "what this armed" summary. Hands off to `/plan` for review and sign-off.

- **Suspended** (`.suspended` present): calls `hooks/suspend-snapshot.sh verify`, shows per-plan reconciliation output (HIGH/LOW severity), accepts or rejects each changed plan, proposes REQ supersession for accepted HIGH-severity plans, then re-enables enforcement.

- **Already enabled** (`.enabled` present): hands off to `/plan` to start or continue a task.

Power users with an active signed plan can skip directly to `/plan`.
