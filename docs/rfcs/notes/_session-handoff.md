# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-25
**Scope:** Key decisions and open items from three sessions: guided-entry reshape, Pending A + scope-ingest conflicts, scope-ingest RFC promotion + review + OQ-SCOPE-1 resolution.
**Related:**
- [`guided-entry-session-resume-multi-role.md`](../guided-entry-session-resume-multi-role.md) — PR #1, ready for review
- [`scope-ingest.md`](../scope-ingest.md) — formal RFC draft, all open questions resolved, implementation checklist unblocked
- [`multi-team-approval.md`](../multi-team-approval.md) — accepted RFC; all constraints honored
- PR #1: https://github.com/lantisprime/claude-sdlc/pull/1

---

## Binding decisions (cumulative)

### Guided-entry RFC reshape (2026-04-24)

- Dropped PRs 5 + 7; kept + reworked PRs 1, 2, 3, 4, 6, 8, 9, 10.
- Ship order: 1 → 2 → 3 → 4 → 8 → 9 → 6 → 10. Hard deps: PR 10 last, PR 4 before PR 6.
- Compensating additions (option-b): PR 1 unordered pipe render, PR 3 historical-email heuristic, PR 9 unordered-parallel callout.
- PR #1 marked ready-for-review 2026-04-25.

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

### Scope-ingest implementation checklist (unblocked)

All open questions resolved. 13 remaining checklist items in RFC §14 — ready to begin. Natural first step: `domains/_schema.md` + seed files (cheapest; validates shape before building consumers).

---

## Recommended next-session start

**Primary: begin scope-ingest implementation — `domains/_schema.md` + seed files.**

Why now: OQ-SCOPE-1 resolved; all RFC constraints locked in; implementation checklist is fully unblocked. The schema + seed files are the cheapest first step and validate the domain file shape before anything consumes it.

After seed files:
1. Build `domain-expert` skill (reads `_index.json`, injects `## Domain context`)
2. Dry-run against 3–5 past plan artifacts before building the agent
3. Then `scope-ingest` agent (markdown + plain text first)

Also outstanding (lower priority): OQ-1 in guided-entry RFC, resolve before PR 4 implementation begins.

---

## Commits this session

- `ba39520` — resolve Pending A, write back scope-ingest conflicts
- `725bda4` — promote scope-ingest discussion note to formal RFC
- `a9a0528` — apply second-opinion review findings (8 findings)
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
3. Start with `domains/_schema.md` — write the domain file contract before the first seed file
