# Review Processes

How the SDLC plugin reviews the three artifacts that most directly determine whether a change is safe to ship: **production code**, **test cases**, and **test scripts**.

All three share a common shape:

- Reviews are scoped to the current `git diff` — never the whole repo.
- Humans sign every gate; subagents *propose*, never approve.
- Every artifact traces to a REQ ID (or a ticket / signed CR for fixes and scope changes).
- Blocking is reserved for severe, verifiable issues. Everything else warns.

See [SDLC.md](SDLC.md) for the authoritative phase reference.

---

## 1. Code review

### When it runs

| Trigger | Mechanism |
|---|---|
| After every `Edit` / `Write` | [`format-on-write.sh`](../hooks/format-on-write.sh) applies the configured formatter |
| Phase 4 Build — Step 3 conformance pass | [`skills/build/SKILL.md`](../skills/build/SKILL.md) |
| On demand | [`/review`](../commands/review.md) — quality + security pass over the diff |
| Build gate | [`security-review`](../skills/security-review/SKILL.md) skill runs automatically |

### What gets checked

| Concern | Enforced by |
|---|---|
| Formatting | [`format-on-write.sh`](../hooks/format-on-write.sh) using the formatter from `config/tools.json` |
| In-scope files only | [`diff-scope-check.sh`](../hooks/diff-scope-check.sh) (warn) |
| No adjacent-function edits | [`adjacent-function-detector.sh`](../hooks/adjacent-function-detector.sh) (warn) |
| Work-item traceability | [`work-item-validation.sh`](../hooks/work-item-validation.sh) — REQ ID / ticket / signed CR (block) |
| No secrets | [`secret-scan.sh`](../hooks/secret-scan.sh) (block on confirmed secrets) |
| Naming, complexity, correctness, edge cases, error handling | [`/review`](../commands/review.md) quality pass — judgment-based over the diff |
| Spec conformance (API signatures, error modes, side effects, NFRs) | Build Step 3 vs. [`templates/tech-spec.md`](../templates/tech-spec.md) |
| Security (10 categories: input validation, authN/Z, secrets, injection, deps, sensitive data, output encoding, error handling, crypto, infra) | [`skills/security-review/SKILL.md`](../skills/security-review/SKILL.md) |

### Logic concerns (retry, timeout, idempotency, etc.)

The plugin does **not** have a dedicated linter for resilience logic. Retry/backoff/idempotency are handled as **spec-conformance** concerns:

- **Design phase:** if retries matter, they get specified in the [tech-spec `Error modes` and `NFRs` sections](../templates/tech-spec.md).
- **Build phase Step 3:** code is validated against that spec — missing retry behavior surfaces as a spec deviation.
- **Security-review §8:** retries must be bounded with backoff ([`skills/security-review/SKILL.md`](../skills/security-review/SKILL.md)) — the only hard rule on retry shape, framed as an abuse-amplification concern.
- **Support phase:** external calls require timeout / failure / retry counters for observability ([`skills/support/SKILL.md`](../skills/support/SKILL.md)).

To enforce stricter logic rules, add them to the tech-spec template so Build's conformance pass can catch deviations.

### Enforcement

- **Block (exit 2):** no plan, missing work item, confirmed secret, critical / high security finding.
- **Warn (stderr):** scope drift, adjacent-function edit, test-gate mismatch.
- **Human gate:** sign-off recorded in `.claude/sdlc/gates/build-<task-slug>.md`.

---

## 2. Test-case review

### When it runs

- Phase 3 Design — [`skills/design/SKILL.md`](../skills/design/SKILL.md).

### Where test cases live

- `.claude/sdlc/test-cases/` — one file per test case.
- Shape per [`templates/test-case.md`](../templates/test-case.md).

### Required fields

| Field | Notes |
|---|---|
| `Covers REQ(s)` | One or more REQ IDs — **mandatory** |
| `Type` | unit / integration / e2e / NFR / security / UX |
| `Priority` | must / should / could |
| `Preconditions` | System state required before the test |
| `Steps` | Ordered, reproducible |
| `Expected outcome` | Observable, assertable |
| `Data needs` | Fixtures, synthetic data, external inputs |

### Review rules

- **Coverage:** every requirement has **at least one** test case ([design SKILL.md](../skills/design/SKILL.md)).
- **Traceability:** every test case references a REQ ID. Orphans are rejected — "Do not produce test cases that aren't traceable to a REQ ID."
- **Validate-before-rewrite:** when test cases already exist, produce a *delta report* against the current requirements rather than regenerating. Only update after human agreement.

### Who

- The [`test-designer`](../agents/test-designer.md) subagent may draft test cases (write scope: `.claude/sdlc/test-cases/` only).
- The human approves at the Design gate (`.claude/sdlc/gates/design-<task-slug>.md`).

---

## 3. Test-script review

Split across two phases — **authoring and review in Build**, **execution and review in Test**.

### Build-time review (Phase 4)

Reference: [`skills/build/SKILL.md`](../skills/build/SKILL.md) Step 4.

- **Scope rule:** tests are added or updated **only for functions modified in the current diff**. Do not rewrite tests for unmodified functions.
- **Location:** `.claude/sdlc/test-scripts/`, mirroring the source tree.
- **Traceability:** each test references a test case from Design → through it a REQ ID.
- **Hook enforcement:** [`modified-code-test-gate.sh`](../hooks/modified-code-test-gate.sh) — warns if source files changed but no test files were touched in the session.
- **Anti-pattern blocked:** inflating coverage by adding tests for untouched code.

### Test-time review (Phase 5)

Reference: [`skills/test/SKILL.md`](../skills/test/SKILL.md).

1. **Execute** — run the test runner configured in `config/tools.json`. Capture pass/fail per test case (tied to REQ IDs), coverage, duration, flakiness.
2. **Coverage gate** — coverage on *modified code* vs. `config/tools.json` → `coverage.threshold_percent` (default 80%). Below threshold = phase fails unless a human-signed waiver is recorded.
3. **Defect logging** — every failure becomes a defect record:
   - Git Issues when available (labels: `defect`, `severity:<level>`, `phase:test`), or
   - `.claude/sdlc/defects/<task-slug>/<defect-id>.md` using [`templates/defect.md`](../templates/defect.md).
   - Every defect references **at least one REQ ID and at least one test case**.
4. **UX conformance** — frontend changes compared to mockups under `.claude/sdlc/test/ux/<task-slug>/`. Spacing, palette, typography, component usage, accessibility basics (contrast, keyboard nav, ARIA). UX failures are defects.
5. **Report** — written to `.claude/sdlc/test/<task-slug>-report.md`.
6. **Human gate** — sign-off at `.claude/sdlc/gates/test-<task-slug>.md`.

### Must-NOT list

- Silently skip failing tests.
- Inflate coverage by testing unmodified code.
- Downgrade a UX failure to "cosmetic" without human confirmation.

---

## Cross-reference

| Process | Primary skill | Primary hook(s) | Gate file |
|---|---|---|---|
| Code | [`build`](../skills/build/SKILL.md), [`security-review`](../skills/security-review/SKILL.md) | `plan-gate`, `work-item-validation`, `secret-scan`, `diff-scope-check`, `adjacent-function-detector`, `format-on-write` | `build-<slug>.md` |
| Test cases | [`design`](../skills/design/SKILL.md) (+ [`test-designer`](../agents/test-designer.md) agent) | — (judgment-based, human-gated) | `design-<slug>.md` |
| Test scripts | [`build`](../skills/build/SKILL.md) (authoring), [`test`](../skills/test/SKILL.md) (execution) | `modified-code-test-gate` | `build-<slug>.md`, then `test-<slug>.md` |
