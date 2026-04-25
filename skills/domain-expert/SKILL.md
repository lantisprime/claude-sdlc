---
name: domain-expert
description: Use this skill during /plan (between scope validation and writing the plan artifact) to inject domain-specific context, gap questions, and regulatory concerns into the plan. Triggers automatically when the plan skill detects a scope.md or task description containing domain-sensitive keywords (payment, stripe, checkout, billing, pci, authentication, oauth, jwt, mfa, login — and many others listed in domains/_index.json). Produces a ## Domain context section in the plan artifact. Also triggers when the human says "add domain context", "what are the domain concerns here", or "check domain rules".
---

# Domain Expert

Inject domain knowledge — gap questions, NFRs, regulatory flags, security hotspots — into the plan artifact before the human reviews it. The goal is to surface what the plan might be missing, not to expand its scope.

## When this skill runs

Invoked by the `plan` skill between Step 2 (scope validation) and Step 3 (write the plan). It runs when any of the following are true:

- The plan task description or `scope.md` matches a rule in the merged domain index (see **Domain lookup** below).
- The `scope.md` frontmatter contains an explicit `domain:` tag.
- The human explicitly asks for domain context.

If neither condition is met, this skill exits silently — no `## Domain context` section is written.

## Domain lookup

Two directories are checked, in this order:

1. **Project-level** — `<repo-root>/domains/` (the consuming project's own domain files)
2. **Plugin-level** — `<plugin-root>/domains/` (the plugin's built-in seeds)

Each directory may contain `_index.json` (matching rules) and `<slug>.md` (domain content files).

**Index merge:** Load both `_index.json` files. Append project rules before plugin rules — project rules are evaluated first. If both indices define rules for the same slug, project rules for that slug take precedence (the project's version is evaluated; plugin rules for that slug are skipped entirely).

**Content resolution:** When a slug is matched, look for `<slug>.md` in the project directory first. If found, use it exclusively. If not found, fall back to the plugin directory. There is no merging of content files — one file wins entirely.

If neither `domains/` directory exists, exit silently with `domain: unknown` — do not produce a `## Domain context` section.

## Matching: 3-tier resolution

**Tier 1 — Explicit tag (authoritative)**

Read `scope.md` frontmatter. If a `domain:` field is present and non-empty, that value is the slug. Skip index evaluation entirely. Confidence is `explicit`.

```yaml
# scope.md frontmatter
domain: payments
```

**Tier 2 — Index rule match**

Scan the task description and `scope.md` body against the merged `_index.json` rules. Each rule has:

- `slug` — the domain it maps to
- `confidence` — `high`, `medium`, or `low`
- `keywords` — list of terms to match. Single-word entries use whole-word matching; multi-word entries (e.g. `"access token"`, `"session management"`) are phrase-matched — the entire phrase must appear in the text, not any word in isolation. Case-insensitive in both cases.
- `stacks` — list of stack/library names to match against the plan's technology stack section

Rules are evaluated in order; first match at each confidence level wins. Confidence levels:

| Confidence | Behavior |
|---|---|
| `high` | Proceed without confirmation. Write `## Domain context` using the matched domain file. |
| `medium` | Ask the human to confirm before injecting: "I matched this task to the **payments** domain (medium confidence). Proceed with domain context injection?" On confirmation, proceed. On decline, treat as `unknown`. |
| `low` | Always confirm before injecting, even when the threshold is low. |

**Tier 3 — No match**

Set `domain: unknown`. Do not inject a `## Domain context` section. Offer the authoring flow (see **Domain miss**) only if the plan involves a specialized or regulated area that the human names — do not offer it for every unmatched task.

## Output: `## Domain context` section

Append the following section to the plan artifact (`.claude/sdlc/plans/<task-slug>.md`) immediately after the `## Approach` section:

```markdown
## Domain context

**Domain:** payments (high confidence)
**Domain file:** domains/payments.md (plugin-level)

> This domain typically involves: product, security, compliance.
> Advisory only — these roles are not written into the gate file's ## Required sign-offs block.

### Scope gaps

The following items from `## Scope must address` in the domain file are not covered by the current scope:

- [ ] PCI scope boundary: which systems are in-scope, and the strategy for reducing scope
- [ ] Idempotency strategy for charge and refund operations

If the scope intentionally excludes these, note that in `scope.md` to suppress future flags.

### Unanswered questions

Questions from `## Questions plan must answer` not addressed in the **plan body or `scope.md`**:

- ⚠️ **Which payment processor is in use, and which SDK/API version?** *(required — plan is incomplete without this)*
- ⚠️ **Is this change PCI-scoped? If yes, what is the cardholder data isolation strategy?** *(required — plan is incomplete without this)*
- What is the idempotency key strategy for mutating operations (charges, refunds, captures)?
- How are webhook events authenticated (signature verification mechanism)?

Questions marked ⚠️ required produce a warn-level flag. They do not block the plan gate — the human decides whether to answer them now or proceed with acknowledged gaps.

### NFR reminders

- All payment operations must be idempotent.
- Webhook endpoints must respond within 5 seconds.
- Cardholder data must never appear in application logs or error messages.

### Security hotspots

- Payment form inputs must be hosted fields or fully PCI-scoped.
- Webhook endpoint: must be signature-verified; rate-limit separately.
- Processor API keys must not be committed; rotate on any suspected exposure.
```

**Formatting rules:**

- `suggested_roles` → advisory sentence only, inside `## Domain context`. Never written to `## Required sign-offs` in any gate file.
- `required: true` questions → `⚠️` prefix + italic qualifier. Warn-level only (exit 0 in hook terms). Never hard-block the plan gate.
- Scope gaps → unchecked checkboxes so the human can tick them off as they address each item.
- If all scope items are covered and all required questions are answered → write a brief "No gaps found" note and omit the subsections.
- **Answer search order:** before marking a question as unanswered, check (1) the plan body, then (2) the signed `scope.md` if it exists. A question answered in `scope.md` is answered — do not flag it. Only emit ⚠️ when the question is genuinely unaddressed in both.

## Domain miss

When no domain matches and the task involves an area that looks specialized or regulated (the human has named a domain or the context is clearly sensitive), offer the authoring flow once per session:

> No domain file found for this area. Would you like to add one? I can:
>
> **A — Source-driven ingest:** paste a URL (docs, spec, compliance guide) and I'll draft a domain file from it.
> **B — Guided Q&A:** answer 6 questions and I'll build the file interactively.
>
> Type **A**, **B**, or **skip** (won't ask again this session).

On **skip**, write `domain_authoring_declined: true` to `.claude/sdlc/hints.jsonl` and do not offer again until the next session.

On **A** or **B**, run the authoring flow (see `skills/domain-expert/AUTHORING.md`). On completion, re-run domain lookup with the new file and inject `## Domain context` as normal.

## What this skill must NOT do

- Do not write anything into a gate file's `## Required sign-offs` block. `suggested_roles` is advisory context, not a sign-off requirement.
- Do not hard-block the plan gate for unanswered required questions. Warn; let the human decide.
- Do not merge content from two domain files for the same slug — one source wins entirely (project-level takes precedence).
- Do not ask the human to confirm a `high`-confidence match — inject silently.
- Do not offer the authoring flow for every unmatched task — only when the context is clearly domain-sensitive.
- Do not modify `scope.md` — it is the human's artifact. Write `## Domain context` into the plan artifact only.

## Graceful degradation

| Condition | Behavior |
|---|---|
| No `domains/` directory at either level | Exit silently; `domain: unknown`; no `## Domain context` written |
| `_index.json` missing but `<slug>.md` exists | Skip rule matching; tier 1 (explicit tag) still works |
| Domain file exists but has no `## Questions plan must answer` | Omit that subsection from `## Domain context` |
| Domain file exists but has no `## Scope must address` | Omit that subsection from `## Domain context` |
| `scope.md` does not exist | Match against task description only; note absence in `## Domain context` |
| Human declines medium/low-confidence confirmation | Treat as `unknown`; do not inject |

## Related

- [`domains/_schema.md`](../../domains/_schema.md) — contract all domain files must follow
- [`domains/_index.json`](../../domains/_index.json) — built-in matching rules
- [`skills/domain-expert/AUTHORING.md`](./AUTHORING.md) — Path A (source ingest) and Path B (guided Q&A) authoring flows
- [`skills/plan/SKILL.md`](../plan/SKILL.md) — the skill that invokes this one
- [`docs/rfcs/scope-ingest.md`](../../docs/rfcs/scope-ingest.md) — design decisions behind this skill
