# Changelog

All notable changes to claude-sdlc are documented here.

## [1.3.0] — 2026-04-27

Closes RFC-003 (Hook Enforcement Alignment) — eight PRs that tighten the four documented gaps between `USER-MANUAL.md`'s enforcement claims and the actual hook implementations. All changes are additive and back-compat: default behavior on upgrade matches pre-upgrade, with new enforcement modes available behind opt-in config flips.

### Added

- **`phase-gate.sh` PreToolUse prior-gate enforcement (RFC-003 PR-3)** — `phase-gate.sh` is now registered on `PreToolUse Edit|Write|MultiEdit` in addition to the existing `Stop` event. The `PreToolUse` branch reads the active plan's `Phase:` (or `Active Phase:`) field, looks up the prior gate (e.g. `analyze` requires `plan-<slug>.md`), and exits 2 with `[phase-gate] BLOCK` when the prior gate file is missing. Source/test/config edits block; `.md`/`.rst`/`.txt` edits warn instead. The `Stop` advisory reminder is unchanged.
- **`phase-gate.sh` deploy/fix-fast placeholder validation (RFC-003 PR-4)** — When the active phase is `deploy` or follows a `fix-fast` mini-gate, the hook scans the most recent gate file for unfilled `<signer>` / `<timestamp>` / `<work-item>` / `<acknowledgment>` placeholder tokens, `___` blanks, or bare `TODO` markers in the `Signed by`, `Signed at`, `Work-item reference`, `## Acknowledgment`, and `## Confirmation` fields. Multi-line HTML comments are stripped before the scan. Block-level — refuses the edit until every required field is filled.
- **`work-item-validation.sh` file-level traceability warning (RFC-003 PR-5)** — The hook now reads `CLAUDE_TOOL_INPUT.file_path` (jq → grep/sed → raw fallback) and emits two warn-level signals: file not in the active plan's `## In-scope files` section, or plan has no `(REQ|TICKET|CR|ISSUE)-[0-9]+` reference. Generated-file inheritance via `config/tools.json`'s `generated_files` map: edits to entries listed there inherit traceability from the configured `generated_by` source. In-scope check uses token-level line-by-line matching (not substring) so bare basenames don't falsely match longer paths. `.claude/sdlc/` paths bypass as a repair escape hatch.
- **`work-item-validation.sh` file-level traceability opt-in block (RFC-003 PR-8)** — Promotes the file-level warning to a hard block (exit 2) when `enforcement.file_traceability: "block"` is set in `config/tools.json` AND the active plan contains a structured `## Traceability` markdown table. Each edited file must appear as a row in the table with a `(REQ|TICKET|CR|ISSUE)-[0-9]+` reference. Plans without the section fall back to warn-only regardless of config (back-compat). Header column accepts `File` / `Path` / `Source` / `Source File` (case-insensitive). Default mode is `warn` — opt-in only.
- **Strict-mode `enforcement` config block (RFC-003 PR-2)** — `config/tools.example.json` reserves `enforcement` keys: `phase_gate` (default `block`), `file_traceability` (default `warn`), `scope_drift` (default `warn`), `missing_tests` (default `warn`). Hooks consume these for severity overrides — set any key to `warn` to demote a block (or `block` to promote a warn) without code changes.
- **`generated_files` config schema (RFC-003 PR-2/PR-5)** — `config/tools.example.json` reserves `generated_files` as an array of `{path, generated_by}` entries. `work-item-validation.sh` (PR-5/PR-8) inherits traceability from the configured generator, so edits to lockfiles, generated SDKs, and build artifacts no longer warn or block when their source is in-scope and REQ-mapped.
- **`Phase:` field in plan template (RFC-003 PR-3)** — `templates/plan.md` now ships a `Phase:` field (values: `plan | analyze | design | build | test | deploy | support | docs`) read by `phase-gate.sh` to determine prior-gate requirements. Both `Phase:` and `Active Phase:` forms are accepted.
- **`## Traceability` section in plan template (RFC-003 PR-7)** — `templates/plan.md` now ships a 5-row markdown table (`File | REQ/Ticket/CR | Change Type`) for per-file work-item mapping. Read by `work-item-validation.sh` (PR-8) when block mode is configured. Purely additive; warn-only when absent.
- **Anchor-token placeholders in gate template (RFC-003 PR-4)** — `templates/gate.md` replaces ambiguous multi-word placeholders with anchor tokens (`<signer>`, `<timestamp>`, `<work-item>`, `<acknowledgment>`) plus inline HTML-comment guidance. Detected reliably by `phase-gate.sh`'s placeholder scanner.

### Changed

- **`hooks/hooks.json`** — `phase-gate.sh` is now registered on `PreToolUse Edit|Write|MultiEdit` (in addition to the existing `Stop` event). The `PreToolUse` branch is reached for every Edit/Write call; the `Stop` branch continues to print a 2-hour reminder if no gate file has been updated recently. Both branches share a single script via `$CLAUDE_HOOK_EVENT` dispatch.

### Documentation

- **`docs/USER-MANUAL.md` enforcement language audit (RFC-003 PR-1)** — Five overclaimed enforcement sites were corrected to match shipped behavior, with `Planned (RFC-003 PR-N)` tags pointing at the implementing PR.
- **`docs/USER-MANUAL.md` four-status legend + status-table sync (RFC-003 PR-6)** — Added a four-status legend block (Implemented hard block / Implemented warning / Planned / Strict-mode only) above the downstream-enforcement section. After Phase 2 shipped, replaced "Planned" tags with the shipped status: `phase-gate.sh` → Implemented hard block (PR-3, PR-4); `work-item-validation.sh` → Implemented warning for file-level traceability (PR-5), Implemented hard block when opt-in (PR-8). The gate-as-contract paragraph now reads "with RFC-003 PR-3 through PR-8 shipped, the contract is enforced end-to-end".
- **`docs/rfcs/RFC-003-hook-enforcement-alignment.md`** — RFC accepted, all 8 PRs logged with commit SHAs and per-PR summaries, status flipped to `implemented`.
- **`docs/rfcs/RFC-004-maintainer-code-review-enforcement.md`** — RFC accepted (not yet implemented). Index files updated.
- **`docs/rfcs/pending-analysis.md`** — Items 3 and 4 closed; quick-reference table added.
- **README + `docs/CONTRIBUTING.md`** — Install section updated with marketplace method and `v1.2.0` ref pin (now `v1.3.0`); Linux/WSL install commands added to prerequisites table.

### Issues filed and closed (pre-commit code review traceability)

- [#22](https://github.com/lantisprime/claude-sdlc/issues/22), [#23](https://github.com/lantisprime/claude-sdlc/issues/23) — RFC-003 PR-3 review fixes (Active Phase regex, branch detection)
- [#24](https://github.com/lantisprime/claude-sdlc/issues/24), [#25](https://github.com/lantisprime/claude-sdlc/issues/25), [#26](https://github.com/lantisprime/claude-sdlc/issues/26) — RFC-003 PR-4 review fixes (case-insensitive field grep, multi-line HTML comments, pipefail brittleness)
- [#27](https://github.com/lantisprime/claude-sdlc/issues/27) — RFC-003 PR-5 review fix (substring false-match in In-scope check)
- [#28](https://github.com/lantisprime/claude-sdlc/issues/28), [#29](https://github.com/lantisprime/claude-sdlc/issues/29) — RFC-003 PR-8 review fixes (header parser brittleness, misleading promote-to-block hint)

### Test count

126/126 passing (`tests/run.sh`) — up from 109/109 at v1.2.0. New coverage: 30 phase-gate scenarios + 35 work-item-validation scenarios.

---

## [1.2.0] — 2026-04-27

### Added

- **Distribution packaging system (RFC-002)** — `scripts/package.sh` builds a consumer-ready distribution: reads `devFiles` from `plugin.json`, applies a hardcoded infra exclusion list (`.git`, `.github`, `dist`, `.claude`, `config/tools.json`), produces a `dist/sdlc-plugin-vX.Y.Z.tar.gz` archive, and force-pushes a clean `release` branch. Supports `--dry-run` (manifest preview, no writes), `--skip-tests`, and `--skip-tag` flags.
- **Self-hosted marketplace** — `.claude-plugin/marketplace.json` enables consumers to install with `/plugin marketplace add lantisprime/claude-sdlc` then `/plugin install sdlc-plugin@claude-sdlc`. No Anthropic approval required.
- **CI release pipeline** — `.github/workflows/release.yml` runs a `test` job on every push to `main` and a `release` job on `v*.*.*` tags (only after `test` passes). Release job installs `jq`, configures git identity, calls `package.sh --skip-tests --skip-tag`, verifies the archive exists, creates a GitHub Release with the attached `.tar.gz`, validates `marketplace.json`, and commits the updated `ref` back to `main` with `[skip ci]`.
- **Packaging test suite** — `tests/scripts/package.bats` (18 tests): covers all 4 CI bugs as regression tests, manifest exclusion correctness for all `devFiles` and infra categories, missing-dependency detection, and flag-parsing edge cases.
- **Contributor/maintainer guide** — `docs/CONTRIBUTING.md` covers prerequisites, running tests, per-artifact-type rules (linking `AGENT-RULES.md` rather than duplicating it), release procedure, and the per-push docs-sync checklist.
- **Docs-sync validator** — `tests/plugin/validate_docs_sync.sh` reads the machine-readable counts block from `docs/references/_repo-context.md` and compares against disk counts for skills, commands, hooks, templates, and agents. Also checks that every command file has a `/<name>` entry in `README.md`. Runs automatically on every `tests/run.sh` invocation.
- **Machine-readable counts block** — `docs/references/_repo-context.md` now contains a `<!-- validate-counts:start ... end -->` block parsed by `validate_docs_sync.sh`.

### Fixed

- **`mapfile` bash 4+ incompatibility** — `scripts/package.sh` used `mapfile` to build the `DEV_FILES` array from `jq` output; `mapfile` is not available on macOS system bash 3.2. Replaced with a `while IFS= read -r line` loop.
- **Git identity not set in CI** — `release_branch()` called `git commit` inside an isolated repo that inherited no git identity. Fixed by adding a `git config --global user.name/email` step to `release.yml` before the Package step.
- **In-place orphan branch checkout failed in GitHub Actions worktree** — `git checkout --orphan release-tmp` inside an Actions worktree produced `cannot delete branch used by worktree`. Replaced with an isolated `/tmp` repo approach: init a new repo, copy distributable files, commit, add remote, force-push.
- **Tag already exists in CI** — `package.sh` tried to create a tag that already existed when re-run after a partial failure. Added `--skip-tag` flag; `release.yml` passes it unconditionally.
- **Credentials missing for isolated repo push** — `actions/checkout` sets credentials locally on the checked-out repo only; the isolated `/tmp` repo had no auth. Fixed by adding a `git config --global url.insteadOf` rewrite with `GITHUB_TOKEN` to `release.yml`.
- **Hook count in `_repo-context.md`** — corrected from "13 registered" to "14 total (13 event hooks + `suspend-snapshot.sh` skill-invoked)".

### Changed

- `tests/run.sh` — structural validators section now auto-discovers all `validate_*.sh` scripts under `tests/plugin/` via `find`, so new validators are picked up without editing the runner.

### Documentation

- `docs/PACKAGING.md` — maintainer reference covering how the Claude Code installer works, the release branch model, step-by-step release checklist, dry-run usage, consumer install commands, packaging test suite table, and a troubleshooting table.

---

## [1.1.0] — 2026-04-26

### Bug fixes

- **`find -printf` portability** ([#7](https://github.com/lantisprime/claude-sdlc/issues/7)) — `hooks/adjacent-function-detector.sh`, `hooks/diff-scope-check.sh`, and `hooks/work-item-validation.sh` used `find -printf "%T@ %p\n"` to sort plan files by mtime. `-printf` is a GNU find extension not available on macOS BSD find. Replaced with a portable `stat -f %m` (BSD) / `stat -c %Y` (GNU) fallback loop.
- **`awk \s` not supported on macOS nawk** ([#11](https://github.com/lantisprime/claude-sdlc/issues/11)) — `diff-scope-check.sh` and `adjacent-function-detector.sh` used `\s` in awk regex patterns to match the header whitespace in `## In-scope files` / `## In-scope functions`. macOS ships BWK/nawk, which treats `\s` as a literal character, so `IN_SCOPE` and `IN_SCOPE_FNS` were always empty on macOS — every file and function triggered a false warning. Replaced with POSIX `[[:space:]]`.
- **`adjacent-function-detector.sh` pipefail on empty diff** ([#8](https://github.com/lantisprime/claude-sdlc/issues/8)) — `grep` exited 1 when `git diff` produced no output, killing the script via `pipefail` before the empty-check guard. Added `|| true`.

### Tests

- **Automated test suite added** — 58 bats-core tests covering all hooks (unit + integration). Closes the gap noted in `CLAUDE.md`. CI runs on Ubuntu via GitHub Actions.
- **Test fixture format fixed** ([#9](https://github.com/lantisprime/claude-sdlc/issues/9)) — fixtures used markdown-bold `**Classification:**` syntax; hook regex expected plain `Classification:`. Fixed fixture files.
- **Integration test setup fixed** ([#10](https://github.com/lantisprime/claude-sdlc/issues/10)) — missing `mkdir -p src/` before writing test files caused integration tests to pass vacuously. Fixed.

### Documentation

- **Prerequisites section added to README** — new section above Install covering Claude Code (required; plugin has no standalone runtime), bash (Windows: Git Bash or WSL2), and Git (recommended for scope/diff hooks).
- **User Manual prerequisites updated** — section 1 now includes a Windows platform note and expanded Claude Code and bash rows.

---

## [1.0.0] — 2026-04-26

Initial public release. claude-sdlc is a governance layer for AI-assisted software delivery — an 8-phase SDLC workflow with human sign-off at every gate, plan-before-code enforcement, surgical-edit discipline, and full work-item traceability.

---

### Commands

16 slash commands covering every phase and cross-cutting concern:

| Command | Purpose |
|---|---|
| `/start` | Activate the SDLC workflow — handles fresh install, re-enable after suspension, and hand-off to `/plan` if already active |
| `/plan` | Required first step for every task; classifies work, validates scope, estimates effort, proposes a tech stack, writes a plan artifact all downstream phases depend on |
| `/analyze` | Turns an approved plan into stable-ID requirements (REQ-001, REQ-002, …); halts for UX designs and brand guidelines when frontend work is detected |
| `/design` | Produces application/data/security/test architecture, tech spec, test cases, and DevOps pipeline design from approved requirements |
| `/build` | Enforces surgical-edit discipline and work-item traceability during implementation; coordinates security review |
| `/test` | Executes tests, records results, logs defects (Git Issues or local markdown), reports coverage, validates UX conformance |
| `/deploy` | Proposes deployment actions and writes deployment artifacts; never auto-executes — always waits for explicit human confirmation |
| `/support` | Generates monitoring, alerting, logging, and runbook artifacts for a deployed change |
| `/docs` | Updates the SDLC documentation tree: artifact index, requirements traceability matrix, architecture manifest, and user-facing docs |
| `/review` | Code review against SDLC artifacts and security checklist |
| `/fix-fast` | Compressed path for small bug fixes (≤2 files, ≤50 LOC, no schema/API/security/UX changes) — collapses Plan + Analyze + Design into one mini-gate |
| `/status` | Read-only snapshot of active plan, gate progress, sign-off state, and next action |
| `/configure` | Guided setup wizard for `config/tools.json`; auto-invoked on fresh install and when a required config key is missing at runtime |
| `/help` | Plugin command reference |
| `/suspend` | Snapshots governance state and disables enforcement with a required stated reason; re-enables via `/start` with reconciliation |
| `/token-review` | Reports token usage aggregated by SDLC phase |

---

### Skills

20 skills spanning all 8 phases plus cross-cutting concerns:

**Phase skills**

- **start** — Opt-in activation (sets `.enabled` marker), re-enable reconciliation (verifies governance snapshot), and hand-off to `/plan`
- **plan** — Work-item classification (new build / bug fix / change request), scope validation against `scope.md`, high-level estimate, tech stack proposal and compatibility check; writes plan artifact to `.claude/sdlc/plans/`
- **analyze** — Requirements intake with stable REQ IDs; validates each against the scope statement; halts for UX designs when frontend changes are in scope
- **design** — Architecture validation against existing artifacts, tech spec authoring, test-case generation (REQ-traced), DevOps pipeline design; delegates to `architect` and `test-designer` subagents
- **build** — Validates work-item reference, enforces surgical-edit and minimal-code rules, coordinates formatter and security review
- **test** — Test execution, defect logging with ticket/markdown fallback, coverage reporting against threshold, UX conformance validation
- **deploy** — Deployment proposal and artifact generation; writes to `.claude/sdlc/deployments/`; propose-only, never auto-executes
- **support** — Monitoring, alerting, and runbook artifact generation; integrates with Grafana/Datadog/CloudWatch via MCP when configured; falls back to platform-neutral scripts
- **docs** — SDLC documentation tree update after any phase change

**Cross-cutting skills**

- **gate-signoff** — Chat-driven phase-gate sign-off: prompts for work-item URL, validates URL shape against configured tracker, writes signed gate file to `.claude/sdlc/gates/`
- **domain-expert** — Injects domain-specific context, regulatory concerns, and gap questions into the plan based on semantic match against `domains/_index.json` — no keyword list required
- **scoping** — Forces clarification when a request is ambiguous or missing critical information; writes clarified scope into the plan artifact before planning begins
- **api-integration** — Verifies API spec exists (OpenAPI, GraphQL, Protobuf, AsyncAPI) and probes endpoint reachability; offers a mock scaffold (MSW, Prism, WireMock) if the spec is missing or the endpoint is unreachable
- **security-review** — Reviews the current diff for OWASP-class vulnerabilities: input validation, auth/authz, secrets, injection surfaces (SQL, command, template, prompt), unsafe APIs, sensitive data handling, output encoding

**Utility skills**

- **surgical-edit** — Enforces minimum-diff discipline on every Edit/Write: only plan-listed files and functions, no adjacent-function modifications, no "while I'm here" cleanups; unrelated bugs are logged to followups, not fixed inline
- **minimal-code** — Enforces YAGNI, KISS, and DRY-when-it-actually-repeats during Build; resists speculative abstractions, new dependencies, and unnecessary layers
- **status** — Read-only workflow snapshot; writes nothing
- **configure** — Guided config setup with public/local split (`tools.json` / `tools.local.json`), diff-before-write, and resume semantics for interrupted setup
- **help** — Plugin command reference; read-only
- **suspend** — Governance snapshot via `suspend-snapshot.sh`, `.suspended` marker, re-enable block if workflow not active

---

### Enforcement Hooks

14 shell hooks registered in `hooks/hooks.json`:

**PreToolUse (block or warn before a tool runs)**

- **plan-gate.sh** — Blocks `Edit`/`Write` when no approved plan exists for the active task; also checks for `scope.md` and a signed scope gate; hardest block in the plugin
- **work-item-validation.sh** — Ensures every edit references a valid work item (REQ ID for new builds, issue ticket for fixes, signed CR for change requests)
- **bash-safety.sh** — Blocks obvious shell footguns (destructive `rm`, pipe-to-shell, force-push to main) without explicit confirmation

**PostToolUse (check after a tool runs)**

- **diff-scope-check.sh** — Compares `git diff` against the plan's `In-scope files` list; warns on out-of-scope touches
- **adjacent-function-detector.sh** — Uses `git diff --function-context` hunk headers (or tree-sitter, configurable) to detect edits to functions not listed in the plan; warns rather than blocks to avoid false-positive halts
- **format-on-write.sh** — Runs the configured formatter after every write; no-ops gracefully if no formatter is configured
- **secret-scan.sh** — Runs the configured secret scanner after every write; blocks (`exit 2`) on confirmed findings

**SessionStart (run once when the session opens)**

- **env-detect.sh** — Detects available integrations (Git, ticket system, formatter, linter, test runner, secret scanner, observability platform) and writes `.claude/sdlc/env.json`; skills read this to decide fallbacks
- **session-plan-check.sh** — Surfaces any in-flight SDLC work (active plans, unsigned gates) at session open; writes nothing, blocks nothing

**Stop (run when the session ends)**

- **approval-reconcile.sh** — For every gate file with a `## Required sign-offs` block, verifies the required approvals are present; supports three transports: network share (tier 1), git mirror (tier 2), MCP connector (tier 3 stub)
- **phase-gate.sh** — Reminds that ending a phase requires a signed gate file; warns if the current phase has no gate
- **modified-code-test-gate.sh** — Warns if functions modified during the session have no corresponding test update
- **token-tracker.sh** — Parses the session transcript and aggregates token usage into SDLC phase buckets using gate file timestamps

**Utility (skill-invoked)**

- **suspend-snapshot.sh** — Captures a governance snapshot (active plans, gate state, scope hash) for `/suspend`; used by `/start` to verify state integrity on re-enable

---

### Subagents

5 bounded subagents with strict write-scope limits:

| Agent | Role | Write scope |
|---|---|---|
| **scope-ingest** | Turns raw source material (markdown, plain text, pasted content) into a normalized, provenance-traced scope draft | `.claude/sdlc/scope-drafts/` only — never writes `scope.md` directly |
| **architect** | Read-only architecture validator; validates existing artifacts against current requirements and proposes updates | `.claude/sdlc/architecture/` only — never touches application code |
| **security-reviewer** | Read-only security diff auditor; runs the security-review checklist and proposes remediations | Cannot apply remediations — propose only |
| **test-designer** | Generates REQ-traced test cases from approved requirements during Design | `.claude/sdlc/test-cases/` only — never touches implementation or existing tests |
| **observability** | Produces monitoring, alerting, and runbook artifacts during Support | `.claude/sdlc/monitoring/` only — never touches application code |

---

### Templates

13 artifact templates covering every SDLC output:

| Template | Produces |
|---|---|
| `plan.md` | Plan artifact with work-item classification, scope validation, estimate, tech stack, and in-scope file/function lists |
| `requirements.md` | Requirements with stable REQ IDs, acceptance criteria, and scope validation |
| `tech-spec.md` | Technical specification with architecture decisions and interface contracts |
| `test-case.md` | REQ-traced test case with preconditions, steps, and expected results |
| `gate.md` | Phase gate sign-off record |
| `scope-gate.md` | Scope gate with provenance tracing back to source material |
| `sign-off.md` | Single-approver sign-off |
| `sign-off-multi.md` | Multi-team sign-off with role assignments |
| `approval-packet.md` | Multi-team approval packet for change requests |
| `change-request.md` | Scope change request with impact analysis |
| `ticket.md` | Work item ticket |
| `defect.md` | Defect record with reproduction steps and REQ trace |
| `deployment.md` | Deployment artifact with rollback plan |

---

### Domain Registry

Built-in semantic domain context automatically injected into plans:

- **payments** — PCI-DSS compliance rules, tokenization requirements, fraud signal concerns, regulatory gap questions
- **auth** — Session management rules, credential storage, OAuth/OIDC surface concerns, privilege escalation risks

Domain files follow `domains/_schema.md` and are indexed in `domains/_index.json`. Any team can add custom domain files — they are picked up automatically by the `domain-expert` skill via semantic matching, with no keyword list to maintain.

---

### Configuration

`config/tools.example.json` defines the full configuration schema. Users copy it to `config/tools.json` (committed) and optionally `config/tools.local.json` (gitignored) for local overrides. The plugin is fully stack-agnostic — formatter, linter, test runner, coverage threshold, secret scanner, ticket system, observability platform, and artifact format fallback are all configurable and default to graceful degradation when absent.

---

### Documentation

- [README.md](README.md) — Install, quick start, core principles, command reference
- [docs/USER-MANUAL.md](docs/USER-MANUAL.md) — Detailed walkthrough with scenarios and exact user inputs at each phase
- [docs/SDLC.md](docs/SDLC.md) — Full phase reference and validation metrics
- [docs/claude-sdlc-enterprise-adoption.md](docs/claude-sdlc-enterprise-adoption.md) — Role shifts, cost mechanics, audit evidence, and human-in-the-lead model for enterprise teams
- [docs/GLOSSARY.md](docs/GLOSSARY.md) — Term definitions
- [docs/diagrams.md](docs/diagrams.md) — Architecture and flow diagrams
