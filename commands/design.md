---
description: Start Phase 3 — produce or update application / data / platform / infrastructure / security / test architecture, technical specs, and test cases.
---

Invoke the `design` skill. Prerequisite: `.claude/sdlc/gates/analyze-<task-slug>.md`.

If architecture artifacts exist under `.claude/sdlc/architecture/`, the skill validates them against current requirements before proposing changes — never wholesale-regenerates a working architecture.

When the `architect` and `test-designer` subagents are available, delegate validation and test-case generation to them in parallel.

Produces: architecture bundle, tech specs, test cases tied to REQ IDs, DevOps pipeline design.

On completion, invoke the `gate-signoff` skill to capture the human sign-off via chat and write `.claude/sdlc/gates/design-<task-slug>.md`.
