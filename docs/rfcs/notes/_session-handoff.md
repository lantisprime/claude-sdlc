# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-24
**Scope:** Key decisions and open items from the most recent session on the guided-entry UX RFC (PR #1). Complements `_repo-context.md` (long-lived grounding) with short-lived "what just happened" continuity. Overwrite — don't append — when a new session closes.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — main RFC, reshaped this session
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC read in full this session
- [`plan-phase-scope-ingest-discussion.md`](./plan-phase-scope-ingest-discussion.md) — overlaps with Pending A
- PR #1: https://github.com/lantisprime/claude-sdlc/pull/1

---

## Binding decisions this session

### Reshape of guided-entry RFC

- **Dropped** PR 5 (`approvals.chain` + assignments map) and PR 7 (commits-as-signatures, env-var identity). Independent reviewer confirmed no reshape path existed — the accepted RFC's parallel one-file-per-signer model can't host a chain render, and its self-asserted `signer:` field can't be replaced by commit authorship.
- **Kept + reworked** PRs 1, 2, 3, 4, 6, 8, 9, 10 against accepted-RFC vocabulary.
- **Ship order (final):** 1 → 2 → 3 → 4 → 8 → 9 → 6 → 10.
- **Hard dependencies (the only true constraints):** PR 10 must ship last (rewrites every skill's output shape); PR 4 must precede PR 6 (delta section consumes version machinery). Everything else is rollout preference, not coupling.

### Compensating additions (option-b, chosen over option-a)

Three additions to recover most of the multi-role UX lost with PR 5, honoring accepted-RFC constraints:

- **PR 1** — unordered pipe render for active gate: `security ✓ | product ✓ | compliance □`. Honest about the parallel-not-sequential mechanism.
- **PR 3** — opt-out historical-email heuristic. Matches `git config user.email` against `signer:` fields on past sign-off files. Advisory, labeled "based on past sign-offs," config key `display.session_signoff_hints`. **No role-to-email map introduced in config.**
- **PR 9** — explicit unordered-parallel callout in glossary + `/help sign-offs`. Prevents users from assuming chain-style ordering that doesn't exist.

### Constraints honored from accepted `multi-team-approval.md`

Guardrails every future PR must respect:

- Signer identity lives in the sign-off file (`signer:` field), never in config
- No role-to-email map in config
- No signed-commit enforcement in the plugin (team workflow, outside scope)
- No tracker-notification-on-signature (would need its own mini-RFC)
- Sign-offs are parallel, not sequential — no chain rendering in any UX surface

### Second-opinion review findings applied

Commit `d647593` addresses five findings:

1. PR 8 scope note ("Deliberately excluded from Q5–Q8") moved above the question list and inlined at Q5/Q6
2. Pending A "Small team" preset role list changed from `[product, tech_lead]` to `[product, qa]` (inside the 9-role set); added paragraph pointing Custom users at §3.2 for free-form labels
3. Ship-order prose softened — separated hard deps from rollout preferences
4. Dropped unverifiable claims ("smaller than pre-reshape draft," "largest single cognitive-load win")
5. Added new Open questions section with OQ-1 (PR 4 material-edit detection)

Reviewer verdict: structural reshape sound, vocabulary clean, threat model preserved.

## Open items carried forward

### OQ-1 (now in RFC body, resolve before PR 4 implementation)

PR 4 material-edit detection for `In-scope files`. Proposal: set-change semantics (additions/removals trigger version bump; reordering doesn't).

### Pending discussions (A–E, in RFC body)

- **A.** Workflow templates in `/configure` — **overlaps with scope-ingest note's workflow-template-vs-domain-file question** → resolve A first
- **B.** Back/cancel navigation in interactive flows
- **C.** Error-message audit to three-part template
- **D.** TodoWrite integration for long-running phases
- **E.** Per-phase checklist rendering in `/status`

### Scope-ingest note conflicts — now unblocked

Reading the accepted RFC resolved all four conflicts listed in `plan-phase-scope-ingest-discussion.md`. Resolutions captured here but **not yet written back to that note** — do it next session before or during the scope-ingest RFC promotion:

1. Sign-off filename → synthetic REQ-ID `REQ-SCOPE-<project-slug>`
2. Multi-role → default signer is `product`; drop tentative `scope-owner`; domain files declare additional roles for regulated domains
3. Transport → same ladder as other sign-offs, Tier 0 only for v1
4. Reconciler → scope gate file at `.claude/sdlc/gates/scope-<project>.md` with `## Required sign-offs` block

Remaining open: treat scope as pseudo-phase gate (cheap) vs. new sign-offable artifact class (cleaner). Defer to scope-ingest RFC promotion.

## Recommended next-session start

**Primary: Pending A — workflow templates vs. domain files unification.**

Why A first:

- Dual-listed in two active threads (PR #1 pending, scope-ingest note)
- Gates scope-ingest's "decide unification before building seed domain files" next action
- Contained decision (unify / keep orthogonal / merge indices split content) with three concrete options
- Shapes downstream vocabulary for two RFCs before any implementation PR opens

If A resolves quickly, next candidates:

1. Write A's resolution back to `plan-phase-scope-ingest-discussion.md`
2. Mark PR #1 ready-for-review on GitHub (currently draft)
3. Begin scope-ingest RFC promotion (note → formal RFC)

## Commits this session

- `2e2a085` — reshape guided-entry RFC against accepted multi-team-approval
- `d647593` — address second-opinion review findings

## Conventions reinforced

- Co-Authored-By: Claude Opus 4.7 trailer on every commit
- Example identity: `juan.delacruz@acme.com` (matches accepted RFC line 81)
- Propose edits before making them (doc changes — non-trivial)
- Second-opinion review after feature design, before implementation
- Ground every claim in observable repo behavior; no inflated metaphors or unsupported claims

## To resume in a new session

1. Paste `_repo-context.md` first (long-lived grounding)
2. Paste this file second ("what just happened")
3. Start with Pending A
