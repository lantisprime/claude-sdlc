# SDLC Plugin for Claude Code

A Claude Code plugin that enforces an 8-phase SDLC workflow — Plan, Analyze, Design, Build, Test, Deploy, Support, Docs — with the human always in the lead.

## What this plugin does

- **Makes planning mandatory.** No `Edit`/`Write` tool call is allowed until a plan artifact exists for the current task.
- **Validates work items.** Every build must reference a valid requirement ID (new build), issue ticket (fix), or signed change request (CR).
- **Enforces surgical edits.** Only modified code is touched. Adjacent functions are never changed without explicit scope extension.
- **Gates each phase behind a human sign-off.** The next phase's command refuses to run until the prior phase's gate file exists and is signed.
- **Degrades gracefully.** If Git, a ticketing system, or an observability platform isn't detected, the plugin falls back to markdown (or JSON) artifacts under `.claude/sdlc/`.
- **Stays stack-agnostic.** Formatter, linter, test runner, and scanner are config placeholders — fill in `config/tools.json` for your project.

## Install

```bash
# from the plugin repo root:
claude plugin install .

# or, once published:
claude plugin install <published-name>
```

Then, in the target repo, run:

```bash
/plan "Describe the work item"
```

## Configure for your stack

Copy the example config and fill in the tool names for your project:

```bash
cp config/tools.example.json config/tools.json
```

Every hook and skill reads from `config/tools.json`. Leave a value as `null` to skip that check.

## The 8 phases

| # | Phase    | Command     | Produces                                                |
|---|----------|-------------|---------------------------------------------------------|
| 1 | Plan     | `/plan`     | Plan file, estimate, tech stack, compatibility matrix   |
| 2 | Analyze  | `/analyze`  | Requirements with stable IDs, UX ask (if frontend)      |
| 3 | Design   | `/design`   | Architecture bundle, test architecture, tech specs      |
| 4 | Build    | `/build`    | Code + unit tests for modified code only                |
| 5 | Test     | `/test`     | Test execution report, defects, UX conformance          |
| 6 | Deploy   | `/deploy`   | Deployment record (ticket or artifact file)             |
| 7 | Support  | `/support`  | Observability scripts, alerts, dashboards               |
| 8 | Docs     | `/docs`     | Updated SDLC docs, traceability matrix, changelog       |

See [`docs/SDLC.md`](docs/SDLC.md) for the full reference.

## The artifact tree

The plugin writes to `.claude/sdlc/` in the **consuming** repo (not this one):

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

## Human-in-the-lead, always

Every gate, every scope change, every irreversible action requires explicit human confirmation. Subagents and MCP connectors extend what the plugin can do in parallel, but none of them can bypass a gate.

## Layout of this repo

```
sdlc-plugin/
├── .claude-plugin/plugin.json
├── config/tools.example.json
├── docs/SDLC.md
├── skills/          # 12 skills (8 phases + 4 cross-cutting)
├── commands/        # 10 slash commands
├── agents/          # 4 subagents
├── hooks/           # enforcement scripts + hooks.json
└── templates/       # artifact templates
```

## Contributing

This scaffold is a starting point. Fork it, tune the hook strictness, add project-specific checks. The `validation metrics` section in `docs/SDLC.md` explains what to measure when iterating.

## License

MIT
