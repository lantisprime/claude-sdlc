# SDLC Plugin for Claude Code

A Claude Code plugin that enforces an 8-phase SDLC workflow — **Plan → Analyze → Design → Build → Test → Deploy → Support → Docs** — with the human always in the lead.

Subagents, hooks, and MCP connectors *propose*. Humans *approve*. Every phase ends at a signed gate file.

## Why this exists

Claude Code is fast. Sometimes too fast. This plugin trades a little velocity for a lot of discipline:

- No code written before a plan exists.
- No file touched that isn't listed in the plan.
- No phase advanced without a human signature.
- No build merged without a traceable work item (REQ ID, ticket, or signed CR).

If any of that sounds like friction you don't want — this plugin is not for you, and that's fine.

## Core principles

These are load-bearing. The plugin is built around them; changes that violate them usually feel like simplifications but aren't.

1. **Human in the lead, always.** Subagents and hooks never advance a phase on their own.
2. **Plan before code.** `plan-gate.sh` blocks `Edit`/`Write` when no plan exists for the task.
3. **Surgical edits.** Only plan-listed files and functions are modified. Adjacent functions are never touched. "While I'm here" cleanups are a footgun.
4. **Work-item traceability.** Every build references a REQ ID (new work), a ticket (bug), or a signed change request (scope change).
5. **Graceful degradation.** No Git? No ticket system? No observability platform? The plugin writes local markdown/JSON artifacts and surfaces the gap. It never silently skips a check.
6. **Stack-agnostic.** Formatter, linter, test runner, scanners — all live in `config/tools.json`. Nothing is hardcoded.

## Install

Clone the repo and install as a local plugin:

```bash
git clone https://github.com/lantisprime/claude-sdlc.git
# then, from your project repo, load it via Claude Code's /plugin command
```

See [Claude Code's plugin docs](https://docs.claude.com/en/docs/claude-code/plugins) for the current install flow — plugin distribution is still evolving.

## Configure for your stack

Copy the example config and fill in the tools your project uses:

```bash
cp config/tools.example.json config/tools.json
```

Every hook and skill reads from `config/tools.json`. Leave a value as `null` to skip that check. Tunable knobs include:

- `formatter`, `linter`, `test_runner`, `security_scanner`, `secret_scanner`
- `coverage.threshold_percent`
- `artifact_format_fallback` — `markdown` or `json` when rich integrations are missing
- `adjacent_function_detection` — `git-hunk-headers` (default) or `tree-sitter`

## Quick start

From inside a repo that has this plugin installed:

```bash
/plan "Add rate-limit headers to the public API"
# writes .claude/sdlc/plans/<slug>.md — classification, scope, estimate, tech stack
# human reviews + signs; plan-gate.sh now permits edits

/analyze    # requirements with stable REQ IDs
/design     # architecture + tech specs
/build      # code + unit tests — scoped strictly to plan
/test       # execution report, defects
/deploy     # deployment record
/support    # observability wiring
/docs       # docs, traceability matrix, changelog
```

Each command refuses to run until the prior phase's gate file exists and is signed.

## The 8 phases

| # | Phase   | Command    | Gate file                             | Produces |
|---|---------|------------|---------------------------------------|----------|
| 1 | Plan    | `/plan`    | `gates/plan-<slug>.md`                | Plan, classification, estimate, tech stack |
| 2 | Analyze | `/analyze` | `gates/analyze-<slug>.md`             | Requirements with stable REQ IDs, UX ask (if frontend) |
| 3 | Design  | `/design`  | `gates/design-<slug>.md`              | Architecture bundle, test architecture, tech specs |
| 4 | Build   | `/build`   | `gates/build-<slug>.md`               | Code + unit tests for modified code only |
| 5 | Test    | `/test`    | `gates/test-<slug>.md`                | Test execution report, defects, UX conformance |
| 6 | Deploy  | `/deploy`  | `gates/deploy-<slug>.md`              | Deployment record (ticket or artifact file) |
| 7 | Support | `/support` | `gates/support-<slug>.md`             | Observability scripts, alerts, dashboards |
| 8 | Docs    | `/docs`    | (cross-cutting, no dedicated gate)    | Updated SDLC docs, traceability matrix, changelog |

See [`docs/SDLC.md`](docs/SDLC.md) for the authoritative reference.

### `/fix-fast` — the only shortcut

A compressed path for **small bug fixes only**. Collapses Plan + Analyze + Design into one mini-gate; Build through Docs run normally.

Eligibility is strict and will not be widened:

- Bug fix only (no new features, no refactors)
- ≤ 2 files changed
- ≤ 50 LOC changed
- No schema, API, security, or UX changes

If a task doesn't fit, run the full phases. There is no second shortcut.

## Hook strictness: block vs. warn

The plugin distinguishes two severities deliberately:

- **Block (exit 2)** — refuses the tool call. Used only when the consequence is severe: no plan at all, unsigned CR, confirmed secret found.
- **Warn (stderr, exit 0)** — surfaces the signal; lets the human decide. Scope drift, adjacent-function edits, test-scope mismatches.

Warnings are *warnings*. They're not auto-blockers-in-waiting. The adjacent-function detector in particular uses git hunk headers, which are imperfect — an aggressive block there would halt legitimate work.

## Artifact tree (in the consuming repo)

The plugin writes to `.claude/sdlc/` in the repo that *uses* the plugin — not in this one:

```
.claude/sdlc/
├── env.json                # detected integrations
├── scope.md                # project scope statement
├── plans/                  # one file per task
├── requirements/
├── architecture/
├── tech-specs/
├── test-cases/
├── test-scripts/
├── tickets/
├── change-requests/
├── sign-offs/
├── gates/                  # phase-gate sign-offs
├── defects/
├── deployments/
├── monitoring/
└── docs/
```

## Validation metrics

When iterating on the plugin (or your own tuning of it), measure against these targets:

| Metric                                             | Target    |
|----------------------------------------------------|-----------|
| Plan-first compliance                              | 100%      |
| Work-item validation (REQ / ticket / signed CR)    | 100%      |
| Scope discipline (files touched ÷ files in scope)  | 1.0       |
| Adjacent-function modifications per task           | 0         |
| Test scope ratio (tests modified ÷ code modified)  | ≈ 1.0     |

Details in [`docs/SDLC.md`](docs/SDLC.md).

## Capabilities reference

### Skills (13)

Phase skills — one per checkpoint:

| Skill | What it does |
|---|---|
| [plan](skills/plan/SKILL.md) | Classifies the task, validates scope, estimates effort, locks tech stack |
| [analyze](skills/analyze/SKILL.md) | Turns the plan into requirements with stable REQ IDs; captures UX ask for frontend work |
| [design](skills/design/SKILL.md) | Produces architecture bundle, test architecture, and per-component tech specs |
| [build](skills/build/SKILL.md) | Writes code + unit tests for modified code only; coordinates surgical-edit, minimal-code, security-review |
| [test](skills/test/SKILL.md) | Runs tests, records defects, checks UX conformance |
| [deploy](skills/deploy/SKILL.md) | Produces a deployment record; hands off to the configured deploy mechanism |
| [support](skills/support/SKILL.md) | Wires observability — monitoring, logging, alerts, dashboards, runbooks |
| [docs](skills/docs/SKILL.md) | Updates SDLC docs, traceability matrix, and changelog |

Cross-cutting skills — triggered by context across phases:

| Skill | What it does |
|---|---|
| [scoping](skills/scoping/SKILL.md) | Validates scope boundaries on plans and change requests |
| [surgical-edit](skills/surgical-edit/SKILL.md) | Enforces "only touch what the plan lists"; no adjacent-function edits |
| [minimal-code](skills/minimal-code/SKILL.md) | Discourages speculative abstractions, unused branches, and feature creep |
| [security-review](skills/security-review/SKILL.md) | Reviews the current diff for OWASP-class issues; runs as part of `/review` |
| [api-integration](skills/api-integration/SKILL.md) | Verifies API spec + endpoint reachability; offers a mock if unreachable |

### Commands (10)

| Command | Purpose |
|---|---|
| [/plan](commands/plan.md) | Phase 1 — scope, classify, estimate |
| [/analyze](commands/analyze.md) | Phase 2 — requirements with REQ IDs |
| [/design](commands/design.md) | Phase 3 — architecture + tech specs |
| [/build](commands/build.md) | Phase 4 — code + unit tests (scoped) |
| [/test](commands/test.md) | Phase 5 — test execution + defects |
| [/deploy](commands/deploy.md) | Phase 6 — deployment record |
| [/support](commands/support.md) | Phase 7 — observability wiring |
| [/docs](commands/docs.md) | Phase 8 — SDLC docs + traceability |
| [/review](commands/review.md) | Cross-cutting diff review (correctness + security) |
| [/fix-fast](commands/fix-fast.md) | Compressed path for small bug fixes only (≤2 files, ≤50 LOC) |

### Agents (4)

Bounded subagents with narrow write scope — they propose; humans approve.

| Agent | Role | Write scope |
|---|---|---|
| [architect](agents/architect.md) | Validates architecture against requirements; proposes updates | `.claude/sdlc/architecture/` only |
| [test-designer](agents/test-designer.md) | Generates test cases from approved REQs | `.claude/sdlc/test-cases/` only |
| [security-reviewer](agents/security-reviewer.md) | Audits the diff against the security checklist | Read-only (proposes remediations) |
| [observability](agents/observability.md) | Produces monitoring / alerts / runbooks | `.claude/sdlc/monitoring/` only |

### Hooks (9)

Registered in [hooks/hooks.json](hooks/hooks.json). Block vs. warn philosophy documented above.

| Hook | Event | Severity | What it does |
|---|---|---|---|
| [plan-gate.sh](hooks/plan-gate.sh) | PreToolUse (Edit/Write) | **Block** | Refuses edits when no plan exists for the task |
| [work-item-validation.sh](hooks/work-item-validation.sh) | PreToolUse | **Block** | Requires a valid REQ ID, ticket, or signed CR |
| [secret-scan.sh](hooks/secret-scan.sh) | PreToolUse | **Block** | Blocks writes containing confirmed secrets |
| [phase-gate.sh](hooks/phase-gate.sh) | PreToolUse (commands) | **Block** | Refuses a phase command until the prior gate is signed |
| [diff-scope-check.sh](hooks/diff-scope-check.sh) | PostToolUse | Warn | Flags edits to files outside the plan |
| [adjacent-function-detector.sh](hooks/adjacent-function-detector.sh) | PostToolUse | Warn | Flags edits to functions adjacent to in-scope ones |
| [modified-code-test-gate.sh](hooks/modified-code-test-gate.sh) | Stop | Warn | Flags modified code without corresponding tests |
| [bash-safety.sh](hooks/bash-safety.sh) | PreToolUse (Bash) | Warn | Flags risky shell patterns |
| [format-on-write.sh](hooks/format-on-write.sh) | PostToolUse | — | Runs the configured formatter on written files |
| [env-detect.sh](hooks/env-detect.sh) | SessionStart | — | Writes `.claude/sdlc/env.json` with detected integrations |

### Templates (10)

Shape of the artifacts the plugin produces. Headings and fields are parsed by hooks — don't rename them without checking downstream consumers.

| Template | Artifact |
|---|---|
| [plan.md](templates/plan.md) | Plan file under `.claude/sdlc/plans/` |
| [requirements.md](templates/requirements.md) | Requirements with stable REQ IDs |
| [tech-spec.md](templates/tech-spec.md) | Per-component tech spec |
| [test-case.md](templates/test-case.md) | Test case traced to REQ IDs |
| [ticket.md](templates/ticket.md) | Issue ticket (fallback when no ticket system detected) |
| [change-request.md](templates/change-request.md) | Scope change with sign-off |
| [sign-off.md](templates/sign-off.md) | Reusable sign-off block |
| [gate.md](templates/gate.md) | Phase gate file |
| [deployment.md](templates/deployment.md) | Deployment record |
| [defect.md](templates/defect.md) | Defect report |

## Repo layout

```
.
├── .claude-plugin/plugin.json   # manifest
├── config/tools.example.json    # copy to tools.json and fill in
├── docs/SDLC.md                 # full phase reference
├── skills/          (13)        # 8 phase skills + 5 cross-cutting
├── commands/        (10)        # one per checkpoint + /review + /fix-fast
├── agents/          (4)         # bounded subagents
├── hooks/                       # hooks.json + 9 shell scripts
└── templates/       (10)        # artifact templates
```

## Contributing

Before submitting a change, read [`CLAUDE.md`](CLAUDE.md) — it documents the design intent and the anti-patterns that look like improvements but aren't.

Short version: the plugin eats its own dog food. Plan before code, surgical edits, one concern per change. Unrelated ideas go in a follow-up, not in the current PR.

## License

MIT
