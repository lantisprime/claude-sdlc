# Repo context — claude-sdlc

> **Purpose.** Paste or reference this file at the start of any new conversation about the repo so the assistant has accurate grounding without re-fetching everything. Keep it short and current. If a fact drifts, fix it here first.
>
> **Plugin artifact work (skills, hooks, commands, templates, config):** load `AGENT-RULES.md` (repo root) — concise decision rules for adding and modifying plugin artifacts.
>
> **RFC work:** also load `docs/rfcs/AGENT-RULES.md` — it contains the concise decision rules for creating, transitioning, and archiving RFCs.

**Repo:** https://github.com/lantisprime/claude-sdlc
**Last updated:** 2026-04-30 (RFC-006 rfc-lifecycle-quality-gates implemented + archived)

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
- **Hooks:** 14 total (13 registered in `hooks/hooks.json` as event hooks + `suspend-snapshot.sh` skill-invoked by `/suspend`)
- **Templates:** 13 (incl. `scope-gate`, `approval-packet`, `sign-off-multi`)

<!-- validate-counts:start
skills=20
commands=16
hooks=14
templates=13
agents=5
validate-counts:end -->

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

Eight RFCs fully implemented.

- **`docs/rfcs/archived/multi-team-approval.md`** (implemented) — sign-off files at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md`; `APPROVALS.md` reconciler; transport ladder Tier 0–3; `approval-reconcile.sh` hook; `sign-off-multi.md` + `approval-packet.md` templates.

- **`docs/rfcs/archived/scope-ingest.md`** (implemented) — `scope-ingest` agent (writes only to `scope-drafts/`); `domain-expert` skill (domain context injection, gap questions, NFRs); `scope-gate.md` template; pseudo-phase scope gate; two-source domain lookup; domain authoring paths A and B.

- **`docs/rfcs/archived/guided-entry-session-resume-multi-role.md`** (implemented) — `/status`, `/start`, `/configure`, `/help`; `session-plan-check.sh` hook; plan versioning; approval packets; auto next-step hints (`_shared/next-hint.sh` + `hints.jsonl` fade-after-3); glossary.

- **`docs/rfcs/archived/opt-in-activation-suspend-resume.md`** (implemented) — opt-in `.enabled` marker; hooks guard on `.enabled`; enhanced `/start` (PATH A: config auto-detect + scope + plan draft; PATH B: re-enable reconciliation with snapshot verify + REQ supersession); `/suspend` with `suspend-snapshot.sh` (AES-256, plain fallback); `.suspension-log.jsonl`; `secret-scan.sh` always-on regardless of activation state.

- **`docs/rfcs/archived/RFC-002-release-packaging.md`** (implemented) — `.claude-plugin/marketplace.json` (self-hosted install), `scripts/package.sh` (devFiles exclusion + release branch + dist tags; `--dry-run` + `--skip-tests`), `.github/workflows/release.yml` (CI test gate + release job with archive check + marketplace.json validation), `docs/PACKAGING.md` maintainer reference.

- **`docs/rfcs/archived/RFC-003-hook-enforcement-alignment.md`** (implemented) — closed four gaps between `USER-MANUAL.md` enforcement claims and actual hook implementations: `phase-gate.sh` `PreToolUse` registration + prior-gate block, placeholder field validation for deploy/fix-fast gates, `work-item-validation.sh` file-level traceability (warn in PR-5, opt-in hard block in PR-8), enforcement language audit. All 8 PRs shipped.

- **`docs/rfcs/archived/RFC-004-maintainer-code-review-enforcement.md`** (implemented, all 5 PRs shipped 2026-04-28) — four-layer pre-merge multi-reviewer gate for maintainer PRs to this repo. §14 in `sdlc-plugin/AGENT-RULES.md` rule (PR-1, [#36](https://github.com/lantisprime/claude-sdlc/pull/36)); four parallel Haiku 4.5 review agents under `.claude/agents/maintainer-{security,code-quality,test-adequacy,dependency}-reviewer.md` (PR-2, [#36](https://github.com/lantisprime/claude-sdlc/pull/36)); Stop hook `.claude/hooks/pre-merge-review-gate.sh` + 14-case bats suite (PR-3, [#37](https://github.com/lantisprime/claude-sdlc/pull/37)); `.claude/settings.json` registration (PR-4, [#38](https://github.com/lantisprime/claude-sdlc/pull/38)); `.github/workflows/pr-review.yml` CI gate (PR-5, [#39](https://github.com/lantisprime/claude-sdlc/pull/39)). Doc-only PRs bypass; `.claude/sdlc/plans/**` and `.claude/sdlc/gates/**` excluded from doc-only set. Strictly maintainer-only — every artifact under `.claude/`, `.github/`, or `sdlc-plugin/AGENT-RULES.md` (itself maintainer-only). Plugin capability counts (`hooks=14`, `agents=5`) unchanged. **Post-merge step (one-time, by repo admin):** add `review-required` to required status checks on `main` via `gh api -X PUT repos/${OWNER}/${REPO}/branches/main/protection` (full payload in `.github/workflows/pr-review.yml` header). Until that runs, the gate is advisory.

- **`docs/rfcs/archived/RFC-006-rfc-lifecycle-quality-gates.md`** (implemented, all 8 PRs shipped 2026-04-30) — RFC Lifecycle Quality Gates and Build-Stage Enforcement. Adds machine-verifiable lifecycle gates plus a build-stage loop and AI-slop enforcement to `docs/rfcs/AGENT-RULES.md`. PR-1 TEMPLATE.md ↔ §3b format reconcile ([#41](https://github.com/lantisprime/claude-sdlc/pull/41)); PR-2 §2–§7 gate checklists ([#42](https://github.com/lantisprime/claude-sdlc/pull/42)); PR-3 `.claude/hooks/rfc-quality-gate.sh` + bats ([#43](https://github.com/lantisprime/claude-sdlc/pull/43)); PR-4 `.claude/hooks/ai-slop-check.sh` + bats ([#44](https://github.com/lantisprime/claude-sdlc/pull/44)); PR-5 `.claude/settings.json` PostToolUse registration appended to RFC-004's Stop block ([#48](https://github.com/lantisprime/claude-sdlc/pull/48)); PR-6 `.claude/agents/rfc-pr-reviewer.md` (Haiku 4.5, exact ID pin) ([#45](https://github.com/lantisprime/claude-sdlc/pull/45)); PR-7 §3.5 Building per-PR loop + stub-detection extension ([#49](https://github.com/lantisprime/claude-sdlc/pull/49)); PR-8 §3a slop-check field + Haiku 4.5 default note ([#53](https://github.com/lantisprime/claude-sdlc/pull/53)). Strictly **maintainer-only** — every artifact under `.claude/` paths; nothing under `sdlc-plugin/`. Plugin capability counts (`hooks=14`, `agents=5`) unchanged. Follow-up tracked in `pending-analysis.md` §5: extend `rfc-quality-gate.sh` to grep for the new `**AI-slop check:**` field and warn when concerns remain unresolved alongside `Decision: proceed`.

## Open PRs

*(none)*

## Draft RFCs

- **`docs/rfcs/RFC-005-work-item-reference-validation.md`** (draft) — two-layer work-item existence check: Layer 1 (default warn) confirms REQ IDs resolve to local `.claude/sdlc/requirements/` artifact files and CR IDs resolve to signed CR files; Layer 2 (opt-in) queries the detected ticketing integration (GitHub Issues via `gh`, Jira via REST, Linear via GraphQL) for ticket existence and open status, warn-only with graceful degradation on network failure. Extends `work-item-validation.sh`; adds `enforcement.work_item_existence` and `work_item_lookups` config blocks.


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
