# docs/ — Documentation Index

This file is the authoritative index for everything under `docs/`. Its primary job is to tell you **which files need updating** whenever an RFC is accepted, an RFC is implemented, or a new feature lands. The machine-readable counterpart is [`_index.json`](_index.json).

---

## RFC Workflow

All RFCs and their companion discussion notes follow a single lifecycle. See [`rfcs/README.md`](rfcs/README.md) for the full rules. Short version:

| Stage | Where the file lives | When to move it |
|-------|---------------------|-----------------|
| Early discussion / pre-RFC thinking | `rfcs/notes/` | — |
| Companion note for an active RFC | `rfcs/notes/` | — |
| Formal RFC (draft or accepted) | `rfcs/` root | — |
| RFC fully implemented | `rfcs/archived/` | On implementation |
| Companion note whose RFC is implemented | `rfcs/archived/` | Same step as the RFC |

**Rule:** When an RFC is archived, every companion note that belongs to it moves to `rfcs/archived/` in the same step. `rfcs/notes/` only holds notes for RFCs that are still active.

---

## File Registry

### Core docs

| Path | Title | Status | Role | Description |
|------|-------|--------|------|-------------|
| [GLOSSARY.md](GLOSSARY.md) | Glossary | active | core-reference | Canonical definitions for plugin-specific terms; must mirror accepted RFC vocabulary |
| [SDLC.md](SDLC.md) | SDLC Reference | active | core-reference | Authoritative 8-phase workflow spec — phases, gates, hooks, config layers, validation metrics |
| [USER-MANUAL.md](USER-MANUAL.md) | User Manual | active | user-guide | Practical walkthrough: 8 real-world scenarios, sign-off modes, hook behavior, troubleshooting |
| [review-processes.md](review-processes.md) | Review Processes | active | user-guide | Four review tracks: code, architecture, test-case, and test-script |
| [when-not-to-use.md](when-not-to-use.md) | When Not to Use | active | user-guide | Anti-use-cases and best-fit conditions for the plugin |
| [claude-sdlc-enterprise-adoption.md](claude-sdlc-enterprise-adoption.md) | Enterprise Adoption | active | positioning | Regulatory/enterprise positioning, role changes, cost model, shipped-vs-deferred roadmap |
| [diagrams.md](diagrams.md) | Diagrams | draft | visual-reference | Mermaid diagrams for 8-phase flow and plugin architecture |
| [diagrams-preview.html](diagrams-preview.html) | Diagrams Preview | draft | diagram-source | Rendered HTML preview of diagrams.md Mermaid output |
| [sdlc-architecture.excalidraw](sdlc-architecture.excalidraw) | Architecture Diagram Source | draft | diagram-source | Excalidraw source for the plugin architecture diagram |
| [sdlc-flow.excalidraw](sdlc-flow.excalidraw) | Flow Diagram Source | draft | diagram-source | Excalidraw source for the SDLC phase flow diagram |
| [ideas/capabilities.md](ideas/capabilities.md) | Capabilities Review | active | ideas | Capability maturity ratings, integration matrix, RFC-backed roadmap status |
| [ideas/comparison-gstack.md](ideas/comparison-gstack.md) | Comparison vs. gstack | active | ideas | Strategic positioning: claude-sdlc (governance) vs. gstack (acceleration) |

### References

Living reference files for grounding sessions and tracking development history.

| Path | Title | Status | Role | Description |
|------|-------|--------|------|-------------|
| [references/_repo-context.md](references/_repo-context.md) | Repo Context | active | reference | Canonical repo grounding — principles, capability counts, accepted RFCs, open PRs, anti-patterns. Paste first in any new conversation. |
| [references/_session-handoff.md](references/_session-handoff.md) | Session Handoff | active | reference | Rolling session continuity file (overwritten each session). Key decisions and open items from the most recent session. |
| [references/workflow-log.md](references/workflow-log.md) | Workflow Log | active | reference | Chronological record of what was built and decided across all working sessions on this repo. |

### RFCs

Active RFC trackers and notes.

| Path | Title | Status | Role | Description |
|------|-------|--------|------|-------------|
| [rfcs/AGENT-RULES.md](rfcs/AGENT-RULES.md) | RFC Agent Rules | active | agent-rules | Load when doing RFC work — concise numbered decision rules for AI/Claude Code, no prose |
| [rfcs/README.md](rfcs/README.md) | RFC Workflow | active | workflow | Lifecycle overview with rationale — status vocabulary, naming convention (RFC-NNN), stage transitions, archive rules |
| [rfcs/TEMPLATE.md](rfcs/TEMPLATE.md) | RFC Template | active | template | Copy this when creating a new RFC; includes AI context, alternatives considered, and implementation sections |
| [rfcs/pending-analysis.md](rfcs/pending-analysis.md) | Pending Analysis | active | tracker | Open design questions: items 1–2 open (deferred); all other items closed |
| [rfcs/notes/README.md](rfcs/notes/README.md) | RFC Notes Index | active | notes-index | Index of companion notes, risk analyses, and experiment notes for RFCs currently in flight |
| [rfcs/RFC-001-plan-quality-gates.md](rfcs/RFC-001-plan-quality-gates.md) | Plan Command Quality Gates | accepted | rfc | Closes gap between plan governance intent and enforcement: status check in plan-gate.sh, staleness threshold, scope-delta records, low-provenance markers, degraded-mode banner, domain no-match note |
| [rfcs/RFC-004-maintainer-code-review-enforcement.md](rfcs/RFC-004-maintainer-code-review-enforcement.md) | Maintainer Code-Review Enforcement | accepted | rfc | Three-layer code-review gate (AGENT-RULES.md §14, .claude/hooks/ Stop hook, .github/workflows/code-review.yml) for maintainer PRs to this repo; doc-only PRs bypass (plan/gate files excluded); consuming-repo artifacts untouched |
| [rfcs/RFC-005-work-item-reference-validation.md](rfcs/RFC-005-work-item-reference-validation.md) | Work-Item Reference Validation | draft | rfc | Two-layer work-item existence check: Layer 1 (default warn) verifies REQ IDs resolve to local artifacts and CR IDs to signed CR files; Layer 2 (opt-in) queries detected ticketing integrations with graceful degradation. Extends work-item-validation.sh |
| [rfcs/RFC-006-rfc-lifecycle-quality-gates.md](rfcs/RFC-006-rfc-lifecycle-quality-gates.md) | RFC Lifecycle Quality Gates and Build-Stage Enforcement | accepted | rfc | Adds machine-verifiable lifecycle gates plus a build-stage loop and AI-slop enforcement to docs/rfcs/AGENT-RULES.md. Eight changes: rfc-quality-gate.sh hook (warn), TEMPLATE.md ↔ §3b reconciliation, §2–§7 gate checklists, hook registration, new §3.5 Building (per-PR loop: classify, spawn rfc-pr-reviewer agent on Haiku 4.5, run tests/run.sh if hooks/tests/scripts/config touched, ai-slop-check on doc PRs), new rfc-pr-reviewer agent, ai-slop-check.sh hook, §3a slop-check tightening. Strictly maintainer-only — every artifact under .claude/ paths; capability counts unchanged |

### Archived RFCs

Fully implemented RFCs. Kept for historical traceability; no longer updated.

| Path | Title | Status | Role | Description |
|------|-------|--------|------|-------------|
| [rfcs/archived/RFC-002-release-packaging.md](rfcs/archived/RFC-002-release-packaging.md) | Release Packaging & Marketplace Distribution | implemented | rfc | marketplace.json, scripts/package.sh (devFiles exclusion + release branch), release workflow (CI gate + marketplace ref update), docs/PACKAGING.md |
| [rfcs/archived/RFC-003-hook-enforcement-alignment.md](rfcs/archived/RFC-003-hook-enforcement-alignment.md) | Hook Enforcement Alignment | implemented | rfc | Closes four gaps between USER-MANUAL.md enforcement claims and actual hook implementations: phase-gate.sh PreToolUse registration + severity, placeholder field validation for deploy/fix-fast gates, work-item file-level traceability (warn PR-5, opt-in block PR-8), enforcement language audit. All 8 PRs shipped. |
| [rfcs/archived/scope-ingest.md](rfcs/archived/scope-ingest.md) | Scope Ingest & Domain Expert RFC | implemented | rfc | Defines scope-ingest agent and domain-expert skill; all checklist items complete |
| [rfcs/archived/plan-phase-scope-ingest-discussion.md](rfcs/archived/plan-phase-scope-ingest-discussion.md) | Scope Ingest — RFC Discussion Note | archived | rfc-companion | Pre-RFC discussion note for scope-ingest; promoted to RFC 2026-04-25. Historical record of the analysis path. |
| [rfcs/archived/multi-team-approval.md](rfcs/archived/multi-team-approval.md) | Multi-team Approval RFC | implemented | rfc | All 5 steps shipped: approval-reconcile.sh, sign-off-multi.md, Required sign-offs block, APPROVALS.md, network-share sync (tier 1), git transport (tier 2), MCP connector stub (tier 3) |
| [rfcs/archived/guided-entry-session-resume-multi-role.md](rfcs/archived/guided-entry-session-resume-multi-role.md) | Guided Entry, Session Resume, Multi-role RFC | implemented | rfc | All 10 PRs shipped: /status, /start, session hook, plan versioning, /configure, /help + glossary, approval-packet, next-hints, docs sync |
| [rfcs/archived/guided-entry-pr7-degradation.md](rfcs/archived/guided-entry-pr7-degradation.md) | Guided Entry — PR 7 Degradation Analysis | archived | rfc-companion | Companion note for dropped PR 7; superseded by multi-team-approval.md §3.4–§3.6. |
| [rfcs/archived/opt-in-activation-suspend-resume.md](rfcs/archived/opt-in-activation-suspend-resume.md) | Opt-in Activation, Suspend/Resume RFC | implemented | rfc | Opt-in activation model (.enabled marker), enhanced /start absorbing configure wizard, /suspend with SHA-256 + AES-256 snapshot, re-enable reconciliation with REQ ID supersession |

---

## Change-trigger Checklist

Use this as a PR checklist. For each type of change, the listed files **must be reviewed** and updated if affected.

### New discussion note or pre-RFC thinking
- [ ] Create file in `rfcs/notes/` per conventions in [`rfcs/notes/README.md`](rfcs/notes/README.md)
- [ ] Add entry to `rfcs/notes/README.md` Current contents table
- [ ] Add any open questions to `rfcs/pending-analysis.md`

### RFC written (new RFC file added to `rfcs/`)
- [ ] Copy `rfcs/TEMPLATE.md` → `rfcs/RFC-NNN-<slug>.md`; assign next RFC number
- [ ] `rfcs/pending-analysis.md` — add any open questions surfaced
- [ ] `references/_repo-context.md` — add to draft RFC list
- [ ] Update companion note in `rfcs/notes/` status to `companion`
- [ ] Register in this file (File Registry → RFCs) and in `_index.json`

### RFC accepted
- [ ] **Hard rule: second-opinion review must pass first** — complete per `rfcs/AGENT-RULES.md §3a`; record findings in RFC's `## Second opinion` section; decision must be `proceed` before any step below runs
- [ ] Update `status: accepted` and `last_modified:` in RFC frontmatter
- [ ] `references/_repo-context.md` — move from draft → accepted RFC list
- [ ] `rfcs/pending-analysis.md` — close any resolved items
- [ ] `GLOSSARY.md` — add new terms coined in the RFC
- [ ] `ideas/capabilities.md` — update roadmap status for capabilities the RFC designs

### RFC deferred
- [ ] Update `status: deferred` and `last_modified:` in RFC frontmatter
- [ ] Add `## Deferral note` section explaining why and unpark conditions
- [ ] `references/_repo-context.md` — note as deferred (file stays in `rfcs/` root)

### RFC implemented
- [ ] Populate `## Implementation` section in RFC with commit/PR refs
- [ ] Move RFC file: `rfcs/<slug>.md` → `rfcs/archived/<slug>.md`
- [ ] Move all companion notes for this RFC: `rfcs/notes/<companion>.md` → `rfcs/archived/<companion>.md`
- [ ] Update `rfcs/notes/README.md` — remove moved entries
- [ ] Update this file — move RFC row to **Archived RFCs**; add companion note rows
- [ ] Update `_index.json` — change paths and roles (`rfc` → `rfc-archived`, `rfc-companion`)
- [ ] `references/_repo-context.md` — update capability counts and move RFC to implemented list
- [ ] `references/workflow-log.md` — add a session/feature section
- [ ] `ideas/capabilities.md` — update maturity ratings for newly shipped capabilities
- [ ] `SDLC.md` — if the RFC changes phase behavior, gates, hooks, or validation metrics
- [ ] `USER-MANUAL.md` — if the RFC changes user-facing behavior or introduces new scenarios
- [ ] `GLOSSARY.md` — if the RFC introduces new terms
- [ ] `claude-sdlc-enterprise-adoption.md` — if a roadmap item ships or the cost model changes

### RFC withdrawn
- [ ] Add `## Withdrawal note` section explaining why
- [ ] Update `status: withdrawn` and `last_modified:` in RFC frontmatter
- [ ] Move RFC and companion notes to `rfcs/archived/` (same steps as Implemented, minus living-doc updates)
- [ ] `references/_repo-context.md` — remove from active list

### RFC superseded
- [ ] Add `superseded_by: RFC-NNN-<new-slug>` to old RFC frontmatter
- [ ] Add `supersedes: RFC-NNN-<old-slug>` to new RFC frontmatter
- [ ] Add `## Supersession note` to old RFC
- [ ] Move old RFC and companion notes to `rfcs/archived/`
- [ ] Update indexes (same steps as Implemented)

### New phase added or reordered
- [ ] `SDLC.md`
- [ ] `USER-MANUAL.md`
- [ ] `diagrams.md`
- [ ] `references/_repo-context.md`

### New `/command` added or renamed
- [ ] `USER-MANUAL.md`
- [ ] `review-processes.md` (if the command adds or changes a review track)
- [ ] `references/_repo-context.md` (capability counts)

### New hook added or behavior changed
- [ ] `SDLC.md` (if block/warn behavior changes)
- [ ] `review-processes.md` (if it affects a review track)
- [ ] `USER-MANUAL.md` (if the hook produces user-visible output)

### New term coined (in RFC, PR, or conversation)
- [ ] `GLOSSARY.md`

### Capability shipped (not RFC-tracked)
- [ ] `ideas/capabilities.md`
- [ ] `references/_repo-context.md`
- [ ] `references/workflow-log.md`

---

## RFC Impact Matrix

Derived from `_index.json` update_triggers. A stale `implemented` column against an `accepted` RFC is a signal that implementation docs haven't landed yet.

| RFC | RFC Status | On Acceptance — update | On Implementation — update |
|-----|------------|------------------------|----------------------------|
| [rfcs/RFC-001-plan-quality-gates.md](rfcs/RFC-001-plan-quality-gates.md) | **accepted** | references/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, ideas/capabilities.md, references/_repo-context.md |
| [rfcs/archived/RFC-003-hook-enforcement-alignment.md](rfcs/archived/RFC-003-hook-enforcement-alignment.md) | **implemented** | references/_repo-context.md | USER-MANUAL.md, SDLC.md, references/_repo-context.md |
| [rfcs/RFC-004-maintainer-code-review-enforcement.md](rfcs/RFC-004-maintainer-code-review-enforcement.md) | **accepted** | references/_repo-context.md, rfcs/pending-analysis.md | references/_repo-context.md (capability counts unchanged — maintainer-only) |
| [rfcs/RFC-006-rfc-lifecycle-quality-gates.md](rfcs/RFC-006-rfc-lifecycle-quality-gates.md) | **accepted** | references/_repo-context.md, rfcs/pending-analysis.md | references/_repo-context.md (capability counts unchanged — maintainer-only) |
| [rfcs/archived/RFC-002-release-packaging.md](rfcs/archived/RFC-002-release-packaging.md) | **implemented** | references/_repo-context.md | docs/README.md (PACKAGING.md added), references/_repo-context.md |
| [rfcs/archived/scope-ingest.md](rfcs/archived/scope-ingest.md) | **implemented** | GLOSSARY.md, references/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, ideas/capabilities.md, references/_repo-context.md |
| [rfcs/archived/multi-team-approval.md](rfcs/archived/multi-team-approval.md) | **implemented** | GLOSSARY.md, references/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, claude-sdlc-enterprise-adoption.md, ideas/capabilities.md, references/_repo-context.md |
| [rfcs/archived/guided-entry-session-resume-multi-role.md](rfcs/archived/guided-entry-session-resume-multi-role.md) | **implemented** | references/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, ideas/capabilities.md, references/_repo-context.md |
| [rfcs/archived/opt-in-activation-suspend-resume.md](rfcs/archived/opt-in-activation-suspend-resume.md) | **implemented** | rfcs/pending-analysis.md, references/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, ideas/capabilities.md, references/_repo-context.md |

---

## Maintenance Tiers

### Must stay current
These files are load-bearing. A PR that changes behavior covered by these docs should not merge until they're updated.

- `SDLC.md` — the authoritative phase/hook/gate reference
- `GLOSSARY.md` — term definitions; stale terms break RFC traceability
- `rfcs/AGENT-RULES.md` — the machine-readable RFC decision rules; must stay in sync with `rfcs/README.md`
- `rfcs/README.md` — the RFC lifecycle workflow and rationale
- `rfcs/notes/README.md` — index of in-flight companion notes
- `references/_repo-context.md` — repo grounding; capability counts must match reality

### Acceptable lag
These files should be updated soon after a feature lands, but are not merge-blockers.

- `USER-MANUAL.md` — scenarios can trail behind implementation
- `review-processes.md` — review tracks update less frequently
- `diagrams.md` — visual updates can follow after behavior is stable
- `references/workflow-log.md` — chronological log; acceptable to update at session wrap-up

### Intentionally static / historical
No enforcement. These exist for context and positioning, not as living specs.

- `rfcs/archived/` — append-only; nothing is edited after archiving
- `ideas/` — capability reviews and competitive comparisons update on a market/adoption clock, not a code clock
- `when-not-to-use.md` — philosophy document; changes rarely
- `claude-sdlc-enterprise-adoption.md` — positioning document; updates on a business clock
- `diagrams-preview.html`, `*.excalidraw` — design artifacts, not living docs
