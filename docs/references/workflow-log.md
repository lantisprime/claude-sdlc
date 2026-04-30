# Workflow Log — SDLC Plugin Development Sessions

Informal record of what was built and decided across our working sessions on this repo. Ordered chronologically. Not an RFC — no approval process needed.

---

## 1. Starting point

The repo arrived with a working skeleton:

- 8-phase SDLC model (`/plan` → `/analyze` → `/design` → `/build` → `/test` → `/deploy` → `/support` + cross-cutting `/docs`)
- `plan-gate.sh` blocking `Edit`/`Write` when no plan exists
- Phase gate (`phase-gate.sh`) and sign-off template (`templates/sign-off.md`)
- Stack-agnostic tool config (`config/tools.json`)
- Core hooks: `secret-scan.sh`, `bash-safety.sh`, `diff-scope-check.sh`, `work-item-validation.sh`, `modified-code-test-gate.sh`
- Domain expert skill dispatching tasks to the right skill based on the prompt

---

## 2. Guided-entry RFC (PRs 1–10) — all shipped

Goal: make the plugin discoverable and usable without reading the docs first. Each PR added one piece of the guided-entry flow.

| PR | Commit | What was added |
|----|--------|----------------|
| PR 1 `/status` | `9d7b522` | Read-only render of task state, phase progress, and sign-off status |
| PR 2 `/start` | `6647e70` | Front-door onboarding command; guides users into the right first phase |
| PR 3 session hook | `3f8dc63` | `session-plan-check.sh` — fires at SessionStart, surfaces in-flight work and personalized sign-off hints |
| PR 4 versioning | `522b7ee` | `Version:` and `Status:` fields on plan files; material-change detection; `*.v<N>.md` archive convention for superseded plans |
| PR 8 `/configure` | `8aa6981` | Guided setup wizard; four-layer config model; `config_requirements:` frontmatter on skills |
| PR 9 `/help` + glossary | `7b3e0bb` | `/help` command; extended `GLOSSARY.md`; shared message catalog under `skills/_shared/messages/` |
| PR 6 approval packet | `bfb595b` | `templates/approval-packet.md`; `gate-signoff` skill compiles a packet when the gate has a `## Required sign-offs` block |
| PR 10 next-hints | `983b302` | `skills/_shared/next-hint.sh`; all 11 user-facing skills emit a `## Next step hint` via `next_suggestions:` frontmatter |

---

## 3. Docs & infrastructure passes

Work that ran alongside the guided-entry PRs to keep docs and metadata consistent.

| Commit(s) | What changed |
|-----------|--------------|
| `1fee47d`, `0d2c97c` | README and `docs/USER-MANUAL.md` synced to reflect all PRs 1–10 |
| post-`b1d542c` | `domains/_index.json` redesigned: keyword arrays replaced with semantic description strings, enabling LLM-based domain dispatch instead of keyword matching |
| `a257aca` | `docs/README.md` + `docs/_index.json` added — file registry, RFC impact matrix, change-trigger checklists for keeping docs in sync with code |
| `e4ae3a8`, `08f9114`, `e28ed19` | RFC cleanup: scope-ingest RFC marked **Implemented**; stale "all three open" status line fixed; pending-analysis tension tables synced with updated core principles |

---

## 4. Multi-team approval RFC — steps 1–3 shipped, step 4 parked

Goal: extend sign-offs to span multiple teams or organizations, not just a single repo.

### Step 1 — Contract + reconciler skeleton (`6653a48`)

- `templates/sign-off-multi.md` — multi-team sign-off template with `## Required sign-offs` block
- `hooks/approval-reconcile.sh` — validates: required roles present, gate hash matches current gate file, orphan detection (sign-off referencing a gate that no longer exists)
- `templates/gate.md` updated with the `## Required sign-offs` section
- `hooks/hooks.json` updated to register reconciler on the Stop event
- `.claude/sdlc/sign-offs/.gitkeep` — establishes the sign-off directory

### Step 2 — APPROVALS.md git mirror + merge guidance (`e6c313b`)

- `approval-reconcile.sh` extended: generates `APPROVALS.md` with mtime-based gate detection
- Self-healing merge marker: if the file has a Git conflict marker, the script rewrites it rather than bailing
- Explanation comment in the generated file guides reviewers on how to interpret the summary

### Step 3 — Tier 1 network share transport (`f8f0936`)

- `approval-reconcile.sh` extended with an outbox/inbox model for network share scenarios:
  - **Outbox push** — writes sign-off files to a configured share path on commit
  - **Inbox pull** — reads inbound sign-offs from the share and merges them locally
  - **Conflict files** — when a pull finds a local file with different content, writes a `.conflict` sidecar instead of overwriting
  - **Queue drain** — retries failed outbox pushes when the share becomes reachable again

### Step 4 — Git transport (parked)

RFC gates this on real adoption data before implementation. Design question also unsettled (sparse checkout vs. dedicated branch).

**Unpark criteria:** ≥3 repos dogfooded, ≥5 sign-offs collected end-to-end, ≥4 weeks of step 3 in use.

### Step 5 — MCP connector (deferred)

Deferred pending RFC §5 connector spec stabilization.

---

## 5. Meta / dev-process decisions

Changes to how sessions on this repo are run — not plugin features.

| Decision | Detail |
|----------|--------|
| Session handoff → rolling file | `memory/session_handoff.md` overwrites each session (~350 tokens) instead of scanning timestamped summaries (~7,000 tokens). |
| Plan-gate marker reverted | The `plan-approval-pending` marker approach was added then removed (`5ddafdb` → reverted `90b2d53`). Root cause: the hook runs inside *user* repos during normal plugin use, not inside dev sessions on this repo. CLAUDE.md wording alone enforces the "end-the-response" rule. |
| CLAUDE.md rules 8 & 9 rewritten | Rule 8 (plan before task): end the response after presenting the plan — do not call any tool in the same turn. Rule 9 (session handoff): write to rolling file on wrap-up; offer to reload at next session start. |

---

## 6. Opt-in activation + suspend/resume RFC — all shipped

Goal: make the plugin opt-in per repo (no hooks fire without explicit activation), add a governed suspension mechanism, and harden `/start` to cover both first-time setup and re-enable reconciliation.

### PR 1 — Opt-in activation model

- `.claude/sdlc/.enabled` marker — plugin is inactive until the file exists
- All hooks guard on `.enabled` at entry (exit 0 when absent)
- `secret-scan.sh` exempted: always-on regardless of activation state
- `/start` command becomes the activation front-door

### PR 2 — `/suspend` plumbing (`f673ac2`)

- `hooks/suspend-snapshot.sh` — 260-line substrate: AES-256 encrypted governance snapshot with SHA-256 manifest (sha256 + size + mtime per file); plain-text fallback when openssl is absent
- `skills/suspend/SKILL.md` — 6-step suspend flow
- `commands/suspend.md` — command descriptor
- `.suspension-log.jsonl` — append-only log of suspend/resume events
- 7 warn-type hooks amended to emit suspended-state messaging when `.suspended` is present: `diff-scope-check.sh`, `adjacent-function-detector.sh`, `format-on-write.sh`, `modified-code-test-gate.sh`, `phase-gate.sh`, `token-tracker.sh`, `approval-reconcile.sh`

Key decisions made during this PR:
- `suspend-snapshot.sh` uses `python3` for JSON (already a repo dependency via `env-detect.sh`)
- `tools.local.json` merge uses python3 to preserve existing fields (e.g. `tracker.auth_token`)
- Verify JSON is plan-keyed (`{"plans": {"REQ-001": {...}}}`) so `/start` doesn't reconstruct grouping
- PATH B (re-enable) preserves snapshot until REQ supersession is signed, not deleted on re-enable

### PR 3 — `/start` rewrite (`dc5659a`)

- `skills/start/SKILL.md` — full rewrite: three-path dispatch
  - **PATH A** (fresh activation): config auto-detect → scope → plan draft
  - **PATH B** (re-enable): snapshot verify → REQ supersession → reconciliation
  - **PATH C** (already active): task intake only
- `commands/start.md` — updated description to cover all three paths
- Scope overflow cap: warns when `cap_warning` is non-null (triggered by scope.md ∈ S2 with >20 active plans)

---

## 7. Risk analyses — `/plan` and `/analyze`

Structured risk analyses produced via code inspection + ChatGPT second opinion, then synthesized.

| File | Coverage | Risk count | Priority fix |
|------|----------|-----------|--------------|
| [`plan_command_analysis.md`](./plan_command_analysis.md) | `skills/plan/SKILL.md`, `plan-gate.sh`, `diff-scope-check.sh`, `templates/plan.md`, `scope-ingest`, `domain-expert` | 18 risks | Pre-signoff quality checklist (R-05); WARN on unsigned plan (R-01) |
| [`analysis_command_analysis.md`](./analysis_command_analysis.md) | `skills/analyze/SKILL.md`, `templates/requirements.md`, `hooks/plan-gate.sh` | 14 risks | Gate summary must be decisional not factual (R10); REQ lifecycle states (R2) |

Items 11–13 in the plan analysis (gate_hash verification, TBD enforcement at Build, active-task sentinel) are scoped as separate architectural changes. Implementation has not started.

---

## 8. RFC-003 archived

RFC-003 (Hook Enforcement Alignment) was already implemented (all 8 PRs shipped, HEAD at `80697c4`). File moved from `docs/rfcs/` root to `docs/rfcs/archived/`. Index files updated: `docs/README.md`, `docs/_index.json`, `docs/references/_repo-context.md`.

---

## 9. RFC-004 — Maintainer Pre-Merge Multi-Reviewer Gate (implemented 2026-04-28)

Four-layer pre-merge gate for maintainer PRs to this repo. Original RFC-004 framing conflated "code review" with the narrower `security-review` skill; Revision 2 (2026-04-28) split review into four narrowly-scoped Haiku 4.5 agents covering security, correctness, test adequacy, and dependency hygiene.

**5 PRs shipped** (all 2026-04-28):

| PR | Commit | Files |
|---|---|---|
| PR-1 + PR-2 (combined) | [#36](https://github.com/lantisprime/claude-sdlc/pull/36) `6ea420f` | `sdlc-plugin/AGENT-RULES.md` §14; `.claude/agents/maintainer-{security,code-quality,test-adequacy,dependency}-reviewer.md` |
| PR-3 | [#37](https://github.com/lantisprime/claude-sdlc/pull/37) `bb4432b` | `.claude/hooks/pre-merge-review-gate.sh` + `tests/hooks/pre_merge_review_gate.bats` (14 cases) |
| PR-4 | [#38](https://github.com/lantisprime/claude-sdlc/pull/38) `6270115` | `.claude/settings.json` (Stop hook registration) |
| PR-5 | [#39](https://github.com/lantisprime/claude-sdlc/pull/39) `fcaafd6` | `.github/workflows/pr-review.yml` |

Companion meta-PRs (same day): [#34](https://github.com/lantisprime/claude-sdlc/pull/34) queue plumbing; [#35](https://github.com/lantisprime/claude-sdlc/pull/35) RFC-004 Revision 2 design (independent Haiku 4.5 second-opinion review — no findings, AI-slop check clean, decision proceed).

**Bootstrap chicken-and-egg solved.** PR-5 added a `review-required` CI check that gated its own PR. Resolved by rebase-last sequencing: merged #34→#38 first (no gating yet), then rebased #39 onto main with diff shrunk to a single workflow file (matched `.github/*` doc-only glob), self-passed, merged. Documented for future self-introducing CI gates.

**Strictly maintainer-only.** Every artifact under `.claude/`, `.github/`, or `sdlc-plugin/AGENT-RULES.md` (the file is itself maintainer-only per its line-3 scope statement). `sdlc-plugin/hooks/`, `sdlc-plugin/agents/`, `sdlc-plugin/skills/` untouched. Plugin capability counts (`hooks=14`, `agents=5`) unchanged.

**Post-merge step (one-time, by repo admin):** add `review-required` to required status checks on `main` via `gh api -X PUT repos/${OWNER}/${REPO}/branches/main/protection` (full payload in `.github/workflows/pr-review.yml` header). Until that runs, the gate is advisory. (Note: the workflow header originally said `PATCH` — wrong verb for this endpoint; corrected to `PUT` in a follow-up doc fix.)

OQ-3 (dependency-reviewer invocation), OQ-4 (dispatcher vs direct), OQ-5 (artifact freshness check) all resolved at PR implementation time and recorded in the archived RFC's Open Questions table.

---

## 10. RFC-006 — RFC lifecycle quality gates and build-stage enforcement (implemented 2026-04-30)

All 8 PRs shipped across four dependency tiers. Strictly maintainer-only — every artifact under `.claude/` paths; nothing under `sdlc-plugin/`. Plugin capability counts (`hooks=14`, `agents=5`) unchanged.

**Tier 1 (parallel-ready):** PR-1 [#41](https://github.com/lantisprime/claude-sdlc/pull/41) `docs/rfcs/TEMPLATE.md` — Implementation-plan format reconciled to §3b's `### PR-N` subheading shape; PR-2 [#42](https://github.com/lantisprime/claude-sdlc/pull/42) `docs/rfcs/AGENT-RULES.md` — gate checklists added to §2–§7; PR-3 [#43](https://github.com/lantisprime/claude-sdlc/pull/43) `.claude/hooks/rfc-quality-gate.sh` + bats — status-driven grep checks (warn-only); PR-4 [#44](https://github.com/lantisprime/claude-sdlc/pull/44) `.claude/hooks/ai-slop-check.sh` + bats — case-insensitive grep over a closed pattern set from `sdlc-plugin/AGENT-RULES.md §12`; PR-6 [#45](https://github.com/lantisprime/claude-sdlc/pull/45) `.claude/agents/rfc-pr-reviewer.md` — Haiku 4.5 with exact ID pin (`claude-haiku-4-5-20251001`).

**Tier 2:** PR-5 [#48](https://github.com/lantisprime/claude-sdlc/pull/48) `.claude/settings.json` — appended `hooks.PostToolUse` block registering both new hooks; preserved RFC-004's `hooks.Stop` block (cross-RFC coordination resolved cleanly).

**Tier 3:** PR-7 [#49](https://github.com/lantisprime/claude-sdlc/pull/49) `docs/rfcs/AGENT-RULES.md §3.5` Building per-PR loop + TEMPLATE.md `## Implementation` table format + extended hook stub-detection to recognise `_pending_` sentinel; PR-8 [#53](https://github.com/lantisprime/claude-sdlc/pull/53) `docs/rfcs/AGENT-RULES.md §3a` slop-check field + Haiku 4.5 default note + decision rules tightening; same commit edits TEMPLATE.md for parser parity.

**Cross-RFC coordination delivered:** RFC-004's `.claude/settings.json` `hooks.Stop` block (PR-4 of RFC-004) preserved verbatim while PR-5 of RFC-006 appended `hooks.PostToolUse`. The append-don't-overwrite discipline now codified in the `_comment` field for any future hook additions.

**Bootstrap recursion handled.** The build-stage loop introduced by §3.5 (PR-7) was applied retroactively to RFC-006's own PRs in PR-52 catch-up; the `n/a (pre-§3.5)` value was used as a one-off vocabulary extension for retroactive rows. PR-8's slop-check field tightening was the final piece of the loop.

**Follow-ups tracked in `pending-analysis.md` §5:** extend `rfc-quality-gate.sh` to grep for the new `**AI-slop check:**` field and warn when concerns remain unresolved alongside `**Decision:** proceed`. Out-of-scope discussion notes (red-X review-required UX) live in `docs/rfcs/notes/pr-review-workflow-red-x-discussion.md` — pending RFC-007 promotion.

---

## 11. What's next

1. **Implement plan risk-analysis fixes** — 10 priority items from `plan_command_analysis.md`: pre-signoff checklist, WARN on unsigned status, low-provenance marker, degraded-mode banner, resolved-plan logging, scope-delta decision record, domain no-match note, UNKNOWN-as-open-item in compatibility matrix, materiality checklist, domain context template placeholder.
2. **V2 scope gate note** — write `docs/rfcs/notes/scope-gate-v2-followup.md`. Open question: should the scope gate be a first-class artifact class in v2 rather than a pseudo phase-gate?
3. **OQ-1 in guided-entry RFC** — resolve set-change semantics for `In-scope files`. Required before guided-entry PR 4 can begin.
4. **Dogfood** — install the plugin in 1–2 real repos and run a full task end-to-end. Prerequisite for unparking multi-team approval step 4.
5. **Steps 4 & 5 (multi-team approval)** — only after dogfood data meets the unpark criteria.
6. **RFC-007 (pr-review red-X UX)** — promote `docs/rfcs/notes/pr-review-workflow-red-x-discussion.md` to a real RFC if/when the user prioritises it. Discussion note already documents three rejected workflow-level options and the preferred direction (GitHub-native `required_pull_request_reviews`).

---

*Last updated: 2026-04-30. HEAD at the RFC-006 close-out merge — RFC-006 implemented + archived.*
