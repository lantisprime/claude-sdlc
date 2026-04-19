# Using claude-sdlc in Enterprise Engineering Teams

## TL;DR

- claude-sdlc is an opinionated gate-keeper for Claude Code: plan before edit, surgical scope, signed gates, local-first artifacts.
- It fits enterprise environments because it produces a traceable paper trail and never advances without a human signature — not because it is a stepping stone to removing humans.
- The human-in-the-lead rule is load-bearing. Experiments with automated gates belong in a separate project, not in the core plugin.
- Concrete wins: plan-bounded edits reduce PR churn, token tracking surfaces expensive loops, gate files serve as audit evidence, and graceful degradation means zero new infrastructure is required to pilot it.

## 1. What the plugin actually does

claude-sdlc wraps Claude Code in an 8-phase workflow — Plan, Analyze, Design, Build, Test, Deploy, Support, Docs — with a small set of blocking hooks and a larger set of warning hooks around it.

The blocking hooks are the ones that matter for trust:

- `plan-gate.sh` refuses Edit/Write calls when no plan exists for the current task.
- `work-item-validation.sh` requires a REQ ID, ticket URL, or signed change request.
- `secret-scan.sh` blocks writes containing confirmed secrets.
- `bash-safety.sh` refuses destructive shell patterns — `rm -rf /`, `rm -rf ~`, `rm -rf .`, fork bombs, and `curl … | sh` — and warns on `git push --force`.

Phase-prerequisite enforcement sits in the commands themselves: `/build`, `/test`, and the rest declare the required prior gate file at the top of each command definition. The separately-named `phase-gate.sh` is an advisory Stop hook, not a blocker — it emits a reminder on session end if no gate file has been updated in the last two hours. It does not refuse any tool call.

The remaining hooks — `diff-scope-check.sh`, `adjacent-function-detector.sh`, `modified-code-test-gate.sh` — are warnings. They surface signals to the human without halting work. This distinction is deliberate and documented in the repo: scope detection uses git hunk headers, which are imperfect, and silent blocking would stop legitimate edits. Anyone evaluating the plugin for InfoSec review should read these as "audit trail plus guidance," not as hard containment.

Every phase writes markdown artifacts under `.claude/sdlc/`. Gate files record the signer's pasted work-item URL and an ISO-8601 timestamp. A bare "yes," "ok," or "lgtm" is rejected. The URL is the non-trivial acknowledgment that makes the signature auditable.

## 2. How roles change when a team adopts it

Adoption shifts where engineers spend their time. The shifts below are what the plugin enables; whether a team realizes them depends on how they use it.

**Product managers.** Vague requirements surface earlier. The Analyze phase produces requirements with stable REQ IDs from whatever input is provided, which means ambiguity that used to appear during code review now appears before any code is written. PMs who already write clear PRDs gain a faster path — `/plan "use the RFC at docs/..."` ingests their document directly. PMs who don't get told, earlier, that they need to.

**Tech leads and architects.** Review shifts onto the tech spec rather than the diff. The `architect` agent produces a drift report in Phase 3 when existing architecture has fallen out of sync with the new requirements. Code review in Phase 4 is narrower because the Build skill is scoped to plan-listed files — reviewers are checking conformance to an approved spec rather than discovering scope on the fly.

**Junior engineers.** The plugin behaves like a patient senior who insists on a plan before touching code. Adjacent-function warnings catch the "while I'm here" reflex early. The discipline is real, and so is the friction; teams onboarding juniors should expect some initial frustration before the workflow clicks.

**QA engineers.** Every test case traces to a REQ ID via the `test-designer` agent, and `modified-code-test-gate.sh` flags modified code without corresponding tests. That handles baseline unit coverage, which frees QA to focus on integration, adversarial, and end-to-end testing. Load and performance test authorship is still manual.

**SREs.** Phase 7 writes observability artifacts — alerts, dashboards, runbooks — as platform-neutral markdown and JSON under `.claude/sdlc/monitoring/`, with optional MCP routing to whatever platform a team uses. SREs review and apply; the plugin does not deploy on its own.

## 3. Where the cost savings come from

Four mechanisms, each tied to a specific repo feature.

**Bounded token usage.** With `token_tracking.enabled: true` in `config/tools.json`, the Stop hook writes per-phase token counts to `token-log.json` and `token-history.jsonl`. The `/token-review` command surfaces phases with anomalous usage, which is typically the signature of a runaway fix-this-test loop. Teams can set internal budgets per phase and catch expensive patterns before they show up on an invoice.

**Earlier catch of scope drift.** The Build skill is scoped to plan-listed files, and `diff-scope-check.sh` warns on out-of-scope edits. Catching drift at write-time rather than at PR-review-time avoids the most expensive category of rework: a nominally-approved change that turns out to touch three unrelated modules.

**No new infrastructure to adopt.** The plugin runs with no external dependencies. `env-detect.sh` probes for Git, CI, issue trackers, and MCP servers on session start, and whatever is absent degrades to local markdown. Teams can pilot claude-sdlc in a single repo without waiting on InfoSec approval for new services.

**Audit evidence collection.** `.claude/sdlc/gates/` accumulates an append-only record of human approvals, each stamped with a work-item URL and a timestamp. This is audit *evidence*, not audit *attestation* — the plugin does not make a SOC2 or ISO 27001 claim on its own — but it removes the "reconstruct the paper trail from Slack and commit messages" step that often dominates audit prep.

## 4. Roadmap

The items below are not implemented in the core repo. They are prioritized based on what current users have asked for.

**Token and cost dashboards.** A `generate-token-report.sh` utility that compiles `token-history.jsonl` into a static HTML summary under `.claude/sdlc/analytics/`. The goal is per-task cost visibility for engineering managers without adding a hosted analytics dependency.

**CI/CD step summary export.** A utility that runs on the final Phase 8 hook, reads the contents of `.claude/sdlc/gates/`, and writes a markdown summary suitable for `$GITHUB_STEP_SUMMARY` or GitLab MR widgets. This moves the audit trail out of the IDE and into the PR UI where reviewers already work.

**Schema-first enforcement.** An optional `schema-validation.sh` hook that, for projects with an OpenAPI or Protobuf definition, blocks Phase 4 edits that drift from the contract established in Phase 3. Opt-in per project; off by default.

**A separate repo for automated-judge experiments.** Some users have asked about replacing human gate sign-off with an LLM judge. This does not belong in claude-sdlc. The core plugin's "human in the lead, always" rule is load-bearing, and weakening it would change what the tool is. Teams wanting to experiment with automated gates can do so in a sibling repo that inherits the artifact contracts but replaces the signer. Any such repo will need its own audit architecture — an immutable judge-decision log, a secondary auditor process, and a rollback path when the auditor detects drift. That is a large enough problem to deserve its own project, not a feature flag on this one.

## What this article is not

It is not a case for replacing engineers with agents. It is not a compliance attestation. It is not a claim that the warning hooks provide containment. If a future version of this document starts making those claims, it has drifted from what the repo does and should be corrected.
