# Risk Analysis: `/plan` Command

> **Status:** companion — RFC-001-plan-quality-gates.md

**Date:** 2026-04-26  
**Branch:** `claude/zealous-fermi-JHrih`  
**Scope:** `commands/plan.md`, `skills/plan/SKILL.md`, `hooks/plan-gate.sh`, `hooks/diff-scope-check.sh`, `templates/plan.md`, `agents/scope-ingest.md`, `skills/domain-expert/SKILL.md`  
**Method:** First-principles code inspection → external review synthesis (ChatGPT second opinion, provided)

---

## Executive Summary

`/plan` is the highest-leverage command in the SDLC plugin because it produces the artifact that every downstream phase and hook depends on. It is also the single point where the plugin's core discipline — human in the lead, plan before code, surgical edits, work-item traceability — is either established or compromised.

The command is well-structured in its intent. The risks are not in what the skill says to do; they are in the gaps between what the skill describes and what the surrounding infrastructure (hooks, templates, gate files) actually enforces. **A vague or partially-complete plan that passes the gate hook creates formal compliance without meaningful governance.**

This analysis is organized in two parts:

1. **Original findings** from direct code inspection, anchored on the plugin's core principles.
2. **Synthesis with external review** — validating, extending, or correcting ChatGPT's risk assessment.

---

## Part 1 — Original Findings (Code Inspection)

### R-01: `plan-gate.sh` checks file existence, not gate signature

**Severity:** High  
**Principle violated:** Human in the lead

**Evidence:** `hooks/plan-gate.sh` lines 30–35 block on the absence of any `.md` file in `plans/` that is not a versioned archive. It does not check whether the plan file contains `Status: signed`. A `Status: draft` plan — one that has never been reviewed or signed by a human — satisfies the hook and unblocks all `Edit`/`Write` calls.

**Impact:** An AI agent running `/plan` can produce a draft, skip the gate sign-off step (or have sign-off fail silently), and proceed to write code against an unsigned plan. The hook's block guarantee is weaker than its documentation implies.

**Recommended fix:** Add a check in `plan-gate.sh` that reads the active plan's `Status:` field and emits a WARN (not BLOCK) when it is not `signed`:

```bash
STATUS=$(grep -m1 '^\- \*\*Status:\*\*' "$ACTIVE_PLAN" | sed 's/.*Status:\*\* //')
if [ "$STATUS" != "signed" ]; then
  echo "[plan-gate] WARN: active plan Status is '$STATUS', not 'signed'. Gate sign-off may be incomplete." >&2
fi
```

Keep this at WARN, not BLOCK, to avoid false positives when the plan is being actively reviewed.

---

### R-02: `diff-scope-check.sh` picks the plan by mtime, not by task slug

**Severity:** Medium–High  
**Principle violated:** Surgical edits, work-item traceability

**Evidence:** `hooks/diff-scope-check.sh` lines 16–21 select the active plan using `sort -rn` on mtime. If multiple `.md` files exist in `plans/` — which happens legitimately when parallel tasks or follow-up fixes are being tracked — the hook enforces scope from whichever plan was most recently touched, which may not match the task currently being built.

**Impact:** An engineer working on task B could accidentally satisfy scope enforcement with task A's plan, or trigger false-positive warnings about task B's legitimate edits.

**Recommended fix:** Surface the resolved plan name in the warning message so the human can immediately see which plan the hook consulted:

```bash
echo "[diff-scope] NOTE: enforcing scope from plan: $PLAN" >&2
```

Longer term: correlate the active plan to the current task via a `.claude/sdlc/.active-task` sentinel file written by the `plan` skill at gate sign-off time.

---

### R-03: The 24-hour staleness check warns but never escalates

**Severity:** Low–Medium  
**Principle violated:** Human in the lead

**Evidence:** `hooks/plan-gate.sh` lines 43–45 warn when no plan file was modified in the last 24 hours. The warning is correct; the calibration is not. A plan produced three days ago — before scope changed, before a dependency was identified — can unblock edits indefinitely without any escalation.

**Impact:** Long-running tasks that run into the next calendar day silently continue against a potentially stale plan. The hook provides false assurance.

**Recommended fix:** Increase the staleness threshold to 48h and escalate the warning text explicitly:

```
WARN: no plan modified in the last 48h. If the task spans multiple days,
confirm the plan still reflects current scope before continuing.
```

This is still a WARN (consistent with hook philosophy), but makes the human's required action explicit.

---

### R-04: `gate_hash` in scope gate is computed but never verified

**Severity:** Medium  
**Principle violated:** Work-item traceability, human in the lead

**Evidence:** `skills/plan/SKILL.md` Step 4.5 instructs the skill to compute `sha256` of the scope gate content above the `## Required sign-offs` heading and write it into the `gate_hash:` line. However, neither `plan-gate.sh` nor any other hook verifies this hash on subsequent reads. The scope gate can be modified after signing without detection.

**Impact:** A signed scope gate can drift from the content the human actually approved. Downstream phases assume the scope gate reflects a genuine human decision.

**Recommended fix:** Add a check in `plan-gate.sh` (or a dedicated `scope-gate-verify.sh`) that recomputes the hash and warns on mismatch:

```bash
# Pseudocode — adapt to actual gate_hash extraction
STORED=$(grep 'gate_hash:' "$SCOPE_GATE" | awk '{print $2}')
COMPUTED=$(awk '/^## Required sign-offs/{exit} {print}' "$SCOPE_GATE" | sha256sum | awk '{print $1}')
if [ "$STORED" != "$COMPUTED" ]; then
  echo "[scope-gate] WARN: scope gate hash mismatch — gate may have been modified after signing." >&2
fi
```

---

### R-05: No completeness check before sign-off is requested

**Severity:** High  
**Principle violated:** Human in the lead, reduce cognitive load

**Evidence:** `skills/plan/SKILL.md` Step 5 instructs the skill to "produce a one-screen summary and ask the human to confirm." There is no checklist or validation that required fields in the plan artifact are non-empty before sign-off is requested. The plan template (`templates/plan.md`) shows placeholder text for all fields, but nothing enforces that placeholders are replaced.

**Impact:** A plan with empty `In-scope files`, generic `Out-of-scope`, or placeholder risks can reach the human at sign-off. The human either rubber-stamps it (false governance) or must read carefully enough to catch it themselves (increased cognitive load — the opposite of the plugin's goal).

**Recommended fix:** The skill should run a pre-signoff quality checklist before invoking `gate-signoff`:

```
Cannot request sign-off until:
✓ Classification is one of: new-build / fix / change-request
✓ In-scope files is non-empty
✓ In-scope functions is non-empty or explicitly deferred (allowed before Build only)
✓ Out-of-scope is not the template placeholder text
✓ Tests to add/update is non-empty
✓ Risks & rollback is non-empty
✓ Compatibility matrix has no unresolved FAIL
```

This is not auto-approval; it is pre-signoff quality control that reduces the human's review burden.

---

### R-06: Domain context placement is implicit — template has no placeholder

**Severity:** Low  
**Principle violated:** Reduce cognitive load

**Evidence:** `skills/domain-expert/SKILL.md` appends `## Domain context` "immediately after the `## Approach` section." However, `templates/plan.md` has no `## Domain context` placeholder. The section appears between `## Approach` and `## Tests to add or update` in the final artifact — which is fine structurally — but its position is determined by runtime instruction, not template shape. A template change could silently break injection position.

**Recommended fix:** Add a `## Domain context` placeholder to `templates/plan.md` with a comment:

```markdown
## Domain context

<!-- Populated automatically by domain-expert skill if a domain match is found. Remove this section if no domain matched. -->
```

---

## Part 2 — Synthesis with External Review (ChatGPT Analysis)

The external review identified 15 risks. This section evaluates each against the code, notes where the analysis is accurate, adds precision where needed, and identifies one area of disagreement.

---

### Agreement with full confidence: 6 risks

**Misclassification (R-ChatGPT-1)** — Confirmed. The skill handles misclassification through narrative guidance and scope-delta prompts, but there is no structural challenge at classification time. The recommended mitigation (explicit challenge before gate) aligns with the pre-signoff quality checklist in R-05 above.

**Shallow scope on first task (R-ChatGPT-2)** — Confirmed. `scope-ingest` handles this well, but the one-paragraph fallback (`skills/plan/SKILL.md` Step 2, "Fallback — no source material") produces a scope that is only as good as what the human types in 30 seconds. Marking it `Scope source quality: low` is the right signal and does not violate graceful degradation — it makes the gap visible.

**Scope drift hidden in the plan (R-ChatGPT-3)** — Confirmed. The skill surfaces scope deltas but does not prevent gate sign-off while a delta is unresolved. Adding a mandatory decision record in the plan before proceeding is consistent with the plan-as-contract principle.

**Rubber-stamp sign-off (R-ChatGPT-6)** — Confirmed and partially addressed by R-05 above. The external review correctly identifies that summary length is a governance risk. The plan gate summary should show decision-critical information only and explicitly label what the human is and is not approving.

**Plan versioning bypass (R-ChatGPT-7)** — Confirmed. The version check in Step 3 relies on Claude's judgment to detect material changes. A "non-material" prose edit that happens to change the implied function boundary is not caught. The materiality checklist recommendation is sound.

**Hooks depend on plan fields verbatim (R-ChatGPT-13)** — Confirmed and strong. `diff-scope-check.sh` uses an `awk` pattern match on the literal heading `##?[[:space:]]*In-scope files`. Renaming the heading breaks enforcement silently. Fixture tests for plan parsing are necessary — this is a structural dependency, not a style preference.

---

### Agreement with added precision: 5 risks

**Fake file/function precision (R-ChatGPT-4)** — Confirmed, with a nuance. The risk is real and the mitigation (allow TBD before Build, block TBD at Build) is correct. However, the proposed enforcement mechanism ("Build cannot proceed while In-scope functions contain TBD") requires a new hook or an extension to `plan-gate.sh` to read the plan's `In-scope functions` field. This is non-trivial and needs to be scoped as its own change.

**Superficial compatibility matrix (R-ChatGPT-8)** — Confirmed, with a nuance. The template uses `✓` and `✗` symbols in the current `Compatibility` column. Adding an `Evidence` column is the right call, but the real problem is that `UNKNOWN` silently passes. The skill says "Any FAIL row halts planning" — it says nothing about `UNKNOWN`. `UNKNOWN` should be treated as an open item, not a pass.

**Domain context false confidence (R-ChatGPT-9)** — Confirmed, with a nuance. `skills/domain-expert/SKILL.md` already includes confidence levels (`high`, `medium`, `low`) and provenance (which domain file was used). The risk is real but partially mitigated. The gap is the "no match" case — the skill exits silently, but `No domain matched` does not mean `No domain concerns`. A brief note in the plan (`Domain: unknown — no domain profile matched`) surfaces this for human judgment without adding noise.

**First scope gate friction (R-ChatGPT-12)** — Confirmed. The mitigation is largely a UX copy change. The skill should frame the scope gate as "one-time setup" not "unexpected blocker." This is low cost and high value for adoption.

**Perceived bureaucracy (R-ChatGPT-15)** — Confirmed. The most actionable recommendation is the suggested UX message: *"This plan prevents the agent from touching unrelated code."* This explains the value directly. Also: the plan skill's description (`SKILL.md` frontmatter) should be updated to lead with the user benefit, not the process.

---

### Partial disagreement: 1 risk

**Degraded mode normalized (R-ChatGPT-11)** — The external review says degraded mode should be "clearly visible" in the plan. This is correct. However, the review implies that degraded mode is a governance failure. The plugin's principle is **graceful degradation** — missing systems should produce local artifacts and surface the gap, not block work. Degraded mode that is clearly labelled is acceptable and desirable for pilots and small teams. The fix is labelling, not blocking.

Current `config_requirements` in the skill:

```yaml
config_requirements:
  - key: tracker.type
    required: false
    on_skip: degrade_to_req_id_only
  - key: tracker.project
    required: false
    on_skip: skip_project_validation
```

`on_skip: degrade_to_req_id_only` triggers silently. It should instead write a visible marker in the plan artifact:

```markdown
> **Traceability mode: degraded** — tracker not configured. REQ ID is required as compensating control.
> Set `tracker.type` in `config/tools.json` to enable full project validation.
```

This surfaces the gap without blocking work — which is the correct balance.

---

## Consolidated Risk Table

| # | Risk | Severity | Core Principle at Risk | Source | Priority Fix |
|---|------|----------|----------------------|--------|--------------|
| R-01 | plan-gate.sh checks file existence, not signed status | High | Human in the lead | Code inspection | WARN on unsigned plan |
| R-02 | diff-scope-check.sh picks plan by mtime, not task | Med–High | Surgical edits | Code inspection | Log resolved plan name |
| R-03 | 24h staleness check never escalates | Low–Med | Human in the lead | Code inspection | Increase to 48h + clearer text |
| R-04 | gate_hash never verified after scope gate is written | Medium | Traceability | Code inspection | Hash verification in hook |
| R-05 | No completeness check before sign-off is requested | High | Human in the lead, cognitive load | Code inspection | Pre-signoff quality checklist |
| R-06 | Domain context placement implicit in template | Low | Cognitive load | Code inspection | Add placeholder to template |
| R-07 | Wrong classification corrupts downstream artifact chain | High | All phases | External review | Classification challenge in checklist |
| R-08 | Weak one-paragraph scope silently passes | High | Surgical edits | External review | Low-provenance marker |
| R-09 | Scope delta can be acknowledged without a decision record | High | Human in the lead | External review | Require decision record in plan |
| R-10 | Fake function precision misleads hook enforcement | Med–High | Surgical edits | External review | Allow TBD before Build; block at Build |
| R-11 | Generic out-of-scope is a token gesture | Medium | Surgical edits | External review | Pre-signoff: reject template placeholder |
| R-12 | Rubber-stamp sign-off | High | Human in the lead | External review | Decision-focused summary + R-05 |
| R-13 | Signed plan versioning bypassed by "non-material" edit | High | Traceability | External review | Materiality checklist |
| R-14 | UNKNOWN in compatibility matrix treated as pass | Med–High | Work-item traceability | External review | Treat UNKNOWN as open item |
| R-15 | Domain no-match exits silently | Medium | Cognitive load | External review | Write `Domain: unknown` note |
| R-16 | Degraded mode proceeds without visible marker in plan | Medium | Traceability | External review | Write degraded-mode banner in plan |
| R-17 | Valid gate file does not prove plan quality | High | Human in the lead | External review | R-05 is the fix |
| R-18 | Plan becomes design doc — adoption risk | Medium | Cognitive load | External review | Enforce plan-as-contract via template |

---

## Priority Order for Fixes

These are ordered by the ratio of severity × implementation cost. Low-cost, high-impact changes first.

1. **Pre-signoff quality checklist** (R-05, R-12, R-17) — add to `skills/plan/SKILL.md` Step 5. Text-only change, no new infrastructure.
2. **WARN on unsigned plan status** (R-01) — 4-line addition to `plan-gate.sh`.
3. **Low-provenance scope marker** (R-08) — text addition to skill Step 2 fallback path.
4. **Degraded-mode banner in plan** (R-16) — text addition, triggered by `on_skip` conditions.
5. **Log resolved plan name in diff-scope-check.sh** (R-02) — 1-line addition, reduces debugging time.
6. **Scope-delta decision record required** (R-09) — add to skill Step 2 scope validation.
7. **Domain no-match note** (R-15) — text addition to `skills/domain-expert/SKILL.md`.
8. **UNKNOWN = open item in compatibility matrix** (R-14) — add to skill Step 4 guidance.
9. **Materiality checklist for signed plan edits** (R-13) — extend Step 3 version check.
10. **Domain context placeholder in template** (R-06) — 3-line addition to `templates/plan.md`.
11. **gate_hash verification hook** (R-04) — new hook logic; scope as separate change.
12. **TBD enforcement at Build** (R-10) — requires hook extension; scope as separate change.
13. **Active-task sentinel for plan selection** (R-02 long-term) — architectural change; scope separately.

---

## Closing Assessment

`/plan` is the right control point. Its risks are not design flaws — they are implementation gaps between the governance intent and the enforcement layer. The plugin's own principle applies here: warn where the consequence is recoverable; block only where the consequence is severe.

The highest-priority gap is the absence of a pre-signoff quality checklist (R-05). Without it, the gate file proves a human was present, not that the plan was adequate. A signed inadequate plan is the worst outcome: it is worse than no plan because it creates false confidence while providing weak enforcement to every downstream hook.

The second-highest priority is making `plan-gate.sh` status-aware (R-01). The hook currently enforces "a plan file exists" rather than "a signed plan exists." This is a single grep away from a meaningful improvement.

All other risks are real but bounded. The external review from ChatGPT correctly identified the macro-level failure modes. Code inspection confirms their severity and adds four structural gaps not visible from the skill description alone (R-01, R-02, R-04, R-06). Together, the two perspectives give a more complete picture than either alone.
