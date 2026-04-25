# Approval Packet: <phase>-<task-slug>

> **Summary only.** This packet is a compiled overview to reduce reviewer load. Source artifacts remain authoritative — follow the source links in each section for full detail. Do not sign off on the packet alone; read the linked artifacts.

- **Task:** <task-slug>
- **Phase:** plan | analyze | design | build | test | support
- **Plan version:** <N>
- **Prepared at:** <YYYY-MM-DDTHH:MM:SSZ>

---

## Scope

What is in scope and what is explicitly excluded for this task.

**In scope:**
- <item from plan In-scope files / In-scope functions>
- …

**Out of scope:**
- <item from plan Out-of-scope>
- …

Source: [`plans/<task-slug>.md`](.claude/sdlc/plans/<task-slug>.md)

---

## Delta from previous approved version

<!-- If this is Plan v1 (no prior signed version): state "First version — no prior approved plan." -->
<!-- If Plan vN (N > 1): summarise material field changes from vN-1 to vN -->

<Changes to Classification, In-scope files, In-scope functions, Out-of-scope, or Risks since the last signed version — or "First version — no prior approved plan.">

Source (prior version, if applicable): [`plans/<task-slug>.v<N-1>.md`](.claude/sdlc/plans/<task-slug>.v<N-1>.md)

---

## Risk level and justification

**Risk:** <low | medium | high>

<Verbatim or summarised risk justification from the plan's Risks section.>

Source: [`plans/<task-slug>.md`](.claude/sdlc/plans/<task-slug>.md) § Risks

---

## Mitigation and rollback plan

<Key mitigations from the plan or architecture artifacts. Include rollback steps if identified in the deployment or architecture artifact.>

Source: [`architecture/platform.md`](.claude/sdlc/architecture/platform.md) · [`plans/<task-slug>.md`](.claude/sdlc/plans/<task-slug>.md)

---

## Traceability

| REQ ID | Requirement summary | Test case | Status |
|--------|---------------------|-----------|--------|
| REQ-n  | <short description> | TC-n      | passed / pending |

Source: [`requirements/<task-slug>.md`](.claude/sdlc/requirements/<task-slug>.md) · [`test-cases/`](.claude/sdlc/test-cases/) · [`gates/build-<task-slug>.md`](.claude/sdlc/gates/build-<task-slug>.md)

---

## Decision required

<What the reviewer is being asked to approve: advancing the phase, accepting a risk level, signing off on scope, or a combination. Be specific — "approve advancing from design to build" is clearer than "approve the design.">

---

## Reason this role is required

<Why this role appears in the gate's `## Required sign-offs` block. E.g. "Security sign-off is required because this task modifies the authentication surface." Pull from the gate file or state the reason if known.>

---

## After reviewing

If you approve, write your sign-off file at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md` and include this packet as evidence:

```
evidence: .claude/sdlc/approval-packets/<phase>-<task-slug>.md
```

Using a relative file path keeps the reference in-repo and auditable. Per the evidence quality ladder, prefer this over external URLs or editable documents.
