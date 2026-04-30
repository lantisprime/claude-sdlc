# Pending Analysis

Open design questions that need deeper analysis before the plugin commits to a direction. Each item is a problem + options + tension with core principles + next steps — **not** a proposed change. Nothing on this page is a decision.

If you're evaluating the plugin: these are known gaps the maintainers are thinking about, not silent ones.

### Quick reference

| # | Item | Status | Risk |
|---|------|--------|------|
| 1 | [Spike / exploratory-work bypass](#1-spike--exploratory-work-bypass) | Open | High |
| 2 | [Pre-plan brainstorming for high-level / vague requirements](#2-pre-plan-brainstorming-for-high-level--vague-requirements) | Open | Low |
| 3 | [RFC-004 maintainer code-review enforcement — open questions](#3-rfc-004-maintainer-code-review-enforcement--open-questions) | Closed 2026-04-27 | — |
| 4 | [RFC-006 RFC lifecycle quality gates — open questions](#4-rfc-006-rfc-lifecycle-quality-gates--open-questions) | Closed 2026-04-30 — RFC implemented | — |
| 5 | [Parser extension for §3a `**AI-slop check:**` field](#5-parser-extension-for-3a-ai-slop-check-field) | Open | Low |
| — | [Multi-team approval across Claude Code sessions](#multi-team-approval-across-claude-code-sessions) | Closed 2026-04-19 | — |
| — | [`secret-scan.sh` — always-on or opt-in?](#secret-scansh--always-on-or-opt-in) | Closed 2026-04-26 | — |

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

## 3. RFC-004 maintainer code-review enforcement — open questions

> **Status update (2026-04-27):** **Closed — resolved.** Both OQs decided and recorded in [RFC-004-maintainer-code-review-enforcement.md](./RFC-004-maintainer-code-review-enforcement.md). RFC-004 moved to `accepted`. The context below is preserved for historical reference.

> **Raised by:** [RFC-004-maintainer-code-review-enforcement.md](./RFC-004-maintainer-code-review-enforcement.md)

### Problem

RFC-004 introduces a doc-only bypass (PR is "doc-only" when every changed file matches `*.md`, `docs/**`, `templates/**`, `agents/**`, `commands/**`, `.github/**`). Two operational questions remain unresolved before acceptance.

### Open questions

| # | Question | Notes |
|---|---|---|
| 3a | Should `.claude/sdlc/plans/*.md` and `.claude/sdlc/gates/*.md` be excluded from the doc-only set? | They are prose but represent substantive governance decisions. Proposed default: **exclude** — if they appear in a diff, treat as code-PR (review required) so substantive plan/gate changes don't merge un-reviewed. |
| 3b | Branch protection settings on `main` — does the workflow need to be marked "required" via GitHub repo settings for the CI gate to actually block merge? | The workflow alone surfaces the failure but does not prevent merge unless branch protection requires it. Confirm with repo admin and document the required settings. |

### Next steps

1. Decide 3a default before RFC-004 moves to `accepted`. The proposed default is conservative (exclude).
2. For 3b, document the required branch-protection settings in the workflow file's header comment so future repo admins know what to configure.
3. Close both items and move RFC-004 to `accepted` once decisions are recorded in the RFC.

---

## 4. RFC-006 RFC lifecycle quality gates — open questions

> **Status update (2026-04-30):** **Closed — RFC-006 implemented and archived.** All 8 PRs shipped (#41, #42, #43, #44, #45, #48, #49, #53). 4b resolved at PR-3 implementation: `last_modified == TODAY` heuristic shipped as proposed; cross-day false-positive rate is acceptable per the OQ-2 acceptance criterion ("revisit if observable").
>
> **Raised by:** [RFC-006-rfc-lifecycle-quality-gates.md](./archived/RFC-006-rfc-lifecycle-quality-gates.md) (archived)

### Open questions

| # | Question | Status |
|---|---|---|
| 4a | Should the hook also warn when an RFC under `archived/` is edited beyond errata (AGENT-RULES.md §8)? | **Closed 2026-04-28** — out of scope for RFC-006. Diff-content analysis has a different cost shape than grep-on-current-file; scoped as a follow-up RFC. |
| 4b | Should `last_modified:` validation be relaxed to "within the last 24h" rather than "matches today"? | **Closed 2026-04-30** — `matches today` heuristic shipped as default in PR-3 (#43). Cross-day false-positive rate is acceptable; reversible in a follow-up commit if observed rate disagrees. |
| 4c | Build-stage step 3 triggers `tests/run.sh` on changes to `hooks/`, `tests/`, `scripts/`, `config/`. Configurable or hardcoded? | **Closed 2026-04-28** — hardcoded in §3.5 prose. Maintainer-only audience and small surface area don't justify the configurability cost. |
| 4d | `ai-slop-check.sh` auto-fix mode: conservative or aggressive? | **Closed 2026-04-28** — conservative. Auto-apply only deletion of single hedge words, swap of inflated metaphors against a fixed lookup table, or trim of triplets to duplets. Anything else flagged for human review. Aggressive can be added later as a `--aggressive` flag. |
| 4e | `rfc-pr-reviewer` verdict storage — inline in the PR row, or sidecar file? | **Closed 2026-04-28** — inline append with hard 500-char limit. Keeps the RFC self-contained and grep-checkable. Longer detail lives in PR review comments. |

### Next steps

All items closed. RFC-006 implementation complete and archived 2026-04-30.

---

## 5. Parser extension for §3a `**AI-slop check:**` field

> **Status:** Open. Surfaced post-RFC-006 implementation by PR-53's bot review (2026-04-30).
>
> **Raised by:** [archived/RFC-006-rfc-lifecycle-quality-gates.md](./archived/RFC-006-rfc-lifecycle-quality-gates.md) PR-8 → bot review on [#53](https://github.com/lantisprime/claude-sdlc/pull/53).

### Problem

RFC-006 PR-8 added a required `**AI-slop check:**` field to the `## Second opinion` block in both `AGENT-RULES.md §3a` and `TEMPLATE.md`. The decision rules forbid `**Decision:** proceed` when `**AI-slop check:** concerns:[…]` is recorded. This rule is currently honour-system: `.claude/hooks/rfc-quality-gate.sh`'s `accepted`-status branch checks for `**Decision:** proceed` but does not parse the `**AI-slop check:**` field. An RFC could move to `status: accepted` with `**Decision:** proceed` AND `**AI-slop check:** concerns:[…]` and the hook would not warn.

### Options

| Option | Description | Tradeoff |
|---|---|---|
| (a) Extend `rfc-quality-gate.sh` `accepted` branch to grep for `**AI-slop check:**` line; warn when missing or `concerns:[…]` while `**Decision:** proceed` | Closes the gap. Pure grep. ~5 lines added to the hook + 2 bats cases. | Low cost. Same warn-only severity as existing checks. |
| (b) Defer indefinitely | Honour-system continues. | Low immediate cost; risk grows if multiple RFCs accumulate without the check. |
| (c) Build a richer parser (yaml-block aware) | Could also validate the field's value is in the closed vocabulary `clean | fixed in revision | concerns:[…]` | Higher cost; the existing hook is grep-based for portability. |

### Recommendation

**(a)**, shipped as a tiny follow-up PR. The grep is straightforward; the bats coverage is one true-positive + one true-negative case parallel to the existing `Decision: revise first` test.

### Next steps

1. Open a small PR adding ~5 lines to `.claude/hooks/rfc-quality-gate.sh` and 2 bats cases to `tests/hooks/rfc_quality_gate.bats`.
2. Close this section once the hook lands.

---

## Summary: alignment with core principles

| Item | Conflicts with a core principle? | Risk |
|---|---|---|
| 1. Spike bypass | Yes — Plan-before-code (#3), Traceability (#5); Tension with Cognitive load (#2) for Option B | High. `CLAUDE.md` constrains the design space — see item 1. |
| 2. Pre-plan brainstorm | No direct conflict. Cognitive load (#2) actively favors resolution. | Low. Safest item on the page. |
| 3. RFC-004 OQs | No direct conflict. Operational questions only (default + branch protection settings). | Resolved 2026-04-27. RFC-004 accepted. |
| 4. RFC-006 OQs | No direct conflict. Operational questions only. | Closed 2026-04-30 — RFC-006 implemented. 4b shipped as `matches today` heuristic in PR-3. |
| 5. Parser extension for §3a `**AI-slop check:**` | No direct conflict. Closes an honour-system gap from RFC-006 PR-8. | Open. ~5-line hook patch + 2 bats cases. |

---

## Process for items on this page

- **Status today:** items 1, 2, and 5 are fully open; item 4 closed at RFC-006 implementation 2026-04-30. All other items are closed — see [Closed Items](#closed-items) below.
- **When an item is ready to decide,** it moves into a short RFC-style write-up (a new file under `docs/rfcs/`) with a single recommended option and a sign-off.
- **When an item is decided,** this page is updated with the decision + a link to the implementation work.
- **When an item is rejected,** the rejection and its reason stay on this page — a rejected item is still useful context for future contributors.

Related reading: [docs/when-not-to-use.md](../when-not-to-use.md), [CLAUDE.md](../../CLAUDE.md), [docs/SDLC.md](../SDLC.md).

---

## Closed Items

### Multi-team approval across Claude Code sessions

> **Closed 2026-04-19 — accepted.** See [multi-team-approval.md](./archived/multi-team-approval.md) for the accepted RFC. The context below is preserved for historical reference.

#### Problem

Sign-offs today live in gate files, signed by a human editing the markdown. When one team owns the code, this is simple. When a change needs **multiple teams' approval** — security + product, backend + frontend, compliance + dev — the model gets awkward:

- Team B is in a different repo / different Claude Code session
- Team A's session has no native way to see "has security signed off yet?"
- Coordination is ad-hoc (Slack, PR comments, "did you sign the gate file yet?")
- Audit trail is split across artifacts that don't reference each other

Today's workaround: stuff all required signatures into a single gate file and coordinate manually. This works for co-located teams and fails for cross-repo or cross-timezone approvals.

#### Tension with core principles

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

#### Options considered

| Option | Description | Sync model | Degrades to |
|---|---|---|---|
| A | Multi-signature gate files — one gate file, multiple named signature blocks (e.g., `## Sign-off: security`, `## Sign-off: product`). Each team signs their block in their own session | File-based, same repo | Works offline |
| B | External approval references — gate file links to approval artifacts in *other* repos via URL or relative path; a hook verifies the referenced artifact exists and is signed | File-based, cross-repo via git | Degrades if external repo unreachable |
| C | Shared `.claude/sdlc/sign-offs/` in a central "approvals" repo pointed to by a config key; each team pushes their signed sign-off file there; the initiating session pulls and verifies | Git-based central store | Degrades to "unverified" with warning |
| D | Integrate with existing tools — GitHub PR reviews, Jira approvals, GitLab merge-request approvals — via an optional MCP connector; use their approval as the signature | Tool-specific | Degrades to local gate-file sign-off |
| E | Don't solve this in the plugin; document the Slack-and-manual-coordination pattern as the accepted workflow | None | N/A |

---

### `secret-scan.sh` — always-on or opt-in?

> **Closed 2026-04-26 — accepted.** Decision: **Option B (always-on)** — `secret-scan.sh` does not receive the `.enabled` guard and fires regardless of activation state. See [opt-in-activation-suspend-resume.md](./archived/opt-in-activation-suspend-resume.md) §9. The context below is preserved for historical reference.

> **Originally raised by:** `docs/rfcs/opt-in-activation-suspend-resume.md` §9, OQ-1

#### Problem

The opt-in activation RFC gates all enforcement hooks behind a `.claude/sdlc/.enabled` marker. A developer who hasn't run `/start` gets no blocking, no warnings — the plugin is invisible. This is the intended default.

`secret-scan.sh` is an enforcement hook on `PostToolUse Edit|Write|MultiEdit`. Under the RFC it would be silenced until the developer opts in. A developer who installs the plugin but never runs `/start` could accidentally commit credentials, and the hook would not fire.

The question is whether credential scanning is a governance feature (opt-in, like the rest) or a safety feature (always-on, independent of plugin state).

#### Tension with core principles

| Principle | Tension |
|---|---|
| 1. Human in the lead | Aligned either way — opt-in was a human choice |
| 2. Reduce cognitive load | **Tension (always-on).** If the hook fires when the developer thought the plugin was inactive, it's surprising. |
| 5. Work-item traceability | Neutral |
| 6. Graceful degradation | **Aligned (always-on).** Catching a secret is strictly safer than not catching it. |

Opt-in model principle: the RFC's stated goal is that an unactivated plugin is *invisible*. An always-on `secret-scan.sh` breaks that contract. But credential exposure is a different category of harm than scope drift or missing plans.

#### Options considered

| Option | Description | Consistency | Safety |
|---|---|---|---|
| A | Opt-in (symmetric with all other hooks) — `secret-scan.sh` gets the enabled guard, fires only after `/start` | Fully consistent with RFC model | Developer unprotected until opt-in |
| B | Always-on — `secret-scan.sh` does not get the enabled guard, fires regardless of activation state | Exception to the opt-in contract | Developer protected from day 1 |
| C | Warn-only always-on — `secret-scan.sh` always fires but only warns (stderr, exit 0) when not enabled; blocks (exit 2) only when enabled | Partial exception; softer surprise | Protected but not blocked |
