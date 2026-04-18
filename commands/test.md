---
description: Start Phase 5 — execute functional tests, log defects, report coverage, validate UX conformance.
---

Invoke the `test` skill. Prerequisite: `.claude/sdlc/gates/build-<task-slug>.md`.

Defects route to Git Issues when detected; otherwise markdown (or JSON, per `config/tools.json`) under `.claude/sdlc/defects/`.

Coverage threshold defaults to 80% on modified code (configurable). UX conformance runs for frontend changes.

Produces: test execution report, defect records, and a Test gate file.
