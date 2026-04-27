# Domain File Authoring

Two paths for creating a domain file when no match exists. Both are offered inline from the `domain-expert` skill during `/plan` — no separate command is needed.

---

## Path A — Source-driven ingest

Use when the human has a URL (spec, compliance guide, vendor docs, internal wiki page) they want to convert into a domain file.

### Steps

**Step 1 — Collect the source**

Ask for the URL:

> Paste the URL of the source to ingest (e.g. a Stripe docs page, PCI-DSS summary, internal wiki page).

Accept one URL per run. If the human pastes multiple, ingest the first and offer to repeat for the others.

**Step 2 — Fetch and extract**

Fetch the page content. Extract:

- Domain name (slug candidate)
- Glossary terms (defined terms, abbreviations)
- NFRs or SLAs (any numbers, thresholds, time bounds)
- Regulatory references (named frameworks, standards, acts)
- Common pitfalls or antipatterns
- Stack or library references
- Security guidance

If the page is behind auth or returns an error, stop and tell the human — do not silently proceed with an empty extraction.

**Step 3 — Draft the domain file**

Produce a draft using `domains/_schema.md` as the contract. Fill all required sections from extracted content. Omit optional sections that have no extracted content — do not pad with generic filler.

Frontmatter:
```yaml
---
slug: <derived from domain name>
last_reviewed: <today's date>
owner: <ask the human — "who owns this domain file?">
suggested_roles: []   # human fills in later if desired
---
```

**Step 4 — Show draft and confirm**

Display the full draft in chat. Ask:

> Does this look right? Type **yes** to write it, **edit** to give me corrections, or **discard** to cancel.

On **edit**: apply corrections and show the revised draft. Repeat until the human types **yes** or **discard**.

**Step 5 — Write and register**

On **yes**:

1. Ask where to write it:
   > Write to project `domains/<slug>.md` (local, takes precedence) or plugin `domains/<slug>.md` (shared across projects)?

   Default: project-level unless the human says otherwise.

2. Write the file. Do not overwrite an existing file without explicit confirmation.

3. If a `_index.json` exists at the target level, ask the human for 3–5 keywords to add as a `high`-confidence rule for this slug. Write the new rule entry at the top of the rules array (project rules are evaluated first).

4. Report: "Domain file written to `domains/<slug>.md`. Re-running domain lookup…" then re-run the domain-expert skill.

**Provenance note:** Write a comment at the bottom of the domain file:

```markdown
<!-- Ingested from: <url> on <date>. Review before publishing to shared domains/. -->
```

---

## Path B — Guided Q&A

Use when no external source exists or the human prefers to answer questions directly.

### The 6 questions

Ask one at a time. Wait for a full answer before asking the next. Don't batch them.

---

**Q1 — What is the domain?**

> What domain are we working in? (e.g. "insurance claims processing", "real-time bidding", "medical records")

Use the answer to set the `slug` (lowercase, hyphens for spaces). Confirm the slug: "I'll use `<slug>` as the domain identifier — OK?"

---

**Q2 — What are the core concepts?**

> What are 3–5 terms in this domain that engineers outside it often misunderstand or misuse? Give a name and a one-sentence definition for each.

These become the `## Glossary` section. If the human gives fewer than 3, prompt once: "Any others? Even 1–2 more helps future engineers."

---

**Q3 — What must always be true? (NFRs)**

> What non-functional requirements apply to almost every project in this domain? Think: latency targets, idempotency rules, audit trail requirements, data retention rules.

Accept a free-form answer. Extract bullet-level NFRs. If the answer is vague, ask one clarifying follow-up: "Any specific thresholds or time bounds?"

---

**Q4 — What are the common mistakes?**

> What mistakes do engineers commonly make in this domain — things that aren't obvious and often cause incidents or compliance issues?

Accept 2–5 pitfalls. If the human gives only 1, prompt once: "Any others?"

---

**Q5 — What does a scope document need to cover?**

> When planning a project in this domain, what topics must the scope document address before the team starts building? (These become checklist items that flag gaps.)

These become `## Scope must address` bullets.

---

**Q6 — What questions must a plan answer?**

> What questions must a plan answer before you'd be confident the team understands the domain risks? Mark any question as required if an unanswered plan would be genuinely incomplete.

Format: list of questions. For each, ask: "Is this required (plan is invalid without it) or advisory?" Required questions get `(required: true)` in the domain file.

---

### After Q6 — Draft and confirm

Assemble the answers into a domain file draft (same schema as Path A). Show it and ask:

> Here's the domain file. Type **yes** to write it, **edit <section>** to revise a section, or **discard** to cancel.

On **edit**: re-ask the relevant question and show the revised draft. Repeat.

On **yes**: proceed with **Step 5** from Path A (write + register + re-run lookup).

---

## Shared rules for both paths

- Never write a domain file to a path the human didn't approve.
- Never overwrite an existing domain file without explicit "yes, overwrite" confirmation.
- `suggested_roles` is always left empty in the draft — the human fills it in if desired. Do not guess roles.
- `owner` must be a real team or person name — ask the human. Do not write `unknown`.
- After writing, always re-run the domain-expert skill so `## Domain context` is injected into the current plan.
