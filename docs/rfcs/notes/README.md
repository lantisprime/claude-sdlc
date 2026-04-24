# `docs/rfcs/notes/`

Working notes that sit alongside RFCs but aren't RFCs themselves. This directory is for in-flight thinking, companion implementation notes, conflict analyses, and shared context that the main repo docs shouldn't carry.

**Start here:** [`_repo-context.md`](./_repo-context.md) — the canonical grounding for any new conversation about the repo. Paste it first.

---

## What belongs here vs. in `docs/rfcs/`

| Lives in `docs/rfcs/` | Lives in `docs/rfcs/notes/` |
| --- | --- |
| Accepted RFC | Discussion note leading up to an RFC |
| Proposed RFC under formal review | Companion implementation note for a specific RFC |
| Decision the repo now enforces | Conflict analysis between competing proposals |
| Long-lived reference | Working context, repo state snapshots |

If a note hardens into a decision, promote it to an RFC in the parent directory. If an RFC gets superseded, its companion notes stay here as history.

## Naming conventions

- **Underscore prefix** (`_repo-context.md`) — meta-files for the directory itself. Kept short to sort to the top.
- **RFC companions** — match the RFC's slug, with a qualifier. Example: `guided-entry-pr7-degradation.md` is the degradation matrix for PR 7 of the guided-entry RFC.
- **Standalone discussions** — descriptive slug with the phase or area first. Example: `plan-phase-scope-ingest-discussion.md`.
- **Conflict checks** — slug + `-conflict-check.md`. Use when a proposal needs to be reconciled with an accepted RFC before it can move forward.

## Status vocabulary

Every note should declare its status in the first line after the title. Use one of:

- **discussion** — active thinking; not yet a proposal
- **draft** — structured enough to review, not ready to accept
- **companion** — implementation detail for an existing RFC (accepted or draft)
- **superseded** — kept for history, no longer current; point at what replaced it
- **archived** — historical record of a path not taken

A note with no status field should be treated as `discussion`.

## Current contents

| File | Status | What it covers |
| --- | --- | --- |
| [`_repo-context.md`](./_repo-context.md) | reference | Canonical repo grounding — principles, capability counts, accepted RFCs, open PRs, anti-patterns. Paste first in any new conversation. |
| [`plan-phase-scope-ingest-discussion.md`](./plan-phase-scope-ingest-discussion.md) | discussion | Proposal for reshaping Phase 1: `scope-ingest` agent + `domain-expert` skill. Includes conflict analysis against accepted multi-team-approval RFC and PR #1. |
| [`guided-entry-pr7-degradation.md`](./guided-entry-pr7-degradation.md) | companion | Refuse/degrade/hand-off taxonomy for PR 7 of the guided-entry UX RFC (PR #1). |

## Adding a new note

1. Pick a name per the conventions above.
2. First line after the title: a `> **Status:**` blockquote with one of the vocabulary terms.
3. Top of the body: a `**Date:**` line, a `**Scope:**` line (what this note is and isn't about), and a `**Related:**` list pointing at any RFCs, PRs, or other notes it depends on.
4. Add a one-line entry to the "Current contents" table in this README.
5. If the note meaningfully changes repo state, update `_repo-context.md` too.

## Conventions for the writing itself

These inherit from the repo's documentation discipline and are reiterated here so they apply to notes even when they're informal:

- Ground every claim in observable repo behavior — a hook, a skill, a template, an artifact path. If it can't be grounded, flag it as aspirational or leave it out.
- No inflated metaphors, manufactured personas, formulaic triplets, false severity, or unsupported compliance assertions.
- Name what the note *can't* see — missing context, unresolved questions, things deferred — rather than papering over them.
- Honest tradeoff analysis over persuasive framing.

The anti-pattern list in `_repo-context.md` applies in full.
