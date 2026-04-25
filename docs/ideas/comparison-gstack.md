# Claude SDLC vs. gstack

Reviewed locally:

- `lantisprime/claude-sdlc` at commit `918b201`
- `garrytan/gstack` at commit `62091639`

## Short answer

`claude-sdlc` and `gstack` both structure AI-assisted software work, but they optimize for different worlds.

`claude-sdlc` is an enterprise SDLC control layer. It emphasizes plan-before-code, human sign-off, phase gates, traceable artifacts, scope discipline, local audit evidence, graceful degradation when external systems are absent, and now explicitly reducing cognitive load for human reviewers.

`gstack` is a high-throughput AI engineering workflow and tool suite. It emphasizes specialist skills, founder/product review, design exploration, browser-driven QA, release automation, persistent memory, cross-agent/browser coordination, safety modes, and multi-host portability.

In plain terms: `claude-sdlc` asks "can this AI change be governed, audited, and made easier for a human to approve safely?" `gstack` asks "how can one builder operate like a whole product engineering team?"

## What changed in this rerun

`claude-sdlc` changed since the prior comparison. The latest commit adds:

- A new core principle: reduce cognitive load.
- A new plugin-level `domains/` directory.
- A domain-file schema.
- Domain registry rules for semantic domain detection.
- Seed domain files for `auth` and `payments`.
- Implemented `domain-expert` skill for plan-time domain context.
- Implemented `scope-ingest` subagent for provenance-traced scope drafts.
- Implemented `scope-gate` template and plan-skill wiring.
- Updated `plan-gate.sh` to warn on missing scope and missing scope gate.
- RFCs for guided entry, session resume, plan versioning, approval packets, `/status`, `/start`, `/configure`, `/help`, and next-step hints.

The important implementation caveat has shifted: `domain-expert` and `scope-ingest` are now present, but v1 scope ingest only supports markdown, plain text, pasted text, and existing `scope.md` revalidation. PDF, DOCX, PPTX, auth-walled URLs, ticket references, `/status`, `/start`, `/configure`, `/help`, approval packets, and plan versioning remain future work.

## Positioning

| Dimension | `claude-sdlc` | `gstack` |
|---|---|---|
| Primary identity | Claude Code SDLC plugin | AI engineering workflow stack and skill pack |
| Main goal | Governance, traceability, phase control, lower review load | Shipping velocity, specialist workflows, browser QA |
| Operating metaphor | Controlled enterprise delivery process | Virtual software team / software factory |
| Best fit | Regulated teams, enterprise audit trails, controlled AI coding | Founders, technical leads, solo builders, fast-moving product teams |
| Core workflow | Plan -> Analyze -> Design -> Build -> Test -> Deploy -> Support -> Docs | Think -> Plan -> Build -> Review -> Test -> Ship -> Reflect |
| Default posture | Conservative, human-gated, reviewer-signal oriented | Expansive, high-throughput, role-specialized |
| Primary artifact location | `.claude/sdlc/` in the consuming repo | `~/.gstack/`, generated skills, browser state, project-local config |
| Enforcement model | Claude Code hooks plus signed gate files | Skills, generated prompts, browser daemon, optional hooks and safety modes |

## Architecture comparison

### claude-sdlc

`claude-sdlc` is mostly markdown, shell hooks, templates, and bounded subagent definitions:

- Commands: `/plan`, `/analyze`, `/design`, `/build`, `/test`, `/deploy`, `/support`, `/docs`, `/review`, `/fix-fast`, `/token-review`
- Skills: phase skills plus cross-cutting skills such as `surgical-edit`, `minimal-code`, `security-review`, `api-integration`, `gate-signoff`
- Hooks: `plan-gate`, `work-item-validation`, `diff-scope-check`, `adjacent-function-detector`, `format-on-write`, `secret-scan`, `modified-code-test-gate`, `phase-gate`, `token-tracker`, `env-detect`, `bash-safety`
- Agents: `architect`, `test-designer`, `security-reviewer`, `observability`
- Templates: plan, requirements, tech spec, test case, ticket, defect, CR, sign-off, gate, deployment
- Scope/domain additions: `agents/scope-ingest.md`, `skills/domain-expert/SKILL.md`, `skills/domain-expert/AUTHORING.md`, `templates/scope-gate.md`
- Domain knowledge assets: `domains/_schema.md`, `domains/_index.json`, `domains/auth.md`, `domains/payments.md`
- RFC design direction: guided entry, session resume, approval UX

It is intentionally simple and local-first. It does not ship a large runtime. Most enforcement comes from hook scripts and artifact conventions.

### gstack

`gstack` is a larger software system:

- Dozens of generated `SKILL.md` files from `.tmpl` sources
- A TypeScript/Bun build pipeline
- A compiled persistent browser CLI and daemon
- A Chrome extension and GStack Browser app wrapper
- Host adapters for Claude, Codex, Cursor, Factory, Kiro, OpenCode, Slate, Hermes, GBrain, and OpenClaw
- Model overlays
- Local analytics and optional telemetry
- Learnings/memory support
- Cross-model review and benchmark tooling
- Browser prompt-injection defenses
- E2E and LLM-eval test harnesses

It is much more operationally ambitious. `gstack` is not just a prompt pack; it has substantial browser automation, install/update, host-generation, test, security, memory, and telemetry infrastructure.

## Workflow comparison

### Planning

`claude-sdlc` planning is a hard prerequisite. `plan-gate.sh` blocks application edits until a plan artifact exists. The plan defines classification, scope, in-scope files, in-scope functions, tests, risk, rollback, and stack compatibility.

The updated repo now adds real scope and domain machinery to planning:

- `scope-ingest` can turn markdown, text, pasted text, or an existing `scope.md` into a normalized, provenance-traced scope draft.
- The plan skill now resolves scope before writing the plan.
- First-task planning can create a `scope-<project>.md` gate using `templates/scope-gate.md`.
- `plan-gate.sh` warns when scope or a scope gate is missing.
- `domain-expert` can inject `## Domain context` into the plan using project-level or plugin-level domain files.

This is now stronger than a static checklist. It creates an artifact path from source material -> scope draft -> signed scope -> domain context -> plan.

`gstack` has richer ideation and review modes:

- `/office-hours` reframes the product problem.
- `/plan-ceo-review` challenges scope and product value.
- `/plan-eng-review` reviews architecture, data flow, edge cases, and tests.
- `/plan-design-review` reviews UX and design quality.
- `/plan-devex-review` reviews developer experience.
- `/autoplan` runs the review pipeline automatically.

`gstack` planning is still deeper on product taste and execution quality today. `claude-sdlc` planning is now stronger as a governance contract and has become meaningfully more mature on scope/domain drift detection.

### Guided entry and cognitive load

This remains a major product-direction area for `claude-sdlc`, though less of it is implemented than the new scope/domain work.

`claude-sdlc` now explicitly treats human attention as the scarce resource. The accepted guided-entry RFC proposes:

- `/status` for current task and sign-off state.
- `/start` as guided intake over `/plan`.
- SessionStart reminders for in-flight work and pending sign-offs.
- Approval packets that compile review evidence.
- `/configure` for scoped config setup.
- `/help` and glossary surfaces.
- Automatic next-step hints.

These are not implemented yet, but they clarify the product direction: `claude-sdlc` wants fewer open-ended prompts and less reviewer assembly work.

`gstack` already has a richer front door for ambiguous work:

- `/office-hours`
- `/autoplan`
- `/plan-ceo-review`
- `/plan-eng-review`
- `/plan-design-review`
- `/plan-devex-review`

So today, `gstack` still wins on guided ideation and planning ergonomics. `claude-sdlc` is catching up specifically around governance UX, not product creativity.

### Drift detection

After the latest `claude-sdlc` update, drift detection is a clearer differentiator.

`claude-sdlc` now has a stronger governance-drift model:

- Scope drift: `scope-ingest` can revalidate an existing `scope.md` and write a drift report.
- Domain drift: `domain-expert` checks whether plans address domain-specific scope requirements and plan questions.
- Plan drift: plan-listed files/functions and out-of-scope sections are checked by warning hooks.
- Architecture drift: the `architect` subagent validates existing architecture against current requirements during Design.
- Requirements/test drift: REQ IDs, test cases, defects, and traceability docs form the formal chain.

`gstack` is still stronger on operational drift:

- Browser-visible behavior drift through `/qa`, `/browse`, and screenshots.
- Performance drift through `/benchmark`.
- Production/runtime drift through `/canary`.
- Documentation drift through `/document-release`.
- Design quality drift through `/design-review`.

So for scope, requirements, and architecture drift, `claude-sdlc` is now more mature. For product/runtime drift, `gstack` remains stronger.

### Build control

`claude-sdlc` strongly emphasizes surgical implementation:

- Edit only plan-listed files.
- Modify only plan-listed functions.
- Do not touch adjacent functions.
- Do not perform ambient cleanup.
- Log unrelated discoveries as follow-ups.
- Expand scope only with human approval.

`gstack` has scope controls, but they are more opt-in and tactical:

- `/freeze` blocks edits outside a chosen directory.
- `/guard` combines freeze and destructive-command safety.
- `/careful` warns before destructive shell commands.
- Review skills flag drive-by edits and completeness gaps.

`claude-sdlc` has stronger default scope governance. `gstack` has practical safety tools, but its overall culture is more "move fast with specialist review."

### Review

`claude-sdlc` review is tied to phase gates:

- Build validates code against tech specs and architecture.
- `/review` and `security-review` inspect the current diff.
- Critical/high findings block the Build gate until fixed or waived.
- Artifacts capture waivers and evidence.

`gstack` review is broader and more operational:

- `/review` acts like a staff engineer review.
- `/cso` performs OWASP Top 10 plus STRIDE security review.
- `/codex` invokes OpenAI Codex as an independent second opinion.
- Design, DX, QA, benchmark, and canary reviews cover more practical shipping surfaces.

`claude-sdlc` review is better for auditability. `gstack` review is better for catching product, UI, browser, release, and real-world usage issues.

### Testing and QA

`claude-sdlc` builds a traceability chain:

```text
REQ -> Tech Spec -> Test Case -> Test Script -> Test Report -> Defect -> Deploy
```

It requires test cases tied to REQ IDs and warns when source changes do not include test changes. Phase 5 records coverage, defects, and UX conformance.

`gstack` is much stronger for live/browser QA:

- `/browse` gives agents a persistent Chromium browser.
- `/qa` runs browser-based QA, finds bugs, fixes them, and generates regression tests.
- `/qa-only` reports without changing code.
- `/benchmark` measures page performance and web vitals.
- `/canary` watches post-deploy behavior.
- `/setup-browser-cookies` imports authenticated sessions.

`claude-sdlc` is stronger at requirements-level test traceability. `gstack` is stronger at practical end-to-end product testing, especially web applications.

### Deployment

`claude-sdlc` treats deployment as a high-risk phase:

- Requires signed Test gate.
- Produces a deployment proposal.
- Requires human approval.
- Executes under supervision.
- Records deployment evidence.
- Runs smoke tests.
- Rolls back and logs defects on failure.

`gstack` has more automation:

- `/ship` syncs base branch, runs tests, audits coverage, updates release artifacts, commits, pushes, and opens PRs.
- `/land-and-deploy` can merge, wait for CI/deploy, and verify production health.
- `/setup-deploy` detects and stores deploy configuration.

`claude-sdlc` is safer for controlled release governance. `gstack` is more complete as an automated release engineer.

## Capability comparison matrix

| Capability | `claude-sdlc` | `gstack` | Advantage |
|---|---|---|---|
| Human phase gates | First-class, required | Present in some workflows, less central | `claude-sdlc` |
| Plan-before-code blocking | Hard hook | Planning skills, not universal hard gate | `claude-sdlc` |
| Work-item traceability | Strong REQ/ticket/CR model | More workflow/review oriented | `claude-sdlc` |
| Requirements management | Stable REQ IDs and coverage table | Product and plan review, less formal REQ model | `claude-sdlc` |
| Domain-aware planning | Implemented `domain-expert`, auth/payments seeds, project-over-plugin lookup, plan injection | Specialist review can reason about domains but no comparable domain-file schema | `claude-sdlc` |
| Scope ingestion | Implemented v1 `scope-ingest`, provenance-traced drafts, scope gate template | No comparable governed scope-ingest flow | `claude-sdlc` |
| Scope/requirements/architecture drift | Scope revalidation, domain gaps, REQ/test traceability, architect delta reports | Review skills can catch issues, but no formal traceability spine | `claude-sdlc` |
| Runtime/product/docs drift | Limited to Test/Support artifacts and UX conformance | Browser QA, benchmark, canary, document-release | `gstack` |
| Guided intake | `/start`, `/status`, `/configure`, `/help` accepted in RFC but not shipped | Rich shipped skill front doors: `/office-hours`, `/autoplan`, plan reviews | `gstack` today |
| Cognitive-load reduction | Explicit core principle; approval packet/status roadmap | Strong UX in many skills but not audit-first | Tie, different target |
| Scope discipline | Plan-listed files/functions, warnings, follow-ups | `/freeze`, review checks, guardrails | `claude-sdlc` |
| Architecture artifacts | Formal architecture bundle and tech specs | Eng review, design docs, architecture checks | Tie, different style |
| Security review | Diff-based checklist plus scanner hooks | `/cso`, prompt-injection defenses, review specialists | `gstack` for breadth, `claude-sdlc` for gate evidence |
| Browser QA | Minimal / UX conformance references | Persistent browser daemon, QA, cookies, screenshots | `gstack` |
| Design workflow | Requires UX artifacts for frontend work | Design consultation, shotgun variants, HTML generation | `gstack` |
| Release automation | Proposal and evidence oriented | `/ship`, `/land-and-deploy`, deploy setup | `gstack` |
| Observability | Support artifacts and runbooks | Canary, benchmark, browser monitoring | Tie, different style |
| Multi-agent support | Bounded subagents | Cross-agent browser pairing, multi-host skill generation | `gstack` |
| Multi-host portability | Claude Code plugin | Claude, Codex, Cursor, Factory, Kiro, OpenCode, Slate, Hermes, OpenClaw, GBrain | `gstack` |
| Persistent memory | Token logs and artifacts | Learnings, taste profile, GBrain integration, sync | `gstack` |
| Audit evidence | Strong local artifact tree | Some logs/analytics/docs, not audit-first | `claude-sdlc` |
| Setup complexity | Low | Higher: Bun, build, browser binary, host setup | `claude-sdlc` |
| Runtime complexity | Low | High | `claude-sdlc` |

## Risk comparison

### claude-sdlc risks

- Can feel heavy for small or exploratory work.
- Warning hooks do not fully prevent scope drift.
- Architecture conformance is judgment-based, not mechanically enforced.
- Test traceability depends on well-maintained artifacts.
- External SaaS integrations are referenced but not bundled.
- It does not provide strong browser automation or live product QA.
- Scope ingest v1 supports only markdown, plain text, pasted text, and existing `scope.md`; enterprise source formats remain deferred.
- Domain-required questions are warn-level, not hard blockers, so domain governance still relies on human review.
- Guided-entry capabilities are still roadmap, so onboarding can remain heavier than gstack's shipped front doors.

### gstack risks

- Larger attack and failure surface because it includes a browser daemon, extension, telemetry paths, host adapters, update logic, and optional tunnels.
- Faster shipping workflows can conflict with strict enterprise change-control policies.
- More global/user-level state under `~/.gstack` and skill install paths.
- More dependency complexity: Bun, Playwright/Chromium, compiled binaries, host-specific install behavior.
- Some safety is opt-in (`/careful`, `/freeze`, `/guard`) rather than default for every task.
- More powerful automation means more care is needed around credentials, authenticated browser sessions, deployment, and remote pairing.

## Where each wins

Choose `claude-sdlc` when:

- Audit trail matters.
- Human approval must be explicit.
- Requirements traceability matters.
- You need to control AI scope creep.
- You want local markdown evidence.
- You are in a regulated or enterprise delivery environment.
- You want a small, understandable plugin surface.
- You want domain-specific planning questions and scope drift checks to become part of the governance layer, especially around auth and payments.

Choose `gstack` when:

- Shipping velocity matters most.
- You want rich specialist roles.
- You build web products and need browser QA.
- You want design, DX, QA, security, release, and canary workflows.
- You want cross-agent or multi-host support.
- You value persistent learnings and taste/memory.
- You are comfortable with a larger runtime and more automation.

## Can they be combined?

Yes, but the combination needs clear precedence.

The most sensible hybrid is:

- Use `claude-sdlc` as the governance backbone: phase gates, plans, requirements, CRs, approvals, and traceability.
- Use selected `gstack` capabilities inside approved phases:
  - `/office-hours` before or during Plan for product shaping.
  - Use `claude-sdlc` `scope-ingest` and `domain-expert` during Plan for governed scope/domain context.
  - `/plan-eng-review` during Design for architecture review.
  - `/plan-design-review` or `/design-consultation` before frontend Design sign-off.
  - `/review` or `/cso` during Build review.
  - `/browse`, `/qa-only`, `/benchmark`, and `/canary` during Test/Support.
  - Avoid `/ship` and `/land-and-deploy` unless they are wrapped by `claude-sdlc` Deploy gates.

Do not let both systems own release authority. If `claude-sdlc` is used for governance, `gstack` should produce evidence and findings, not bypass phase gates.

## Bottom line

`claude-sdlc` is a control system. `gstack` is an acceleration system.

They are not direct substitutes. They answer adjacent but different questions:

- `claude-sdlc`: "How do we keep AI coding auditable, scoped, and human-approved?"
- `gstack`: "How do we make an AI coding agent behave like a full product engineering team?"

After the latest `claude-sdlc` update, the strategic gap narrowed materially on governance intelligence. `scope-ingest` and `domain-expert` are now implemented v1 capabilities, not just RFC intent. `gstack` still ships a much broader set of working specialist flows, especially around browser QA, design, release, memory, and runtime verification.

For enterprise adoption, `claude-sdlc` is still the cleaner starting point. For founder-led product velocity, `gstack` is still far more capable. For a mature team that wants both speed and governance, the best path is a hybrid: `claude-sdlc` gates and artifacts around selected `gstack` specialist workflows, with `gstack` providing execution muscle and `claude-sdlc` preserving approval discipline.
