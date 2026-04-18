---
description: Start Phase 2 — turn a planned task into structured requirements with stable IDs, halting for UX input if the task touches a UI.
---

Invoke the `analyze` skill. Prerequisite: `.claude/sdlc/gates/plan-<task-slug>.md` must exist.

If the task touches a frontend surface and no UX artifact exists at `.claude/sdlc/architecture/ux/`, the skill will halt and ask for UX designs and brand guidelines before producing requirements.

Produces: `.claude/sdlc/requirements/<task-slug>.md` with REQ-<n> IDs, a scope-coverage table, and an Analyze gate file.
