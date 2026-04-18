---
description: Start Phase 6 — propose a deployment for human approval and, once approved, execute with post-deploy verification.
---

Invoke the `deploy` skill. Prerequisite: `.claude/sdlc/gates/test-<task-slug>.md`.

**This command never auto-deploys.** It produces a deployment proposal (environment, commit, migrations, feature flags, rollback plan, blast radius), waits for explicit human approval, executes under supervision, and runs post-deploy smoke tests.

Deployment records route to tickets when configured; otherwise markdown or JSON under `.claude/sdlc/deployments/`.

Produces: deployment record, ticket updates, and a Deploy gate file.
