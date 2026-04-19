# RFC: Multi-team approval across Claude Code sessions

**Status:** Draft — 2026-04-19. Supersedes [pending-analysis](./pending-analysis.md) §3. Recommends a single direction; not yet accepted. Comments in this file are in scope; amendments require a sign-off block at the bottom.

Related reading: [CLAUDE.md](../../CLAUDE.md), [docs/SDLC.md](../SDLC.md), [templates/sign-off.md](../../templates/sign-off.md).

---

## 1. Problem

Sign-offs today live in gate files, signed by a human editing the markdown. When one team owns the code, this is simple. When a change needs multiple teams' approval — security + product, backend + frontend, compliance + dev — the model breaks down:

- Team B is in a different repo / different Claude Code session
- Team A's session has no native way to see "has security signed off yet?"
- Coordination is ad-hoc (Slack, PR comments, "did you sign the gate file yet?")
- Audit trail is split across artifacts that don't reference each other

The existing `templates/sign-off.md` captures one approver against one change request. It has no notion of role, no notion of *which teams are still pending*, and no contract for how approvals arrive from other sessions or other tools.

## 2. Design goals (mapped to core principles)

| Principle | How this RFC respects it |
|---|---|
| 1. Human in the lead | Every sign-off is a human signature. No auto-approval, no subagent can produce one. |
| 2. Plan before code | Unchanged — approvals gate post-plan phases, not pre-plan. |
| 3. Surgical edits | Unchanged. |
| 4. Work-item traceability | **Strengthened.** Every approval references a REQ ID and a gate file. |
| 5. Graceful degradation | **Load-bearing.** Works fully offline with local files. Network share, git, and Slack are optional transports, never required. |
| 6. Stack-agnostic | **Load-bearing.** No tool-specific logic in skills or hooks. `APPROVALS.md` is plain markdown. Slack is a *file drop*, not an identity source. |

No direct conflict with the six principles.

## 3. Proposed design

### 3.1 Approval artifact contract

One file per signer, at `.claude/sdlc/sign-offs/<REQ-ID>-<role>.md`. The plugin's reconciler treats this location as **authoritative**: every transport syncs files *into* this directory.

Fields (YAML frontmatter + statement block):

```markdown
---
req_id: REQ-042
gate_ref: .claude/sdlc/gates/design-auth-refresh.md
role: security
signer: juan.delacruz@acme.com
timestamp: 2026-04-19T14:22:00Z
transport: network-share
evidence: share://approvals/REQ-042/security.md
---
I, Juan Dela Cruz (Security), approve REQ-042 per gate `design-auth-refresh`.
Reviewed threat model §3; OWASP A02 addressed.
```

This extends [templates/sign-off.md](../../templates/sign-off.md) with three fields needed for cross-team reconciliation (`role`, `transport`, `req_id`) while preserving the original's approver/date/evidence/statement shape. A new template `templates/sign-off-multi.md` will mirror this contract.

**Why one file per signer, not one file per gate:** parallel signing. Two teams can produce their files independently without merge conflicts. The reconciler composes them into a gate view.

### 3.2 Gate-file integration

Gate files declare required sign-offs in a new, parseable block:

```markdown
## Required sign-offs
- security
- product
- compliance
```

Roles are free-form strings; the plugin doesn't enforce a fixed vocabulary. Teams define their own.

### 3.3 Reconciliation hook

A new hook `hooks/approval-reconcile.sh` runs:

- **PreToolUse** on phase-advance commands (`/test`, `/deploy`, etc.) — reads the current gate file's `## Required sign-offs` block, checks `.claude/sdlc/sign-offs/` for one file per required role, and **warns (exit 0 with stderr)** if any are missing.
- **Stop** — same check, surfaces status in the turn summary.

Warn, not block — consistent with the plugin's hook-strictness philosophy (CLAUDE.md §"Hook strictness"). The human decides whether to proceed.

**Escalation to block** requires an explicit config flag `approvals.block_on_missing: true`, off by default. Teams opting in accept the false-positive risk.

### 3.4 Transport ladder

Transports *deliver* sign-off files into `.claude/sdlc/sign-offs/`. They never replace it.

| Tier | Transport | Config key | When used | Failure mode |
|---|---|---|---|---|
| 0 | Local file | — | Baseline; signer authors the file in their own session | Always works |
| 1 | Network share | `approvals.share_path` | Enterprise environments with SMB/NFS; cross-repo visibility | Reconciler warns if path unreachable; local still works |
| 2 | Git central repo | `approvals.git_repo` | Orgs with a shared git host; strong audit trail | Warn on fetch failure; local still works |
| 3 | Slack file drop | `approvals.slack.*` | Teams wanting "attach signed file in thread" convenience | Warn if sidecar absent; local still works |

**Local is authoritative.** All transports are eventual-consistency pipes. A signer who authors the file locally and commits it has produced a valid sign-off regardless of transport availability.

### 3.5 Git mirror: `APPROVALS.md`

When the repo is git-tracked, the reconciler regenerates a tracked file `APPROVALS.md` at the repo root listing open and closed approvals:

```markdown
# Approvals

Generated by approval-reconcile.sh — do not edit by hand.

## Open
- REQ-042 — waiting on: compliance
  - [x] security — juan.delacruz@acme.com — 2026-04-19
  - [x] product — (pending)
  - [ ] compliance — (pending)

## Closed
- REQ-039 — all sign-offs received 2026-04-12
```

This is the "todo in git" surface: pending approvals show up in PR diffs, git blame, and any tool that reads markdown. It is plain markdown — no GitHub-specific integration, no Jira hook. Stack-agnostic.

**Regeneration vs. hand-edit:** the file is machine-generated; hand-edits are overwritten. A header comment warns. Teams that want richer tracking can add a separate hand-edited file; the plugin owns only `APPROVALS.md`.

### 3.6 Identity model

Slack is a **file-drop transport, not a signature source.** A signer authors the sign-off file (in their own Claude Code session or by hand), uploads it to a Slack thread, and an optional sidecar moves it into `sign-offs/`. The plugin does not read Slack user IDs, does not map them to emails, and does not trust Slack's authentication layer.

Three alternatives were considered and rejected (see §5).

**Consequence:** the "approve from my phone by replying yes" pattern is *not supported by this RFC*. Teams that want it must build a sidecar outside the plugin that produces a valid sign-off file on their behalf. The plugin reconciles whatever files appear in `sign-offs/`.

## 4. Degradation matrix

| Scenario | Behavior | Principle |
|---|---|---|
| No network, no git, no Slack | Local `sign-offs/` only. All signers commit files directly. | 5 — always works offline |
| Share configured but unreachable | Warn on reconcile; local signatures still count | 5 |
| Git configured but unreachable | Warn on reconcile; `APPROVALS.md` regenerates from whatever is local | 5 |
| Slack sidecar absent | Warn only if `approvals.slack.*` is set; signers fall back to direct file commit | 5 |
| Required role has no sign-off file | Warn (default) or block (if `approvals.block_on_missing: true`) | 1 — human decides |
| Sign-off file present but `gate_ref` points at a gate that doesn't exist | Warn; reconciler flags as "orphan" | 4 |

## 5. Alternatives considered

Mapped to the five options in [pending-analysis.md §3](./pending-analysis.md#3-multi-team-approval-across-claude-code-sessions):

| Option (pending-analysis) | Decision | Reason |
|---|---|---|
| A — multi-signature gate files | **Partially adopted.** We keep the gate file as the declaration of required signers (3.2), but move the signatures themselves into per-signer files (3.1) so teams sign without merge conflicts. | Parallel signing. |
| B — external approval references | **Absorbed.** The git transport (3.4 tier 2) is a constrained form of this. | Simpler than arbitrary URL refs. |
| C — shared central approvals repo | **Adopted as tier 2.** Not as the primary model. | Graceful degradation requires local to be canonical. |
| D — integrate with GitHub / Jira / etc. | **Rejected for the plugin core.** Users who want this can add a sidecar. | Principle 6 — stack-agnostic. |
| E — document the manual pattern, don't solve | **Rejected.** The artifact contract is cheap, the reconciler is cheap, and the gap is real. | Demand is concrete. |

Rejected identity models (for §3.6):

| Model | Why rejected |
|---|---|
| Slack author = signer | Requires Slack API integration; spoofable if channel→role isn't enforced; Slack messages are editable |
| Signed phrase / HMAC challenge | Signers must manage secrets; friction for product/compliance signers; overkill |
| Two-factor (Slack + local confirm) | Two steps per approval kills the mobile-convenience value |

## 6. Open questions

Each question below must be answered before the RFC can be marked **Accepted** in §8. A proposal is recorded for each; reviewers either confirm the proposal (write "confirm proposal") or replace it with an alternative. Record the resolution inline under **Answer**.

### 6.1 Locking on network shares

Concurrent writes from two sessions to the same share path — acceptable or needs file locking? SMB and NFS behave differently.

- **Proposal:** rely on one-file-per-signer to avoid overlap; document that the plugin does not implement locking.
- **Answer:** _pending_

### 6.2 `APPROVALS.md` regeneration timing

On every reconcile run, or only on phase advance?

- **Proposal:** on every reconcile (cheap; keeps the file fresh).
- **Answer:** _pending_

### 6.3 `/fix-fast` interaction

The fast-path collapses Plan + Analyze + Design; cross-team approval is almost certainly out of scope for a ≤2-file, ≤50-LOC fix.

- **Proposal:** `/fix-fast` does not parse `## Required sign-offs` and does not run the reconciler. Documented exception.
- **Answer:** _pending_

### 6.4 Role vocabulary

Free-form per §3.2, but should the plugin ship a suggested list (security, product, compliance, sre, legal)?

- **Proposal:** yes, in [docs/SDLC.md](../SDLC.md) as guidance, not enforcement.
- **Answer:** _pending_

### 6.5 Signer revocation

If Juan signs, then the design changes substantively — is Juan's sign-off auto-invalidated?

- **Proposal:** no, but the reconciler warns when `gate_ref`'s mtime is newer than the sign-off's `timestamp`. Human judgment call.
- **Answer:** _pending_

### 6.6 Evidence field integrity

Can the `evidence` URL point at something mutable (a Slack message that gets deleted)?

- **Proposal:** document that evidence should be immutable where possible; no enforcement.
- **Answer:** _pending_

## 7. Rollout

Incremental. Each step is independently valuable and stops a useful place:

1. **Contract + template + reconciler (tier 0 only).** Ship [templates/sign-off-multi.md](../../templates/), `hooks/approval-reconcile.sh`, and the `## Required sign-offs` gate-file convention. Teams can already do multi-team approval via local files + manual distribution.
2. **Git mirror (`APPROVALS.md`).** Add the generator. Stack-agnostic; no config.
3. **Network share transport (tier 1).** Add `approvals.share_path` support. Simple copy-in, copy-out.
4. **Git transport (tier 2).** Add `approvals.git_repo` with fetch/push semantics.
5. **Slack sidecar (tier 3).** Document the contract for external sidecars; ship a reference implementation *outside* the plugin core if demand warrants.

Stop after step 1 if usage stays flat. Each further step is gated on seeing real adoption of the previous one.

## 8. Decision & sign-off

**Decision:** *pending.*

**Prerequisite:** all six questions in §6 must have a recorded **Answer** before this section can be signed. A sign-off here attests that the answers in §6 are the ones the plugin will implement.

When accepted, this RFC will be marked **Accepted** and the `Status` line updated with the accepting reviewer and date. [pending-analysis.md §3](./pending-analysis.md#3-multi-team-approval-across-claude-code-sessions) will be updated to point at the accepted RFC and the implementation work.

### Sign-off

- **Maintainer:** (pending)
- **Date:** (pending)
- **Statement:** (pending)
