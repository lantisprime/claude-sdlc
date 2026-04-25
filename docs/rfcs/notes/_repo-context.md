# Repo context — claude-sdlc

> **Purpose.** Paste or reference this file at the start of any new conversation about the repo so the assistant has accurate grounding without re-fetching everything. Keep it short and current. If a fact drifts, fix it here first.

**Repo:** https://github.com/lantisprime/claude-sdlc
**Last updated:** 2026-04-25 (scope-ingest RFC promoted)

---

## What the repo is

An 8-phase SDLC plugin for Claude Code that gates every coding task behind planning, surgical-edit enforcement, and human sign-off artifacts. Trades velocity for discipline, on purpose.

## Core principles (load-bearing — do not erode)

1. **Human in the lead, always.** Subagents and hooks never advance a phase on their own.
2. **Plan before code.** `plan-gate.sh` blocks `Edit`/`Write` when no plan exists for the task.
3. **Surgical edits.** Only plan-listed files and functions. No adjacent-function edits. No "while I'm here" cleanups.
4. **Work-item traceability.** Every build references a REQ ID, ticket, or signed CR.
5. **Graceful degradation.** Missing integrations fall back to local markdown/JSON artifacts. Never silently skip a check.
6. **Stack-agnostic.** Formatter, linter, runners, scanners all configured via `config/tools.json`. Nothing hardcoded.

## 8 phases and the commands that run them

1. Plan — `/plan`
2. Analyze — `/analyze`
3. Design — `/design`
4. Build — `/build`
5. Test — `/test`
6. Deploy — `/deploy`
7. Support — `/support`
8. Docs — `/docs` (cross-cutting)

Plus: `/review` (cross-cutting diff review), `/fix-fast` (bug-only shortcut, ≤2 files, ≤50 LOC), `/token-review` (phase token usage).

Each phase writes a gate file at `.claude/sdlc/gates/<phase>-<slug>.md`. The next phase refuses to start until the prior gate is signed.

## Current capability counts

- **Commands:** 11 (8 phase + `/review` + `/fix-fast` + `/token-review`)
- **Skills:** 14 (8 phase + 6 cross-cutting: `scoping`, `surgical-edit`, `minimal-code`, `security-review`, `api-integration`, `gate-signoff`)
- **Agents:** 4 (`architect`, `test-designer`, `security-reviewer`, `observability`) — bounded write scope, propose-only
- **Hooks:** 10 registered in `hooks/hooks.json` (+ optional `token-tracker.sh`)
- **Templates:** 10

## Hook severity model

- **Block (exit 2)** — refuses the tool call. Reserved for severe consequences: no plan, unsigned CR, confirmed secret.
- **Warn (stderr, exit 0)** — surfaces signal, human decides. Scope drift, adjacent-function edits, test-scope mismatches.

Warnings are not auto-blockers-in-waiting. The adjacent-function detector uses git hunk headers (imperfect) — aggressive blocking there would halt legitimate work.

## Artifact tree in the consuming repo

```
.claude/sdlc/
├── env.json                # detected integrations
├── scope.md                # project scope statement
├── plans/
├── requirements/
├── architecture/
├── tech-specs/
├── test-cases/
├── test-scripts/
├── tickets/
├── change-requests/
├── sign-offs/              # per accepted RFC, one file per signer
├── gates/                  # phase gate files
├── defects/
├── deployments/
├── monitoring/
└── docs/
```

## External connectivity

Four channels, auto-detected by `env-detect.sh` on SessionStart:

- **VCS:** Git + host CLI (gh for GitHub, etc.)
- **Issue tracker:** host-native for GitHub/GitLab/Bitbucket; MCP for Jira/Linear
- **CI:** filesystem sniffing only (never triggers pipelines)
- **Observability:** MCP for Grafana/Datadog; IaC proposals for CloudWatch
- **UX tooling:** MCP for Figma; local markdown fallback
- **Dev-time APIs:** direct HTTP probes via `api-integration`

All MCP-mediated changes are propose-only.

## Sharp edge — frontend UX track

Frontend tasks halt in Phase 2 until some UX artifact exists at `.claude/sdlc/architecture/ux/<task-slug>.md`. Any form counts: Figma link, PDF mockups, screenshots, hand-drawn wireframes, or a written description. Backend-only tasks skip the UX track entirely.

## Accepted RFCs

- **`docs/rfcs/multi-team-approval.md`** (accepted 2026-04-19) — defines:
  - Sign-off files at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md` (one file per signer)
  - `APPROVALS.md` reconciler artifact
  - Transport ladder Tier 0–3 (how approvals arrive)
  - 9-role set (suggested vocabulary)
  - *(Full text not inlined here — read the RFC directly when details are needed.)*

## Open PRs

- **PR #1** — *Draft: Guided-entry, session resume, and approval UX (reshaped)*
  - Branch: `rfc/guided-entry-ux-draft`
  - Status: draft, reshaped 2026-04-24 against accepted `multi-team-approval.md`; ready for review.
  - Proposes 8 PRs layering UX surfaces over the accepted sign-off mechanism: 1 (`/status` with sign-off render), 2 (`/start`), 3 (SessionStart plan-check with opt-out personalization), 4 (plan versioning), 6 (approval packet as `evidence:` target), 8 (`/configure` with reshaped question bank), 9 (glossary + `/help` + unordered-parallel callout + message library), 10 (auto next-step hints).
  - **Dropped during reshape:** former PRs 5 (in-session chain) and 7 (commits-as-signatures) — both duplicated or conflicted with the accepted RFC's model. Companion note `guided-entry-pr7-degradation.md` marked `superseded`.
  - **Compensating additions (option-b):** PR 1 unordered sign-off state render, PR 3 opt-out historical-email personalization, PR 9 unordered-parallel callout — together recover most of the multi-role UX affordance without reopening the conflict.
  - **Pending discussions:** A. Workflow templates — **resolved 2026-04-25 (keep orthogonal; advisory `suggested_roles:` bridge in domain file schema)**. B–E deferred: B. Back/cancel navigation, C. Error-message audit, D. TodoWrite integration, E. Per-phase `/status` detail.

## Draft RFCs (not yet PR'd)

- **Scope ingest + domain expert** — `docs/rfcs/scope-ingest.md` (promoted from discussion note 2026-04-25). Proposes `scope-ingest` agent + `domain-expert` skill hanging off `/plan`. All accepted-RFC conflicts resolved. One open question before implementation: OQ-SCOPE-1 (pseudo-phase gate vs. new artifact class for scope gate file).

## Anti-patterns the repo explicitly guards against

Documented design intent lives in `CLAUDE.md`. Short list of things that *look* like improvements but aren't:

- Auto-advancing phases (breaks "human in the lead")
- Widening `/fix-fast` eligibility beyond bug-only / ≤2 files / ≤50 LOC
- Promoting warn-level hooks to block without evidence
- Silently skipping a check when an integration is missing
- Hardcoding tool choices instead of routing through `config/tools.json`
- Adding commands the human has to memorize when a skill would do

## Writing / framing anti-patterns (for documentation)

Flagged explicitly by the project owner as things to avoid in any documentation, wiki, or RFC prose for this repo:

- Inflated metaphors ("Trojan Horse for autonomy", "velocity unlock", etc.)
- Manufactured personas or job titles used as rhetorical devices
- Formulaic triplet structures when a single clear sentence does the job
- False severity escalation (calling warnings "blockers", advisory findings "critical")
- Unsupported compliance assertions (implying the plugin delivers SOC2 / PCI-DSS / HIPAA guarantees it does not)
- Aspirational framing that outruns what the repo actually does

When in doubt, ground every claim in observable repo behavior (a hook, a skill, a template, an artifact path). If it can't be grounded, either leave it out or flag it as aspirational.

## Validation metrics (targets when tuning)

- Plan-first compliance: 100%
- Work-item validation: 100%
- Scope discipline (files touched ÷ files in scope): 1.0
- Adjacent-function modifications per task: 0
- Test scope ratio (tests modified ÷ code modified): ≈ 1.0

## How to use this file

- **Starting a new conversation about the repo:** paste this file first, then ask your question.
- **Something here is wrong or stale:** fix it here before making the decision that depends on it. This file is the index; drift here is worse than drift anywhere else.
- **Adding a new active discussion:** add a one-line entry under "Active discussions" pointing to the note file in this directory.
