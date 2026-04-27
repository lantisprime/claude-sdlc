---
rfc_id: RFC-005
slug: work-item-reference-validation
title: Work-Item Reference Validation
status: draft
champion: juan.delacruz@acme.com
created: 2026-04-27
last_modified: 2026-04-27
second_opinion: 2026-04-27
supersedes: ~
superseded_by: ~
---

# RFC-005 — Work-Item Reference Validation

## AI context

> `work-item-validation.sh` currently checks that a plan *contains* a pattern like `REQ-001` or `TICKET-123` — it does not verify those IDs exist anywhere. This RFC adds a two-layer existence check: Layer 1 (local) confirms REQ IDs resolve to artifact files in `.claude/sdlc/requirements/` and CR IDs resolve to signed change-request files; Layer 2 (external, opt-in) queries the detected ticketing integration for ticket existence and open status, warn-only with graceful degradation. Key trade-off: external validation adds a network call on every Build edit — the default must degrade gracefully when the integration is unreachable rather than block.

---

## Problem

`work-item-validation.sh` (as shipped in RFC-003 PR-5 and PR-8) validates two things:

1. The active plan has a `Classification` field (`new-build`, `fix`, or `change-request`).
2. For `change-request` plans, a signed CR artifact exists under `.claude/sdlc/change-requests/`.

The file-level traceability added in RFC-003 PR-5 / PR-8 checks that an edited file appears in the plan's `## Traceability` table and that the table row contains a `(REQ|TICKET|CR|ISSUE)-[0-9]+` pattern.

**What neither check does:** verify that the referenced ID actually exists in an underlying system. A plan can reference `REQ-999`, `TICKET-XYZ-0`, or `CR-signed-by-nobody` — all will pass current validation. The hook proves a pattern is present, not that the thing it names is real.

This means:

- A developer can fabricate a REQ ID (`REQ-9999`) and pass all enforcement checks with no underlying requirement artifact.
- A ticket reference (`TICKET-ABC-0`) can pass even if no such ticket exists in Jira, Linear, or GitHub Issues.
- A CR reference can point at a deleted or unsigned file if the hook fails to re-check at edit time (it only validates on plan creation).

Observable consequence: the traceability chain from plan → code → requirement is syntactically correct but semantically hollow. An audit of `.claude/sdlc/` artifacts would show valid-looking IDs that resolve to nothing.

---

## Proposal

Two validation layers, independently configurable.

### Layer 1 — Local artifact existence (default: warn)

For each work-item reference found in the active plan's `## Traceability` table, check whether the corresponding local artifact exists:

| Reference type | Local artifact expected |
|---|---|
| `REQ-NNN` | At least one file matching `.claude/sdlc/requirements/*REQ-NNN*.md` — any match counts as found; when multiple files match, the hook logs the first match alphabetically and continues. Duplicate artifacts are not an error at this layer. |
| `CR-NNN` or `CR-<slug>` | At least one file matching `.claude/sdlc/change-requests/*CR-NNN*.md` or the existing CR path already validated |
| `TICKET-NNN`, `ISSUE-NNN` | Skipped entirely in Layer 1 when `work_item_lookups.enabled: false` (the default) — no warn, no block. Local ticket artifacts under `.claude/sdlc/tickets/` are not required. Layer 2 handles external existence when opted in. |

Behaviour:

- **REQ miss** → warn: `[work-item] WARN: REQ-NNN referenced in plan but no matching artifact found in .claude/sdlc/requirements/`
- **CR miss** → block (exit 2): a signed CR is already required by the existing hook; a missing artifact after plan creation is an error
- **TICKET or ISSUE (lookups disabled)** → skip silently

Promotable to hard block for REQ misses via `enforcement.work_item_existence: "block"` in `config/tools.json`.

### Layer 2 — External ticket existence (default: off)

When `work_item_lookups.enabled: true` is set in `config/tools.json`, the hook reads the `work_item_lookups.<integration>` block from `config/tools.json` (not `env.json`) to determine which integration to query. `env.json` records auto-detected integrations at session start, but credential and endpoint configuration for lookups must be explicit in `config/tools.json` — relying on auto-detection alone would cause silent failures when detection is wrong. The hook queries each `TICKET-*` or `ISSUE-*` reference in the plan:

| Integration | Detection | Lookup method |
|---|---|---|
| GitHub Issues | `work_item_lookups.github.repo` is set | `gh issue view <number> --repo <repo>` — checks for `gh auth status` first; skips with INFO if unauthenticated |
| Jira | `work_item_lookups.jira.base_url` is set | `timeout 5 curl -sf -u <email>:<token> <base_url>/rest/api/3/issue/<id>` — checks HTTP 200 |
| Linear | `work_item_lookups.linear.api_key` is set | `timeout 5 curl -sf -H "Authorization: <key>" https://api.linear.app/graphql` — issue existence query |

All external calls use a 5-second hard cap via the shell `timeout` command (or `curl --max-time 5` for curl targets). When multiple tickets are referenced and one times out, the remaining are still checked — each reference is independent.

Behaviour:

- Ticket found and open/active → pass silently
- Ticket found but closed/resolved → warn: `[work-item] WARN: TICKET-NNN is closed — confirm this edit is still in scope`
- Ticket not found → warn: `[work-item] WARN: TICKET-NNN not found in <integration>`
- Timeout → skip with note: `[work-item] INFO: TICKET-NNN lookup timed out (5s) — skipping`
- Network unreachable / CLI missing / unauthenticated → skip with note: `[work-item] INFO: external lookup skipped (<reason>)` — never blocks
- `work_item_lookups.enabled: false` (default) → Layer 2 does not run at all

Promotable to block on "not found" only (not closed) via `enforcement.work_item_existence: "block"`.

### Explicit non-goals

This RFC deliberately does not:

- Verify that a requirement is *approved* — that is a business-process decision outside the hook layer.
- Verify that a ticket is *assigned* to the current engineer.
- Verify that the change *satisfies* the requirement — that is the purpose of the test and review phases.
- Replace or supersede the plan-level REQ validation already in `work-item-validation.sh`.

### Scope

**In scope:**

- `hooks/work-item-validation.sh` — two new check functions (local artifact lookup, external ticket lookup)
- `config/tools.example.json` — two new config additions: `enforcement.work_item_existence` (default `"warn"`, sibling to existing `enforcement.*` keys) and a new root-level `work_item_lookups` block with the following schema:

  ```json
  "work_item_lookups": {
    "_comment": "Set enabled: true and fill in credentials to activate Layer 2 external ticket validation.",
    "enabled": false,
    "github": {
      "repo": null
    },
    "jira": {
      "base_url": null,
      "email": null,
      "api_token": null
    },
    "linear": {
      "api_key": null
    }
  }
  ```
- `tests/hooks/work_item_validation.bats` — new test cases for each new check
- `docs/USER-MANUAL.md` — extend the enforcement status table with RFC-005 row

**Out of scope:**

- Changes to plan template fields or traceability table structure (RFC-003 shipped those)
- Any change to `phase-gate.sh` or `plan-gate.sh`
- CR signing workflow (already handled)
- Verification that a requirement *content* matches the change

---

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Block on every ID that has no local artifact | False-positive rate too high — many legitimate teams never create local REQ files, relying entirely on an external tracker. Warn-by-default respects graceful degradation (design principle 6). |
| Validate requirements content (does the code satisfy REQ-001?) | Out of scope for static hook enforcement; that is a semantic check for humans and test output, not a pre-edit gate. |
| Single external-only lookup (skip local) | Local artifact check is zero-latency and deterministic — it should always run when artifacts exist. External-only loses the fast path. |
| Always-on external lookup (remove `enabled` flag) | Network calls on every Edit are too slow for the default path; opt-in is the right default here. |
| Validate CR re-existence on every edit (not just plan creation) | Already partially done — existing hook checks CR artifact at PreToolUse. Layer 1 hardens this for the REQ case with the same logic pattern. |

---

## Implementation plan

> Populate when RFC moves to `accepted`.

| Phase | PRs / tasks | Files in scope |
|---|---|---|
| 1 | Config schema additions | `config/tools.example.json` |
| 2 | Layer 1: local REQ/CR existence check | `hooks/work-item-validation.sh`, `tests/hooks/work_item_validation.bats` |
| 3 | Layer 2: external ticket lookup (opt-in) | `hooks/work-item-validation.sh`, `tests/hooks/work_item_validation.bats` |
| 4 | Documentation + enforcement status table | `docs/USER-MANUAL.md` |

Sequencing notes:
- Phase 1 must merge before Phase 2 (hook reads new config keys).
- Phase 3 is independent of Phase 2 and can be implemented in parallel, but merge order should be Phase 2 first to keep PRs reviewable in isolation.
- Phase 4 only after Phases 2 and 3 are merged (document what shipped, not what was planned).

---

## Implementation

> Populate after all PRs are merged.

| PR / Commit | What it delivered |
|---|---|
| — | — |

---

## Related RFCs

- `RFC-003-hook-enforcement-alignment` — shipped the file-level traceability that this RFC extends; RFC-005 Layer 1 is a direct continuation of RFC-003 PR-5/PR-8.
- `RFC-001-plan-quality-gates` — accepted; also touches `work-item-validation.sh` plan-level status checks. Implementation order: RFC-001 before RFC-005 to avoid merge conflicts.

---

## Second opinion

**Reviewer:** subagent-review (independent, no prior RFC context)
**Date:** 2026-04-27
**Findings:** Four gaps surfaced — (1) Layer 1 REQ artifact glob lacked tie-breaking rules for duplicate files; (2) `work_item_lookups` config schema was unnamed in the RFC body; (3) Layer 2 integration detection was ambiguous (`env.json` vs. `config/tools.json`); (4) TICKET/ISSUE behavior in Layer 1 when lookups are disabled was implicit. All four addressed in this revision: glob behavior now documented (any match = pass, first alphabetically logged), config schema added to Scope section, Layer 2 detection clarified (explicit `config/tools.json` keys, `env.json` is advisory only), TICKET/ISSUE Layer 1 behavior made explicit (skip silently). OQ-3 resolved (pre-check `gh auth status`). No alternatives missed. OQ-1, OQ-2, OQ-4 remain open and do not block safe implementation.
**Decision:** proceed

---

## Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Should Layer 1 warn or block by default for REQ misses? Current proposal is warn; early teams may have zero `.claude/sdlc/requirements/` files on day one. | — | open |
| OQ-2 | How to handle `REQ-NNN` IDs used in a plan that was created before local requirement artifacts existed (retrofitted traceability)? Grace period or unconditional warn? | — | open |
| OQ-3 | GitHub Issues lookup uses `gh` CLI — this assumes the consuming repo has `gh` authenticated. Should the hook check for `gh auth status` before attempting? | — | resolved: yes — Layer 2 checks `gh auth status` before calling `gh issue view`; skips with INFO if unauthenticated |
| OQ-4 | Should a closed ticket block or warn? Current proposal is warn-only; some teams may want to block edits that reference resolved tickets to prevent ghost work. | — | open |
