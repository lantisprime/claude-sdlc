# Changelog

All notable changes to claude-sdlc are documented here.

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
