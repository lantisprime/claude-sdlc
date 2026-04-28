# Repo context — claude-sdlc

> **Purpose.** Paste or reference this file at the start of any new conversation about the repo so the assistant has accurate grounding without re-fetching everything. Keep it short and current. If a fact drifts, fix it here first.
>
> **Plugin artifact work (skills, hooks, commands, templates, config):** load `AGENT-RULES.md` (repo root) — concise decision rules for adding and modifying plugin artifacts.
>
> **RFC work:** also load `docs/rfcs/AGENT-RULES.md` — it contains the concise decision rules for creating, transitioning, and archiving RFCs.

**Repo:** https://github.com/lantisprime/claude-sdlc
**Last updated:** 2026-04-28 (RFC-006 rfc-lifecycle-quality-gates accepted; 8-PR implementation plan)

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

Six RFCs fully implemented.

- **`docs/rfcs/archived/multi-team-approval.md`** (implemented) — sign-off files at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md`; `APPROVALS.md` reconciler; transport ladder Tier 0–3; `approval-reconcile.sh` hook; `sign-off-multi.md` + `approval-packet.md` templates.

- **`docs/rfcs/archived/scope-ingest.md`** (implemented) — `scope-ingest` agent (writes only to `scope-drafts/`); `domain-expert` skill (domain context injection, gap questions, NFRs); `scope-gate.md` template; pseudo-phase scope gate; two-source domain lookup; domain authoring paths A and B.

- **`docs/rfcs/archived/guided-entry-session-resume-multi-role.md`** (implemented) — `/status`, `/start`, `/configure`, `/help`; `session-plan-check.sh` hook; plan versioning; approval packets; auto next-step hints (`_shared/next-hint.sh` + `hints.jsonl` fade-after-3); glossary.

- **`docs/rfcs/archived/opt-in-activation-suspend-resume.md`** (implemented) — opt-in `.enabled` marker; hooks guard on `.enabled`; enhanced `/start` (PATH A: config auto-detect + scope + plan draft; PATH B: re-enable reconciliation with snapshot verify + REQ supersession); `/suspend` with `suspend-snapshot.sh` (AES-256, plain fallback); `.suspension-log.jsonl`; `secret-scan.sh` always-on regardless of activation state.

- **`docs/rfcs/archived/RFC-002-release-packaging.md`** (implemented) — `.claude-plugin/marketplace.json` (self-hosted install), `scripts/package.sh` (devFiles exclusion + release branch + dist tags; `--dry-run` + `--skip-tests`), `.github/workflows/release.yml` (CI test gate + release job with archive check + marketplace.json validation), `docs/PACKAGING.md` maintainer reference.

- **`docs/rfcs/archived/RFC-003-hook-enforcement-alignment.md`** (implemented) — closed four gaps between `USER-MANUAL.md` enforcement claims and actual hook implementations: `phase-gate.sh` `PreToolUse` registration + prior-gate block, placeholder field validation for deploy/fix-fast gates, `work-item-validation.sh` file-level traceability (warn in PR-5, opt-in hard block in PR-8), enforcement language audit. All 8 PRs shipped.

## Open PRs

*(none)*

## Draft RFCs

- **`docs/rfcs/RFC-005-work-item-reference-validation.md`** (draft) — two-layer work-item existence check: Layer 1 (default warn) confirms REQ IDs resolve to local `.claude/sdlc/requirements/` artifact files and CR IDs resolve to signed CR files; Layer 2 (opt-in) queries the detected ticketing integration (GitHub Issues via `gh`, Jira via REST, Linear via GraphQL) for ticket existence and open status, warn-only with graceful degradation on network failure. Extends `work-item-validation.sh`; adds `enforcement.work_item_existence` and `work_item_lookups` config blocks.


## Accepted RFCs (awaiting implementation)

- **`docs/rfcs/RFC-006-rfc-lifecycle-quality-gates.md`** (accepted, 2026-04-28) — RFC Lifecycle Quality Gates **and Build-Stage Enforcement**. Second-opinion review by Haiku 4.5 subagent: `Decision: proceed`, AI-slop check clean, three findings fixed in revision. **8-PR implementation plan**, four dependency tiers:
  - **Tier 1 (parallel-ready):** PR-1 `docs/rfcs/TEMPLATE.md` (§3b format reconcile); PR-2 `docs/rfcs/AGENT-RULES.md` §2–§7 gate checklists; PR-3 `.claude/hooks/rfc-quality-gate.sh` + bats; PR-4 `.claude/hooks/ai-slop-check.sh` + bats; PR-6 `.claude/agents/rfc-pr-reviewer.md` (Haiku 4.5, exact ID pin).
  - **Tier 2:** PR-5 `.claude/settings.json` registers both hooks (depends on PR-3 + PR-4).
  - **Tier 3:** PR-7 `AGENT-RULES.md §3.5 Building` + TEMPLATE.md row (depends on PR-1, PR-3, PR-4, PR-6); PR-8 `§3a` slop-check tightening + TEMPLATE.md (depends on PR-7).
  
  Eight changes total: rfc-quality-gate hook (warn, status-driven grep), TEMPLATE.md ↔ §3b format reconcile, §2–§7 gate checklists, settings.json registration, new §3.5 Building procedural section (per-PR loop: classify → spawn reviewer if code-touching → tests/run.sh if hooks/tests/scripts/config touched → ai-slop-check on doc-touching with conservative auto-apply), rfc-pr-reviewer agent on Haiku 4.5, ai-slop-check hook (warn, case-insensitive, closed pattern set), §3a Second opinion gains required `**AI-slop check:**` line.
  
  Strictly **maintainer-only** — every new artifact under `.claude/` paths; **nothing under `sdlc-plugin/`**. Capability counts (`hooks=14`, `agents=5`) unchanged. OQ-1, OQ-3, OQ-4, OQ-5 closed at acceptance; OQ-2 (last_modified heuristic — "matches today" vs. "within 24h") deferred to PR-3 implementation.

- **`docs/rfcs/RFC-004-maintainer-code-review-enforcement.md`** (accepted, Revision 2 on 2026-04-28) — four-layer pre-merge multi-reviewer gate for maintainer PRs: §14 in `sdlc-plugin/AGENT-RULES.md`, four parallel Haiku 4.5 review agents under `.claude/agents/maintainer-{security,code-quality,test-adequacy,dependency}-reviewer.md` (each writes its own artifact in `.claude/sdlc/test/`), Stop hook `.claude/hooks/pre-merge-review-gate.sh` (warn — checks all four artifacts present), `.github/workflows/pr-review.yml` CI gate (≥1 approved review, self-approval filter). Doc-only bypass applies; `.claude/sdlc/plans/**` and `.claude/sdlc/gates/**` explicitly excluded from doc-only set. 5 PRs: PR-1 `AGENT-RULES.md`, PR-2 four review agents, PR-3 hook + bats, PR-4 settings.json registration, PR-5 CI workflow. Cross-RFC `.claude/settings.json` coordination with RFC-006 PR-5 (append-don't-overwrite). Original 3-PR scope conflated "code review" with the narrower `security-review` skill; Revision 2 split review into four narrowly-scoped agents covering security, correctness, test adequacy, and dependency hygiene.



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
