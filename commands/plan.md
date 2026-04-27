---
description: Start Phase 1 — plan a new task, fix, or change request. Produces a plan artifact required by all downstream phases.
---

Invoke the `plan` skill for the task described by the user. The skill will:

1. Classify the work item (new-build / fix / change-request)
2. Validate against `.claude/sdlc/scope.md`
3. Write a plan to `.claude/sdlc/plans/<task-slug>.md`
4. Validate the technology stack and produce a compatibility matrix
5. Ask the human to confirm before any code is written

On completion, invoke the `gate-signoff` skill to capture the human sign-off via chat and write `.claude/sdlc/gates/plan-<task-slug>.md`.

The plan-gate hook will block all `Edit` and `Write` tool calls until this file exists.
