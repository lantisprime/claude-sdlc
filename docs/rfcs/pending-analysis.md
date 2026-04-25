# Pending Analysis

Open design questions that need deeper analysis before the plugin commits to a direction. Each item is a problem + options + tension with core principles + next steps — **not** a proposed change. Nothing on this page is a decision.

If you're evaluating the plugin: these are known gaps the maintainers are thinking about, not silent ones.

---

## 1. Spike / exploratory-work bypass

### Problem

Teams have legitimate needs for throwaway, exploratory code — spikes, prototypes, PoCs, live-debug sessions. The plugin's `plan-gate.sh` blocks `Edit`/`Write` without a plan; `work-item-validation.sh` requires a REQ ID or ticket. Both are correct for code intended to merge and wrong for code intended to delete.

[docs/when-not-to-use.md](../when-not-to-use.md) currently recommends **not installing the plugin** in spike repos (Option A). That works for dedicated spike repos. It does **not** cover:

- Mid-task spikes — you're in a normal 8-phase task and need to spike a library choice for 30 minutes
- Shared repos where spike work happens on `spike/*` branches alongside production code
- Teams that want a single uniform toolchain across spike and production work

### Tension with core principles

| Principle | Tension |
|---|---|
| 1. Human in the lead | Neutral — any bypass is human-initiated |
| 2. Reduce cognitive load | **Tension (Option B).** A marker-file mode adds a new state the human must track — is spike mode active? did the pre-commit hook stamp these files? Options A, C, D are neutral. |
| 3. Plan before code | **Direct conflict.** A bypass skips the plan-gate. |
| 4. Surgical edits | Neutral — spike code is not merged, so scope doesn't matter |
| 5. Work-item traceability | **Direct conflict.** Spikes have no REQ ID by definition. |
| 6. Graceful degradation | Aligned — bypass as "degrade to no-plugin" is consistent |
| 7. Stack-agnostic | Neutral |

[CLAUDE.md](../../CLAUDE.md) is explicit: *"Don't add a 'quick fix' escape hatch that bypasses [work-item traceability]"* and *"I'll add a convenience path for small changes — that's what `/fix-fast` already is. Don't add a second one."* Any option on this item has to be evaluated against those constraints. This page surfaces the constraint; the decision is open.

### Options considered

| Option | Description | Surface area | Abuse risk |
|---|---|---|---|
| A | Docs-only: don't install the plugin for spike repos/branches (current) | Zero | Low |
| B | `/spike` command that creates a time-bounded marker file; hooks allow edits while marker is live; a pre-commit hook refuses to merge files stamped during spike mode | High | Medium — teams may abuse the marker; also conflicts with principle 2 (cognitive load: new mode state to track) |
| C | `/spike` as a pure docs-pointer command — prints bypass guidance, no behavior change | Low | None |
| D | Environment variable (`CLAUDE_SDLC_SPIKE=1`) that disables the plan-gate/work-item hooks for the session | Low | High — invisible once set |

### Next steps

1. **Quantify demand.** Survey 3–5 teams already using the plugin: do they hit this? How often? What do they do today?
2. **Decide on framing.** Is a spike mode "in scope as a product feature" or "explicitly out of scope, document-only"? This is the upstream question.
3. If in scope: prototype Option B in a fork, measure how often the marker is abused vs. used correctly.
4. If out of scope: strengthen the bypass guidance in [docs/when-not-to-use.md](../when-not-to-use.md) with a mid-task recipe (how to pause the plugin for 30 minutes) and close the item.
5. Record decision and rationale in this file regardless of outcome.

---

## 2. Pre-plan brainstorming for high-level / vague requirements

### Problem

The plugin's flow starts at `/plan`, which assumes you already know roughly what you want to build. Upstream of that, `/analyze` produces REQ IDs from input and halts if the input is vague.

Neither phase supports **open-ended discovery** — "we want to improve onboarding, what should we do?" — which is a common starting state for:

- Greenfield features where the PM has a goal, not a spec
- Internal tooling decisions where the team is brainstorming solutions
- RFCs that need shaping before they become requirements
- Users who are junior enough to need help structuring the problem, not just executing on it

Today, the workaround is either "do the brainstorming outside the plugin and come back with a plan input" or "hit `/analyze`'s vague-input halt and iterate via chat." Neither produces a durable artifact, and neither integrates with the rest of the flow.

### Tension with core principles

| Principle | Tension |
|---|---|
| 1. Human in the lead | Aligned — brainstorming is inherently human-led |
| 2. Reduce cognitive load | **Strongly aligned (Option A).** Directly addresses the friction of vague-input users who have nowhere to start. **Tension (Option B):** overloading `/analyze` makes it harder to know what the command does. |
| 3. Plan before code | Neutral — this is *pre*-plan, not instead-of-plan |
| 4. Surgical edits | N/A — no code written during brainstorm |
| 5. Work-item traceability | Aligned if a brainstorm session produces a candidate REQ set |
| 6. Graceful degradation | Aligned — works entirely offline with markdown artifacts |
| 7. Stack-agnostic | Aligned — no tool-specific logic |

**Notable:** this is the only open item on this page without a direct conflict with any core principle. Principle 2 (cognitive load) actively favors resolving it. Low risk of violating the plugin's design intent; high value.

### Options considered

| Option | Description | Cost | Risk |
|---|---|---|---|
| A | New `/brainstorm` command that produces a `brainstorm-<slug>.md` artifact with candidate ideas, pros/cons, open questions; user picks one and feeds it to `/plan` | Medium — new command + skill + template | Low |
| B | Extend `/analyze` with a "vague mode" — when input is abstract, enter a structured Q&A loop before producing REQ IDs | Medium — skill modification | Medium — risks overloading `/analyze` |
| C | New "Phase 0 — Discover" as an explicit, optional phase before Plan; gets its own gate file | High — changes the phase model | High — CLAUDE.md says "don't change phase order without deep thought" |
| D | Docs-only: add a scenario to USER-MANUAL.md showing how to use `/analyze`'s clarifying-questions mode for brainstorming | Zero | Low |

### Next steps

1. **Read the current `/analyze` skill** ([skills/analyze/SKILL.md](../../skills/analyze/SKILL.md)) and confirm how it handles vague input today. The answer shapes whether Option B is a small extension or a rewrite.
2. **Define the artifact.** If we add a brainstorm artifact, what fields does it have? Candidate ideas, pros/cons, open questions, chosen direction, deferred ideas? Where does it live — `.claude/sdlc/brainstorms/`?
3. **Decide phase vs. extension.** Is discovery a distinct phase (Option C) or an extension to Analyze (Option B) or its own command (Option A)? Cross-check with [docs/SDLC.md](../SDLC.md) to see if Phase 0 fits cleanly.
4. **Prototype on a real vague request** — pick one from a real user's backlog and run each option manually to see which produces the best plan input.
5. **Check integration with REQ IDs.** If brainstorm produces candidate ideas, how do they become REQ IDs without duplication?

---

## 3. Multi-team approval across Claude Code sessions

> **Status update (2026-04-19):** **Closed — accepted.** See [multi-team-approval.md](./multi-team-approval.md) for the accepted RFC. The context below is preserved for historical reference.

### Problem

Sign-offs today live in gate files, signed by a human editing the markdown. When one team owns the code, this is simple. When a change needs **multiple teams' approval** — security + product, backend + frontend, compliance + dev — the model gets awkward:

- Team B is in a different repo / different Claude Code session
- Team A's session has no native way to see "has security signed off yet?"
- Coordination is ad-hoc (Slack, PR comments, "did you sign the gate file yet?")
- Audit trail is split across artifacts that don't reference each other

Today's workaround: stuff all required signatures into a single gate file and coordinate manually. This works for co-located teams and fails for cross-repo or cross-timezone approvals.

### Tension with core principles

| Principle | Tension |
|---|---|
| 1. Human in the lead | Aligned — every approval is still a human signature |
| 2. Reduce cognitive load | **Strongly aligned.** The problem being solved *is* coordination overhead — the cognitive burden of tracking which teams have signed off. Solving this is a direct application of the principle. |
| 3. Plan before code | Neutral |
| 4. Surgical edits | Neutral |
| 5. Work-item traceability | **Strongly aligned** — cross-team approval is exactly what audit wants |
| 6. Graceful degradation | **Critical constraint.** Must work without a central system or network. |
| 7. Stack-agnostic | Must remain so — can't hard-depend on GitHub PR reviews, Jira, etc. |

No direct conflict. The challenge is operational (sync model) and scope (how much coordination machinery the plugin should own).

### Options considered

| Option | Description | Sync model | Degrades to |
|---|---|---|---|
| A | Multi-signature gate files — one gate file, multiple named signature blocks (e.g., `## Sign-off: security`, `## Sign-off: product`). Each team signs their block in their own session | File-based, same repo | Works offline |
| B | External approval references — gate file links to approval artifacts in *other* repos via URL or relative path; a hook verifies the referenced artifact exists and is signed | File-based, cross-repo via git | Degrades if external repo unreachable |
| C | Shared `.claude/sdlc/sign-offs/` in a central "approvals" repo pointed to by a config key; each team pushes their signed sign-off file there; the initiating session pulls and verifies | Git-based central store | Degrades to "unverified" with warning |
| D | Integrate with existing tools — GitHub PR reviews, Jira approvals, GitLab merge-request approvals — via an optional MCP connector; use their approval as the signature | Tool-specific | Degrades to local gate-file sign-off |
| E | Don't solve this in the plugin; document the Slack-and-manual-coordination pattern as the accepted workflow | None | N/A |

### Next steps

1. **Scope the demand.** Is this enterprise-only, or do mid-size teams hit it too? Enterprise can justify Option C/D; mid-size likely wants Option A.
2. **Pick the degradation story first.** The plugin's principle 7 says missing infrastructure → local artifacts + surfaced gap. For multi-team approval, what's the local fallback? Probably: a gate file with unsigned blocks, plus a warning naming which teams haven't signed.
3. **Prototype Option A (multi-signature gate files)** — this is the minimum-surface-area version and doesn't require any cross-session coordination. If it's enough, we can stop there.
4. **Define the approval artifact contract** — what does an "approval" file look like (REQ ID, signer, role, timestamp, gate reference)? The contract is reusable across Options A/B/C.
5. **Research how other SDLC tools handle this** — specifically how they keep the audit trail coherent across teams.
6. **Interview 2–3 teams** with real multi-team approval needs before building. This is the item most likely to be over-designed if we guess at requirements.

---

## Summary: alignment with core principles

| Item | Conflicts with a core principle? | Risk |
|---|---|---|
| 1. Spike bypass | Yes — Plan-before-code (#3), Traceability (#5); Tension with Cognitive load (#2) for Option B | High. `CLAUDE.md` constrains the design space — see item 1. |
| 2. Pre-plan brainstorm | No direct conflict. Cognitive load (#2) actively favors resolution. | Low. Safest item of the three. |
| 3. Multi-team approval | No direct conflict — aligns with traceability (#5) and cognitive load (#2). Operational challenges only. Accepted RFC: [multi-team-approval.md](./multi-team-approval.md). | Medium. Over-design risk if scoped too broadly. |

---

## Process for items on this page

- **Status today:** items 1 and 2 are open. Item 3 (multi-team approval) is closed — accepted RFC at [multi-team-approval.md](./multi-team-approval.md).
- **When an item is ready to decide,** it moves into a short RFC-style write-up (a new file under `docs/rfcs/`) with a single recommended option and a sign-off.
- **When an item is decided,** this page is updated with the decision + a link to the implementation work.
- **When an item is rejected,** the rejection and its reason stay on this page — a rejected item is still useful context for future contributors.

Related reading: [docs/when-not-to-use.md](../when-not-to-use.md), [CLAUDE.md](../../CLAUDE.md), [docs/SDLC.md](../SDLC.md).
