# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-25
**Scope:** Key decisions from four sessions: guided-entry reshape, Pending A + scope-ingest conflicts, scope-ingest RFC promotion + review + OQ-SCOPE-1 resolution, domain-expert skill + authoring flow build.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — PR #1 merged, RFC Accepted
- [`scope-ingest.md`](../scope-ingest.md) — formal RFC draft, checklist items 1–9 complete
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC; all constraints honored
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
- Index merge: project rules evaluated first; same-slug → project wins entirely
- 3-tier matching: explicit `domain:` tag → index rule match (high/medium/low confidence) → `domain: unknown`
- `## Domain context` block injected into plan artifact; `suggested_roles` advisory only; `required: true` = warn (⚠️), never block
- Domain miss → offer authoring flow once per session; decline written to `hints.jsonl`

`skills/domain-expert/AUTHORING.md` built with:
- Path A: source-driven ingest (URL fetch → extract → draft → confirm → write + register)
- Path B: guided Q&A (6 questions, one at a time); both paths end with re-run of domain lookup

`skills/plan/SKILL.md` updated: Step 2.5 inserted to invoke domain-expert between scope validation and plan write.

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

### Scope-ingest implementation checklist — remaining items (RFC §14)

Completed: items 1–9 (OQ-SCOPE-1 resolution, schema, seed files, index, domain-expert skill, authoring flow, plan/SKILL.md wiring).

Remaining:
- [ ] Dry-run domain-expert + authoring against 3–5 past plan artifacts
- [ ] Build `scope-ingest` agent (markdown + plain text first)
- [ ] Add `scope-drafts/` to artifact tree
- [ ] Write `templates/scope-gate.md`
- [ ] Add scope gate check to `hooks/plan-gate.sh`
- [ ] End-to-end dry-run
- [ ] Documentation pass

---

## Recommended next-session start

**Primary: dry-run domain-expert skill against past plan artifacts (checklist item 8).**

Pick 3–5 plan artifacts from real projects. For each, simulate what domain-expert would inject: does the `## Domain context` block add signal without noise? Are the gap questions relevant? Does the match logic fire correctly?

After dry-run validation:
1. Build `scope-ingest` agent (markdown + plain text first)
2. Add `scope-drafts/` to artifact tree
3. Then scope gate template + hook

Also outstanding (lower priority): OQ-1 in guided-entry RFC, resolve before PR 4 implementation begins.

### V2 reminder

New artifact class for scope gates is deferred to v2. Before closing out v1 of scope-ingest, file a followup note referencing the 3-item v2 checklist in RFC §6. Don't let it get lost.

---

## Commits this session

- `ba39520` — resolve Pending A, write back scope-ingest conflicts
- `725bda4` — promote scope-ingest discussion note to formal RFC
- `a9a0528` — apply second-opinion review findings (8 findings)
- *(current session commit pending — domain-expert skill + authoring flow + plan/SKILL.md wiring)*

## Conventions reinforced

- Co-Authored-By: Claude Opus 4.7 trailer on every commit
- Example identity: `juan.delacruz@acme.com`
- Propose doc edits before making them; skip on explicit "go"
- Second-opinion review after feature design, before implementation
- Ground every claim in observable repo behavior

## To resume in a new session

1. Paste `_repo-context.md` first
2. Paste this file second
3. Start with dry-run validation of domain-expert skill
