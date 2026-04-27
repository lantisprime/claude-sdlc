# Analyze Phase — Risk Assessment

> **Status:** discussion

**Date:** 2026-04-26
**Scope:** Risks in the `/analyze` command and `skills/analyze/SKILL.md` that could allow requirements to look disciplined but be useless downstream. Proposed remediations anchored to the plugin's core principles.
**Related:** `skills/analyze/SKILL.md`, `templates/requirements.md`, `templates/gate.md`, `docs/SDLC.md §Phase 2`, `hooks/hooks.json`

---

## What this note is and is not

This note is a risk analysis. It identifies gaps between what `/analyze` is intended to enforce and what the current implementation actually enforces, given the observable code. It is not a redesign proposal. Every claim is grounded in a specific file or behavior.

A second opinion was provided by ChatGPT (reproduced in summary below). That analysis was reviewed, validated against the codebase, and synthesized here. Agreements, qualifications, and gaps are called out explicitly.

---

## Grounding: what /analyze currently does

The implementation is in three files:

- `commands/analyze.md` — 12 lines; delegates to the analyze skill
- `skills/analyze/SKILL.md` — 86 lines; the full behavioral spec
- `templates/requirements.md` — 37 lines; the requirements artifact shape

The skill defines four steps:

1. **Frontend detection** — keyword and framework scan against the plan's in-scope files. If frontend is detected and no UX artifact exists at `.claude/sdlc/architecture/ux/<task-slug>.md`, the skill halts. Hard rule.
2. **Write requirements** — produces `.claude/sdlc/requirements/<task-slug>.md`. Each REQ gets a stable ID, title, description, acceptance criteria (Given/When/Then suggested), priority, source, and dependencies.
3. **Scope coverage check** — maps each REQ to a section of `.claude/sdlc/scope.md`. Unmapped REQs are surfaced as scope questions. The skill says to surface, not hide.
4. **Human gate** — summarizes total REQs, mapped vs. unmapped, frontend yes/no, UX artifact status. Human confirms. Gate written to `.claude/sdlc/gates/analyze-<task-slug>.md`.

What the skill explicitly prohibits: designing architecture, skipping the UX ask for frontend work, renumbering REQ IDs on edits.

---

## Risk analysis — grounded in the code

### R1 — Acceptance criteria quality is advisory only

**Severity: High**

The skill says "acceptance criteria: testable, unambiguous (Given/When/Then works)" and the template shows the G/W/T pattern. But neither the skill nor any hook verifies that criteria are actually testable. Claude can produce:

```
- Checkout should work better.
- Errors should be handled gracefully.
```

...and both look syntactically correct while being operationally useless. The analyze gate summary ("total REQs, mapped vs. unmapped, frontend yes/no, UX artifact status") does not prompt the human to evaluate criteria quality.

**Principle at stake:** Human in the lead. The gate summary must give the human enough signal to make a real decision.

**Proposed fix:** Add a pre-gate quality checklist to the skill (warn, not block) listing criteria that indicate vague acceptance criteria. At minimum, flag criteria containing modal adjectives ("better", "gracefully", "properly", "appropriate") as candidates for revision. Include this flag count in the gate summary so the human sees it.

---

### R2 — REQ IDs stabilize bad requirements

**Severity: High**

The skill correctly states that REQ IDs must never be renumbered once published. But there are no lifecycle states: a REQ does not distinguish `draft` from `active` from `deprecated`. A REQ written with bad acceptance criteria gets a stable ID and becomes indistinguishable from a well-formed REQ in all downstream references.

The template has no `Status:` field. The skill says "add new ones and deprecate old ones in place" but provides no mechanism for what "deprecated in place" means in the artifact.

**Principle at stake:** Work-item traceability. Traceability is only valuable if the artifact being traced is trustworthy.

**Proposed fix:** Add a `Status: draft | active | deprecated` field to each REQ section in `templates/requirements.md`. Add a `Superseded by:` field for deprecated REQs. This requires a one-line change to the template and a one-sentence addition to the skill.

---

### R3 — Unmapped REQs can reach the gate without resolution

**Severity: High**

The skill correctly says to surface unmapped REQs rather than hide them. The coverage table shows `? unmapped` rows. But the gate sign-off process does not require the human to explicitly waive or resolve each unmapped REQ before signing.

The gate template (`templates/gate.md`) has an `## Explicit waivers` section, but the analyze skill does not instruct Claude to use it for unmapped scope questions. A human can sign a gate with `2 unmapped` in the summary without recording what was decided about them.

**Principle at stake:** Human in the lead. Signing off on a gap without recording the decision is not meaningful approval.

**Proposed fix:** Expand the gate summary to list each unmapped REQ by ID with a required disposition: `mapped | removed | deferred to CR`. Instruct the skill to populate the gate's `## Explicit waivers` section with any unmapped REQ that is accepted as-is, including who accepted it and the reason. This is a two-sentence addition to the skill and a line in the gate summary template.

---

### R4 — Frontend detection has no ambiguous case

**Severity: Medium-High**

The detection logic is binary: either frontend is detected and the skill halts, or it is not. The keywords ("screen", "page", "form", "button", "UI", "UX", "design") can produce false positives on backend tasks (e.g., "design the response format", "page through results") and false negatives on UI tasks with non-standard filenames.

When detection fires, the skill halts with no mechanism for the human to say "this is a false positive." The only way forward is to satisfy the UX artifact requirement, which adds unnecessary friction for backend-only tasks.

**Principle at stake:** Reduce cognitive load. Unnecessary halts are noise that erode trust in the plugin.

**Proposed fix:** When frontend keywords match, present the evidence and ask for human confirmation before halting:

```
Possible frontend impact detected.
Evidence: keyword "form" in plan, file src/api/form-validator.ts in scope.
Is this a UI change? (yes / no)
```

If no, record the human's declaration in the requirements artifact under `## Frontend / UX`:

```
- Touches UI? no
- Declared by: <human>
- Reason: backend-only form validation, no rendered output
```

This adds one confirmation step but eliminates false-positive halts.

---

### R5 — UX artifact is a binary gate, not a quality gate

**Severity: Medium-High**

The skill halts until a UX artifact exists at `.claude/sdlc/architecture/ux/<task-slug>.md`. Once the file exists, the gate is satisfied. Nothing checks the artifact's content. A two-line file satisfies the gate as well as a detailed specification.

**Principle at stake:** Reduce cognitive load. The gate exists to prevent UI debt, not to produce paperwork.

**Proposed fix:** Add a minimum content checklist to the skill. When linking or writing a UX artifact, the skill should verify it addresses:
- affected screen or component
- user flow (entry → action → outcome)
- state behavior: loading, empty, error, success
- brand or component guidance

If these sections are absent, the skill should warn before proceeding, not block. The human can waive. The waiver is recorded in the gate.

---

### R6 — Requirements can contain design decisions

**Severity: Medium**

The skill prohibits designing architecture in Phase 2 but does not detect when requirements include implementation choices. Claude can generate:

```
REQ-002: The system shall use Redis to cache checkout sessions.
```

That is a design decision framed as a requirement. If the human signs it, it becomes a stable REQ that constrains Phase 3 Design for a reason unrelated to business intent.

**Principle at stake:** Plan before code. Phase boundaries matter because collapsing them produces worse outcomes.

**Proposed fix:** During requirement review (pre-gate), flag REQs containing implementation-specific terms (technology names, library references, protocol choices) as potential design leakage. This is a warn-not-block pattern. Output in the pre-gate summary:

```
Possible design leakage detected:
- REQ-002 contains "Redis" — move to Phase 3 unless this is a hard policy constraint.
```

---

### R7 — Source attribution is too vague

**Severity: Medium-High**

The template source field reads `<ticket/CR/stakeholder>`. In practice, this becomes:

```
Source: stakeholder
Source: plan
Source: discussion
```

These are category labels, not sources. They cannot support traceability disputes about where a requirement came from or whether it was authorized.

**Principle at stake:** Work-item traceability. Every build references a REQ ID, and every REQ should reference its authorizing source specifically enough to be auditable.

**Proposed fix:** Update the template to show specific source examples:

```
Source: SCOPE-2.1 Checkout  |  JIRA-PAY-123  |  CR-004  |  Stakeholder 2026-04-25 §Retry
```

Add a note to the skill: if source is inferred from context rather than explicitly provided, label it as such and flag for human confirmation:

```
Source: inferred from plan — confirm before signing gate
```

---

### R8 — Priority has no rationale

**Severity: Medium**

Priority (`must | should | could`) is set by Claude based on wording. There is no rationale field. When everything is `must`, the label is meaningless. When a critical control is labeled `should`, it may be incorrectly deferred.

**Principle at stake:** Reduce cognitive load. Priorities without rationale force the human to relitigate every priority decision at gate time.

**Proposed fix:** Add a `Priority-rationale:` field to the requirements template. One sentence is enough:

```
Priority: must
Priority-rationale: Required to satisfy signed scope §2.1.
```

---

### R9 — Dependencies are under-challenged

**Severity: Medium**

The template shows `Dependencies: REQ-xxx, <external system>`. Claude may leave this blank when real dependencies exist. A requirement like "notify customer after payment failure" has implicit dependencies on a notification service, payment event stream, and retry state — none of which appear if dependency discovery is passive.

**Principle at stake:** Graceful degradation. The plugin should surface gaps rather than silently produce incomplete artifacts.

**Proposed fix:** Add a dependency challenge to the skill. Before writing dependencies for each REQ, prompt:
- Does this REQ depend on another REQ?
- Does it call an external system?
- Does it require data not currently in scope?
- Does it depend on a UX artifact?
- Does it depend on a policy or security decision?

Unresolved dependencies appear as `? unresolved` in the gate summary.

---

### R10 — Gate summary is factual, not decision-oriented

**Severity: High**

The current gate summary instruction is: "Summarize: total REQs, mapped vs. unmapped, frontend yes/no, UX artifact status."

That is a status report. It does not help the human understand what they are approving or what they are explicitly not approving. The human-in-the-lead principle requires meaningful approval, not ceremonial sign-off.

**Principle at stake:** Human in the lead. Every phase ends at a signed gate. The gate must earn its signature by presenting a real decision.

**Proposed fix:** Expand the gate summary structure in the skill to include:

```
You are approving:
- [list of active REQ IDs with one-line summaries]
- scope mapping status (N mapped, N unmapped)
- UX artifact status (present / absent / waived)
- unresolved dependencies (list or "none")
- design leakage flags (list or "none")

You are NOT approving:
- architecture choices (Phase 3)
- implementation approach (Phase 3)
- test strategy (Phase 3)

Outstanding items carried forward: [list or "none"]
```

---

### R11 — No REQ change history after downstream references exist

**Severity: High**

The skill prohibits renumbering REQ IDs but does not prevent editing REQ content after the analyze gate is signed. If REQ-002 is referenced in a design spec and then its acceptance criteria are silently rewritten, the design spec's reference becomes misleading.

**Principle at stake:** Work-item traceability. Stable IDs only provide traceability if the content they identify is also stable.

**Proposed fix:** Add a `## Change history` section to the requirements template. Every edit to an active REQ after the analyze gate is signed should add an entry:

```
## Change history
- 2026-04-26: REQ-002 acceptance criteria revised — retry window changed from 30s to 60s. Human confirmed.
```

This is a documentation discipline, not a hook enforcement. The hook for this would be `diff-scope-check.sh`, which already warns on out-of-scope edits; it should also warn when a requirements file is edited post-gate.

---

### R12 — No hook coverage for analyze-gate prerequisite in design

**Severity: Medium**

The `plan-gate.sh` hook blocks all Edit/Write operations without a plan gate. There is no equivalent hook that blocks design operations when no analyze gate exists. The design skill checks for the analyze gate procedurally, but a Claude session that skips `/design` and goes directly to Edit/Write in a design context would only be blocked by `plan-gate.sh` (which checks for a plan, not an analyze gate).

This is an enforcement gap: the hook layer does not mirror the skill-layer prerequisite.

**Principle at stake:** Human in the lead. Phase gating is only reliable if it is enforced at the hook layer, not just the skill layer.

**Proposed fix:** Add a check in `plan-gate.sh` (or a new `analyze-gate.sh` hook) that also verifies an analyze gate exists before permitting Edit/Write when a requirements file is present. This is consistent with the existing hook philosophy and does not add a new dependency.

---

### R13 — No scope.md existence check

**Severity: Medium**

Step 3 of the skill instructs: "For each requirement, confirm it maps to a section of `.claude/sdlc/scope.md`." If `scope.md` does not exist, the scope coverage check silently fails or maps everything as unmapped. The skill does not explicitly handle the missing-scope case.

**Principle at stake:** Graceful degradation. Missing source material should be surfaced as a gap, not silently skipped.

**Proposed fix:** At the start of Step 3, check whether `scope.md` exists. If absent, add a prominent warning in the requirements artifact and the gate summary:

```
WARNING: .claude/sdlc/scope.md not found.
Scope coverage check skipped. All REQ IDs are unvalidated.
Requirement source quality: LOW (chat prompt or plan only).
```

This surfaces the gap without blocking the phase.

---

### R14 — Source quality is invisible

**Severity: Medium-High**

Requirements generated from a chat prompt and a plan artifact carry the same visual authority as requirements generated from a signed scope document, a contract, and stakeholder meeting notes. Downstream phases treat all REQ IDs as equally trustworthy.

**Principle at stake:** Work-item traceability. The traceability chain is only as strong as its weakest source.

**Proposed fix:** Add a `Source quality:` field to the requirements artifact header:

```
Source quality: high | medium | low
- high: signed scope + ticket or CR + stakeholder notes
- medium: signed scope + plan only
- low: plan or chat prompt only; REQs require human validation before gate
```

If quality is `low`, the gate summary should surface this prominently: "Requirements generated from thin source material — validate against actual stakeholder intent before advancing."

---

## ChatGPT second-opinion synthesis

The ChatGPT analysis identified 15 risks. Below is an assessment of agreement, qualification, or disagreement for each.

| # | ChatGPT Risk | My Assessment |
|---|---|---|
| 1 | Untestable acceptance criteria | **Agree — High.** Confirmed: no quality gate exists. See R1 above. |
| 2 | Stable IDs create false authority | **Agree — High.** No lifecycle states in template. See R2 above. |
| 3 | Unmapped REQs still approved | **Agree — High.** Gate template has waivers section but skill doesn't use it for this. See R3 above. |
| 4 | Frontend detection misfires | **Agree — Medium-High.** But the specific gap is the missing ambiguous case, not just misfires. See R4 above. |
| 5 | Weak UX artifact | **Agree — Medium-High.** File existence ≠ quality. See R5 above. |
| 6 | Requirements include design choices | **Agree — Medium.** No design-leakage detection. See R6 above. |
| 7 | Weak source attribution | **Agree — Medium-High.** Template placeholder is a category, not a source. See R7 above. |
| 8 | Arbitrary priorities | **Agree — Medium.** No rationale field. See R8 above. |
| 9 | Missing dependencies | **Agree — Medium.** Passive discovery only. See R9 above. |
| 10 | Too broad/granular | **Partial agreement — Low-Medium.** Real risk, but sizing guidance adds cognitive load. REQ quality checklist (R1) partly addresses this by forcing testability as a sizing constraint. |
| 11 | Analyze duplicates planning | **Qualified — Low-Medium.** The real boundary violation risk runs the other direction: analyze doing design work, not analyze redoing plan work. R6 addresses the real risk. The "don't re-litigate scope" boundary is worth adding to the skill's prohibition list. |
| 12 | Shallow analyze sign-off | **Agree — High.** Gate summary is factual, not decision-oriented. See R10 above. |
| 13 | REQ edits change meaning | **Agree — High.** No change history mechanism. See R11 above. |
| 14 | REQs not used downstream | **Qualified — Medium.** This is a downstream enforcement problem (design, test skills), not an analyze problem. Analyze can record forward obligations in the gate, but cannot enforce them. Downstream skills need REQ-ID coverage checks, not the analyze skill. |
| 15 | Thin source material | **Agree — Medium-High.** Graceful degradation requires surfacing the gap. See R13 and R14 above. |

**Additional risks not in the ChatGPT analysis:**
- R12: No hook enforcement of analyze gate before design (hook coverage gap)
- R13: No scope.md existence check (graceful degradation gap)
- R14: Source quality is invisible (traceability gap)

**Risks the ChatGPT analysis overstated:**
- Risk 10 (granularity) — adding sizing guidance adds cognitive load and may help less than fixing R1 (testability checklist serves as a natural sizing constraint).
- Risk 14 (downstream use) — correct risk, wrong fix location; belongs in design and test skills.

---

## Combined risk summary

| Risk | Severity | Principle | File to change |
|---|---|---|---|
| R1 — Untestable acceptance criteria | High | Human in the lead | `skills/analyze/SKILL.md` |
| R2 — No REQ lifecycle states | High | Work-item traceability | `templates/requirements.md` |
| R3 — Unmapped REQs reach gate unresolved | High | Human in the lead | `skills/analyze/SKILL.md` |
| R4 — Frontend detection binary (no ambiguous case) | Med-High | Reduce cognitive load | `skills/analyze/SKILL.md` |
| R5 — UX artifact is a file check, not quality check | Med-High | Reduce cognitive load | `skills/analyze/SKILL.md` |
| R6 — Requirements contain design choices | Medium | Plan before code | `skills/analyze/SKILL.md` |
| R7 — Vague source attribution | Med-High | Work-item traceability | `templates/requirements.md` |
| R8 — Priority without rationale | Medium | Reduce cognitive load | `templates/requirements.md` |
| R9 — Passive dependency discovery | Medium | Graceful degradation | `skills/analyze/SKILL.md` |
| R10 — Gate summary is factual not decisional | High | Human in the lead | `skills/analyze/SKILL.md` |
| R11 — No REQ change history | High | Work-item traceability | `templates/requirements.md` |
| R12 — No hook enforcement of analyze gate pre-design | Medium | Human in the lead | `hooks/plan-gate.sh` or new hook |
| R13 — No scope.md existence check | Medium | Graceful degradation | `skills/analyze/SKILL.md` |
| R14 — Source quality invisible | Med-High | Work-item traceability | `templates/requirements.md` |

---

## What not to do

These would feel like improvements but would violate plugin principles:

- **Block on unmapped REQs.** The block vs. warn philosophy is deliberate. Unmapped REQs are scope questions, not errors. Block only when the consequence is severe and the false-positive rate is low.
- **Auto-detect source quality and skip phases.** Graceful degradation means surfacing the gap, not deciding for the human. If scope.md is missing, surface the gap; don't auto-classify requirements.
- **Add a separate "requirements review" skill or phase.** The fix for shallow review is a better gate summary, not a new phase. Adding surface area increases cognitive load.
- **Widen fix-fast eligibility to handle requirements gaps.** The fix-fast path is for ≤2 file, ≤50 LOC bug fixes. Requirements gaps are not bugs.

---

## Recommended sequencing if these risks are acted on

Fix by highest severity and smallest blast radius first:

1. **R2, R7, R8, R11, R14** — template changes only (`templates/requirements.md`). Lowest risk, highest leverage. No behavioral change to the skill.
2. **R1, R3, R10, R13** — skill additions (`skills/analyze/SKILL.md`). Pre-gate quality prompts and gate summary expansion. All warn-not-block.
3. **R4, R5, R6, R9** — skill additions with interactive prompts. Requires care to avoid cognitive load creep.
4. **R12** — hook change. Highest blast radius; test thoroughly before enabling.

Each item is one concern. Follow the plugin's own discipline: one skill or template per change.
