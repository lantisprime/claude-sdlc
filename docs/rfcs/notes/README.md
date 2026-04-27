# `docs/rfcs/notes/`

Working notes that sit alongside RFCs but aren't RFCs themselves. This directory is for in-flight thinking, companion implementation notes, conflict analyses, and shared context that the main repo docs shouldn't carry.

**Start here:** [`docs/references/_repo-context.md`](../../references/_repo-context.md) — the canonical grounding for any new conversation about the repo. Paste it first.

---

## What belongs here vs. in `docs/rfcs/`

| Lives in `docs/rfcs/` | Lives in `docs/rfcs/notes/` |
| --- | --- |
| Formal RFC (draft, accepted, deferred) | Discussion note or experiment leading up to an RFC |
| Decision the repo now enforces | Companion analysis or risk note for an active RFC |
| Closed RFC (implemented, withdrawn, superseded) → `rfcs/archived/` | Conflict analysis between competing proposals |

If a note hardens into a decision, promote it to a formal RFC using [`rfcs/TEMPLATE.md`](../TEMPLATE.md). When an RFC closes, its companion notes move to `rfcs/archived/` in the same step.

## Naming conventions

- **RFC companions** — match the RFC's slug with a qualifier: `<rfc-slug>-<qualifier>.md`. Example: `guided-entry-pr7-degradation.md`.
- **Standalone discussions** — descriptive slug, area first: `<area>-<topic>-discussion.md`. Example: `plan-phase-scope-ingest-discussion.md`.
- **Experiments / spikes** — slug ending in `-spike.md` or `-experiment.md`. Example: `plan-quality-gate-spike.md`.
- **Risk analyses** — slug ending in `_analysis.md`. Example: `plan_command_analysis.md`.
- **Conflict checks** — slug ending in `-conflict-check.md`.

## Status vocabulary

Every note should declare its status in the first line after the title. Use one of:

- **discussion** — open-ended exploration; not yet shaped into a proposal
- **experiment** — a spike or prototype built to learn whether an approach is viable; captures what was tried and what was learned, regardless of whether it became an RFC
- **companion** — analysis or implementation detail for a specific active RFC; moves to `rfcs/archived/` when the RFC closes
- **superseded** — kept for history; point at what replaced it
- **archived** — historical record of a path not taken

A note with no status field should be treated as `discussion`.

## Current contents

Files stay here while their related RFC is still active or not yet accepted. Once the RFC is implemented, both the RFC and its companion notes move to `docs/rfcs/archived/`.

| File | Status | What it covers |
| --- | --- | --- |
| [`plan_command_analysis.md`](./plan_command_analysis.md) | companion | Risk analysis for `/plan` command — 18 risks from code inspection + ChatGPT synthesis. Companion to RFC-001-plan-quality-gates.md; items 11–13 scoped as separate architectural changes. |
| [`analysis_command_analysis.md`](./analysis_command_analysis.md) | discussion | Risk analysis for `/analyze` command — 14 risks from code inspection + ChatGPT synthesis. Recommended sequencing: template changes first, then skill additions, then hook changes. |

Reference files (`_repo-context.md`, `_session-handoff.md`, `workflow-log.md`) are in [`docs/references/`](../../references/). Archived RFC companion notes are in [`docs/rfcs/archived/`](../archived/).

## Adding a new note

1. Pick a name and status per the conventions above. Use `experiment` if you built or prototyped something to learn from it; use `discussion` for open-ended analysis.
2. First line after the title: a `> **Status:**` blockquote with one of the vocabulary terms.
3. Top of the body: a `**Date:**` line, a `**Scope:**` line (what this note is and is not about), and a `**Related:**` list pointing at any RFCs, PRs, or other notes it depends on. For `experiment` notes, add a `**Outcome:**` line summarising what was learned.
4. Add a one-line entry to the "Current contents" table in this README.
5. If the note meaningfully changes repo state, update `references/_repo-context.md`.

## Conventions for the writing itself

These inherit from the repo's documentation discipline and are reiterated here so they apply to notes even when they're informal:

- Ground every claim in observable repo behavior — a hook, a skill, a template, an artifact path. If it can't be grounded, flag it as aspirational or leave it out.
- No inflated metaphors, manufactured personas, formulaic triplets, false severity, or unsupported compliance assertions.
- Name what the note *can't* see — missing context, unresolved questions, things deferred — rather than papering over them.
- Honest tradeoff analysis over persuasive framing.

The anti-pattern list in `_repo-context.md` applies in full.
