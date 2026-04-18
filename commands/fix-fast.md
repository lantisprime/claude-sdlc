---
description: Compressed SDLC path for small bug fixes only — collapses Plan + Analyze + Design into a single mini-gate. Not for new builds or change requests.
---

Eligibility (all must be true):

- Work item is classified as **fix**
- Estimated scope ≤ 2 files AND ≤ 50 LOC
- No schema / API / security-surface changes
- No frontend/UX changes

Flow:

1. Run `plan` skill in compact mode — single mini-plan with classification, in-scope files/functions, repro steps, fix approach, test to add.
2. Skip `analyze` and `design` phases (record reason in the mini-plan).
3. Write a single mini-gate at `.claude/sdlc/gates/fix-fast-<task-slug>.md`.
4. Proceed to `build`, `test`, `deploy`, `support`, `docs` normally — those phases are **not** compressed.

If eligibility is violated at any point, fall back to the full 8-phase flow.
