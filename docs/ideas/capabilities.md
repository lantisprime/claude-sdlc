# Claude SDLC Capabilities

Repository reviewed: `lantisprime/claude-sdlc` at commit `918b201`.

This document describes the capabilities exposed by the Claude SDLC plugin as implemented in this repository. It is intended for capability review, adoption planning, and implementation assessment. The plugin is not an application framework; it is a Claude Code governance package made of slash commands, skills, hooks, subagents, templates, and local artifacts that shape how Claude Code performs software delivery work in a consuming repository.

## Executive summary

Claude SDLC wraps Claude Code in an 8-phase software delivery workflow:

1. Plan
2. Analyze
3. Design
4. Build
5. Test
6. Deploy
7. Support
8. Docs

Its main capability is process control around AI-assisted coding. It forces plan-before-code behavior, captures human sign-off at phase gates, keeps work tied to requirements or tickets, narrows implementation scope to approved files and functions, creates traceable delivery artifacts, and degrades to local markdown or JSON when external systems are unavailable. The latest repository update also makes "reduce cognitive load" an explicit core principle: artifacts, prompts, hook messages, and subagent output should surface the decision signal rather than everything knowable.

The strongest controls are:

- Blocking edits when no plan artifact exists.
- Blocking change-request builds when no signed CR artifact exists.
- Blocking confirmed secrets when a scanner is configured.
- Blocking destructive shell patterns through a Bash safety hook.
- Requiring human gate approval before phase advancement.
- Treating deployment as a proposal that requires explicit human approval.

Several other controls are advisory rather than hard blockers:

- Out-of-scope file edits.
- Adjacent-function edits.
- Source changes without test changes.
- Missing recent phase gate reminders.
- Architecture and test-case traceability gaps.

This distinction matters for risk review: the plugin is a discipline and audit-evidence layer, not a complete sandbox, policy engine, or compliance attestation system.

## Latest review update

The repository changed materially since the first capabilities review. The latest commit moves several previously proposed scope and domain capabilities into the implemented tree.

Implemented in the current tree:

- New core principle: reduce cognitive load.
- New `domains/` directory with a domain-file schema.
- Seed domain files for authentication/authorization and payments.
- Domain matching rules in `domains/_index.json`.
- `domain-expert` skill for injecting domain context into plans.
- `scope-ingest` subagent for producing provenance-traced scope drafts.
- `templates/scope-gate.md` for first-task project scope sign-off.
- `plan-gate.sh` warnings for missing `scope.md` and missing scope gate.
- `skills/plan/SKILL.md` wiring for scope resolution, domain expert, and first-task scope gate.
- `docs/GLOSSARY.md`.
- Documentation updates in `README.md`, `CLAUDE.md`, and `docs/SDLC.md` to include cognitive-load reduction.

Still designed but not fully implemented yet:

- Scope ingestion from PDFs, DOCX, PPTX, auth-walled URLs, and ticket references.
- `/status`, `/start`, `/configure`, `/help`, session plan-check hook, approval packets, plan versioning, and next-step hints from the accepted guided-entry RFC.

This means the current shipped capability has expanded from "domain knowledge assets" to an actual plan-time domain and scope workflow, with remaining limitations around richer source formats and guided-entry UX.

## Primary capability groups

### 1. Human-gated SDLC orchestration

The plugin defines commands for the major lifecycle phases:

| Command | Phase | Primary output |
|---|---:|---|
| `/plan` | 1 | Plan artifact and plan gate |
| `/analyze` | 2 | Requirements with stable REQ IDs and analyze gate |
| `/design` | 3 | Architecture, tech specs, test cases, pipeline design, design gate |
| `/build` | 4 | Production code, scoped tests, pipeline deltas, build gate |
| `/test` | 5 | Test execution report, defects, coverage status, test gate |
| `/deploy` | 6 | Deployment proposal, deployment record, deploy gate |
| `/support` | 7 | Monitoring, alerting, dashboards, runbook artifacts, support gate |
| `/docs` | 8 | Artifact index, traceability matrix, architecture manifest, changelog |

The flow is intentionally sequential. Commands declare their prior gate prerequisite, so a later phase should not proceed until the prior phase has produced a signed gate artifact.

Every gated phase writes a file under:

```text
.claude/sdlc/gates/<phase>-<task-slug>.md
```

Gate files capture:

- Phase and task slug.
- Human signer.
- Timestamp.
- Work-item reference.
- Phase summary.
- Artifacts produced or updated.
- Open items.
- Explicit waivers.
- Raw acknowledgment text.

The plugin rejects trivial sign-offs such as bare approval words in its documented workflow. Sign-off is expected to contain a work-item URL, ticket, CR reference, or degraded-mode REQ reference.

### 2. Plan-before-code enforcement

The `plan-gate.sh` hook is registered on `PreToolUse` for `Edit`, `Write`, and `MultiEdit`.

Capability:

- Blocks code edits when `.claude/sdlc/plans/` has no plan artifact.
- Allows edits to `.claude/sdlc/` artifacts themselves, so plans and gates can be created.
- Warns when no plan has been modified in the last 24 hours.

The plan artifact acts as a contract for downstream enforcement. It must define:

- Classification: `new-build`, `fix`, or `change-request`.
- Reference: REQ, issue, or CR.
- Problem statement.
- Scope alignment.
- In-scope files.
- In-scope functions.
- Explicit out-of-scope list.
- Approach.
- Tests to add or update.
- Technology stack and compatibility matrix.
- Risks and rollback.

This is the plugin's core behavioral guardrail. Without a plan, Claude Code should not touch application files.

### 3. Scope ingest and scope gate

The updated repository adds a `scope-ingest` subagent and a scope-gate template. This turns project scope from a one-paragraph prompt into a reviewable artifact flow.

Implemented capabilities:

- `agents/scope-ingest.md` defines a bounded subagent that writes only under `.claude/sdlc/scope-drafts/`.
- Accepted v1 sources are markdown files, plain-text files, raw pasted text, and existing `scope.md` in re-validation mode.
- The agent normalizes source material into fields such as project name, domain, in-scope items, out-of-scope items, success criteria, constraints, stakeholders, and assumptions.
- Each extracted claim includes provenance metadata pointing back to source file, section, and line span when available.
- Extraction confidence is recorded per field.
- Existing `scope.md` can be revalidated through a drift report rather than rewritten.
- `templates/scope-gate.md` captures a first-task project scope sign-off using synthetic `REQ-SCOPE-<project-slug>`.
- `plan-gate.sh` now warns when `.claude/sdlc/scope.md` is missing or when no `scope-*.md` gate exists.

Important limitations:

- The scope gate warnings are warn-level, not hard blockers.
- The subagent does not write `.claude/sdlc/scope.md`; the human promotes and signs the scope.
- PDF, DOCX, PPTX, auth-walled URLs, and Jira/Linear ticket references are deferred.

### 4. Domain expert and domain knowledge

The updated repository adds both the `domains/` directory and an implemented `domain-expert` skill for making plans smarter in regulated or high-risk product areas.

Implemented artifacts:

- `domains/_schema.md` defines the required schema for domain files.
- `domains/_index.json` defines semantic domain descriptions and optional force/exclude overrides.
- `domains/auth.md` defines authentication and authorization context.
- `domains/payments.md` defines payments context.
- `skills/domain-expert/SKILL.md` injects domain context into plan artifacts.
- `skills/domain-expert/AUTHORING.md` defines source-driven and guided Q&A domain authoring flows.

Domain file frontmatter includes:

- `slug`
- `last_reviewed`
- `owner`
- optional `suggested_roles`

Required sections:

- `## Scope must address`
- `## Questions plan must answer`

Optional sections:

- Glossary.
- Typical NFRs.
- Regulatory concerns.
- Common pitfalls.
- Stack notes.
- Security hotspots.

The auth seed surfaces questions around authentication mechanism, authorization model, token storage, session invalidation, MFA, service-to-service auth, and privilege escalation. The payments seed surfaces questions around processor choice, PCI scope, idempotency, webhook authentication, SCA/3D Secure, processor key storage, and reconciliation.

The `domain-expert` skill runs during `/plan` after scope validation and before the plan is written. It uses a two-source lookup:

- Project-level `domains/` first.
- Plugin-level `domains/` second.

It resolves at most one primary domain per plan. Explicit `domain:` frontmatter in `scope.md` is authoritative. Otherwise, it uses semantic judgment over registry entries. High-confidence matches inject silently; medium and low confidence require human confirmation.

Output is a `## Domain context` section in the plan, including:

- Matched domain and confidence.
- Domain file path.
- Advisory suggested roles.
- Scope gaps.
- Unanswered plan questions.
- Required-question warnings.
- NFR reminders.
- Security hotspots.

Important limitations:

- Required domain questions are warnings only, never hard blockers.
- `suggested_roles` are advisory only and must not populate gate-file required sign-offs.
- Domain file content is not merged across project and plugin sources; one source wins.

### 5. Work-item traceability

Traceability is enforced through plan contents, gate files, templates, requirements, test cases, defects, and deployment records.

The `work-item-validation.sh` hook runs before `Edit`, `Write`, and `MultiEdit`.

Capabilities:

- Requires the active plan to contain a classification.
- For change requests, requires a referenced `CR-<n>` and a signed artifact at `.claude/sdlc/sign-offs/CR-<n>.md`.
- Supports degraded operation through local tickets and REQ references when no issue tracker exists.

Traceability model:

| Artifact | Traceability role |
|---|---|
| Plan | Defines task classification, scope, and work-item reference |
| Requirements | Creates stable `REQ-<n>` IDs |
| Tech specs | Map implementation contracts to REQs |
| Test cases | Map validation to REQs |
| Build gate | Records files, functions, tests, and work-item reference |
| Test report | Maps pass/fail, coverage, and defects to REQs/test cases |
| Defects | Reference at least one REQ and one test case |
| Deployment record | Records commit, environment, approver, smoke tests, and linked REQs/issues |
| Docs traceability matrix | Makes gaps visible across REQ, spec, tests, code, test run, and deploy |

### 6. Surgical edit discipline

The plugin is designed to prevent AI-generated scope creep.

Surgical edit capabilities:

- Restricts edits to plan-listed files.
- Restricts changes to plan-listed functions.
- Rejects ambient cleanup, speculative refactors, unrelated renames, and adjacent-function edits as process violations.
- Routes unrelated discoveries into `.claude/sdlc/followups/<task-slug>.md`.
- Defines a scope-extension protocol requiring human approval before expanding the plan.

Hook support:

| Hook | Enforcement strength | Behavior |
|---|---|---|
| `diff-scope-check.sh` | Warning | Compares changed files to the plan's in-scope file list |
| `adjacent-function-detector.sh` | Warning | Uses git function-context hunks to flag modified functions outside the in-scope list |
| `format-on-write.sh` | Action/warning | Runs the configured formatter on changed files |
| `modified-code-test-gate.sh` | Warning | Warns when source files changed but no test files changed |

Important limitation: file and function scope checks are warnings, not blockers. The repo explicitly keeps these advisory because git hunk headers can produce false positives, and plans may legitimately need expansion.

### 7. Requirements analysis

The Analyze phase turns a plan into structured requirements.

Capabilities:

- Creates requirements under `.claude/sdlc/requirements/<task-slug>.md`.
- Uses stable `REQ-<n>` IDs that should never be renumbered after publication.
- Captures descriptions, acceptance criteria, priority, source, and dependencies.
- Maps each requirement back to a section of `.claude/sdlc/scope.md`.
- Surfaces unmapped requirements as scope questions.
- Detects frontend involvement and requires a UX artifact before proceeding.

Frontend-specific behavior:

- If the task touches UI and no UX artifact exists under `.claude/sdlc/architecture/ux/`, Analyze halts.
- Acceptable UX artifacts include Figma links, PDFs, screenshots, wireframes, or plain-text descriptions.
- Backend-only tasks skip the UX track.

### 8. Architecture and design production

The Design phase creates the artifacts Build needs to implement safely.

Capabilities:

- Produces or updates application architecture.
- Produces or updates data architecture.
- Produces or updates platform architecture.
- Produces or updates infrastructure architecture.
- Produces or updates security architecture.
- Produces or updates test architecture.
- Produces technical specs under `.claude/sdlc/tech-specs/`.
- Produces test cases under `.claude/sdlc/test-cases/`.
- Produces DevOps pipeline design.
- Maintains an architecture manifest.

The Design phase validates before rewriting. If architecture files already exist, the plugin is instructed to compare them against current requirements, surface deltas, and update only affected files after human approval.

Architecture conformance is handled through a chain:

```text
Requirements -> Architecture -> Tech Spec -> Code -> Tests -> Deploy
```

There is no automated architecture hook. Build performs a judgment-based conformance pass against the tech spec, and the human gate records the outcome.

### 9. Implementation support

The Build phase is the phase that writes production code.

Capabilities:

- Validates the work item before code changes.
- Coordinates `surgical-edit`, `minimal-code`, and `security-review`.
- Implements the smallest diff that satisfies the approved plan.
- Validates code shape against tech specs and architecture.
- Validates frontend changes against UX artifacts.
- Adds or updates tests only for functions modified in the current diff.
- Includes deployment script, pipeline, environment, secret-management, or infrastructure deltas when the code change requires them.

Minimal-code guidance:

- Prefer editing over creating.
- Prefer a function over a class when stateful abstraction is unnecessary.
- Avoid speculative interfaces, wrappers, service layers, factories, and config extraction.
- Avoid deleting load-bearing code or tests just to reduce line count.

### 10. Test design, execution, and defect routing

Test capability spans Design, Build, and Test.

Design phase:

- Creates test cases for each requirement.
- Ensures each test case references at least one REQ ID.
- Uses test types such as unit, integration, e2e, NFR, security, and UX.

Build phase:

- Adds executable tests only for modified functions.
- Places test scripts under `.claude/sdlc/test-scripts/` in a mirrored source-tree structure.
- Requires test references back to design-phase test cases and REQs.

Test phase:

- Runs the configured test runner from `config/tools.json`.
- Captures pass/fail per test case.
- Reports coverage against the configured threshold, defaulting to 80%.
- Logs duration and observed flakiness.
- Creates a test execution report at `.claude/sdlc/test/<task-slug>-report.md`.
- Logs defects to Git Issues when available, otherwise local markdown or JSON under `.claude/sdlc/defects/`.
- Runs UX conformance checks for frontend changes.

Coverage enforcement is phase-level rather than purely hook-level. If modified-code coverage is below threshold, the phase fails unless a human-signed waiver is recorded.

### 11. Security review

Security review runs on the current diff, not the whole repository.

Capabilities:

- Input validation review.
- Authentication and authorization review.
- Secret handling review.
- Injection-surface review for SQL, shell, templates, and prompts.
- Dependency review.
- Sensitive-data handling review.
- Output encoding and header review.
- Error-handling review.
- Cryptography review.
- Infrastructure and pipeline security review.

Outputs:

- Findings file at `.claude/sdlc/test/security-review-<task-slug>.md`.
- Findings include severity, category, location, issue, impact, and remediation.

Enforcement:

- Critical or high findings block the Build gate until resolved or explicitly waived by a human.
- `secret-scan.sh` is a hard hook-level blocker only when a secret scanner is configured and reports findings.

### 12. API integration governance

The `api-integration` skill covers external and internal API boundaries.

Capabilities:

- Detects HTTP clients, SDK calls, gRPC stubs, webhooks, OpenAPI files, GraphQL schemas, protobufs, and similar integration surfaces.
- Checks for an API spec such as OpenAPI, Swagger, GraphQL, Protobuf, AsyncAPI, JSON Schema, Avro, or typed SDK.
- Probes configured endpoints using project-configured tooling.
- Warns when specs are missing or endpoints are unreachable.
- Offers explicit mock strategies such as MSW, Prism, WireMock, local fakes, or typed fixtures.

Important limitation:

- It does not silently create mocks.
- It does not block by default.
- It waits for human choice when the real endpoint or spec is unavailable.

### 13. Deployment governance

The Deploy phase is proposal-first and human-approved.

Capabilities:

- Requires a signed Test gate before deployment.
- Produces a deployment proposal containing environment, commit or artifact, changed services, migrations, feature flags, rollback plan, blast radius, and deployment window.
- Requires explicit human approval before execution.
- Executes through the configured pipeline or runbook under human supervision.
- Halts on the first deployment error instead of retrying automatically.
- Records deployment details in tickets when configured.
- Falls back to `.claude/sdlc/deployments/<YYYY-MM-DD>-<task-slug>.md` or JSON.
- Runs post-deploy smoke tests.
- Rolls back and logs a defect if post-deploy verification fails.

Non-capability:

- The plugin never auto-deploys.
- It does not trigger CI pipelines by itself as part of environment detection.

### 14. Support and observability

The Support phase creates operational artifacts after deployment.

Capabilities:

- Identifies new code paths, endpoints, jobs, external calls, and failure modes.
- Defines logs, metrics, alerts, dashboards, and runbook entries.
- Writes artifacts under `.claude/sdlc/monitoring/<task-slug>/`.
- Produces platform-neutral markdown/JSON when no observability system is configured.
- Proposes Grafana or Datadog changes via MCP when configured.
- Proposes CloudWatch changes as infrastructure-as-code rather than direct API mutation.
- Recommends synthetic-failure validation in non-production environments.

Non-capability:

- It does not silently mutate production monitoring.
- It does not auto-apply alert or dashboard changes.
- It does not modify application logging code during Support; logging code changes are proposed for a later Build flow.

### 15. Documentation and traceability maintenance

The Docs phase keeps the generated SDLC artifact tree usable.

Capabilities:

- Refreshes `.claude/sdlc/docs/index.md`.
- Refreshes `.claude/sdlc/docs/traceability.md`.
- Refreshes `.claude/sdlc/architecture/manifest.json`.
- Updates the consuming repo's `CHANGELOG.md`.
- Updates user-facing docs affected by the change.
- Leaves traceability gaps visible rather than filling them with invented data.

Traceability matrix columns include:

- REQ ID.
- Tech spec.
- Test case.
- Code files/functions.
- Test run.
- Deployment.

### 16. Fast path for small fixes

The `/fix-fast` command provides a compressed path for small bug fixes.

Eligibility:

- Classification is `fix`.
- Estimated scope is at most 2 files and 50 LOC.
- No schema changes.
- No API changes.
- No security-surface changes.
- No frontend or UX changes.

Capabilities:

- Collapses Plan, Analyze, and Design into one mini-gate.
- Records why the full early phases were skipped.
- Then resumes normal Build, Test, Deploy, Support, and Docs phases.

Non-capability:

- It is not a general shortcut.
- It is not intended for new builds, change requests, frontend changes, security-sensitive work, or medium-sized refactors.

### 17. Token usage tracking and review

Token tracking is optional and disabled by default.

When `config/tools.json` sets `token_tracking.enabled` to `true`, `token-tracker.sh` runs as a Stop hook.

Capabilities:

- Parses Claude Code session transcripts.
- Aggregates raw token counts into phase buckets.
- Writes `.claude/sdlc/token-log.json` for the latest run.
- Appends `.claude/sdlc/token-history.jsonl` for rolling history.
- Records input, output, cache creation, and cache read tokens.
- Supports `/token-review`, which reports last-run usage, cross-run trends, and optimization candidates.

Non-capability:

- It does not calculate pricing or dollar cost.
- It does not make optimization edits directly.
- It should not draw trend conclusions from a single run.

## Integration capabilities

The plugin is local-first. It can run with no external SaaS integrations and write local artifacts instead.

### Environment detection

`env-detect.sh` runs on `SessionStart` and writes `.claude/sdlc/env.json`.

Detected categories:

- Git repository presence.
- GitHub, GitLab, or Bitbucket issue tracker by remote URL.
- GitHub Actions, GitLab CI, CircleCI, or Jenkins by filesystem sniffing.
- Observability and UX tooling default to `null` unless configured.

### Configurable tools

Users copy `config/tools.example.json` to `config/tools.json` and fill in project-specific commands.

Configurable tool slots:

- Formatter.
- Linter.
- Test runner.
- Coverage command and threshold.
- Secret scanner.
- Dependency scanner.
- SAST scanner.
- Adjacent-function detection method.
- Integrations.
- Artifact fallback format.
- Token tracking.

The plugin is stack-agnostic by design. Tool commands are configured rather than hardcoded.

### External systems matrix

| Category | Supported systems | Transport or approach |
|---|---|---|
| VCS | Git | Local `git` CLI |
| VCS host | GitHub, GitLab, Bitbucket | Detected from Git remote; host CLI or native APIs when available |
| Issue tracking | GitHub/GitLab/Bitbucket Issues | Same host transport as VCS |
| Issue tracking | Jira, Linear | User-provided MCP server |
| CI | GitHub Actions, GitLab CI, CircleCI, Jenkins | Filesystem detection only |
| Observability | Grafana, Datadog | User-provided MCP server |
| Observability | CloudWatch | Infrastructure-as-code proposals |
| UX | Figma | User-provided MCP server |
| API contracts | OpenAPI, GraphQL, gRPC, AsyncAPI, JSON Schema, typed SDKs | Spec check plus direct HTTP probe via configured tool |

### Graceful degradation

When integrations are missing:

- VCS absent: artifacts still write locally.
- Issue tracker absent: tickets and defects write to `.claude/sdlc/tickets/` and `.claude/sdlc/defects/`.
- CI absent: no execution impact; links are omitted.
- Observability absent: platform-neutral monitoring artifacts are written.
- UX tool absent: frontend work still requires a local UX artifact, which can be plain text.
- MCP absent: each MCP-routed system falls back to local markdown or human-provided references.

## Hook capability reference

| Hook | Event | Blocking? | Capability |
|---|---|---:|---|
| `env-detect.sh` | SessionStart | No | Detects local environment and writes `.claude/sdlc/env.json` |
| `plan-gate.sh` | PreToolUse Edit/Write/MultiEdit | Yes when no plan exists | Enforces plan-before-code |
| `work-item-validation.sh` | PreToolUse Edit/Write/MultiEdit | Yes for missing classification or unsigned CR | Enforces work-item/CR traceability |
| `bash-safety.sh` | PreToolUse Bash | Yes for destructive shell patterns | Blocks obvious destructive commands and pipe-to-shell patterns; warns on force push |
| `diff-scope-check.sh` | PostToolUse Edit/Write/MultiEdit | No | Warns on changed files outside plan scope |
| `adjacent-function-detector.sh` | PostToolUse Edit/Write/MultiEdit | No | Warns on modified functions outside plan scope |
| `format-on-write.sh` | PostToolUse Edit/Write/MultiEdit | No | Runs configured formatter on changed files |
| `secret-scan.sh` | PostToolUse Edit/Write/MultiEdit | Yes when scanner finds secrets | Blocks confirmed secret findings |
| `modified-code-test-gate.sh` | Stop | No | Warns when source changed without test changes |
| `phase-gate.sh` | Stop | No | Reminds when no recent gate file was updated |
| `token-tracker.sh` | Stop | No | Writes optional raw token usage logs |

## Subagent capabilities

The repository defines bounded subagents. They are proposal engines, not autonomous approvers.

| Agent | Phase | Read scope | Write scope | Capability |
|---|---|---|---|---|
| `architect` | Design | Repository code and SDLC artifacts | `.claude/sdlc/architecture/` only | Validates architecture against requirements and proposes updates |
| `test-designer` | Design | Requirements, architecture, existing test cases | `.claude/sdlc/test-cases/` only | Generates REQ-traceable test cases |
| `security-reviewer` | Build/Review | Diff, code, config, infra, manifests | Security findings file only | Reviews current diff for security risks |
| `observability` | Support | Code, architecture, deployment records | `.claude/sdlc/monitoring/<task-slug>/` only | Produces monitoring, alerting, dashboards, and runbook artifacts |

Subagents cannot advance phases, sign gates, deploy, or approve their own work.

## Artifact capabilities

The plugin standardizes SDLC evidence under `.claude/sdlc/`.

Key artifact folders:

```text
.claude/sdlc/
├── env.json
├── scope.md
├── plans/
├── requirements/
├── architecture/
├── tech-specs/
├── test-cases/
├── test-scripts/
├── tickets/
├── change-requests/
├── sign-offs/
├── gates/
├── defects/
├── deployments/
├── monitoring/
├── followups/
└── docs/
```

Templates included:

- Change request.
- Defect.
- Deployment record.
- Phase gate.
- Plan.
- Requirements.
- Sign-off.
- Technical spec.
- Test case.
- Ticket.

Repository-level capability artifacts added in the latest update:

- `domains/_schema.md`
- `domains/_index.json`
- `domains/auth.md`
- `domains/payments.md`
- `skills/domain-expert/SKILL.md`
- `skills/domain-expert/AUTHORING.md`
- `agents/scope-ingest.md`
- `templates/scope-gate.md`
- `docs/GLOSSARY.md`

The plugin-level domain files live at repository/plugin level, not under `.claude/sdlc/`. The implemented `domain-expert` skill uses two-source lookup where project-level `domains/` files in the consuming repo override plugin-level domain seeds.

## Review capabilities

The repository documents four review tracks.

### Code review

Checks:

- Formatting.
- In-scope files.
- Adjacent-function changes.
- Work-item traceability.
- Secrets.
- Naming, complexity, correctness, edge cases, and error handling.
- Spec conformance.
- Security.

### Architecture conformance

Handled through:

- Architecture artifacts.
- Tech specs.
- Build-phase conformance pass.
- Human gate.

There is no automated architecture policy hook.

### Test-case review

Checks:

- Every REQ has at least one test case.
- Every test case cites a REQ.
- Test cases include type, priority, preconditions, steps, expected outcomes, and data needs.

### Test-script review

Checks:

- Tests are added only for modified functions.
- Test scripts trace to test cases and REQs.
- Test execution report captures pass/fail, coverage, defects, UX conformance, and waivers.

## RFC-backed roadmap capabilities

The updated repo includes two major RFCs. Parts of the scope-ingest RFC are now implemented; guided-entry is still mostly design direction.

### Scope ingest and domain expert

`docs/rfcs/scope-ingest.md` proposed a scope-ingest and domain-expert design. The current repo now implements the core v1 pieces:

- A `scope-ingest` agent that turns source material into provenance-traced scope drafts.
- Accepted v1 inputs: markdown, plain text, raw pasted text, or existing `scope.md`.
- A normalized scope schema with project name, domain, in-scope items, out-of-scope items, success criteria, constraints, stakeholders, and assumptions.
- Draft output under `.claude/sdlc/scope-drafts/`.
- Human review and sign-off before writing or accepting `scope.md`.
- A pseudo-phase scope gate for v1.
- A `domain-expert` skill that uses plugin-level and project-level `domains/` files to inject `## Domain context` into plan artifacts.
- Inline domain file authoring on domain miss, through source-driven ingest or guided Q&A.

Implementation status in the current repo:

- Implemented: domain schema and seed files, `domain-expert`, domain authoring flow, `scope-ingest`, scope gate template, plan-skill wiring, and plan-gate warnings.
- Deferred: PDF, DOCX, PPTX, auth-walled URL, and ticket-reference ingestion.

### Guided entry, session resume, and approval UX

`docs/rfcs/guided-entry-session-resume-multi-role.md` is accepted as of 2026-04-25. It defines UX improvements layered on top of the accepted multi-team approval model.

Planned capabilities:

- `/status` for read-only active-task and sign-off state.
- `/start` as guided intake over the existing `plan` skill.
- SessionStart plan-check hook for in-flight work and pending sign-offs.
- Plan versioning and supersede behavior.
- Approval packet artifact for reviewer-friendly evidence.
- `/configure` for guided config setup and scoped config repair.
- Glossary, `/help`, shared message library.
- Automatic next-step hints.

Implementation status in the current repo:

- The RFC is present and accepted, but the listed commands, skills, hooks, and templates are not yet present in the file tree.
- PR 5 and PR 7 concepts from earlier drafts were dropped because they conflicted with or duplicated the accepted multi-team approval model.

## Intended adoption profile

Best fit:

- Regulated industries.
- Enterprise teams with mandatory audit trails.
- Teams experiencing AI-generated PR churn or runaway scope.
- Teams that need auditable human approval around AI-assisted changes.
- Junior-heavy teams that benefit from enforced workflow scaffolding.
- Teams wanting raw token usage visibility by SDLC phase.

Poor fit:

- Spikes and throwaway prototypes.
- Solo or early-stage work optimized for speed.
- Research workflows where iteration speed is the primary value.
- Teams without clear requirements.
- Medium-sized tasks that exceed `/fix-fast` but do not justify the full 8-phase flow.

## Explicit non-capabilities and limitations

This repository does not provide:

- A standalone runtime outside Claude Code.
- A complete policy engine.
- A full containment sandbox.
- Compliance certification or attestation.
- Automated human replacement for phase gates.
- Auto-approval.
- Auto-deployment.
- Built-in MCP servers.
- Built-in issue tracker, observability, or UX SaaS integrations.
- Implemented `/status`, `/start`, `/configure`, or `/help` commands yet.
- Implemented approval packet or plan-versioning templates yet.
- PDF, DOCX, PPTX, auth-walled URL, or Jira/Linear ticket ingestion in `scope-ingest` yet.
- Automated architecture enforcement hooks.
- Guaranteed prevention of all out-of-scope edits.
- Guaranteed function-boundary detection across all languages.
- Automated load/performance test generation beyond designed test architecture.
- Rich framework scaffolding for Playwright, Cypress, or k6.
- Cost calculation from token usage.

The repository is explicit that the human-in-the-lead rule is load-bearing. Experiments with automated judges or auto-gates are described as belonging outside the core plugin.

## Capability maturity assessment

| Area | Maturity | Notes |
|---|---|---|
| Workflow orchestration | Strong | Clear phase model, command files, templates, and gates |
| Plan-before-code | Strong | Hard PreToolUse blocker |
| Human approval | Strong | Gate files are central and explicit |
| Scope discipline | Medium | Strong instructions, warning hooks, but not hard blockers |
| Work-item traceability | Medium-strong | CR enforcement is hard; REQ/ticket evidence also depends on artifact quality and human gates |
| Domain knowledge | Medium | Schema, auth/payments seeds, two-source lookup, domain context injection, and authoring flow exist |
| Scope ingestion | Early-medium | Agent, scope draft format, scope gate template, and plan wiring exist; rich source formats are deferred |
| Guided entry UX | Designed, not implemented | Accepted RFC defines `/start`, `/status`, `/configure`, `/help`, and session hints; files are not yet present |
| Requirements management | Medium | Clear templates and REQ conventions; no automated semantic validation |
| Architecture governance | Medium | Good artifact model; conformance is judgment-based |
| Test governance | Medium | Strong traceability model; hook enforcement is partial |
| Security review | Medium | Detailed checklist and secret-scan blocker when configured; deeper checks depend on configured tools and reviewer quality |
| Deployment governance | Medium-strong | Human-approved proposal model; execution depends on configured runbook/pipeline |
| Observability | Medium | Good artifact generation; production mutation is deliberately human-reviewed |
| External integration | Medium | Local-first with MCP/CLI hooks; external systems are referenced, not bundled |
| Token visibility | Medium | Raw token logging and trend review exist when enabled |

## Review questions for adopters

Before adopting, reviewers should answer:

1. Do we want full 8-phase gates for the class of work where this plugin will be used?
2. Who is authorized to sign each phase gate?
3. What counts as a valid work-item reference in our environment?
4. Will warnings for out-of-scope edits be enough, or do we need stricter local policy?
5. Which tools should populate `config/tools.json` for formatter, linter, tests, coverage, secrets, dependencies, and SAST?
6. Where should local SDLC artifacts live in relation to source control?
7. Are `.claude/sdlc/` artifacts committed, archived, or excluded?
8. Which integrations, if any, should be wired through MCP?
9. What is the waiver process for failed coverage, security findings, or traceability gaps?
10. Is `/fix-fast` acceptable for our small-fix risk profile?
11. Should project-specific `domains/` files be maintained, and who owns their `last_reviewed` dates?
12. Is v1 `scope-ingest` enough for our source material, or do we need PDF/DOCX/PPTX/ticket ingestion before rollout?
13. Do we want to adopt the upcoming guided-entry features when they land, or keep `/plan` as the main front door?

## Bottom line

Claude SDLC is best understood as an opinionated AI coding governance layer. Its value is not faster coding by itself; its value is bounded AI behavior, smaller and more reviewable diffs, explicit human gates, audit-ready artifacts, local-first fallback behavior, and visibility into process and token usage. The latest update materially strengthens scope and domain-aware planning: the repo now has a scope-ingest agent, domain-expert skill, scope gate template, and plan-gate warnings. It remains intentionally conservative. That conservatism is the feature.
