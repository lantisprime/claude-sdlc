---
description: Start Phase 4 — implement the approved design with surgical-edit discipline and work-item traceability.
---

Invoke the `build` skill. Prerequisite: `.claude/sdlc/gates/design-<task-slug>.md`.

The skill coordinates with `surgical-edit`, `minimal-code`, and `security-review`. Hooks enforce:

- `plan-gate` — no Edit/Write without a plan
- `work-item-validation` — builds reference a REQ ID / ticket / signed CR
- `diff-scope-check` — only plan-listed files are modified
- `adjacent-function-detector` — only plan-listed functions are modified
- `modified-code-test-gate` — unit tests added only for functions actually modified
- `format-on-write` — formatter runs on every changed file
- `secret-scan` — blocks secrets committed to the diff

Produces: code + unit tests + deployment/pipeline deltas, and a Build gate file.
