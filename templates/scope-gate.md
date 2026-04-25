# Scope Gate: <project-slug>

- **REQ ID:** REQ-SCOPE-<project-slug>
- **Scope draft:** `.claude/sdlc/scope-drafts/<timestamp>.md`
- **Scope file:** `.claude/sdlc/scope.md`
- **Signed by:** <human name or email>
- **Signed at:** <YYYY-MM-DDTHH:MM:SSZ>
- **Work-item reference:** <URL of REQ / ticket / CR, or `no ticket REQ-SCOPE-<project-slug>` in degraded mode>
- **gate_hash:** sha256:<hash of file content above the ## Required sign-offs heading, computed at signing time>

## Scope summary

<One paragraph: what the scope covers, what source material was used, and any significant items that are explicitly out of scope.>

## Source material

- **Source:** <file path, URL, or "pasted text">
- **Extraction confidence:** <high / medium / low per field, or "manual entry">
- **Provenance:** see `.claude/sdlc/scope-drafts/<timestamp>.md` for per-bullet source spans

## Scope fields confirmed

Check each field that was explicitly reviewed and accepted. Unchecked fields were absent in the source or deferred:

- [ ] Project name
- [ ] Domain
- [ ] In scope
- [ ] Out of scope
- [ ] Success criteria
- [ ] Constraints
- [ ] Stakeholders
- [ ] Assumptions

## Open items carried forward

<Items in the scope draft that were flagged as low-confidence or absent, and what the plan must address to resolve them. If none, write "None.">

## Explicit waivers (if any)

- <scope item skipped>: <reason> — accepted by <name>

## Acknowledgment

<The user's raw sign-off message, quoted verbatim.>

## Confirmation

I have reviewed the scope draft, corrected any extraction errors, and approve this scope as the basis for planning.

---

## Required sign-offs

<!-- Populated from approvals.roles in config/tools.json, or filled in by the human at scope-gate time.     -->
<!-- The gate-signoff skill writes suggested_roles from the domain file here ONLY if approvals.roles is set. -->
<!-- If approvals.roles is absent, leave this block empty until the human fills it.                          -->
<!-- Format: one role per line, e.g.:                                                                        -->
<!--   - product                                                                                             -->
<!--   - security                                                                                            -->
