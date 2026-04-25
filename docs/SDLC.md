# SDLC Reference

This document is the authoritative reference for the 8-phase workflow the plugin enforces. The plugin's README is the quick-start; this is the full picture.

## Guiding principles

1. **Human in the lead, always.** Every phase ends at a signed gate. Every scope change, every irreversible action, every production touch is confirmed by a human — never by a subagent, a hook, or a heuristic.
2. **Reduce cognitive load.** Artifacts, prompts, and gate summaries surface the essential signal, not everything knowable. Every new field, hook output, or subagent earns its place by shrinking what the human must hold in their head.
3. **Plan before code.** No `Edit`/`Write` tool call runs without a plan artifact. This is enforced by the plan-gate hook.
4. **Surgical edits.** Only plan-listed files are modified. Only plan-listed functions are changed. Adjacent functions are never touched.
5. **Work-item traceability.** Every build references a REQ ID (new build), an issue ticket (fix), or a signed change request (CR).
6. **Graceful degradation.** Missing Git, ticketing, or observability? The plugin writes markdown (or JSON) artifacts locally and surfaces the gap in the phase summary — never silently skips.
7. **Stack-agnostic.** Tool choices are placeholders in `config/tools.json`. Leave any value as `null` to skip that check.

## The artifact tree

The plugin writes into `.claude/sdlc/` in the consuming repo:

```
.claude/sdlc/
├── env.json                # integrations detected by env-detect.sh
├── scope.md                # signed project scope statement
├── scope-drafts/           # scope-ingest output; reviewed before promoting to scope.md
├── gates/scope-<project>.md  # scope gate (pseudo-phase gate, signed before first /plan)
├── plans/<task-slug>.md
├── requirements/<task-slug>.md
├── architecture/
│   ├── application.md
│   ├── data.md
│   ├── platform.md
│   ├── infrastructure.md
│   ├── security.md
│   ├── test.md
│   ├── ux/<task-slug>.md
│   └── manifest.json
├── tech-specs/<module>.md
├── test-cases/TC-<n>.md
├── test-scripts/...
├── tickets/ISSUE-<n>.md
├── change-requests/CR-<n>.md
├── sign-offs/CR-<n>.md
├── gates/<phase>-<task-slug>.md
├── defects/<task-slug>/DEF-<n>.md
├── deployments/<date>-<task-slug>.md
├── monitoring/<task-slug>/
├── followups/<task-slug>.md
└── docs/
    ├── index.md
    └── traceability.md
```

## Phase 1 — Plan

**Command:** `/plan`  
**Skill:** `plan`  
**Prereq:** a signed `scope.md`. On first run the `scope-ingest` agent turns source material (README, brief, spec) into a provenance-traced draft; the human reviews, corrects, and signs the scope gate before planning proceeds. Fallback: one-paragraph statement entered in chat.

Produces a plan artifact in six steps:

1. Classify the work item (new-build / fix / CR)
2. Resolve scope — read `scope.md` if signed; otherwise invoke `scope-ingest` against source material the human provides
3. Domain-expert check — matches the task against `domains/_index.json`; injects a `## Domain context` block (gap questions, NFRs, security hotspots) when a domain is detected
4. Write the plan artifact (classification, in-scope files/functions, out-of-scope, approach, tests, risks, estimate)
5. Technology stack compatibility matrix
6. Human gate sign-off

For fixes and CRs, Step 2 also validates the request against the original scope and surfaces any delta for human decision.

**Gate:** `.claude/sdlc/gates/plan-<task-slug>.md`  
**Scope gate (one-time per project):** `.claude/sdlc/gates/scope-<project>.md`

## Phase 2 — Analyze

**Command:** `/analyze`  
**Skill:** `analyze`  
**Prereq:** Plan gate.

Creates or intakes requirements with stable `REQ-<n>` IDs, each with acceptance criteria, priority, source, and dependencies. Maps each REQ to a section of the scope statement; unmapped REQs are surfaced as scope questions.

**Hard rule:** frontend work halts the phase until a UX artifact exists at `.claude/sdlc/architecture/ux/<task-slug>.md`. Brand guidelines must be linked.

**Gate:** `.claude/sdlc/gates/analyze-<task-slug>.md`

## Phase 3 — Design

**Command:** `/design`  
**Skill:** `design`  
**Prereq:** Analyze gate.  
**Subagents:** `architect`, `test-designer` (optional, run in parallel when available).

Produces or validates the full architecture bundle — application, data, platform, infrastructure, security, test — plus technical specs (per module), test cases (one or more per REQ), and the DevOps pipeline design. Never wholesale-regenerates a working architecture; always validates against current requirements first and surfaces deltas for human decision.

**Gate:** `.claude/sdlc/gates/design-<task-slug>.md`

## Phase 4 — Build

**Command:** `/build`  
**Skills:** `build` (coordinates `surgical-edit`, `minimal-code`, `security-review`)  
**Prereq:** Design gate. (Or fix-fast mini-gate; see below.)

Validates the work item (REQ / ticket / signed CR), writes the smallest possible diff per the plan, validates code against the tech spec and architecture, and adds unit tests **only for functions actually modified**. Frontend work is validated against the UX artifact.

**Active hooks:**

| Hook                             | Trigger                | Effect                                              |
|----------------------------------|------------------------|-----------------------------------------------------|
| `plan-gate.sh`                   | PreToolUse Edit/Write  | Blocks if no plan exists                            |
| `work-item-validation.sh`        | PreToolUse Edit/Write  | Blocks CRs without a sign-off artifact              |
| `diff-scope-check.sh`            | PostToolUse Edit/Write | Warns on files outside the plan's in-scope list     |
| `adjacent-function-detector.sh`  | PostToolUse Edit/Write | Warns on functions outside the plan's in-scope list |
| `format-on-write.sh`             | PostToolUse Edit/Write | Runs the configured formatter on changed files      |
| `secret-scan.sh`                 | PostToolUse Edit/Write | Blocks if the secret scanner finds anything         |
| `modified-code-test-gate.sh`     | Stop                   | Warns if source changed without tests               |

**Gate:** `.claude/sdlc/gates/build-<task-slug>.md`

## Phase 5 — Test

**Command:** `/test`  
**Skill:** `test`  
**Prereq:** Build gate.

Executes functional tests, reports coverage against threshold (default 80% on modified code), logs defects. Defect routing:

- Git + Issues detected → create issues with `defect`, `severity:*`, `phase:test` labels
- Otherwise → `.claude/sdlc/defects/<task-slug>/DEF-<n>.md` (or `.json` per config)

For frontend work, runs UX conformance checks against mockups (screenshots stored under `.claude/sdlc/test/ux/`).

**Gate:** `.claude/sdlc/gates/test-<task-slug>.md`

## Phase 6 — Deploy

**Command:** `/deploy`  
**Skill:** `deploy`  
**Prereq:** Test gate.

Produces a deployment proposal (environment, commit, migrations, feature flags, rollback, blast radius), waits for explicit human approval, executes under supervision, and runs post-deploy smoke tests. **Never auto-deploys.** Records deployment details in tickets when available; otherwise in markdown/JSON artifacts.

**Gate:** `.claude/sdlc/gates/deploy-<task-slug>.md`

## Phase 7 — Support

**Command:** `/support`  
**Skill:** `support`  
**Subagent:** `observability` (optional)  
**Prereq:** Deploy gate.

Produces logging deltas, metrics/alert config, dashboard artifacts, and a runbook stub. Platform-neutral when no observability platform is configured; integrates via MCP when wired up — but never auto-applies production alert changes.

**Gate:** `.claude/sdlc/gates/support-<task-slug>.md`

## Phase 8 — Docs (cross-cutting)

**Command:** `/docs`  
**Skill:** `docs`  
**Trigger:** after any phase that changed artifacts, or after deploy.

Refreshes the artifact index, the requirements traceability matrix, the architecture manifest, the changelog, and user-facing docs. Leaves traceability gaps visible — the human decides whether to fill or waive.

## Cross-cutting skills

- **`scoping`** — called by `plan` when the request is ambiguous. Forces clarification before any artifact is written.
- **`surgical-edit`** — called by `build` on every Edit/Write. The heart of the "only touch code that needs modifying" rule.
- **`minimal-code`** — called by `build`. YAGNI, KISS, DRY-when-it-actually-repeats. Prefer editing over creating. Prefer a function over a class.
- **`security-review`** — called by `build` and `/review`. Scoped to the current diff, not the whole codebase.

## The fix-fast path

For small bug fixes only. Collapses Plan + Analyze + Design into a single mini-gate. Eligibility (all required):

- Classification = fix
- Estimated scope ≤ 2 files AND ≤ 50 LOC
- No schema / API / security-surface changes
- No frontend / UX changes

Phases 4–8 are **not** compressed. Deploy, Test, Support, Docs still run normally.

## Validation metrics (what to measure when iterating on this plugin)

- **Plan-first compliance:** 100% of Edit/Write calls have a preceding plan file.
- **Work-item validation:** 100% of builds reference a valid REQ / ticket / signed CR.
- **Scope discipline:** files-touched ÷ files-in-scope = 1.0.
- **Adjacent-function modifications:** target 0 per task.
- **Test scope:** tests-modified ÷ functions-modified stays close to 1.0.
- **Requirements traceability:** 100% of REQ IDs appear in at least one test case and one code reference.
- **Defect escape rate:** post-deploy defects per task — expect a drop over time.
- **Human-gate touch rate:** gates are actually reviewed, not rubber-stamped — measure average review time.
- **Diff size per feature:** track the trend. Over-engineering shows up here first.

## Agentic modernization — scope and limits

Subagents in this plugin are **bounded**:

- `architect` — read code, write only to `architecture/`
- `test-designer` — read requirements and specs, write only to `test-cases/`
- `security-reviewer` — read only, write only findings to `test/security-review-*.md`
- `observability` — read architecture, write only to `monitoring/`

### External connectivity

The plugin integrates with external systems through four transports, chosen per category:

- **Local CLI / filesystem** — Git (VCS); GitHub/GitLab/Bitbucket detected via `git remote`; CI systems (GitHub Actions, GitLab CI, CircleCI, Jenkins) detected by sniffing workflow files. The plugin never triggers pipelines.
- **MCP (user-provided servers)** — Jira and Linear (issues), Grafana and Datadog (observability), Figma (UX).
- **Infrastructure-as-code proposals** — CloudWatch and similar cloud-native observability; proposed as IaC diffs rather than direct API calls.
- **Direct HTTP probes** — the `api-integration` skill probes development-time API endpoints (OpenAPI/GraphQL/gRPC) via the tool configured in `config/tools.json`.

Every MCP connector is **propose-only** for state-changing operations. Every cross-phase handoff ends at a human gate. No subagent and no MCP tool can advance a phase on its own. The plugin does not ship or configure MCP servers — users wire their own. See the README's *External connectivity* section for the full matrix.

## Iterating on this plugin

Tune hook strictness against real work:

- If `diff-scope-check` fires too often on legitimate discoveries, your plans are too narrow — or your planning skill needs prompting to be more thorough.
- If `adjacent-function-detector` has many false positives, switch `adjacent_function_detection.method` to `tree-sitter` in `config/tools.json` and set the language.
- If `modified-code-test-gate` fires on code that genuinely doesn't need tests (pure config, generated code), narrow its file-path exclusions.
- If humans rubber-stamp gates without reading, the phase summaries are too long — tighten them.

The goal is a plugin that makes the right thing feel natural and the wrong thing feel friction-y — not one that stops work.
