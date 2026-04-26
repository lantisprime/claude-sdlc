# CLAUDE.md

Context for Claude Code sessions working on **this repository** — the SDLC plugin itself. This file is read on startup. Keep it short; keep it honest.

## What this repo is

A Claude Code plugin that enforces an 8-phase SDLC workflow with human-in-the-lead discipline. It is *not* application code — it is instructions, hooks, templates, and agents that shape how other Claude Code sessions work in other repos.

Read `README.md` for the quick-start and `docs/SDLC.md` for the full phase reference before making substantive changes.

## Design intent — read this before "improving" anything

These principles are essential. Changes that violate them usually feel like simplifications but aren't:

1. **Human in the lead, always.** Every phase ends at a signed gate file. Subagents, hooks, and MCP connectors propose — humans approve. Do not add an "auto-approve" convenience. Do not let a subagent advance a phase. Do not let observation of past behavior substitute for a fresh human confirmation.

2. **Reduce cognitive load, always.** The human is the bottleneck this plugin is designed to protect. Additions to artifacts, prompts, hook messages, and subagent output must make the human's decision easier — less to read, less to reconcile, clearer next step. If a change adds surface area without removing more elsewhere, it's the wrong change.

3. **Plan before code.** `plan-gate.sh` blocks Edit/Write when no plan exists. This is the single most important rule in the plugin. If it seems to be firing "too often," the fix is better planning, not a looser hook.

4. **Surgical edits.** Skills and hooks together enforce that only plan-listed files and functions are modified. Adjacent functions are never touched. "While I'm here" cleanups are a known failure mode, not a virtue.

5. **Work-item traceability.** Every build references a REQ ID, an issue ticket, or a signed CR. Don't add a "quick fix" escape hatch that bypasses this.

6. **Graceful degradation.** Missing Git? Missing ticket system? Missing observability platform? The plugin writes markdown/JSON artifacts locally and surfaces the gap. It never silently skips a check.

7. **Stack-agnostic.** Tool names live in `config/tools.json`, nowhere else. Don't hardcode `ruff`, `pytest`, `eslint`, `vitest`, etc. anywhere in skills or hooks.

## Eat your own dog food

When modifying this repo, follow the plugin's own discipline even though the hooks aren't installed yet:

- Write a plan before code. A plan file under `.claude/sdlc/plans/` in *this* repo is welcome.
- Make surgical edits. Touch only the skill, command, hook, or template the task requires.
- Don't refactor across files in the same change.
- Unrelated ideas go in `.claude/sdlc/followups/` — not into the current change.

## Hook strictness philosophy

The plugin distinguishes *block* from *warn*:

- **Block (exit 2)** — used only when the consequence is severe: no plan at all, unsigned CR, confirmed secret found. Exit 2 refuses the tool call.
- **Warn (stderr, exit 0)** — the default. Surface the signal to Claude and the human; let them decide. Scope drift, adjacent-function edits, test-scope mismatch — all warnings.

Do not "upgrade" a warning to a block without thinking through false-positive rates. The adjacent-function detector in particular uses git hunk headers, which are imperfect — an aggressive block there would halt legitimate work.

## The 8-phase model (quick reference)

| # | Phase    | Command     | Gate file prefix                        |
|---|----------|-------------|-----------------------------------------|
| 1 | Plan     | `/plan`     | `.claude/sdlc/gates/plan-*.md`          |
| 2 | Analyze  | `/analyze`  | `.claude/sdlc/gates/analyze-*.md`       |
| 3 | Design   | `/design`   | `.claude/sdlc/gates/design-*.md`        |
| 4 | Build    | `/build`    | `.claude/sdlc/gates/build-*.md`         |
| 5 | Test     | `/test`     | `.claude/sdlc/gates/test-*.md`          |
| 6 | Deploy   | `/deploy`   | `.claude/sdlc/gates/deploy-*.md`        |
| 7 | Support  | `/support`  | `.claude/sdlc/gates/support-*.md`       |
| 8 | Docs     | `/docs`     | (cross-cutting, no dedicated gate)      |

`/fix-fast` is a compressed path for small bug fixes only — collapses Plan + Analyze + Design into one mini-gate. Build through Docs run normally. Eligibility is strict: fix only, ≤2 files, ≤50 LOC, no schema/API/security/UX changes. Do not widen this eligibility.

## Repository layout

```
sdlc-plugin/
├── .claude-plugin/plugin.json  # manifest — name, version, description
├── README.md                   # quick-start for users of the plugin
├── docs/SDLC.md                # full phase reference
├── config/tools.example.json   # placeholders — users copy to tools.json
├── skills/      (20)           # 8 phase + 7 cross-cutting (incl. domain-expert) + 5 utility (configure, start, status, help, suspend)
├── commands/    (16)           # one per checkpoint + /status + /help + /review + /fix-fast + /token-review + /suspend
├── agents/      (5)            # bounded subagents (incl. scope-ingest)
├── hooks/                      # hooks.json + 14 shell scripts (incl. suspend-snapshot.sh, skill-invoked)
└── templates/   (13)           # artifact templates
```

## Key files by "why they matter"

- `skills/plan/SKILL.md` — classification, scope validation, estimate, tech stack. The first skill in the workflow.
- `skills/surgical-edit/SKILL.md` — encodes the "only touch what needs modifying, no adjacent functions" rule. This is the plugin's signature discipline.
- `skills/build/SKILL.md` — coordinates surgical-edit, minimal-code, security-review.
- `hooks/plan-gate.sh` — the single most important hook. Blocks all edits without a plan.
- `hooks/adjacent-function-detector.sh` — the cleverest hook. Uses `git diff --function-context` hunk headers; can be switched to tree-sitter via `config/tools.json` for higher accuracy.
- `hooks/hooks.json` — hook registration. PreToolUse, PostToolUse, Stop, SessionStart matchers live here.
- `docs/SDLC.md` — the authoritative reference. If you're about to change behavior, check here first to see if the behavior is essential.

## Tuning knobs (safe to adjust)

- **Formatter, linter, test runner, scanners** — all live in `config/tools.json`. Users fill these in per project.
- **Coverage threshold** — `config/tools.json` → `coverage.threshold_percent`.
- **Artifact fallback format** — markdown or JSON via `artifact_format_fallback`.
- **Adjacent-function detection method** — `git-hunk-headers` (default) or `tree-sitter` in `config/tools.json`. Switch to tree-sitter when git hunk headers are unreliable in your language.
- **Skill descriptions** — refine these based on observed triggering behavior. "Pushier" descriptions improve triggering; overly broad ones cause misfires.

## Things NOT to change without deep thought

- **The phase order.** Plan → Analyze → Design → Build → Test → Deploy → Support → Docs. Reordering breaks every downstream check.
- **The gate-file naming convention** (`<phase>-<task-slug>.md` under `.claude/sdlc/gates/`). Commands and hooks depend on this shape.
- **The plan artifact fields** (`Classification`, `In-scope files`, `In-scope functions`, `Out-of-scope`). The hooks parse these verbatim. Renaming a heading breaks `diff-scope-check.sh` and `adjacent-function-detector.sh`.
- **The REQ ID convention** (`REQ-<n>` stable across edits). Traceability across Analyze → Design → Build → Test → Docs depends on stability.
- **The "fix-fast" eligibility rules.** Widening them defeats the point.

## Common tasks and how to do them right

### Adding a new skill

1. Plan the skill: what does it enable, when does it trigger, what does it NOT do?
2. Write `skills/<name>/SKILL.md` with YAML frontmatter (`name` and `description` required). Description must be "pushy" — lists concrete trigger phrases.
3. Keep the body under ~500 lines. Move detail into resource files and reference them.
4. Add the skill to the README's skill table and to `docs/SDLC.md` if it's a phase or cross-cutting concern.
5. Test trigger behavior with a few representative prompts before calling it done.

### Adding a new hook

1. Decide the event: `PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`.
2. Decide block vs. warn. Default to warn. Block only with clear justification.
3. Write the shell script — POSIX-ish bash, `set -euo pipefail`, handle missing tools gracefully (exit 0 if a dependency is absent).
4. Register it in `hooks/hooks.json` with the appropriate matcher.
5. Test against a repo where hooks actually run — hook misbehavior is hard to catch without exercising them.

### Modifying a template

Templates in `templates/` are the shape of the artifacts the plugin produces. Changing a heading or field affects every downstream skill and hook that parses that artifact. Search the repo for references before changing a template's structure.

### Updating the config schema

`config/tools.example.json` is authoritative. If you add a key, document it inline with a `_comment` field and update any skill or hook that consumes it. Users copy this to `tools.json`, so backward compatibility matters across versions.

## Testing the plugin

There's no automated test suite in this repo yet (contributions welcome). Until there is, validate changes by:

1. Installing the plugin into a throwaway repo
2. Running through a representative task (new build, fix, CR) end-to-end
3. Observing which hooks fire, which skills trigger, where friction appears
4. Adjusting descriptions, matchers, and thresholds based on what you see

Track results against the validation metrics in `docs/SDLC.md`:

- Plan-first compliance → target 100%
- Work-item validation → target 100%
- Scope discipline (files-touched ÷ files-in-scope) → target 1.0
- Adjacent-function modifications → target 0 per task
- Test scope ratio → target near 1.0

## Anti-patterns seen when working on this repo

- **"Let me just make this skill a bit more flexible."** Flexibility is usually the enemy of discipline. A skill that sometimes requires a plan is a skill that doesn't require a plan.
- **"I'll refactor the hooks to be cleaner."** The hooks are bash for a reason: they need to run anywhere `git` and a POSIX shell exist. Rewriting in Python or JS adds a dependency.
- **"I'll add a convenience path for small changes."** That's what `/fix-fast` already is. Don't add a second one.
- **"Let me update multiple skills in this commit."** Surgical-edit applies to this repo too. One concern per change.

## When Claude Code is uncertain

Ask the human. This repo exists to keep humans in the lead; the repo's maintenance should follow the same principle. Better to pause and clarify than to push a change that erodes a discipline the plugin was built to enforce.
