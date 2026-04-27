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

## 8. What's next

1. **Implement plan risk-analysis fixes** — 10 priority items from `plan_command_analysis.md`: pre-signoff checklist, WARN on unsigned status, low-provenance marker, degraded-mode banner, resolved-plan logging, scope-delta decision record, domain no-match note, UNKNOWN-as-open-item in compatibility matrix, materiality checklist, domain context template placeholder.
2. **V2 scope gate note** — write `docs/rfcs/notes/scope-gate-v2-followup.md`. Open question: should the scope gate be a first-class artifact class in v2 rather than a pseudo phase-gate?
3. **OQ-1 in guided-entry RFC** — resolve set-change semantics for `In-scope files`. Required before guided-entry PR 4 can begin.
4. **Dogfood** — install the plugin in 1–2 real repos and run a full task end-to-end. Prerequisite for unparking multi-team approval step 4.
5. **Steps 4 & 5 (multi-team approval)** — only after dogfood data meets the unpark criteria.

---

*Last updated: 2026-04-27. HEAD at `dc5659a` on `main` (`lantisprime/claude-sdlc`).*
