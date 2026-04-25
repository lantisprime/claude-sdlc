# Glossary

Terms introduced by this plugin that aren't obvious from context or that differ from common usage.

---

## Scope draft

A normalized, provenance-traced markdown file produced by the [`scope-ingest`](../agents/scope-ingest.md) agent from raw source material (README, project brief, spec, pasted text). Lands at `.claude/sdlc/scope-drafts/<timestamp>.md`.

Not authoritative — it is a working draft the human reviews and corrects before promoting to `scope.md`. Contains extraction-confidence annotations (`high` / `medium` / `low` / `absent` per field) and per-bullet provenance comments tracing each claim to its source.

## Provenance footer

The HTML comment beneath each bullet in a scope draft (and in domain file drafts produced by Path A authoring) that records where the information came from:

```html
<!-- source: README.md, ## Security, lines 223–229 -->
```

Lets the human verify what was inferred vs. what was stated explicitly. Stripped from the final file when the human confirms a section is accurate.

## Scope gate

A phase-gate-shaped sign-off file at `.claude/sdlc/gates/scope-<project>.md`, produced once per project before the first `/plan` completes. Uses [`templates/scope-gate.md`](../templates/scope-gate.md).

Signals that the team has reviewed and accepted the scope statement as the basis for planning. The `plan-gate.sh` hook warns (not blocks) when this file is absent. REQ ID format: `REQ-SCOPE-<project-slug>`.

Implemented as a **pseudo-phase gate** for v1 — same file shape and reconciler behavior as phase gates, but not tied to any of the 8 phases. If post-ship usage shows that the "pre-Plan gate" label causes operator confusion, it will be promoted to a first-class artifact class in v2.

## Domain context

The `## Domain context` section the `domain-expert` skill appends to a plan artifact when a domain match is found. Contains:

- Matched domain name and confidence level
- `## Scope gaps` — items from `Scope must address` not covered in `scope.md`
- `## Unanswered questions` — questions from `Questions plan must answer` not addressed in the plan or scope
- `## NFR reminders` — non-functional requirements that apply to almost every project in the domain
- `## Security hotspots` — areas where security errors are most likely in this domain

`⚠️` marks questions flagged `required: true` in the domain file. These are warn-level only — they do not block the plan gate.

## Gap questions

The `## Questions plan must answer` bullet list in a domain file. Surfaced in `## Domain context` when the question is not addressed in the plan body or `scope.md`. Questions marked `(required: true)` produce a `⚠️` warn-level flag; unmarked questions are advisory. Neither form hard-blocks the plan gate.

## Domain miss

The state when the `domain-expert` skill runs and finds no matching domain — neither an explicit `domain:` tag in `scope.md` frontmatter nor a keyword/stack match in `_index.json`. Result: `domain: unknown`; no `## Domain context` is written.

When a domain miss occurs in a clearly domain-sensitive context, the skill offers the authoring flow once per session. If the human declines, a `domain_authoring_declined: true` flag is written to `.claude/sdlc/hints.jsonl` and the offer is suppressed until the next session.

## Two-source lookup

The `domain-expert` skill's resolution strategy for domain files. Checks two locations in order:

1. **Project-level `domains/`** — the consuming repo's own domain files. Takes precedence.
2. **Plugin-level `domains/`** — the plugin's built-in seeds (`payments`, `auth`).

Both `_index.json` files are merged at match time with project rules evaluated first. If both locations define a file for the same slug, the project-level file is used exclusively — no content merging.

Absent project `domains/` → plugin-only lookup. Both absent → `domain: unknown`.

## Suggested roles

The optional `suggested_roles:` frontmatter field in a domain file. Lists roles (e.g. `[security, compliance]`) that typically sign off on work in this domain. **Advisory only** — surfaces in `## Domain context` as a display note. Never written to a gate file's `## Required sign-offs` block. Gate sign-offs are driven by `approvals.roles` in `config/tools.json` or explicit human input, not by this field.

## Extraction confidence

A per-field label the `scope-ingest` agent attaches to each field in a scope draft:

| Label | Meaning |
|---|---|
| `high` | Value appears verbatim or near-verbatim; minimal interpretation |
| `medium` | Inferred from context; reasonable but not explicit |
| `low` | Guessed; source is thin; human should verify or remove |
| `absent` | Source has no content for this field |

Low-confidence fields get a `⚠️` header prefix in the draft. Absent fields are omitted entirely.
