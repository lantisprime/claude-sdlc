# Domain file schema

This file defines the contract all domain files in `domains/` must follow. Write `_schema.md` before writing the first seed file so seeds validate the schema rather than define it.

---

## Frontmatter

```yaml
---
slug: <string>           # required — unique identifier, matches filename (e.g. payments)
last_reviewed: <date>    # required — YYYY-MM-DD; without this, the file rots silently
owner: <string>          # required — team or person responsible for keeping this accurate
suggested_roles: []      # optional — list of role strings from the accepted 9-role vocabulary
                         # surfaced as advisory context in ## Domain context of the plan artifact
                         # NEVER written into the gate file's ## Required sign-offs block
---
```

`suggested_roles` is display-only advisory. The plan skill surfaces it in `## Domain context` as "this domain typically involves [roles]." It does not enforce or override `approvals.roles`. If `approvals.roles` is absent, the gate file's sign-offs block stays empty until the human fills it.

---

## Required sections

Every domain file must have both of these sections. Empty sections are omitted entirely — present-but-empty adds noise without signal.

### `## Scope must address`

Bullet list of items that a valid `scope.md` for this domain must cover. The `domain-expert` skill surfaces any of these not present in the scope as gaps.

Example:
```
## Scope must address
- PCI scope boundary: which systems are in-scope, and how is cardholder data isolated
- Data residency requirements
```

### `## Questions plan must answer`

Bullet list of questions the plan artifact must address before the plan gate can be signed. Each question is advisory by default. Mark `required: true` to produce a warn-level flag when the plan doesn't address it.

Per the repo's hook philosophy (`CLAUDE.md`): warn-level flags are surfaced; humans decide whether to proceed. `required: true` does NOT hard-block — it produces a visible warning. Only mark required when an unanswered question genuinely voids the plan's correctness.

Format:
```
## Questions plan must answer
- Which payment processor is in use? (required: true)
- Is the scope PCI-DSS scoped? If yes, how is cardholder data handled?
- What is the idempotency strategy for payment operations?
```

---

## Optional sections

Include only when the domain has meaningful content for the section. Omit otherwise.

| Section | What goes here |
|---|---|
| `## Glossary` | Domain-specific terms likely to be misunderstood outside the domain |
| `## Typical NFRs` | Non-functional requirements that apply to almost every project in this domain |
| `## Regulatory concerns` | Compliance frameworks relevant to this domain; name the framework, not unsupported guarantees |
| `## Common pitfalls` | Mistakes that recur in this domain and aren't obvious |
| `## Stack notes` | Framework/library considerations specific to this domain |
| `## Security hotspots` | Areas where security errors are most likely; concrete, not generic |

---

## Maintenance rules

- `last_reviewed` must be updated whenever content changes. A file not reviewed in over 12 months should be flagged as stale.
- `owner` must be a real team or person. "Unknown" is not acceptable — without an owner, the file has no one to flag drift.
- Gap questions and scope requirements must be narrow enough to be answerable. A question so broad it applies to every project belongs in `skills/plan/SKILL.md`, not here.
- Regulatory section must name specific frameworks (PCI-DSS, GDPR, HIPAA). It must not assert the plugin delivers compliance — that is an unsupported claim.
