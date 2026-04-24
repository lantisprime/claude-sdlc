# Plan phase — scope ingest + domain expert discussion

> **Status:** discussion note. Not an RFC, not accepted. Captures current thinking on reshaping Phase 1 to reduce cognitive load around scope authoring and introduce domain-aware plan validation.

**Date:** 2026-04-24
**Scope:** Phase 1 (`/plan`) only. Skill-count audit explicitly deferred.
**Related:**
- `docs/rfcs/multi-team-approval.md` (accepted 2026-04-19) — sign-off conventions this proposal must conform to
- PR #1 *Guided-entry UX RFC (draft)* — overlapping "reduce cognitive load" thesis, pending Path A reshape

---

## Problem

`scope.md` today is authored by the human at first `/plan` invocation. Three failure modes compound:

1. **Format sprawl.** Real-world scope lives in PDFs, Word docs, PPTX briefs, Confluence pages, Notion, Jira epics. Today the human has to translate any of those into a one-paragraph chat statement or a hand-written markdown file.
2. **Quality uncertainty.** There's no validation that `scope.md` is clear, complete, or aligned with domain-specific regulations. The plan skill reads it and trusts it.
3. **Cognitive load.** Open-ended authoring ("write the scope statement") is higher-load than closed-form answering ("answer these 4 specific questions"). The plugin's own design philosophy — reduce surprise, reduce friction at the expensive moments — applies to scope too.

`scope.md` is the constitution every downstream phase validates against. Getting it wrong silently widens what the plugin permits for months. The failure cascades.

## What can't change

- **The human still signs the final scope.** Auto-generating without a signature breaks "human in the lead." The signature is the expensive, non-delegable act.
- **`scope.md` stays the canonical artifact.** Downstream phases already read it; changing the file path would ripple.
- **Graceful degradation.** Any new path must fall back cleanly when no source is available, same as the rest of the plugin.

## Proposed approach

Two new capabilities, both invoked internally by the existing `/plan` command. No new user-facing commands.

### 1. `scope-ingest` agent

Bounded subprocess with narrow write scope (`scope.md` and `scope-drafts/` only). Handles the expensive, messy work of turning source material into a normalized scope draft.

**Accepts:**
- File paths: `.md`, `.txt`, `.pdf`, `.docx`, `.pptx`
- URLs (with the honest caveat that auth-walled sources require the human to paste exported content)
- Ticket references (if Jira/Linear MCP is wired)
- Raw chat text
- An existing `scope.md` (re-validate mode — reads, reports drift, does not rewrite)

**Pipeline:**
1. Parse to plain-text blocks with provenance (source, page/section, line span)
2. Normalize into a fixed schema: `project_name`, `domain`, `in_scope[]`, `out_of_scope[]`, `success_criteria`, `constraints[]`, `stakeholders`, `assumptions`. Absent fields stay absent — no fabrication.
3. Emit a draft at `.claude/sdlc/scope-drafts/<timestamp>.md` with per-bullet provenance footer.
4. Return to plan skill: draft path + extraction confidence per field.

**Explicit non-goals:** writing `scope.md` directly, signing anything, deciding domain, fabricating missing fields.

**Why agent, not skill:** ingesting a 50-page PDF is expensive; bounding it to a subprocess keeps main-turn tokens sane. Narrow write scope is a real safety property, not cosmetic.

### 2. `domain-expert` skill

Read-and-inject pattern. Lightweight. Invoked by `/plan` now, reusable by `/analyze` and `/design` later.

**New directory at plugin root:**
```
domains/
├── _index.json          # keyword + stack → domain slug
├── _schema.md           # required shape for domain files
├── payments.md          # seed
├── auth.md              # seed
└── ...
```

**Domain file shape:**
```
---
slug: payments
last_reviewed: 2026-03-15
owner: <team-or-person>
---
# Payments

## Glossary
## Typical NFRs
## Regulatory concerns
## Common pitfalls
## Stack notes
## Security hotspots
## Scope must address
## Questions plan must answer
```

The `last_reviewed` + `owner` frontmatter is load-bearing — without it, domain files rot silently.

**Matching logic (3-tier, in order):**
1. Explicit `domain:` tag in `scope.md` frontmatter → authoritative
2. Rule match against `domains/_index.json` → confidence `high` / `medium` / `low`
3. No match → `domain: unknown`, proceed without injection

Low-confidence matches force human confirmation at the plan gate. No silent assignment.

**Output:** a `## Domain context` section injected into the plan artifact containing matched domain, confidence, unanswered `Questions plan must answer`, and `Scope must address` items the scope doesn't yet cover.

### 3. Modified `/plan` flow

6 steps instead of 5:

1. Classify work item *(unchanged)*
2. **Resolve scope** — if `scope.md` exists and is signed, read it. Otherwise invoke `scope-ingest` with whatever source the human points at. No source → prompt for one-paragraph statement (current fallback).
3. **Detect and load domain** — `domain-expert` reads problem + stack + scope, matches, produces gap questions.
4. Write plan artifact, including `## Domain context` section *(new)*
5. Record tech stack + compatibility matrix *(unchanged)*
6. Human gate — sign-off covers plan + domain confirmation

User sees same `/plan` command, same gate ritual. What changes is the quality of what lands in `scope.md` and the depth of the plan artifact.

### Cognitive load — honest accounting

**First `/plan` in a new repo (increases slightly):**
1. Point at a source (path, URL, or paste text)
2. Answer gap questions (closed-form, not open-ended)
3. Sign scope — new one-time step
4. Confirm domain if confidence isn't high
5. Sign plan gate — existing

**Subsequent `/plan` runs (roughly unchanged):**
1. Run `/plan "<task>"`
2. Confirm domain if confidence isn't high
3. Sign plan gate

The load reduction isn't "Claude writes it for you." It's **load shifting from open-ended authoring to closed-form answering.** Don't oversell it — first-time setup gets marginally heavier in exchange for better scope quality from day one.

---

## Conflict analysis — against accepted RFC and PR #1

### Direct conflicts with `multi-team-approval.md` (accepted)

**1. Sign-off filename convention.** Earlier draft of this proposal used `sign-offs/scope-<date>.md`. Accepted RFC uses `sign-offs/<REQ-ID>-<role>.md`. These don't align:
- Scope isn't tied to a REQ-ID (it's upstream of requirements)
- Scope may not have a single role signer

**Reshape:** either assign a synthetic REQ-ID (e.g., `REQ-SCOPE-<project>`) or carve out a named exception. Don't silently invent a parallel pattern — that's exactly the drift the accepted RFC prevents.

**2. Single-signer assumption.** Proposal wrote "human signs scope" in the singular. With the 9-role set and multi-team approval as accepted policy, certain domains probably need multi-role scope sign-off (payments: product + compliance + security). Current position: default single-role, with domain files declaring when multi-role is required. Needs the 9-role list to resolve.

**3. Transport ladder.** Proposal assumed chat sign-off as default. Accepted RFC defines Tiers 0–3. Can't say which tier scope sign-off belongs to without reading the ladder. Deferred.

**4. `APPROVALS.md` reconciler.** Proposal didn't mention it. Scope sign-off output needs to emit something the reconciler can parse. Format constraint unresolved.

### Overlaps with PR #1 (draft)

**1. Shared thesis — reduce cognitive load.** PR #1 comes at it from session/navigation angle (guided entry, session resume, back/cancel, error messages, `/status` detail). This proposal comes from the authoring/validation angle (ingest, domain validation, gap-report vs. blank-page). Both legitimate, not conflicting, but need coordination.

**2. Pending discussion A — workflow templates (per-task-type starters).** Conceptually close to domain files. Different framing — templates are per-task-type; domain files are per-domain — but a world exists where they're the same artifact. Worth asking before shipping whether they should merge.

**3. Pending discussion D — TodoWrite integration.** If long-running phases start using TodoWrite, `scope-ingest` (long-running on large PDFs) should participate in the same pattern.

**4. PR #1 PRs 1, 2, 3, 4, 6, 8, 9, 10** — contents not fetched from draft branch; any could touch Phase 1 UX. Unknown until read.

### What's clearly complementary (no conflict)

Untouched by either RFC:
- Multi-format ingestion
- Normalization schema + provenance
- `domains/` directory and matching logic
- `## Domain context` injection into plan artifact
- Gap-report-not-draft pattern
- Modifying plan Steps 2–3 internally
- `scope-ingest` as an agent

### What I can't see from outside the repo

Explicit: this analysis is partial without these.

1. Full text of `multi-team-approval.md` — needed to resolve sign-off filename, role assignment, transport tier, reconciler format.
2. The 10-PR contents in PR #1 — unknown overlap surface.
3. The 9-role set — determines scope sign-off role(s).

---

## Open questions / deferred

- **Domain file curation process.** Who owns `domains/payments.md`? How are updates reviewed? Same discipline as skills, or lighter? Decide later.
- **Scope regeneration policy.** When the source PDF updates to v4, what happens? Options: ignore / `/plan --refresh-scope` / warn on drift. Ship v1 without regeneration; observe.
- **Multi-domain matching.** v1 matches top-1 domain; human can override to multi. v2 could auto-match multi. Don't build upfront.
- **Workflow templates vs. domain files** (from PR #1 pending A). Unify or keep orthogonal. Decide before shipping domain-expert.
- **Sign-off role naming.** Tentative "scope-owner"; waits on 9-role set confirmation.

---

## Architectural decisions and tradeoffs

- **Agent for `scope-ingest`, skill for `domain-expert`.** Agent when bounded write scope + expensive isolated work justify the subprocess cost. Skill when it's a reusable read-and-inject pattern across phases. Converting everything to agents would increase token cost and reduce traceability.
- **No new commands.** Cognitive load lives at the command level, not the skill level. `/plan` stays the single entry point. Both capabilities hang off it internally.
- **`scope.md` is a derived, validated artifact — not an authoring target.** This reframe is load-bearing. It's what lets us accept any source format: the human points at source material, the plugin derives, the human validates and signs.
- **Gap report, not draft.** A draft invites rubber-stamping. A gap report forces targeted answers. This is the actual cognitive load reduction mechanism.
- **Provenance footer required.** Every scope bullet traces to its source span. Without this, LLM fabrication in the normalization step is undetectable at sign-off.

---

## Failure modes to guard against

- **Domain files too generic.** "Payments" covers too much → gap questions become noise → humans ignore → no value delivered. Start narrow; expand based on observed gaps.
- **Over-aggressive ingestion.** Fabricating scope from thin sources → subtly wrong signed scope → every downstream phase drifts. Mitigation: per-bullet provenance, source-next-to-extracted-bullet view before signing.
- **Onerous first-time setup.** If scope ingest + domain validation makes greenfield setup painful, teams skip the plugin. Mitigation: minimum-viable one-paragraph scope remains acceptable; gap questions are advisory unless domain file marks them `required`.
- **Stale domain files.** `last_reviewed` frontmatter required; owner required; treat as living docs.
- **Wrong domain match.** Wrong checklist → wrong gaps → misleading scope. Low-confidence matches must force human confirmation, not silently proceed.

---

## Suggested sequencing

1. **Wait on accepted-RFC vocabulary** before implementing the sign-off portion. Non-sign-off parts safe to prototype now.
2. **Write the domain file schema** (`domains/_schema.md`) + one seed file (`domains/payments.md`). Cheapest piece; validates shape before building consumers.
3. **Build `domain-expert` skill.** Needs only schema + index. Testable standalone against synthetic plan inputs.
4. **Build `scope-ingest` agent** — markdown + PDF parsers first; DOCX/PPTX/URL in a follow-up. Honest scoping.
5. **Modify `plan` skill** — wire in Step 2 (scope-ingest invocation) and Step 3 (domain-expert injection).
6. **Resolve sign-off alignment** once the accepted RFC's vocabulary is in hand. Rename artifact, pick role(s), emit reconciler-compatible output.
7. **Dry-run on 3–5 past plan artifacts.** Does the new flow produce better plans on real past work? If not, the domain files are wrong, not the architecture.
8. **Documentation pass** — README "Scope setup" section; `docs/SDLC.md` Phase 1 update.

---

## What would make this fail

Named so future reviewers can check:

- Shipping scope-ingest without the provenance footer (fabrication goes undetected)
- Shipping domain-expert with broad/vague seed domain files (gap questions become noise)
- Bypassing the accepted sign-off convention "just for scope" (drift that compounds)
- Adding `/scope` or similar commands (defeats the no-new-commands constraint)
- Treating the first-time-setup load increase as free (it's real; name it honestly in docs)

---

## Next actions

- Decide on workflow-templates-vs-domain-files unification before building seed domain files (coordinate with PR #1 pending A)
- Read `multi-team-approval.md` in full; update this note's conflict section
- Read PR #1's RFC body in full; update overlap section
