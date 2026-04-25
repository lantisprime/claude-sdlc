# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-25
**Scope:** Key decisions and open items from three sessions: guided-entry reshape, Pending A resolution, scope-ingest RFC promotion. Complements `_repo-context.md` with short-lived "what just happened" continuity.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — main RFC, all pending discussions resolved or deferred; PR #1 marked ready for review
- [`scope-ingest.md`](../scope-ingest.md) — formal RFC draft as of 2026-04-25
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC; all constraints honored
- PR #1: https://github.com/lantisprime/claude-sdlc/pull/1

---

## Binding decisions (cumulative)

### Reshape of guided-entry RFC (2026-04-24)

- **Dropped** PR 5 and PR 7 — accepted RFC's model can't host them.
- **Kept + reworked** PRs 1, 2, 3, 4, 6, 8, 9, 10.
- **Ship order:** 1 → 2 → 3 → 4 → 8 → 9 → 6 → 10. Hard deps: PR 10 last, PR 4 before PR 6.
- **Compensating additions (option-b):** PR 1 unordered pipe render, PR 3 historical-email heuristic, PR 9 unordered-parallel callout.

### Pending A: workflow templates vs. domain files — keep orthogonal (2026-04-25)

Workflow presets (PR #1 §A, `/configure` Q5) = pure config. Domain files (`domains/payments.md`) = pure knowledge. Advisory bridge: optional `suggested_roles: []` in domain file frontmatter; plan skill surfaces it but does not enforce. Written back to scope-ingest note, guided-entry RFC, and `_repo-context.md`.

### Scope-ingest conflict resolutions — written back (2026-04-25)

All four conflicts with `multi-team-approval.md` resolved in scope-ingest note and carried into the formal RFC:
1. Sign-off filename → `REQ-SCOPE-<project-slug>`, file `sign-offs/REQ-SCOPE-<slug>-product.md`
2. Default signer → `product`; drop `scope-owner`; `suggested_roles` advisory only
3. Transport → Tier 0 for v1; same config keys as phase sign-offs
4. Reconciler → scope gate at `.claude/sdlc/gates/scope-<project>.md` with `## Required sign-offs` block

### Scope-ingest RFC promoted (2026-04-25)

`docs/rfcs/notes/plan-phase-scope-ingest-discussion.md` → `docs/rfcs/scope-ingest.md`.

RFC contents:
- `scope-ingest` agent (narrow write scope: `scope-drafts/` only; provenance-traced)
- `domain-expert` skill (read-and-inject; `domains/` directory; `suggested_roles` advisory bridge)
- Modified `/plan` flow (6 steps; user surface unchanged)
- All sign-off alignment resolved
- `domains/_schema.md` + seed files (`payments.md`, `auth.md`) specified
- OQ-SCOPE-1 open: pseudo-phase gate vs. new artifact class (see §6)
- 14-item implementation checklist

Discussion note status: `superseded (promoted)`.

### PR #1 ready-for-review (2026-04-25)

Marked ready via `gh pr ready 1`. No longer draft.

### Constraints honored from accepted `multi-team-approval.md`

- Signer identity in sign-off file (`signer:`), never in config
- No role-to-email map in config
- No signed-commit enforcement
- No tracker-notification-on-signature
- Sign-offs are parallel, not sequential

---

## Open items carried forward

### OQ-SCOPE-1 (resolve before scope-ingest implementation begins)

Pseudo-phase gate vs. new artifact class for `.claude/sdlc/gates/scope-<project>.md`. Proposal: ship v1 as pseudo-phase gate (low cost; upgrade path is a rename + registry entry if confusion causes operator errors). Answer pending.

### OQ-1 in guided-entry RFC (resolve before PR 4 implementation)

PR 4 material-edit detection for `In-scope files`. Proposal: set-change semantics (additions/removals trigger version bump; reordering doesn't).

### Pending B–E in guided-entry RFC (deferred)

B. Back/cancel navigation, C. Error-message audit, D. TodoWrite integration, E. Per-phase `/status` detail.

---

## Recommended next-session start

**Primary: resolve OQ-SCOPE-1** (pseudo-phase gate vs. artifact class) before the scope-ingest implementation checklist can begin.

Why first: it's a contained yes/no with a clear proposal already in RFC §6. Resolving it unblocks the entire 14-item implementation checklist.

After OQ-SCOPE-1:
1. Begin scope-ingest implementation — `domains/_schema.md` and seed files are the cheapest first step per §14 checklist
2. Resolve OQ-1 (guided-entry PR 4) before its implementation begins

---

## Commits this session

- `ba39520` — docs(rfc): resolve Pending A, write back scope-ingest conflicts
- *(current session commit pending)*

## Conventions reinforced

- Co-Authored-By: Claude Opus 4.7 trailer on every commit
- Example identity: `juan.delacruz@acme.com`
- Propose doc edits before making them; skip on explicit "go"
- Second-opinion review after feature design, before implementation
- Ground every claim in observable repo behavior

## To resume in a new session

1. Paste `_repo-context.md` first
2. Paste this file second
3. Start with OQ-SCOPE-1 — read RFC §6, confirm or replace the proposal
