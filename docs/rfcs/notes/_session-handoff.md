# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-25
**Scope:** Key decisions and open items from the two most recent sessions on the guided-entry UX RFC (PR #1) and the scope-ingest discussion note. Complements `_repo-context.md` (long-lived grounding) with short-lived "what just happened" continuity. Overwrite — don't append — when a new session closes.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — main RFC, all pending discussions now resolved or deferred
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC; constraints honored throughout
- [`plan-phase-scope-ingest-discussion.md`](./plan-phase-scope-ingest-discussion.md) — all conflicts resolved; ready for RFC promotion
- PR #1: https://github.com/lantisprime/claude-sdlc/pull/1

---

## Binding decisions (cumulative)

### Reshape of guided-entry RFC (2026-04-24)

- **Dropped** PR 5 (`approvals.chain` + assignments map) and PR 7 (commits-as-signatures, env-var identity). Independent reviewer confirmed no reshape path existed — the accepted RFC's parallel one-file-per-signer model can't host a chain render, and its self-asserted `signer:` field can't be replaced by commit authorship.
- **Kept + reworked** PRs 1, 2, 3, 4, 6, 8, 9, 10 against accepted-RFC vocabulary.
- **Ship order (final):** 1 → 2 → 3 → 4 → 8 → 9 → 6 → 10.
- **Hard dependencies:** PR 10 must ship last (rewrites every skill's output shape); PR 4 must precede PR 6 (delta section consumes version machinery). Everything else is rollout preference.

### Compensating additions (option-b, 2026-04-24)

- **PR 1** — unordered pipe render: `security ✓ | product ✓ | compliance □`. Honest about the parallel-not-sequential mechanism.
- **PR 3** — opt-out historical-email heuristic. Matches `git config user.email` against `signer:` on past sign-off files. Advisory, labeled "based on past sign-offs," config key `display.session_signoff_hints`. No role-to-email map in config.
- **PR 9** — explicit unordered-parallel callout in glossary + `/help sign-offs`.

### Pending A resolved: workflow templates vs. domain files (2026-04-25)

**Decision: keep orthogonal.**

- **Workflow presets** (PR #1 §A, `/configure` Q5) = pure config: `approvals.roles` + transport defaults. Answer "how does your team manage sign-offs?"
- **Domain files** (`domains/payments.md` etc.) = pure knowledge: glossary, NFRs, regulatory concerns, gap questions. Answer "what domain-specific constraints apply?"
- **Advisory bridge:** domain file schema gains optional `suggested_roles: []`. Plan skill surfaces it at plan-time as context; does not enforce or override `approvals.roles`. Absent and empty list are equivalent.
- Both artifacts have separate owners and evolve independently. No coordination gate going forward.

Written back to: scope-ingest note (open question resolved, schema updated), guided-entry RFC (Pending A section), `_repo-context.md` (PR #1 entry).

### Scope-ingest conflict resolutions (2026-04-24, written back 2026-04-25)

All four conflicts against `multi-team-approval.md` now recorded in `plan-phase-scope-ingest-discussion.md`:

1. Sign-off filename → synthetic REQ-ID `REQ-SCOPE-<project-slug>`; file: `sign-offs/REQ-SCOPE-<slug>-product.md`
2. Default signer role → `product`; drop tentative `scope-owner`; domain files may declare `suggested_roles` for regulated domains
3. Transport → same ladder as other sign-offs, Tier 0 only for v1
4. Reconciler → scope gate file at `.claude/sdlc/gates/scope-<project>.md` with `## Required sign-offs` block; pseudo-phase gate model

### Constraints honored from accepted `multi-team-approval.md`

- Signer identity lives in the sign-off file (`signer:` field), never in config
- No role-to-email map in config
- No signed-commit enforcement in the plugin
- No tracker-notification-on-signature
- Sign-offs are parallel, not sequential — no chain rendering

---

## Open items carried forward

### OQ-1 (in RFC body, resolve before PR 4 implementation)

PR 4 material-edit detection for `In-scope files`. Proposal: set-change semantics (additions/removals trigger version bump; reordering doesn't).

### Pending B–E (in RFC body, deferred)

- **B.** Back/cancel navigation in interactive flows
- **C.** Error-message audit to three-part template
- **D.** TodoWrite integration for long-running phases
- **E.** Per-phase checklist rendering in `/status`

### Scope-ingest RFC promotion

`plan-phase-scope-ingest-discussion.md` is now unblocked:
- All 4 accepted-RFC conflicts resolved and written back
- Pending A coordination gate lifted
- One remaining open: pseudo-phase-gate vs. new artifact class for scope (deferred to promotion)
- Next: draft `docs/rfcs/scope-ingest.md`

---

## Recommended next-session start

**Primary: mark PR #1 ready-for-review on GitHub** (currently draft).

Why now: all blocking conflicts resolved (reshape 2026-04-24, Pending A 2026-04-25). OQ-1 and Pending B–E are deferrable post-merge questions.

If that's quick, next candidates:
1. Begin scope-ingest RFC promotion: draft `docs/rfcs/scope-ingest.md` from the discussion note
2. Resolve OQ-1 (PR 4 material-edit detection) before implementation begins

---

## Commits this session

- `0ca09ff` — docs(notes): add session handoff for next-session pickup
- *(current session commit pending)*

## Conventions reinforced

- Co-Authored-By: Claude Opus 4.7 trailer on every commit
- Example identity: `juan.delacruz@acme.com` (matches accepted RFC line 81)
- Propose edits before making them (doc changes — non-trivial); skip on explicit "go"
- Second-opinion review after feature design, before implementation
- Ground every claim in observable repo behavior

## To resume in a new session

1. Paste `_repo-context.md` first (long-lived grounding)
2. Paste this file second ("what just happened")
3. Mark PR #1 ready-for-review, then begin scope-ingest RFC promotion
