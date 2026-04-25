---
name: start
description: Use this skill when the user says "start", "begin", "I want to build", "I want to fix", "I don't know where to begin", "how do I start", or otherwise signals they are beginning a new task and haven't run /plan yet. Guides the user through a six-question intake, checks fix-fast eligibility, and hands off to the plan skill with answers pre-filled. Best for new users and first-time tasks. Power users who know the workflow can skip directly to /plan.
---

# Start — Guided Intake

Ask six questions, determine the right path, then hand off. Never duplicate the plan skill's logic — pre-fill answers and delegate.

## Step 1 — Ask the six intake questions

Ask one at a time. Do not front-load all six at once — that defeats the "front door" purpose.

**Q1 — Task type**
> What type of work is this?
> A) New build — a new feature or capability
> B) Fix — correcting existing behavior
> C) Change request — modifying previously agreed scope

**Q2 — UI/UX impact**
> Does this task involve any UI or UX changes? (yes / no)

**Q3 — API or schema impact**
> Does this task touch any API contracts or database schemas? (yes / no)

**Q4 — File count**
> Roughly how many files do you expect to touch? (enter a number)

**Q5 — Size**
> Rough size estimate:
> A) Tiny — ≤ 50 lines of change
> B) Small — ≤ 200 lines
> C) Medium — a few hundred lines across multiple files
> D) Large — significant scope, hard to estimate yet

**Q6 — Risk**
> What could go wrong with this task? What are you most uncertain about?
> *(Required — a one-sentence minimum. "Nothing" or "n/a" is not accepted.)*

If the user gives a single-word or empty answer to Q6, re-ask once with the prompt above. After a second refusal, note "no risk assessment provided" verbatim and continue — do not block indefinitely.

## Step 2 — Check fix-fast eligibility

Offer routing to `/fix-fast` only when **all five** conditions hold:

| Condition | Threshold |
|---|---|
| Task type | fix (Q1 = B) |
| UI/UX impact | no (Q2 = no) |
| API or schema impact | no (Q3 = no) |
| File count | ≤ 2 (Q4 ≤ 2) |
| Size | tiny (Q5 = A) |

If all five hold, ask:
> This looks like it may qualify for `/fix-fast` — a compressed path that skips Analyze and Design.
> Eligibility: fix, ≤ 2 files, ≤ 50 LOC, no API/schema changes, no UI changes.
> Route to `/fix-fast`? (yes / no — if unsure, choose no and use the full flow)

If the user says yes, stop and tell them to run `/fix-fast` with their task description. Do not invoke fix-fast yourself.

If the user says no, or eligibility is not met, continue to Step 3.

## Step 3 — Build the pre-fill block

Assemble the answers into a plain summary block:

```
Task type:        <new build | fix | change request>
UI/UX impact:     <yes | no>
API/schema impact: <yes | no>
Files expected:   <n>
Size:             <tiny | small | medium | large>
Risk/unknowns:    <verbatim from Q6>
```

## Step 4 — Scope notice

If `.claude/sdlc/scope.md` does not exist, warn the user before handoff:

> No scope.md found. After handoff, the plan skill will ask you to point at source material (a file path, pasted text, or a one-paragraph statement). This is expected on a project's first run.

If `scope.md` exists, skip this notice.

## Step 5 — Hand off to the plan skill

Print the pre-fill block and this disclaimer:

> Handing off to plan. The answers above are a draft — the plan skill will expand them into a full plan artifact. Review the plan carefully before signing the gate; you are responsible for its accuracy.

Then invoke the `plan` skill with the pre-fill block as context. The plan skill runs its full flow from Step 1 onward; it does not re-ask questions that are already answered in the pre-fill block.

## What this skill must NOT do

- Do not write any artifact directly. The plan skill owns plan artifacts.
- Do not invoke `/fix-fast` on the user's behalf — only offer the route.
- Do not skip the risk question, even if the task seems trivial.
- Do not invent answers for unanswered questions.

## Graceful degradation

- User skips a question or gives a partial answer → record "not provided" and continue. The plan skill can clarify.
- `.claude/sdlc/` does not exist → proceed normally; the plan skill will create it.

## References

- `commands/fix-fast.md` — fix-fast eligibility rules
- `skills/plan/SKILL.md` — the skill this hands off to
- `docs/rfcs/guided-entry-session-resume-multi-role.md` §2 — PR 2 spec
