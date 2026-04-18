# Review Processes

How the SDLC plugin reviews the artifacts that most directly determine whether a change is safe to ship: **production code**, **architecture conformance**, **test cases**, and **test scripts**.

They share a common shape:

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
- **Security-review 8:** retries must be bounded with backoff ([`skills/security-review/SKILL.md`](../skills/security-review/SKILL.md)) — the only hard rule on retry shape, framed as an abuse-amplification concern.
- **Support phase:** external calls require timeout / failure / retry counters for observability ([`skills/support/SKILL.md`](../skills/support/SKILL.md)).

To enforce stricter logic rules, add them to the tech-spec template so Build's conformance pass can catch deviations.

### Enforcement

- **Block (exit 2):** no plan, missing work item, confirmed secret, critical / high security finding.
- **Warn (stderr):** scope drift, adjacent-function edit, test-gate mismatch.
- **Human gate:** sign-off recorded in `.claude/sdlc/gates/build-<task-slug>.md`.

---

## 2. Architecture conformance (via tech specs)

Architecture is never compared directly to code. The **tech spec** is the intermediary contract — architecture decisions (API shape, data contracts, NFRs, security controls) are captured in a per-module tech spec during Design, and Build validates the code against that spec.

### The validation chain

```
Requirements (Phase 2)
   ↓
Architecture (Phase 3) — app / data / platform / infra / security / test / UX
   ↓
Tech spec (Phase 3) — per-module contract derived from architecture
   ↓
Code (Phase 4) — validated against the tech spec in Build Step 3
```

### When it runs

| Trigger | Mechanism |
|---|---|
| Phase 3 Design — architecture authoring & drift detection | [`architect`](../agents/architect.md) subagent (read-only over code, write-only into `architecture/`) |
| Phase 3 Design — per-module tech spec authored | [`skills/design/SKILL.md`](../skills/design/SKILL.md) "Tech spec rule" |
| Phase 4 Build — Step 3 conformance pass | [`skills/build/SKILL.md`](../skills/build/SKILL.md) — code shape vs. tech spec |
| Phase 4 Build — UX conformance (frontend only) | Build Step 3 vs. `.claude/sdlc/architecture/ux/<task-slug>.md` |
| Phase 5 Test — NFR test cases | Measures architecture commitments (latency, throughput, availability) |
| Phase 7 Support — observability loopback | [`skills/support/SKILL.md`](../skills/support/SKILL.md) wires alerts per architecture's security / NFR sections |

### What gets checked (Build Step 3)

Reference: [`skills/build/SKILL.md`](../skills/build/SKILL.md) Step 3.

- **API signatures** match the tech spec's public interface ([`templates/tech-spec.md`](../templates/tech-spec.md) "Public interface").
- **Error modes** match the spec — exceptions raised, error codes returned, failure semantics.
- **Side effects** match the spec — what the function writes, publishes, or mutates.
- **NFR commitments** addressed (latency, throughput, availability targets) — or explicitly deferred with justification.
- **Security controls** from the security architecture are in place for the modified surface (authN/Z, input validation, output encoding, etc.).

### Architecture drift detection

[`agents/architect.md`](../agents/architect.md) — the architect subagent runs in Phase 3 Design and produces a **validation report** comparing existing architecture against the current requirements set. Deltas (new NFRs, new entities, new integrations, new controls) surface for human decision. This catches drift that has accumulated between tasks — e.g., when code has evolved beyond what the architecture document reflects.

### Enforcement

- **No hook** runs an automated architecture check. Conformance is a **skill-level judgment pass** performed by `build` in Step 3.
- **Human gate:** sign-off recorded in `.claude/sdlc/gates/build-<task-slug>.md` includes conformance status.
- Deviations must be either fixed or recorded as explicit deferrals with justification.

### What's NOT automated

- No ArchUnit-style dependency rules (e.g., "controllers must not call repositories directly"). Those concerns are encoded as API signatures in the tech spec, not as layer-enforcement rules.
- No NFR measurement at Build time — actual latency / throughput / availability are measured by NFR test cases in Phase 5 Test.
- No hook that fails the build when the tech spec and code diverge.

To tighten enforcement, add the concern to [`templates/tech-spec.md`](../templates/tech-spec.md) so Build Step 3 catches deviations.

---

## 3. Test-case review

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

### Requirements traceability

Test cases are validated against requirements through **bidirectional coverage** — every REQ must map to at least one TC, and every TC must cite at least one REQ. The mapping is visible in three places, and surfaced for human review rather than enforced by a hook.

**Bidirectional coverage rule:**

- **REQ → TC:** each requirement has **at least one** test case ([`skills/design/SKILL.md`](../skills/design/SKILL.md), [`agents/test-designer.md`](../agents/test-designer.md) step 4).
- **TC → REQ:** each test case cites **at least one** REQ ID. Orphan test cases are rejected — "Do not invent requirements" ([`agents/test-designer.md`](../agents/test-designer.md)).

**Coverage tables (visibility during Design):**

| Artifact | Table | Produced by |
|---|---|---|
| `.claude/sdlc/requirements/<task-slug>.md` | Scope-coverage table listing REQs | [`skills/analyze/SKILL.md`](../skills/analyze/SKILL.md) |
| Test-case index at top of `.claude/sdlc/test-cases/` | REQ → TC coverage table | [`agents/test-designer.md`](../agents/test-designer.md) step 5 |

**Traceability matrix (ongoing visibility, Phase 8 Docs):**

[`skills/docs/SKILL.md`](../skills/docs/SKILL.md) Step 2 refreshes `.claude/sdlc/docs/traceability.md`:

| REQ ID  | Tech Spec        | Test Case(s) | Code (files/fns)  | Test Run | Deploy |
|---------|------------------|--------------|-------------------|----------|--------|
| REQ-001 | specs/order.md   | TC-001, 002  | order.py::submit  | 2026-... | prod   |

**Any empty cell is a visible gap.** The human decides whether to fill or waive — the plugin does not paper over missing coverage. This is the end-to-end closure: REQ → tech spec → test case → code → test run → deploy.

**Defect-level traceability (Phase 5 Test):**

Every defect references **at least one REQ ID and at least one test case** ([`skills/test/SKILL.md`](../skills/test/SKILL.md)). Runtime failures trace back to the same REQ chain as authoring-time test cases.

**What's NOT automated:**

- No hook flags a REQ with zero test cases at author time. The coverage tables and traceability matrix make the gap *visible*; the human is responsible for closing it at the Design or Docs gate.
- No hook validates that a TC's cited REQ ID actually exists in the requirements file.

The REQ ID convention (`REQ-<n>`, stable across edits) is the load-bearing contract — see [CLAUDE.md](../CLAUDE.md) "Things NOT to change". Traceability across Analyze → Design → Build → Test → Docs depends on its stability.

---

## 4. Test-script review

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
| Architecture conformance | [`design`](../skills/design/SKILL.md) (+ [`architect`](../agents/architect.md) agent), [`build`](../skills/build/SKILL.md) Step 3 | — (judgment-based, human-gated) | `design-<slug>.md`, then `build-<slug>.md` |
| Test cases | [`design`](../skills/design/SKILL.md) (+ [`test-designer`](../agents/test-designer.md) agent) | — (judgment-based, human-gated) | `design-<slug>.md` |
| Test scripts | [`build`](../skills/build/SKILL.md) (authoring), [`test`](../skills/test/SKILL.md) (execution) | `modified-code-test-gate` | `build-<slug>.md`, then `test-<slug>.md` |
