---
description: Run code-review and security-review skills against the current diff. Safe to run repeatedly during Build.
---

Invoke `security-review` and produce a findings list at `.claude/sdlc/test/security-review-<task-slug>.md`. Also run a quality pass over the diff (correctness, edge cases, error handling, naming, complexity).

Scope: the current `git diff` only — not the whole codebase.

Critical or high findings block the Build gate until resolved or waived with a human-signed note in the gate file.
