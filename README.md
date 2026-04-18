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
