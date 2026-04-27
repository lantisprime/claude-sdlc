# RFC Agent Rules

Load this file at the start of any session that involves creating, updating, moving, or closing an RFC or companion note. It is the authoritative decision source — `rfcs/README.md` is the explanatory version.

---

## 0. Before doing anything

1. Read `docs/references/_repo-context.md` if you haven't already — it tells you what RFCs currently exist and their status.
2. Identify the RFC's current status from its frontmatter (`status:` field) or its location on disk.
3. Confirm the intended transition before touching any file.

---

## 1. Status → location mapping

| Status | File location | Editable? |
|--------|--------------|-----------|
| `draft` | `rfcs/` root | Yes |
| `accepted` | `rfcs/` root | Yes (frontmatter + open questions only) |
| `deferred` | `rfcs/` root | Yes (add deferral note) |
| `implemented` | `rfcs/archived/` | Errata only — no scope changes |
| `withdrawn` | `rfcs/archived/` | Errata only |
| `superseded` | `rfcs/archived/` | Errata only |

Companion notes in `rfcs/notes/` always match the lifecycle of their RFC. When the RFC moves to `archived/`, the companion moves in the same operation.

---

## 2. Creating a new RFC

**Trigger:** a discussion note has matured into a formal proposal, or a new RFC is requested from scratch.

1. Find the highest existing RFC number across `rfcs/`, `rfcs/archived/`, and any `RFC-NNN` references in `pending-analysis.md`. Assign the next integer.
2. Copy `rfcs/TEMPLATE.md` → `rfcs/RFC-NNN-<slug>.md`.
3. Fill in `rfc_id`, `slug`, `title`, `champion`, `created`, `last_modified`. Set `status: draft`.
4. Write `## AI context` first — three sentences: what it does, what problem it solves, the key trade-off. This section is required and must be completed before the RFC is shared for review.
5. If a companion note exists in `rfcs/notes/`, update its `> **Status:**` to `companion`.
6. Register the RFC in `docs/README.md` File Registry under **RFCs** and in `docs/_index.json`.
7. Update `docs/references/_repo-context.md` — add to the draft RFC list.
8. Add open questions to `rfcs/pending-analysis.md`.

---

## 3. Accepting an RFC

**Trigger:** design is approved; implementation can begin.

> **Hard rule — second opinion required.** An RFC cannot move to `accepted` until a second-opinion review is completed and recorded in the RFC's `## Second opinion` section. This step cannot be skipped or deferred.

**3a. Run the second-opinion review first:**

Re-read the RFC in full as if encountering it for the first time. Check:

1. **AI context** — does the 3-sentence summary accurately reflect the RFC as written? Is it still current?
2. **Problem** — is it grounded in observable behavior, not assumed? Is it still the right problem to solve?
3. **Proposal** — is the scope (in/out) explicit? Are there implementation risks not yet captured?
4. **Alternatives considered** — are there alternatives missing from the table that a future reader would reasonably ask about?
5. **Open questions** — are any OQs still unresolved that would block a safe implementation?
6. **Compatibility** — does the proposal conflict with any other accepted or implemented RFC?

Record the findings in the RFC's `## Second opinion` section:

```markdown
## Second opinion

**Reviewer:** <name or "self-review">
**Date:** YYYY-MM-DD
**Findings:** [gaps surfaced, alternatives missed, risks not captured — or "no gaps found"]
**Decision:** proceed | revise first
```

If the decision is `revise first`, address the gaps before setting `status: accepted`. Do not proceed until the decision is `proceed`.

**3b. After second opinion clears:**

1. Update `status: accepted` and `last_modified:` in RFC frontmatter.
2. Resolve or update open questions in the `## Open questions` table.
3. Update `docs/references/_repo-context.md` — move RFC from draft → accepted.
4. Update `docs/GLOSSARY.md` if the RFC introduces new terms.
5. Update `docs/ideas/capabilities.md` roadmap status.
6. Close resolved items in `rfcs/pending-analysis.md`.

---

## 4. Deferring an RFC

**Trigger:** RFC is valid but conditions aren't right to implement it now.

1. Update `status: deferred` and `last_modified:`.
2. Add `## Deferral note` section: why deferred, what conditions would unpark it.
3. File stays in `rfcs/` root — do NOT move to `archived/`.
4. Update `docs/references/_repo-context.md` to note it as deferred.

---

## 5. Implementing an RFC

**Trigger:** all implementation PRs are merged.

1. Populate `## Implementation` section with commit hashes and key files changed.
2. Update `status: implemented` and `last_modified:`.
3. Move RFC: `rfcs/<slug>.md` → `rfcs/archived/<slug>.md`.
4. Move all companion notes: `rfcs/notes/<companion>.md` → `rfcs/archived/<companion>.md`.
5. Update `rfcs/notes/README.md` — remove moved entries.
6. Update `docs/README.md` — move RFC row to **Archived RFCs**; add companion rows below it.
7. Update `docs/_index.json` — change `path` and `role` to `rfc-archived` / `rfc-companion` for all moved files.
8. Update `docs/references/_repo-context.md` — update capability counts; move RFC to implemented list.
9. Update `docs/references/workflow-log.md` — add a section for what was built.
10. Update living docs as needed: `docs/SDLC.md`, `docs/USER-MANUAL.md`, `docs/GLOSSARY.md`, `docs/ideas/capabilities.md`.

---

## 6. Withdrawing an RFC

**Trigger:** champion is abandoning the RFC — not rejected, just dropped.

1. Add `## Withdrawal note` section: why it was dropped, what would need to change for it to be reconsidered.
2. Update `status: withdrawn` and `last_modified:`.
3. Move RFC and companion notes to `rfcs/archived/` (same move steps as §5, steps 3–7).
4. Update `docs/references/_repo-context.md` — remove from active RFC list.
5. Do NOT update living docs (SDLC.md, USER-MANUAL.md) unless the RFC had already changed behavior.

---

## 7. Superseding an RFC

**Trigger:** a new RFC replaces an older one.

1. On the **old RFC**: add `superseded_by: RFC-NNN-<new-slug>`, update `status: superseded`, update `last_modified:`, add `## Supersession note` summarising what changed.
2. On the **new RFC**: add `supersedes: RFC-NNN-<old-slug>` to frontmatter.
3. Move old RFC and its companion notes to `rfcs/archived/` (same steps as §5, steps 3–7).
4. The new RFC follows the normal create → accept → implement lifecycle.

---

## 8. Editing archived files

Archived files (`rfcs/archived/`) are stable. Permitted changes:
- Fixing a factual error in the text (errata)
- Adding a `superseded_by:` pointer when a superseding RFC is written later
- Fixing broken internal links

Not permitted (require a new RFC instead):
- Changing scope, design decisions, or technical choices
- Adding new requirements or removing existing ones

---

## 9. Companion notes

- A companion note lives in `rfcs/notes/` while its RFC is active.
- When the RFC moves to `rfcs/archived/`, the companion moves in the same operation — never separately.
- If a note is not attached to any specific RFC (e.g. a risk analysis or experiment), it stays in `rfcs/notes/` until it is explicitly superseded or archived.

---

## 10. Required sections in every RFC

| Section | Required when |
|---------|--------------|
| `## AI context` | Always — fill before sharing for review |
| `## Problem` | Always |
| `## Proposal` | Always |
| `## Alternatives considered` | Always — at least one row in the table |
| `## Implementation` | After implementation only |
| `## Open questions` | Required if any OQs exist at draft time |
| `## Deferral note` | Only if `status: deferred` |
| `## Withdrawal note` | Only if `status: withdrawn` |
| `## Supersession note` | Only if `status: superseded` |

---

## 11. Index files to keep in sync

Any RFC status change or file move must update all of these:

| File | What to update |
|------|---------------|
| `docs/README.md` | File Registry row (path, status, role) |
| `docs/_index.json` | `path`, `status`, `role` fields |
| `docs/references/_repo-context.md` | RFC list (draft / accepted / implemented / deferred) |
| `rfcs/notes/README.md` | Remove entries for notes that moved to `archived/` |
| `rfcs/pending-analysis.md` | Close resolved questions |

`docs/references/workflow-log.md` and living docs (`SDLC.md`, `USER-MANUAL.md`, etc.) update on implementation only.
