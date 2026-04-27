---
name: scoping
description: Use this skill whenever a request is ambiguous, vague, or missing critical information — e.g. "fix the login bug" (which one?), "make this faster" (how fast? measured how?), "add caching" (where? invalidation strategy?). Forces clarification BEFORE planning or coding begins, and writes the clarified scope into the plan artifact. Trigger proactively when a task lacks: a clear trigger condition, an expected behavior, an actual behavior (for bugs), a specific user flow, an environment, or measurable acceptance criteria.
---

# Scoping

Turn a vague ask into something a plan can be written against.

## When to trigger

Proactively, whenever the request is missing any of:

- Trigger condition (when does this happen / when should it happen?)
- Expected behavior
- Actual behavior (for bugs)
- Specific user flow or entry point
- Environment (dev / staging / prod)
- Measurable success criteria

Don't guess. Claude's guesses become scope creep later.

## The clarification checklist

Ask only the questions whose answers aren't already clear. Typical set:

1. **What is the user trying to do?** (business outcome, not technical symptom)
2. **What happens now?** (current behavior, reproduction steps if a bug)
3. **What should happen?** (target behavior with acceptance criteria)
4. **Which users or flows?** (scope of impact)
5. **Which environment?** (local, staging, prod)
6. **How will we know it's done?** (test or observation)
7. **What's explicitly out of scope?** (prevents "while you're at it")

## Output

Append the clarified scope to the plan artifact under a **Clarifications** section. If no plan exists yet, create one via the `plan` skill using the clarified inputs.

## What this skill must NOT do

- Do not fill in ambiguous fields with plausible-sounding defaults.
- Do not ask every question every time — only the ones not already answered.
- Do not proceed to Plan until the blocking ambiguities are resolved.

## References

- `skills/plan/SKILL.md`
- `templates/plan.md`
