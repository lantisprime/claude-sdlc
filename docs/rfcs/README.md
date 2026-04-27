# `docs/rfcs/` — RFC Directory

This directory manages the full lifecycle of RFCs and their companion discussion notes. Every RFC and its associated notes follow the same path: **notes → active → archived**.

> **AI / Claude Code:** load [`AGENT-RULES.md`](AGENT-RULES.md) at the start of any session that involves creating, updating, moving, or closing an RFC. It contains the decision rules without the explanatory prose.

---

## Directory structure

```
docs/rfcs/
├── README.md              ← this file — lifecycle overview and rationale
├── AGENT-RULES.md         ← load this when doing RFC work — concise decision rules for AI
├── TEMPLATE.md            ← copy this when creating a new RFC
├── pending-analysis.md    ← open design questions tracker (always active)
├── notes/                 ← pre-RFC discussions and active RFC companion notes
│   └── README.md          ← index of notes currently in flight
└── archived/              ← closed RFCs (implemented, withdrawn, superseded) + companion notes
```

---

## Naming convention

RFC files use a sequential ID combined with a descriptive slug:

```
RFC-NNN-<slug>.md
```

Examples: `RFC-005-plan-quality-gates.md`, `RFC-006-multi-team-signing.md`

The RFC-NNN ID is assigned at the time the formal RFC file is created (Stage 2). Discussion notes in `rfcs/notes/` do not get an RFC number — they use a descriptive slug only. Existing RFCs (before this convention was adopted) use slug-only names; do not rename them.

---

## RFC status vocabulary

| Status | Meaning | Where the file lives |
|--------|---------|---------------------|
| `draft` | Proposed; under active discussion | `rfcs/` root |
| `accepted` | Design approved; ready for implementation | `rfcs/` root |
| `deferred` | Valid idea; not the right time — revisit when conditions change | `rfcs/` root |
| `implemented` | Fully shipped | `rfcs/archived/` |
| `withdrawn` | Champion abandoned it; not rejected, just dropped | `rfcs/archived/` |
| `superseded` | Replaced by a newer RFC; carries a `superseded_by:` pointer | `rfcs/archived/` |

---

## RFC lifecycle

### Stage 1 — Discussion (`rfcs/notes/`)

When a new capability or design problem is being explored but no formal RFC exists yet:

1. Create a discussion note in `rfcs/notes/` per the naming conventions in [`notes/README.md`](notes/README.md). Use `experiment` status if the note captures a spike or prototype; use `discussion` for open-ended exploration.
2. Set `> **Status:** discussion` (or `experiment`) at the top of the file.
3. Add a one-line entry to the `## Current contents` table in [`notes/README.md`](notes/README.md).
4. Add any open questions to [`pending-analysis.md`](pending-analysis.md).

Discussion and experiment notes stay in `rfcs/notes/` as long as their RFC is still active. They move to `rfcs/archived/` in the same step as the RFC.

### Stage 2 — Active RFC (`rfcs/`)

When a discussion matures into a formal RFC proposal:

1. Copy [`TEMPLATE.md`](TEMPLATE.md) to `rfcs/RFC-NNN-<slug>.md`. Assign the next available RFC number.
2. Set `status: draft` in the frontmatter.
3. Update the companion note in `rfcs/notes/` status to `companion`.
4. Register the RFC in [`docs/README.md`](../README.md) File Registry under **RFCs**, and in [`docs/_index.json`](../_index.json).
5. Update [`references/_repo-context.md`](../references/_repo-context.md) — add to the draft RFC list.
6. Update `rfcs/pending-analysis.md` with any open questions the RFC surfaces.

When the RFC is **accepted** (design approved, ready for implementation):

> **Hard rule:** a second-opinion review must be completed and recorded in the RFC's `## Second opinion` section before `status: accepted` can be set. See [`AGENT-RULES.md §3`](AGENT-RULES.md) for the review checklist and required output format. An RFC that skips this step remains a draft.

- Run the second-opinion review (`AGENT-RULES.md §3a`). Record findings in `## Second opinion`. If decision is `revise first`, address gaps before continuing.
- Update `status: accepted` and `last_modified:` in the RFC frontmatter.
- Update `GLOSSARY.md` with any new terms the RFC introduces.
- Update `ideas/capabilities.md` with the roadmap status.
- Update `references/_repo-context.md` — move from draft → accepted RFC list.
- Close any resolved items in `pending-analysis.md`.

When an RFC is **deferred** (valid idea, wrong time):

- Update `status: deferred` in the RFC frontmatter.
- Add a `## Deferral note` section explaining why and what conditions would unpark it.
- The file stays in `rfcs/` root — not archived, because it may become active again.
- Update `references/_repo-context.md` to note it as deferred.

### Stage 3 — Closed (`rfcs/archived/`)

An RFC closes when it is **implemented**, **withdrawn**, or **superseded**. All three paths end in `rfcs/archived/`.

**Implemented:**

1. Populate the `## Implementation` section of the RFC with key commit hashes or PR references.
2. Update `status: implemented` and `last_modified:` in the RFC frontmatter.
3. Move the RFC file: `rfcs/<slug>.md` → `rfcs/archived/<slug>.md`.
4. Move all companion notes for this RFC: `rfcs/notes/<companion>.md` → `rfcs/archived/<companion>.md`.
5. Update [`notes/README.md`](notes/README.md) — remove the companion entries.
6. Update [`docs/README.md`](../README.md) — move the RFC row to **Archived RFCs**; add companion note rows.
7. Update [`docs/_index.json`](../_index.json) — update paths and roles (`rfc` → `rfc-archived`).
8. Update `references/_repo-context.md` — update capability counts and move RFC to the implemented list.
9. Update `references/workflow-log.md` — add a section for what was built.
10. Update living docs as applicable: `SDLC.md`, `USER-MANUAL.md`, `GLOSSARY.md`, `ideas/capabilities.md`.

**Withdrawn:**

1. Add a `## Withdrawal note` section to the RFC explaining why it was dropped.
2. Update `status: withdrawn` and `last_modified:`.
3. Move the RFC and all companion notes to `rfcs/archived/`.
4. Update indexes as above (steps 5–7).

**Superseded:**

1. Add `superseded_by: RFC-NNN-<new-slug>` to the RFC frontmatter.
2. Add a `## Supersession note` section pointing to the new RFC and summarising what changed.
3. Update `status: superseded` and `last_modified:`.
4. In the new (superseding) RFC, add `supersedes: RFC-NNN-<old-slug>` to its frontmatter.
5. Move the old RFC and its companion notes to `rfcs/archived/`.
6. Update indexes as above (steps 5–7 from the Implemented path).

---

## Archive rules

- **`rfcs/archived/` is stable, not immutable.** Errata and security clarifications are permitted as minimal in-place edits. Any substantive change in scope or design requires a new RFC with `supersedes: <old-slug>`.
- **Companion notes move with their RFC.** When an RFC closes, every note in `rfcs/notes/` that belongs to it moves to `rfcs/archived/` in the same step.
- **`pending-analysis.md` is never archived.** It is the single always-active tracker for open design questions across all RFCs at any stage.
- **Deferred RFCs stay in `rfcs/` root.** They are not archived because they may become active again.

---

## Quick reference — where does a file go?

| What you have | Status | Where it lives |
|---|---|---|
| Early thinking, not yet a proposal | `discussion` | `rfcs/notes/` |
| Prototype or spike capturing learnings | `experiment` | `rfcs/notes/` |
| Companion analysis for an active RFC | `companion` | `rfcs/notes/` |
| Formal RFC, under discussion | `draft` | `rfcs/` root |
| RFC approved, awaiting implementation | `accepted` | `rfcs/` root |
| RFC parked until conditions change | `deferred` | `rfcs/` root |
| RFC fully shipped | `implemented` | `rfcs/archived/` |
| RFC abandoned by champion | `withdrawn` | `rfcs/archived/` |
| RFC replaced by a newer RFC | `superseded` | `rfcs/archived/` |
| Companion note whose RFC is closed | `archived` | `rfcs/archived/` (same step as RFC) |
| Open design questions, any stage | — | `pending-analysis.md` |
