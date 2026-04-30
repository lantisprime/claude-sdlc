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

**Gate checklist (verify before sharing the draft for review):**
- [ ] `## AI context` written (3 sentences: what, problem, key trade-off)
- [ ] Required sections present and non-empty: `## Problem`, `## Proposal`, `## Alternatives considered`
- [ ] Companion note (if any) in `rfcs/notes/` updated to `> **Status:** companion`
- [ ] All 4 index files updated: `docs/README.md`, `docs/_index.json`, `docs/references/_repo-context.md`, `rfcs/pending-analysis.md`
- [ ] Frontmatter complete: `rfc_id`, `slug`, `title`, `champion`, `created`, `last_modified`, `status: draft`

---

## 3. Accepting an RFC

**Trigger:** design is approved; implementation can begin.

> **Hard rule — second opinion required.** An RFC cannot move to `accepted` until a second-opinion review is completed and recorded in `## Second opinion`.

**3a. Run the second-opinion review first:**

Re-read the RFC as if encountering it for the first time. Check:

| Section | Question |
|---------|----------|
| **AI context** | Does the 3-sentence summary still accurately reflect the RFC? |
| **Problem** | Grounded in observable behavior? Still the right problem? |
| **Proposal** | Is scope (in/out) explicit? Implementation risks captured? |
| **Alternatives** | Any obvious alternatives a future reader would ask about? |
| **Open questions** | Any unresolved OQs that would block safe implementation? |
| **Compatibility** | Conflicts with any accepted or implemented RFC? |

Record findings in `## Second opinion`:

```markdown
## Second opinion

**Reviewer:** <name or "self-review">
**Date:** YYYY-MM-DD
**Findings:** [gaps surfaced, alternatives missed, risks not captured — or "no gaps found"]
**AI-slop check:** clean | fixed in revision | concerns:[<list>]
**Decision:** proceed | revise first
```

**Decision rules:**

- `**Decision:** proceed` is permitted only when `**AI-slop check:**` is `clean` or `fixed in revision`.
- If `**AI-slop check:** concerns:[<list>]` is recorded, `**Decision:** proceed` is forbidden — must be `revise first` until the concerns are resolved or fixed in revision.
- If the decision is `revise first` (whether due to slop concerns or any other gaps), address the gaps before setting `status: accepted`.

> **Preferred approach:** spawn an independent subagent to perform the review rather than self-reviewing. An agent with no prior context on the RFC surfaces risks and alternatives that familiarity obscures. The slop-check pass should default to **Haiku 4.5** for cost discipline (matching Change 6 of RFC-006: ~1–3k tokens per review vs. ~10–15k on Sonnet).

**3b. After second opinion clears:**

1. Update `status: accepted` and `last_modified:` in RFC frontmatter.
2. **Write `## Implementation plan`** — use `### PR-N — <file(s)>` subheadings. For each PR: **Before** block (current state or "file does not exist"), **After** block (exact diff, skeleton, or section outline), one-line dependency note, key constraints. Close with a **Sequencing** diagram.
3. Resolve or update open questions in the `## Open questions` table.
4. Update `docs/references/_repo-context.md` — move RFC from draft → accepted.
5. Update `docs/README.md` — File Registry and RFC Impact Matrix rows.
6. Update `docs/_index.json` — `status` and `rfc_status` fields.

> **Hard stop — do not offer implementation until all steps above are complete.** Specifically: `status: accepted` is set, `## Second opinion` decision is `proceed`, `## Implementation plan` is written, and all index files are updated. Offering to implement before these are done skips the acceptance gate.
5. Update `docs/GLOSSARY.md` if the RFC introduces new terms.
6. Update `docs/ideas/capabilities.md` roadmap status.
7. Close resolved items in `rfcs/pending-analysis.md`.

**Gate checklist (verify before setting `status: accepted`):**
- [ ] `## Second opinion` populated with `**Decision:** proceed` (not `revise first`)
- [ ] `## Implementation plan` written with `### PR-N` subheadings (per §3b — not the template placeholder)
- [ ] `last_modified:` updated in frontmatter to today's date
- [ ] All 5 index files in §11 updated in the same change
- [ ] Open questions either resolved in the RFC table or moved to `pending-analysis.md`

---

## 3.5 Building (after `accepted`, before `implemented`)

**Trigger:** the first PR for an accepted RFC is opened.

**Per-PR loop** — for each PR listed in `## Implementation plan`, before marking its row in the RFC's `## Implementation` table:

1. **Classify the PR by changed paths:**
   - `code-change`: any file outside `docs/` and not matching `*.md`.
   - `docs-change`: only `*.md` files and files under `docs/`.
   - `mixed`: both.

2. **If `code-change` or `mixed`:** spawn `.claude/agents/rfc-pr-reviewer.md` (Haiku 4.5). The agent reads the RFC's `## Implementation plan`, reads the PR diff, and returns a verdict from the closed set: `approved` | `changes-requested` | `concerns:[…]`. Record the verdict on the PR row.

3. **If the PR touches `hooks/`, `tests/`, `scripts/`, or `config/`:** run `tests/run.sh`. Record `pass` or `fail (n suites)` on the PR row.

4. **If `docs-change` or `mixed`:** invoke `.claude/hooks/ai-slop-check.sh` against the PR's changed `.md` files. Auto-apply only: (a) deletion of a single hedge word, (b) swap of an inflated metaphor for a neutral synonym from a fixed lookup table, or (c) trim of a triplet to a duplet. Anything else is flagged for human review on the PR row.

5. **PR row complete only when:** review verdict is recorded, tests pass if applicable, and slop check is clean or auto-fixed. Closed cell vocabularies:
   - **Verdict:** `approved` | `changes-requested` | `concerns:[…]` | `n/a (docs-only)`
   - **Tests:** `pass` | `fail (n suites)` | `n/a (no code)`
   - **Slop:** `clean` | `auto-fixed` | `flagged:[…]` | `n/a (no docs)`

**Move to `implemented`** (per §5) only when every planned PR row is complete per the above. The `rfc-quality-gate.sh` stub-row check (PR-3, extended in PR-7) WARNs on the `status: implemented` transition while any row still holds the template `_pending_` sentinel — completing rows is the maintainer's responsibility, surfaced by the warn-only gate.

**Gate checklist (verify before opening any PR for an accepted RFC):**
- [ ] PR scope matches one row in `## Implementation plan` — no "while I'm here" cleanup
- [ ] Local `tests/run.sh` green if PR touches `hooks/`/`tests/`/`scripts/`/`config/`

---

## 4. Deferring an RFC

**Trigger:** RFC is valid but conditions aren't right to implement it now.

1. Update `status: deferred` and `last_modified:`.
2. Add `## Deferral note` section: why deferred, what conditions would unpark it.
3. File stays in `rfcs/` root — do NOT move to `archived/`.
4. Update `docs/references/_repo-context.md` to note it as deferred.

**Gate checklist (verify before setting `status: deferred`):**
- [ ] `## Deferral note` populated with both reason AND unpark conditions
- [ ] `status: deferred` and `last_modified:` updated in frontmatter
- [ ] `_repo-context.md` notes the deferral
- [ ] File NOT moved to `archived/` (deferred RFCs stay in `rfcs/` root)

---

## 5. Implementing an RFC

**Trigger:** all implementation PRs are merged.

1. Populate `## Implementation` section with PR numbers and key files changed. **Mark each PR row immediately after it merges — do not batch at the end.**
2. Update `status: implemented` and `last_modified:` in RFC frontmatter.
3. Move RFC: `rfcs/<slug>.md` → `rfcs/archived/<slug>.md`.
4. Move all companion notes: `rfcs/notes/<companion>.md` → `rfcs/archived/<companion>.md`.
5. Update `rfcs/notes/README.md` — remove moved entries.
6. Update `docs/README.md` — move RFC row to **Archived RFCs**; add companion rows below it.
7. Update `docs/_index.json` — change `path` and `role` to `rfc-archived` / `rfc-companion` for all moved files.
8. Update `docs/references/_repo-context.md` — update capability counts; move RFC to implemented list.
9. Update `docs/references/workflow-log.md` — add a section for what was built.
10. Update living docs as needed: `docs/SDLC.md`, `docs/USER-MANUAL.md`, `docs/GLOSSARY.md`, `docs/ideas/capabilities.md`.

**Gate checklist (verify before setting `status: implemented`):**
- [ ] `## Implementation` table populated — no `abc1234` placeholder rows; each PR row has both PR link and commit SHA
- [ ] RFC file moved from `rfcs/<slug>.md` to `rfcs/archived/<slug>.md` (and any companion notes moved with it)
- [ ] All §11 index files synced: `docs/README.md` (row moved to Archived RFCs + RFC Impact Matrix), `docs/_index.json` (path + role), `_repo-context.md` (count + section), `rfcs/README.md` (queue removal), `workflow-log.md` (new section), `notes/README.md` (companion entries removed if any)
- [ ] Capability counts in `_repo-context.md` updated if RFC added consumer-facing artifacts (skills/hooks/agents/commands/templates under `sdlc-plugin/`)
- [ ] All open questions in the RFC table marked resolved with their actual implementation outcomes

---

## 6. Withdrawing an RFC

**Trigger:** champion is abandoning the RFC — not rejected, just dropped.

1. Add `## Withdrawal note` section: why it was dropped, what would need to change for it to be reconsidered.
2. Update `status: withdrawn` and `last_modified:`.
3. Move RFC and companion notes to `rfcs/archived/` (same move steps as §5, steps 3–7).
4. Update `docs/references/_repo-context.md` — remove from active RFC list.
5. Do NOT update living docs (SDLC.md, USER-MANUAL.md) unless the RFC had already changed behavior.

**Gate checklist (verify before setting `status: withdrawn`):**
- [ ] `## Withdrawal note` populated with reason AND reconsideration conditions
- [ ] `status: withdrawn` + `last_modified:` updated
- [ ] RFC + companion notes moved to `archived/`
- [ ] Index files synced (`docs/README.md`, `docs/_index.json`, `_repo-context.md`, `rfcs/README.md` queue removal if previously accepted)
- [ ] Living docs (SDLC.md, USER-MANUAL.md) NOT updated unless the RFC had already changed behavior

---

## 7. Superseding an RFC

**Trigger:** a new RFC replaces an older one.

1. On the **old RFC**: add `superseded_by: RFC-NNN-<new-slug>`, update `status: superseded`, update `last_modified:`, add `## Supersession note` summarising what changed.
2. On the **new RFC**: add `supersedes: RFC-NNN-<old-slug>` to frontmatter.
3. Move old RFC and its companion notes to `rfcs/archived/` (same steps as §5, steps 3–7).
4. The new RFC follows the normal create → accept → implement lifecycle.

**Gate checklist (verify before setting `status: superseded`):**
- [ ] Old RFC: `superseded_by:` frontmatter set + `## Supersession note` populated with what changed
- [ ] New RFC: `supersedes:` frontmatter set (cross-link symmetry)
- [ ] Old RFC + companion notes moved to `archived/`
- [ ] Index files synced (path + role updates per §5 steps 5–7)
- [ ] New RFC follows full create → accept → implement lifecycle separately (this checklist only covers the supersession move)

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
| `## Implementation plan` | Required when `status: accepted` |
| `## Implementation` | After implementation only (post-ship PR refs) |
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
| `rfcs/README.md` | `## Implementation queue` table — add a row when status moves to `accepted`; remove the row when status moves to `implemented`, `withdrawn`, or `superseded`. Re-order rows if dependency or sequencing changes. |
| `rfcs/notes/README.md` | Remove entries for notes that moved to `archived/` |
| `rfcs/pending-analysis.md` | Close resolved questions |

`docs/references/workflow-log.md` and living docs (`SDLC.md`, `USER-MANUAL.md`, etc.) update on implementation only.
