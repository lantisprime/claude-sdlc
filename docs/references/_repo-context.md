# Repo context — claude-sdlc

> **Purpose.** Paste or reference this file at the start of any new conversation about the repo so the assistant has accurate grounding without re-fetching everything. Keep it short and current. If a fact drifts, fix it here first.
>
> **Plugin artifact work (skills, hooks, commands, templates, config):** load `AGENT-RULES.md` (repo root) — concise decision rules for adding and modifying plugin artifacts.
>
> **RFC work:** also load `docs/rfcs/AGENT-RULES.md` — it contains the concise decision rules for creating, transitioning, and archiving RFCs.

**Repo:** https://github.com/lantisprime/claude-sdlc
**Last updated:** 2026-04-27 (RFC-002-release-packaging added — draft)

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

Plus: `/review` (cross-cutting diff review), `/fix-fast` (bug-only shortcut, ≤2 files, ≤50 LOC), `/token-review` (phase token usage), `/configure` (stack setup wizard), `/start` (opt-in activation + task intake + re-enable reconciliation), `/status` (read-only task state), `/help` (command reference), `/suspend` (pause enforcement with governance snapshot).

Each phase writes a gate file at `.claude/sdlc/gates/<phase>-<slug>.md`. The next phase refuses to start until the prior gate is signed.

## Current capability counts

- **Commands:** 16 (8 phase + `/review` + `/fix-fast` + `/token-review` + `/suspend` + `/configure` + `/start` + `/status` + `/help`)
- **Skills:** 20 (8 phase + 7 cross-cutting: `scoping`, `surgical-edit`, `minimal-code`, `security-review`, `api-integration`, `gate-signoff`, `domain-expert` + 5 utility: `configure`, `start`, `status`, `help`, `suspend`)
- **Agents:** 5 (`architect`, `test-designer`, `security-reviewer`, `observability`, `scope-ingest`) — bounded write scope, propose-only
- **Hooks:** 13 registered in `hooks/hooks.json` + `suspend-snapshot.sh` (skill-invoked by `/suspend`, not an event hook)
- **Templates:** 13 (incl. `scope-gate`, `approval-packet`, `sign-off-multi`)

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
├── approval-packets/       # compiled reviewer summaries for multi-team sign-offs
├── gates/                  # phase gate files
├── defects/
├── deployments/
├── monitoring/
├── .enabled                # opt-in activation marker (created by /start)
├── .suspended              # suspension marker (created by /suspend)
├── .suspension-log.jsonl   # append-only log of suspend/resume events
├── .suspension-snapshot.enc  # AES-256 encrypted governance snapshot (during suspension)
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

## Implemented RFCs

All four RFCs are fully implemented as of 2026-04-26.

- **`docs/rfcs/multi-team-approval.md`** (implemented) — sign-off files at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md`; `APPROVALS.md` reconciler; transport ladder Tier 0–3; `approval-reconcile.sh` hook; `sign-off-multi.md` + `approval-packet.md` templates.

- **`docs/rfcs/scope-ingest.md`** (implemented) — `scope-ingest` agent (writes only to `scope-drafts/`); `domain-expert` skill (domain context injection, gap questions, NFRs); `scope-gate.md` template; pseudo-phase scope gate; two-source domain lookup; domain authoring paths A and B.

- **`docs/rfcs/guided-entry-session-resume-multi-role.md`** (implemented) — `/status`, `/start`, `/configure`, `/help`; `session-plan-check.sh` hook; plan versioning; approval packets; auto next-step hints (`_shared/next-hint.sh` + `hints.jsonl` fade-after-3); glossary.

- **`docs/rfcs/opt-in-activation-suspend-resume.md`** (implemented) — opt-in `.enabled` marker; hooks guard on `.enabled`; enhanced `/start` (PATH A: config auto-detect + scope + plan draft; PATH B: re-enable reconciliation with snapshot verify + REQ supersession); `/suspend` with `suspend-snapshot.sh` (AES-256, plain fallback); `.suspension-log.jsonl`; `secret-scan.sh` always-on regardless of activation state.

## Open PRs

*(none)*

## Draft RFCs

- **`docs/rfcs/RFC-002-release-packaging.md`** (draft) — establishes marketplace.json (self-distributing install via `claude plugin install`), `scripts/package.sh` (devFiles exclusion + release branch + dist tags), `.github/workflows/release.yml` (test gate on every push, release job on tag), `docs/PACKAGING.md` reference. Fixes: `devFiles` is unrecognized by Claude Code installer; no marketplace.json; no CI gate before release.

## Accepted RFCs (awaiting implementation)

- **`docs/rfcs/RFC-001-plan-quality-gates.md`** (accepted) — closes the gap between plan governance intent and `plan-gate.sh` enforcement: status check (warn on unsigned plan), 48h staleness threshold, scope-delta decision records, low-provenance scope markers, degraded-mode banner, domain no-match note. 7 changes across 4 files: `plan-gate.sh`, `diff-scope-check.sh`, `skills/plan/SKILL.md`, `skills/domain-expert/SKILL.md`.

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
