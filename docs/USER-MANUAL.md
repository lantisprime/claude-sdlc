# SDLC Plugin — User Manual

A walkthrough of how to use the plugin in practice: what you need before you start, what the plugin asks you for at each step, and how it behaves across real scenarios.

For the concise overview, read [README.md](../README.md). For the authoritative phase definitions, read [docs/SDLC.md](SDLC.md). This document sits between them — long enough to show you exactly what a session looks like, short enough to keep near you while you work.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [First-time setup (one-off)](#2-first-time-setup-one-off)
3. [Per-task prerequisites](#3-per-task-prerequisites)
4. [The four input routes (how to feed the plugin)](#4-the-four-input-routes)
5. [Sign-off: the irrevocable step](#5-sign-off-the-irrevocable-step)
6. [Scenarios](#6-scenarios)
    - [6.1 Greenfield feature (full 8 phases)](#61-scenario-a--greenfield-feature-full-8-phases)
    - [6.2 Small bug fix (`/fix-fast`)](#62-scenario-b--small-bug-fix-fix-fast)
    - [6.3 Frontend feature (UX artifact required)](#63-scenario-c--frontend-feature-ux-artifact-required)
    - [6.4 Degraded mode (no Git, no tracker)](#64-scenario-d--degraded-mode-no-git-no-tracker)
    - [6.5 Mid-build scope change (CR flow)](#65-scenario-e--mid-build-scope-change-cr-flow)
    - [6.6 External API integration (mock fallback)](#66-scenario-f--external-api-integration-mock-fallback)
    - [6.7 Pre-written plan / RFC intake](#67-scenario-g--pre-written-plan--rfc-intake)
7. [Hook behavior reference](#7-hook-behavior-reference)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

**These must exist before the plugin can be useful. Without them, either the plugin refuses to advance a phase or it degrades to local-only artifacts.**

### Hard prerequisites (plugin will not work without these)

| Requirement | Why | How to check |
|---|---|---|
| Claude Code installed | The plugin is a Claude Code plugin — it has no standalone runtime | `claude --version` |
| POSIX shell + `bash` | All 10 hooks are bash scripts | `bash --version` |
| The plugin loaded in your repo | Via `/plugin` — see [README install section](../README.md#install) | `/plugin list` inside Claude Code |
| A one-paragraph scope statement at `.claude/sdlc/scope.md` | Phase 1 (`/plan`) validates against it; created interactively on first use if missing | `cat .claude/sdlc/scope.md` |
| `config/tools.json` exists (copy of `tools.example.json`) | Every skill and hook reads tool commands from here; missing file means no formatter/linter/tests run | `ls config/tools.json` |

### Soft prerequisites (plugin degrades, but surfaces the gap)

| Requirement | What happens without it |
|---|---|
| Git repository | `env.json` records `vcs: null`; traceability falls back to REQ IDs + local CR files |
| Issue tracker (GitHub Issues, Jira, Linear) | Local markdown tickets under `.claude/sdlc/tickets/`; gate accepts `no ticket REQ-<n>` as degraded signature |
| CI config (GitHub Actions, GitLab CI, CircleCI, Jenkins) | Zero impact — plugin never triggers pipelines, just links them in artifacts when detected |
| Observability platform (Grafana, Datadog, CloudWatch) | Phase 7 produces platform-neutral markdown under `.claude/sdlc/monitoring/` |
| UX tool (Figma) **for frontend tasks only** | **Phase 2 halts** until `.claude/sdlc/architecture/ux/<task-slug>.md` exists (any form: Figma link, PDF, screenshot, written description) |
| MCP servers for Jira/Linear/Grafana/Datadog/Figma | Degrades to the next tier — local markdown, provided links, or asking you directly |

### Tool commands you should fill into `config/tools.json`

None are mandatory — leave `null` to skip — but the plugin is more valuable with them filled in. Typical stacks:

```jsonc
// Python
"formatter":      { "command": "ruff format" }
"linter":         { "command": "ruff check" }
"test_runner":    { "command": "pytest" }
"coverage":       { "command": "pytest --cov", "threshold_percent": 80 }
"secret_scanner": { "command": "gitleaks detect --no-git" }

// TypeScript/JavaScript
"formatter":      { "command": "prettier --write" }
"linter":         { "command": "eslint" }
"test_runner":    { "command": "vitest run" }
"coverage":       { "command": "vitest run --coverage", "threshold_percent": 80 }

// Go
"formatter":      { "command": "gofmt -w" }
"linter":         { "command": "golangci-lint run" }
"test_runner":    { "command": "go test ./..." }
```

---

## 2. First-time setup (one-off)

Run these once per repo that will use the plugin.

### Step 1 — Install the plugin

From inside Claude Code in your project repo:

```
/plugin install <path-or-URL>
```

See Claude Code's plugin docs for the current flow.

### Step 2 — Copy the tools config

```bash
cp config/tools.example.json config/tools.json
# edit config/tools.json — fill in commands for your stack
```

### Step 3 — Let `env-detect.sh` run

It fires on `SessionStart` automatically. The first session after install writes `.claude/sdlc/env.json`:

```json
{
  "vcs": "git",
  "vcs_host": "github",
  "issue_tracker": "github",
  "ci": "github-actions",
  "observability": null,
  "ux_tool": null
}
```

Review this file. Anything `null` that you *do* have wired up — add it to the `integrations` block in `config/tools.json` to override.

### Step 4 — Write a scope statement

The first `/plan` invocation will prompt you for this if missing. You can also write it directly:

```bash
mkdir -p .claude/sdlc
cat > .claude/sdlc/scope.md <<'EOF'
# Project scope

We build and operate the public-facing billing API for ACME Corp.
In scope: REST endpoints, Stripe integration, invoicing, tax calc.
Out of scope: mobile clients, internal admin UI, CRM sync.
EOF
```

This is the document every plan is validated against.

---

## 3. Per-task prerequisites

Before you start a *task*, the plugin assumes:

| Prereq | Required when | User provides |
|---|---|---|
| **A rough task description** | Always | 1–2 sentences — the `/plan` prompt |
| **A work item reference** (REQ ID, ticket URL, or signed CR path) | Build phase and beyond | Pasted at gate sign-off; degraded mode accepts `no ticket REQ-<n>` |
| **A UX artifact** | Frontend work only, Phase 2 onward | File at `.claude/sdlc/architecture/ux/<task-slug>.md` — a Figma link, screenshot, or written description |
| **API spec + reachable endpoint** *(or acknowledgment to use a mock)* | Only if the task integrates with an external API | Spec file path + base URL. If unreachable, the `api-integration` skill asks you to choose a mock runner (MSW / Prism / WireMock) |

**Your commitment per task:** review the artifact at each of the 8 gates. The plugin will ask for a fresh sign-off every time. Rubber-stamping defeats the point.

---

## 4. The four input routes

All routes produce the same artifact shape under `.claude/sdlc/`. Pick whichever fits the task.

### Route 1 — Slash-command prompt (fastest)

```
/plan "Add rate-limit headers to the public API"
```

Plugin drafts `.claude/sdlc/plans/rate-limit-headers.md`. You open, edit in place, sign the gate.

### Route 2 — Conversation first, then artifact

You chat the problem through:

> "We need rate-limit headers. Probably on the gateway layer. Worried about cache poisoning."

Claude asks clarifying questions, drafts the plan, shows it back. You redirect ("exclude the admin API") until it's right, then Claude writes the file.

### Route 3 — Pre-written artifact

Drop your own plan into place before running the command:

```
.claude/sdlc/plans/rate-limit-headers.md
```

Use the shape in [templates/plan.md](../templates/plan.md). The skill validates required fields and asks about gaps. Good for teams with existing RFC / design-doc culture.

### Route 4 — External source reference

```
/plan "use the RFC at docs/rfcs/rate-limits.md as design input"
/analyze "pull requirements from JIRA PROJ-123"
```

Plugin reads the source, produces an artifact in its own template shape, and preserves the traceability link.

---

## 5. Sign-off: the irrevocable step

Every phase ends at a gate file at `.claude/sdlc/gates/<phase>-<task-slug>.md`. **Claude drafts; only you sign.** There are two modes:

### Chat sign-off (default)

Used for `/plan`, `/analyze`, `/design`, `/build`, `/test`, `/support`.

Claude prompts:

```
Phase artifact: .claude/sdlc/plans/rate-limit-headers.md — please review.
Paste the URL of the REQ / ticket / CR you're approving against,
or type `no ticket REQ-<n>, …` for degraded mode.
```

You paste something like:

```
https://linear.app/acme/issue/PROJ-1234
```

**Rejected signatures:** bare `yes`, `ok`, `lgtm`, `approved`. The URL (or REQ-ID list) is the non-trivial acknowledgment that makes the record auditable.

Claude writes the gate file with your exact text quoted and an ISO-8601 timestamp.

### Manual sign-off (required for `/deploy` and `/fix-fast`)

You open the gate file yourself and edit it. Claude will not capture the signature via chat. Deploy has blast radius; fix-fast bundles three phases into one mini-gate — both warrant the extra friction.

---

## 6. Scenarios

Each scenario shows: the initial user input → what the plugin does → what it asks for → final state.

### 6.1 Scenario A — Greenfield feature (full 8 phases)

**Task:** add rate-limit headers to the public API.

**Prerequisites checked:** `.claude/sdlc/scope.md` exists; `config/tools.json` has test runner + linter.

---

**Phase 1 — Plan**

**You:**
```
/plan "Add X-RateLimit-* response headers to the public API gateway"
```

**Plugin:**
- `plan` skill drafts `.claude/sdlc/plans/rate-limit-headers.md`:
  - Classification: `feature`
  - In-scope files: `gateway/middleware/ratelimit.go`, `gateway/middleware/ratelimit_test.go`
  - In-scope functions: `RateLimitHeaders`, `addRateLimitHeaders`
  - Out-of-scope: admin API gateway, internal RPC layer
  - Estimate: 120 LOC, 2 files
  - Tech stack: Go 1.22, existing gateway middleware pattern
- Returns the plan and asks you to review + sign.

**You (sign-off):**
```
https://linear.app/acme/issue/API-4421
```

**Plugin writes:** `.claude/sdlc/gates/plan-rate-limit-headers.md` with your URL + timestamp.

---

**Phase 2 — Analyze**

**You:** `/analyze`

**Plugin:**
- `analyze` skill drafts `.claude/sdlc/requirements/rate-limit-headers.md`:
  - `REQ-1`: gateway emits `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
  - `REQ-2`: headers match RFC 6585 semantics
  - `REQ-3`: absent when throttling is disabled for a route
  - Each REQ has acceptance criteria, priority, source.
- Maps each REQ to `scope.md` sections.

**You:** sign gate with ticket URL.

---

**Phase 3 — Design**

**You:** `/design`

**Plugin:**
- `design` skill + `architect` subagent validate existing architecture bundle at `.claude/sdlc/architecture/`. No changes needed here — surfaces "no architecture drift."
- Writes `.claude/sdlc/tech-specs/ratelimit-middleware.md`: API signatures, error modes, NFRs.
- `test-designer` subagent writes `.claude/sdlc/test-cases/TC-1.md`…`TC-5.md`, each traced to a REQ ID.

**You:** sign gate.

---

**Phase 4 — Build**

**You:** `/build`

**Plugin:**
- `plan-gate.sh` checks plan exists → pass
- `work-item-validation.sh` checks REQ / ticket → pass
- `build` skill writes code to `gateway/middleware/ratelimit.go` (surgical: only in-scope functions)
- `format-on-write.sh` runs `gofmt -w`
- `secret-scan.sh` scans the diff → pass
- Writes unit tests at `gateway/middleware/ratelimit_test.go` — **only for the modified functions**
- `diff-scope-check.sh` sees any out-of-scope file → warns (doesn't block)
- `adjacent-function-detector.sh` scans hunk headers → warns if you accidentally edited a neighbor
- `modified-code-test-gate.sh` fires on `Stop` — warns if any modified function lacks a test

**You:** review the diff. Sign the gate by pasting the PR URL once the diff is committed.

---

**Phase 5 — Test**

**You:** `/test`

**Plugin:**
- Runs `go test ./...` (from `config/tools.json`)
- Runs coverage, compares to threshold (default 80% on modified code)
- Writes `.claude/sdlc/test/rate-limit-headers-report.md` with pass/fail and coverage
- Any failures → defects opened as GitHub Issues (since `env.json` says `issue_tracker: github`), labeled `defect`, `severity:*`, `phase:test`

**You:** sign gate.

---

**Phase 6 — Deploy**

**You:** `/deploy`

**Plugin:**
- `deploy` skill writes `.claude/sdlc/deployments/2026-04-18-rate-limit-headers.md`:
  - Environment: staging → prod
  - Migrations: none
  - Feature flag: `api.ratelimit_headers_enabled` (default off)
  - Rollback: revert the flag; no data impact
  - Blast radius: public API surface
- **Manual sign-off.** You open the gate file and add your signature, then run the deploy command yourself.

**Plugin never auto-deploys.**

---

**Phase 7 — Support**

**You:** `/support`

**Plugin:**
- `observability` subagent writes to `.claude/sdlc/monitoring/rate-limit-headers/`:
  - `alerts.md` — thresholds for 429 spike, header-missing rate
  - `dashboard.json` — Grafana panel JSON (if `observability: grafana` in config)
  - `runbook.md` — what to check when an alert fires
- Proposes — never auto-applies to production.

**You:** sign gate.

---

**Phase 8 — Docs**

**You:** `/docs`

**Plugin:**
- Updates `.claude/sdlc/docs/index.md` and `traceability.md`
- Appends entry to top-level `CHANGELOG.md`
- Leaves any traceability gaps visible (e.g. REQ-3 with no test reference)

**No dedicated gate** — cross-cutting.

---

**Final artifact tree for this task:**

```
.claude/sdlc/
├── plans/rate-limit-headers.md
├── requirements/rate-limit-headers.md
├── tech-specs/ratelimit-middleware.md
├── test-cases/TC-1.md … TC-5.md
├── gates/
│   ├── plan-rate-limit-headers.md
│   ├── analyze-rate-limit-headers.md
│   ├── design-rate-limit-headers.md
│   ├── build-rate-limit-headers.md
│   ├── test-rate-limit-headers.md
│   ├── deploy-rate-limit-headers.md
│   └── support-rate-limit-headers.md
├── test/rate-limit-headers-report.md
├── deployments/2026-04-18-rate-limit-headers.md
└── monitoring/rate-limit-headers/
```

---

### 6.2 Scenario B — Small bug fix (`/fix-fast`)

**Task:** fix an off-by-one in pagination.

**Eligibility check (all required):**
- [x] Classification = `fix`
- [x] ≤ 2 files touched
- [x] ≤ 50 LOC
- [x] No schema / API / security / UX changes

If any box is unchecked, run the full phases instead. The plugin does **not** widen eligibility.

---

**You:**
```
/fix-fast "off-by-one in /users pagination — last page returns empty"
```

**Plugin:**
- Drafts a single mini-plan covering Plan + Analyze + Design:
  - Root cause: `offset = (page-1) * limit` should be `page * limit` in the cursor code
  - In-scope: `api/users/list.go:42-58` (`paginate` function)
  - Test to add: boundary case — last full page
- Writes `.claude/sdlc/plans/pagination-off-by-one.md` with classification = `fix-fast`.

**You:** **manual sign-off** — you edit the mini-gate file at `.claude/sdlc/gates/plan-pagination-off-by-one.md` yourself. Chat sign-off is rejected here.

**Then Phases 4–8 run normally** — Build, Test, Deploy, Support, Docs are **not** compressed.

---

### 6.3 Scenario C — Frontend feature (UX artifact required)

**Task:** add a saved-searches dropdown to the header.

**The sharp edge:** Phase 2 (`/analyze`) halts until a UX artifact exists. This is the only hard block on a missing external input.

---

**You:** `/plan "add a saved-searches dropdown to the header"`

**Plugin:** drafts plan, classifies as `frontend-feature`, signs normally.

**You:** `/analyze`

**Plugin:**
```
HALT — frontend task detected, but no UX artifact found at
.claude/sdlc/architecture/ux/saved-searches-dropdown.md.

Provide any of:
 - A Figma link (paste URL in the file)
 - PDF mockups or screenshots (reference paths in the file)
 - Hand-drawn wireframes (attach + reference)
 - A plain written description of the UX

Create the file, then re-run /analyze.
```

**You:** create the file. A written description is enough:

```markdown
# UX: saved-searches dropdown

- Button in the header next to the search box, icon + label "Saved"
- Click opens a dropdown with recent 10 saved searches
- Each item: title, icon, last-used timestamp
- Empty state: "No saved searches yet"
- Keyboard: ↑/↓ to navigate, Enter to apply, Esc to close
- Match existing header button style (see button.tsx)
```

**You re-run:** `/analyze` → proceeds, requirements drafted, sign gate.

**Phase 5 (`/test`):** runs UX conformance checks — compares rendered UI against your description / mockups, stores screenshots under `.claude/sdlc/test/ux/`.

---

### 6.4 Scenario D — Degraded mode (no Git, no tracker)

**Situation:** you dropped the plugin into a non-git directory (a prototype, a scratchpad) and there's no issue tracker.

---

**On SessionStart:** `env-detect.sh` writes:

```json
{ "vcs": null, "issue_tracker": null, "ci": null }
```

**You:** `/plan "add a CLI flag for verbose output"`

**Plugin runs normally.** Writes plan to `.claude/sdlc/plans/verbose-flag.md`.

**Phase 2 sign-off prompt:**

```
Paste the URL of the REQ / ticket / CR, or type `no ticket REQ-<n>` for degraded mode.
```

**You:**
```
no ticket REQ-1
```

**Plugin writes gate** with this exact string plus an ISO-8601 timestamp. This is the degraded signature — auditable, still non-trivial, but doesn't require an external system.

**All other phases run.** Defects land as `.claude/sdlc/defects/verbose-flag/DEF-1.md` instead of GitHub Issues. Deployment lands as `.claude/sdlc/deployments/<date>-verbose-flag.md` instead of a ticket comment.

---

### 6.5 Scenario E — Mid-build scope change (CR flow)

**Situation:** you're in Phase 4 (Build) for the rate-limit headers task. You realize the admin API also needs headers — but the admin API was explicitly **out-of-scope** in the plan.

---

**What NOT to do:** just edit the admin file. `diff-scope-check.sh` will warn, `work-item-validation.sh` may block, and you'll lose traceability.

**What to do:** stop the Build, raise a change request.

**You:** draft a CR at `.claude/sdlc/change-requests/CR-3.md` (shape from [templates/change-request.md](../templates/change-request.md)):

```markdown
# CR-3: extend rate-limit headers to admin API

Original scope: public API gateway only
Proposed addition: admin API gateway (same middleware pattern)
Rationale: internal tools hit rate limits without visibility
Risk: moderate — admin ops may see 429s sooner
```

**You sign the CR** at `.claude/sdlc/sign-offs/CR-3.md` — ISO-8601 timestamp + reviewer name.

**Update the plan** to add the admin gateway files to `In-scope files`.

**Resume Build.** `work-item-validation.sh` sees the signed CR and permits the Edit. Without the sign-off, it blocks.

---

### 6.6 Scenario F — External API integration (mock fallback)

**Task:** integrate with the payments provider's refund endpoint.

---

**You:** `/plan "integrate with Stripe refunds API"`

**Plugin** asks: "Spec location? Base URL?"

**You:**
```
Spec: https://stripe.com/docs/api/refunds
Base URL: https://api.stripe.com/v1
```

**`api-integration` skill probes the endpoint:**

- **If reachable:** proceeds normally — validates the spec against live responses.
- **If unreachable** (offline, no credentials, region-blocked): the skill **does not silently stub**. It offers a mock:

```
Stripe API unreachable. Offering a mock to unblock development:

 1. MSW (TypeScript/JS service worker)
 2. Prism (OpenAPI mock server)
 3. WireMock (language-agnostic HTTP mock)
 4. Typed fixture (in-process stub, no server)

Pick a number, or paste a different mock command.
```

**You:** `2`

**Plugin** scaffolds a Prism mock at `mocks/stripe/` with a run script, and notes in the plan: "Integration uses mocked endpoints until live spec verified."

---

### 6.7 Scenario G — Pre-written plan / RFC intake

**Situation:** your team already writes RFCs in Notion. You have one for the rate-limit work.

---

**You:** export the RFC to `docs/rfcs/rate-limits.md`.

**You:** `/plan "use the RFC at docs/rfcs/rate-limits.md as the plan input"`

**Plugin:**
- Reads the RFC.
- Produces `.claude/sdlc/plans/rate-limit-headers.md` in the plugin's template shape, with a `Source:` line pointing back to the RFC.
- If required fields are missing (e.g. no explicit `In-scope files` list), asks you to fill the gaps — doesn't invent them.

**You:** fill gaps, sign gate.

Same pattern works for `/analyze "pull requirements from JIRA PROJ-123"` — the plugin will read the ticket (via MCP if configured) and transform it into the requirements template.

---

## 7. Hook behavior reference

You'll interact with hooks implicitly — they fire on Claude's tool calls, not yours. This table explains what to expect when something "just stops":

| Hook | Fires on | Severity | Typical user experience |
|---|---|---|---|
| `plan-gate.sh` | PreToolUse Edit/Write | **Block** | "I can't edit files yet — there's no plan for this task. Run `/plan` first." |
| `work-item-validation.sh` | PreToolUse Edit/Write | **Block** | "Edit blocked: no REQ ID, ticket, or signed CR references this file." |
| `phase-gate.sh` | PreToolUse (commands) | **Block** | "Can't run `/build` — the design gate isn't signed yet." |
| `secret-scan.sh` | PostToolUse | **Block** | "Secret scanner found a confirmed secret in this diff — refusing the write." |
| `diff-scope-check.sh` | PostToolUse | Warn | "Warning: you touched `admin/api.go` but it's not in the plan's in-scope list." |
| `adjacent-function-detector.sh` | PostToolUse | Warn | "Warning: function `formatAdminError` is adjacent to the in-scope `formatUserError` — verify this was intentional." |
| `modified-code-test-gate.sh` | Stop | Warn | "Warning: `paginate()` was modified but no test was added/updated." |
| `bash-safety.sh` | PreToolUse Bash | Warn | "Warning: command contains `rm -rf` — confirm intent." |
| `format-on-write.sh` | PostToolUse | — | Silent — runs your formatter on changed files. |
| `env-detect.sh` | SessionStart | — | Silent — writes `.claude/sdlc/env.json`. |
| `token-tracker.sh` | Stop | — | Silent — only if `token_tracking.enabled: true`. |

**Warnings are warnings** — they surface the signal and let you decide. They don't escalate to blocks on their own.

---

## 8. Troubleshooting

### "`plan-gate.sh` keeps blocking my edits"

That's the rule working. Run `/plan` first. If you already have a plan, check:
- Is the plan file under `.claude/sdlc/plans/`?
- Does the filename match the task slug the skill inferred?
- Is the plan gate at `.claude/sdlc/gates/plan-<slug>.md` signed?

### "`adjacent-function-detector.sh` has false positives"

In `config/tools.json`, switch:
```json
"adjacent_function_detection": {
  "method": "tree-sitter",
  "tree_sitter_language": "go"
}
```
Tree-sitter gives higher accuracy than git hunk headers but requires the language grammar installed.

### "A frontend task stalled and I can't tell why"

Check `.claude/sdlc/architecture/ux/<task-slug>.md`. Missing → Phase 2 halts. Any form of UX artifact (even a plain-text description) unsticks it.

### "Gate sign-off rejects my `yes` / `lgtm`"

Intentional. The signature must be non-trivial — a URL, a REQ ID, or `no ticket REQ-<n>` for degraded mode. Bare acknowledgments are blocked so gates aren't rubber-stamped.

### "My scope keeps drifting"

If `diff-scope-check.sh` fires often, your plans are too narrow. Expand the `In-scope files` list in the plan *before* the Build phase, or raise a CR if you're already mid-Build. See [Scenario E](#65-scenario-e--mid-build-scope-change-cr-flow).

### "I want to see token usage per phase"

Set `token_tracking.enabled: true` in `config/tools.json`. After each Stop, check `.claude/sdlc/token-log.json` (last run) and `.claude/sdlc/token-history.jsonl` (rolling log). Run `/token-review` for an analysis.

---

## Where to go next

- **Full phase reference:** [docs/SDLC.md](SDLC.md)
- **Review processes (code, test cases, test scripts):** [docs/review-processes.md](review-processes.md)
- **Design-intent notes (and anti-patterns):** [CLAUDE.md](../CLAUDE.md)
- **Artifact templates:** [templates/](../templates/)
- **All skills and hooks:** [README — capabilities reference](../README.md#capabilities-reference)
