# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-25
**Scope:** Six sessions cumulative. This session: scope-ingest v1 close-out — dry-run findings, domain-expert matching redesign (keywords → LLM semantic judgment), scope gate creation step in plan skill, USER-MANUAL docs pass.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — PR #1 merged, RFC Accepted
- [`scope-ingest.md`](../scope-ingest.md) — formal RFC; all checklist items complete ✅
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC; implementation not yet started
- PR #1: https://github.com/lantisprime/claude-sdlc/pull/1

---

## Binding decisions (cumulative)

### Guided-entry RFC reshape (2026-04-24)

- Dropped PRs 5 + 7; kept + reworked PRs 1, 2, 3, 4, 6, 8, 9, 10.
- Ship order: 1 → 2 → 3 → 4 → 8 → 9 → 6 → 10. Hard deps: PR 10 last, PR 4 before PR 6.
- Compensating additions (option-b): PR 1 unordered pipe render, PR 3 historical-email heuristic, PR 9 unordered-parallel callout.
- PR #1 merged to main 2026-04-25 by lantisprime (commit `d50f1e48`). RFC status updated to Accepted.

### Pending A: keep orthogonal (2026-04-25)

Workflow presets = pure config. Domain files = pure knowledge. Advisory bridge: optional `suggested_roles: []`; plan skill surfaces it into `## Domain context` advisory only — never into gate file's `## Required sign-offs` block.

### Scope-ingest RFC (2026-04-25)

Promoted from discussion note. Second-opinion review applied (8 findings). Key constraints locked in:
- `scope-ingest` write restriction is a convention (agent instructions), not a capability boundary
- `required:` question tag is warn-level, not a hard block (per CLAUDE.md hook philosophy)
- `suggested_roles` → `## Domain context` advisory only; gate file block comes from `approvals.roles` or explicit human input
- `gate_hash` required in scope gate template (per accepted RFC §6.5)
- Cross-phase `domain-expert` reuse (`/analyze`, `/design`) deferred to v1 non-goals

### OQ-SCOPE-1 resolved: pseudo-phase gate for v1 (2026-04-25)

Scope gate file at `.claude/sdlc/gates/scope-<project>.md` — same shape as phase gate files, reconciler handles it with no code changes. Label imprecision ("scope isn't a phase") addressed via glossary.

**New artifact class deferred to v2.** Trigger: if post-ship usage shows the "pre-Plan gate" label causes operator confusion, or if reconciler behavior for scope needs to diverge. V2 checklist: (a) `scope_gate` entry in `env.json` artifact registry, (b) rename convention if needed, (c) reconciler branch. No data migration — file content is identical either way.

### Scope-ingest conflict resolutions (written back 2026-04-25)

1. Sign-off filename → `REQ-SCOPE-<project-slug>`; file `sign-offs/REQ-SCOPE-<slug>-product.md`
2. Default signer → `product`; `suggested_roles` advisory only
3. Transport → Tier 0 for v1; same config keys as phase sign-offs
4. Reconciler → pseudo-phase gate at `.claude/sdlc/gates/scope-<project>.md`

### Domain-expert skill + authoring flow (2026-04-25)

`skills/domain-expert/SKILL.md` built with:
- Two-source lookup: project `domains/` first (takes precedence), then plugin `domains/`
- Index merge: project entries evaluated first; same-slug → project wins entirely
- 3-tier matching: explicit `domain:` tag → LLM semantic judgment → `domain: unknown`
- `## Domain context` block injected into plan artifact; `suggested_roles` advisory only; `required: true` = warn (⚠️), never block
- Domain miss → offer authoring flow once per session; decline written to `hints.jsonl`

`skills/domain-expert/AUTHORING.md` built with:
- Path A: source-driven ingest (URL fetch → extract → draft → confirm → write + register)
- Path B: guided Q&A (6 questions, one at a time); both paths end with re-run of domain lookup inline (no need to re-run `/plan`)

`skills/plan/SKILL.md` updated: Step 2.5 (domain-expert) + Step 4.5 (scope gate creation, first task only).

### Domain-expert matching: keywords → LLM semantic judgment (2026-04-25)

`domains/_index.json` v2: replaced keyword/stacks rules array with a `domains` registry (slug + semantic description) and an optional `overrides` block (force/exclude). The domain-expert skill's Tier 2 now uses LLM semantic judgment against the registry descriptions rather than keyword scanning.

**Why:** keyword lists are incomplete by design and require ongoing maintenance. The LLM already understands domain semantics. Dry-run immediately found gaps (`password`, `bcrypt`) that semantic judgment covers without any keyword additions. The `overrides` block preserves deterministic team-level control when needed.

### Scope gate creation added to plan skill (2026-04-25)

`skills/plan/SKILL.md` Step 4.5: after tech-stack validation, the plan skill drafts and signs the scope gate (`gates/scope-<project-slug>.md`) if it doesn't exist. Computes `gate_hash` at draft time, derives project slug from `scope.md project_name`, skips entirely on subsequent tasks where the gate is already signed.

**Previously missing:** the USER-MANUAL described the scope gate as something `/plan` drafts, but the skill had no such instruction.

### Accepted-RFC constraints honored throughout

- Signer identity in `signer:` field, never in config
- No role-to-email map in config
- No signed-commit enforcement
- No tracker-notification-on-signature
- Sign-offs are parallel, not sequential

---

## Open items carried forward

### OQ-1 in guided-entry RFC (resolve before PR 4 implementation)

PR 4 material-edit detection for `In-scope files`. Proposal: set-change semantics (additions/removals trigger version bump; reordering doesn't).

### Pending B–E in guided-entry RFC (deferred)

B. Back/cancel navigation, C. Error-message audit, D. TodoWrite integration, E. Per-phase `/status` detail.

### V2 scope gate followup note (file before closing scope-ingest RFC)

New artifact class for scope gates deferred to v2. Before closing the scope-ingest RFC, file a followup note in `docs/rfcs/notes/` referencing the 3-item v2 checklist in RFC §6: (a) `scope_gate` entry in `env.json` artifact registry, (b) rename convention, (c) reconciler branch.

### Multi-team approval — rollout step 1 (not yet started)

Accepted RFC at [`multi-team-approval.md`](../multi-team-approval.md). Step 1: ship `templates/sign-off-multi.md`, `hooks/approval-reconcile.sh`, and the `## Required sign-offs` gate-file convention. Each subsequent step gated on adoption of the previous.

---

## Recommended next-session start

**Primary: file the v2 scope gate followup note, then start multi-team approval rollout step 1.**

1. Write `docs/rfcs/notes/scope-gate-v2-followup.md` — 3-item checklist, trigger conditions, no-data-migration note. Closes the scope-ingest RFC cleanly.
2. Resolve OQ-1 in guided-entry RFC (set-change semantics for `In-scope files`) — required before PR 4 begins.
3. Start multi-team approval rollout step 1: `templates/sign-off-multi.md` (extends existing `sign-off.md` with `role`, `transport`, `req_id`, `gate_hash` fields) + `hooks/approval-reconcile.sh` (PreToolUse + Stop, warn-not-block) + `## Required sign-offs` gate convention.

---

## Commits this session

- `7ae9fd5` — refactor(domain-expert): replace keyword matching with LLM semantic judgment
- `9a77962` — feat(plan): add scope gate creation step + docs pass for scope-ingest v1

## Scope-ingest checklist — final state

All items complete ✅:
- OQ-SCOPE-1 resolution, schema, seed files
- `domains/_index.json` v2 — semantic registry
- `domains/auth.md` + `domains/payments.md` — seed files
- `skills/domain-expert/SKILL.md` + `AUTHORING.md`
- `skills/plan/SKILL.md` — Step 2.5 (domain-expert) + Step 4.5 (scope gate)
- `agents/scope-ingest.md`
- `templates/scope-gate.md`
- `hooks/plan-gate.sh` — scope gate check
- `docs/GLOSSARY.md` — 9 new terms
- `scope-drafts/` in artifact tree (SDLC.md + README.md)
- `docs/USER-MANUAL.md` — §7.8 re-validate scenario, domain authoring re-entry, semantic judgment note

## Conventions reinforced

- Co-Authored-By: Claude Opus 4.7 trailer on every commit
- Example identity: `juan.delacruz@acme.com`
- Propose doc edits before making them; skip on explicit "go"
- Second-opinion review after feature design, before implementation
- Ground every claim in observable repo behavior

## To resume in a new session

1. Paste `_repo-context.md` first
2. Paste this file second
3. Start with v2 scope gate followup note (one small file), then OQ-1, then multi-team approval rollout step 1
