# docs/ — Documentation Index

This file is the authoritative index for everything under `docs/`. Its primary job is to tell you **which files need updating** whenever an RFC is accepted, an RFC is implemented, or a new feature lands. The machine-readable counterpart is [`_index.json`](_index.json).

---

## File Registry

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
| [rfcs/scope-ingest.md](rfcs/scope-ingest.md) | Scope Ingest & Domain Expert RFC | implemented | rfc | Defines scope-ingest agent and domain-expert skill; all checklist items complete |
| [rfcs/multi-team-approval.md](rfcs/multi-team-approval.md) | Multi-team Approval RFC | implemented | rfc | All 5 steps shipped: approval-reconcile.sh, sign-off-multi.md, Required sign-offs block, APPROVALS.md, network-share sync (tier 1), git transport (tier 2), MCP connector stub (tier 3) |
| [rfcs/guided-entry-session-resume-multi-role.md](rfcs/guided-entry-session-resume-multi-role.md) | Guided Entry, Session Resume, Multi-role RFC | implemented | rfc | All 10 PRs shipped: /status, /start, session hook, plan versioning, /configure, /help + glossary, approval-packet, next-hints, docs sync |
| [rfcs/opt-in-activation-suspend-resume.md](rfcs/opt-in-activation-suspend-resume.md) | Opt-in Activation, Suspend/Resume RFC | draft | rfc | Opt-in activation model (.enabled marker), enhanced /start absorbing configure wizard, /suspend with SHA-256 + AES-256 snapshot, re-enable reconciliation with REQ ID supersession |
| [rfcs/pending-analysis.md](rfcs/pending-analysis.md) | Pending Analysis | active | tracker | Open design questions: items 1–2 open (deferred), item 3 closed/accepted, item 4 open (secret-scan always-on) |
| [rfcs/notes/README.md](rfcs/notes/README.md) | RFC Notes Index | active | notes-index | Index and naming conventions for all RFC companion notes in this directory |

---

## Change-trigger Checklist

Use this as a PR checklist. For each type of change, the listed files **must be reviewed** and updated if affected.

### RFC written (new RFC file added)
- [ ] `rfcs/pending-analysis.md` — add any open questions surfaced
- [ ] `rfcs/notes/_repo-context.md` — add to draft RFC list

### RFC accepted
- [ ] `rfcs/notes/_repo-context.md` — move from draft → accepted RFC list
- [ ] `rfcs/pending-analysis.md` — close any resolved items
- [ ] `GLOSSARY.md` — add new terms coined in the RFC
- [ ] `ideas/capabilities.md` — update roadmap status for capabilities the RFC designs

### RFC implemented
- [ ] The RFC file itself — update status field to `implemented`
- [ ] `rfcs/notes/_repo-context.md` — update capability counts and implemented list
- [ ] `ideas/capabilities.md` — update maturity ratings for newly shipped capabilities
- [ ] `SDLC.md` — if the RFC changes phase behavior, gates, hooks, or validation metrics
- [ ] `USER-MANUAL.md` — if the RFC changes user-facing behavior or introduces new scenarios
- [ ] `GLOSSARY.md` — if the RFC introduces new terms
- [ ] `claude-sdlc-enterprise-adoption.md` — if a roadmap item ships or the cost model changes

### New phase added or reordered
- [ ] `SDLC.md`
- [ ] `USER-MANUAL.md`
- [ ] `diagrams.md`
- [ ] `rfcs/notes/_repo-context.md`

### New `/command` added or renamed
- [ ] `USER-MANUAL.md`
- [ ] `review-processes.md` (if the command adds or changes a review track)
- [ ] `rfcs/notes/_repo-context.md` (capability counts)

### New hook added or behavior changed
- [ ] `SDLC.md` (if block/warn behavior changes)
- [ ] `review-processes.md` (if it affects a review track)
- [ ] `USER-MANUAL.md` (if the hook produces user-visible output)

### New term coined (in RFC, PR, or conversation)
- [ ] `GLOSSARY.md`

### Capability shipped (not RFC-tracked)
- [ ] `ideas/capabilities.md`
- [ ] `rfcs/notes/_repo-context.md`

---

## RFC Impact Matrix

Derived from `_index.json` update_triggers. A stale `implemented` column against an `accepted` RFC is a signal that implementation docs haven't landed yet.

| RFC | RFC Status | On Acceptance — update | On Implementation — update |
|-----|------------|------------------------|----------------------------|
| [rfcs/scope-ingest.md](rfcs/scope-ingest.md) | **implemented** | GLOSSARY.md, rfcs/notes/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, ideas/capabilities.md, rfcs/notes/_repo-context.md |
| [rfcs/multi-team-approval.md](rfcs/multi-team-approval.md) | **implemented** (all 5 steps shipped) | GLOSSARY.md, rfcs/notes/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, claude-sdlc-enterprise-adoption.md, ideas/capabilities.md, rfcs/notes/_repo-context.md |
| [rfcs/guided-entry-session-resume-multi-role.md](rfcs/guided-entry-session-resume-multi-role.md) | **implemented** | rfcs/notes/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, ideas/capabilities.md, rfcs/notes/_repo-context.md |
| [rfcs/opt-in-activation-suspend-resume.md](rfcs/opt-in-activation-suspend-resume.md) | **draft** | rfcs/pending-analysis.md, rfcs/notes/_repo-context.md, ideas/capabilities.md | SDLC.md, USER-MANUAL.md, GLOSSARY.md, ideas/capabilities.md, rfcs/notes/_repo-context.md |

---

## Maintenance Tiers

### Must stay current
These files are load-bearing. A PR that changes behavior covered by these docs should not merge until they're updated.

- `SDLC.md` — the authoritative phase/hook/gate reference
- `GLOSSARY.md` — term definitions; stale terms break RFC traceability
- `rfcs/*.md` — status fields must reflect actual implementation state
- `rfcs/notes/README.md` — the notes directory index

### Acceptable lag
These files should be updated soon after a feature lands, but are not merge-blockers.

- `USER-MANUAL.md` — scenarios can trail behind implementation
- `review-processes.md` — review tracks update less frequently
- `diagrams.md` — visual updates can follow after behavior is stable

### Intentionally static / historical
No enforcement. These exist for context and positioning, not as living specs.

- `ideas/` — capability reviews and competitive comparisons update on a market/adoption clock, not a code clock
- `rfcs/notes/` — individual companion notes are historical once promoted or superseded
- `when-not-to-use.md` — philosophy document; changes rarely
- `claude-sdlc-enterprise-adoption.md` — positioning document; updates on a business clock
- `diagrams-preview.html`, `*.excalidraw` — design artifacts, not living docs
