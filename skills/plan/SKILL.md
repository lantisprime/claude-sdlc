---
name: plan
description: Use this skill at the START of every coding task — new builds, bug fixes, and change requests. Classifies the work item, validates it against project scope, produces a high-level estimate, proposes a technology stack, and checks stack compatibility. Writes a plan artifact to .claude/sdlc/plans/ that every downstream phase and hook depends on. Must run before any Edit, Write, or code-generation tool call. Trigger this skill whenever the user says "implement", "fix", "add", "change", "build", "refactor", or references a ticket/requirement ID — even if the request seems small.
---

# Plan (Phase 1)

Produce a plan artifact before any code is touched. The plan-gate hook blocks `Edit`/`Write` until this file exists.

## Step 1 — Classify the work item

Ask (or infer from context) which of these the request is:

- **New build** — a new feature or capability not previously delivered
- **Fix** — a correction to existing behavior
- **Change request (CR)** — a modification to previously agreed scope

The classification drives different validation downstream (Phase 4 Build).

## Step 2 — Resolve scope

**If `.claude/sdlc/scope.md` exists and is signed:** read it and proceed. Run a quick re-validation check — if the plan task looks materially different from what scope.md describes, invoke `scope-ingest` in re-validate mode and surface the drift report before continuing.

**If `.claude/sdlc/scope.md` does not exist:** ask the human to point at source material (file path or paste text). Then invoke the `scope-ingest` agent, which produces a draft at `.claude/sdlc/scope-drafts/<timestamp>.md`. Show the draft to the human and wait for review. The human copies/renames it to `.claude/sdlc/scope.md` and signs it before the plan proceeds.

**Fallback — no source material:** if the human has no source to point at, ask for a one-paragraph scope statement and write `.claude/sdlc/scope.md` directly (existing behavior, preserved for minimal-friction cases).

Then validate the resolved scope against the work item:

- **New build:** confirm the request is within documented scope. If not, surface a **scope-delta** and ask the human whether to (a) treat as a CR, (b) expand scope, or (c) defer.
- **Fix:** confirm the fix addresses in-scope behavior. An out-of-scope fix is a CR in disguise.
- **CR:** require a change-request ID. If missing, create one under `.claude/sdlc/change-requests/CR-<n>.md` using `templates/change-request.md` and ask the human for sign-off before continuing.

See `agents/scope-ingest.md` for accepted source formats and draft output spec.

## Step 2.5 — Domain expert check

After scope validation and before writing the plan, invoke the `domain-expert` skill. It runs the two-source domain lookup (project `domains/` then plugin `domains/`), matches the task against the domain index, and — when a match is found — prepares a `## Domain context` block to be appended to the plan artifact in Step 3.

If no domain matches, the skill exits silently. Do not wait for the human or prompt them unless the skill itself surfaces a medium/low-confidence match that requires confirmation.

See `skills/domain-expert/SKILL.md` for the full matching and output specification.

## Step 3 — Write the plan

Write to `.claude/sdlc/plans/<task-slug>.md` using `templates/plan.md`. Required fields:

- **Task ID & classification** (new-build / fix / CR + reference ID)
- **Problem** (1–2 sentences)
- **In-scope files** (explicit list — hooks enforce this)
- **In-scope functions** (explicit list — hooks enforce this)
- **Out-of-scope** (explicit "do not touch" list)
- **Approach** (3–5 bullets)
- **Tests to add/update** (function-level — only modified code gets new tests)
- **Risks & rollback**
- **Estimate** (t-shirt size or story points; see `config/tools.json` for convention)

Keep it short. The plan is a contract, not a design doc — Phase 3 handles design.

## Step 4 — Technology stack

For new builds, propose the stack (language, framework, major libraries, platform, data store). For fixes and CRs on existing code, record the *existing* stack the change lives in.

Validate compatibility:

- Language/runtime versions against existing platform
- Library licenses against project policy (if recorded)
- Data schema compatibility if the change touches data
- Auth/identity compatibility
- Deployment target compatibility

Produce a compatibility matrix as a markdown table in the plan file. Any `FAIL` row halts planning and requires human decision.

## Step 5 — Human gate

Produce a one-screen summary of the plan and ask the human to confirm before Analyze/Design/Build proceeds. Write the confirmation to `.claude/sdlc/gates/plan-<task-slug>.md` using `templates/gate.md` — later commands check for this file.

## What this skill must NOT do

- Do not write code.
- Do not modify files outside `.claude/sdlc/`.
- Do not skip the scope check, even if the task feels obvious.
- Do not approve the plan on the user's behalf — the gate file requires the human to confirm.

## References

- `templates/plan.md` — plan artifact template
- `templates/change-request.md` — CR template
- `templates/gate.md` — phase-gate template
- `agents/scope-ingest.md` — scope draft producer (Step 2)
- `skills/domain-expert/SKILL.md` — domain context injector (Step 2.5)
- `docs/SDLC.md` — full phase reference
