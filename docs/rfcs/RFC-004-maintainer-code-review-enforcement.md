---
rfc_id: RFC-004
slug: maintainer-code-review-enforcement
title: Maintainer code-review enforcement
status: accepted
champion: juan.delacruz@acme.com
created: 2026-04-27
last_modified: 2026-04-27
accepted: 2026-04-27
supersedes: ~
superseded_by: ~
---

# RFC-004 — Maintainer code-review enforcement

## AI context

Adds a three-layer code-review gate (rule, Stop hook, CI workflow) for maintainers working on this plugin repo, leaving consuming-repo artifacts untouched. The plugin already ships review discipline to consumer repos but does not enforce the same discipline on its own development, so maintainer PRs can land without an explicit review checkpoint. Key trade-off: doc-only PRs (`*.md`, `docs/`, `templates/`, `agents/`, `commands/`) bypass the gate entirely — chosen over native GitHub branch protection because path-based bypass is load-bearing for this prose-heavy repo.

---

## Problem

- Maintainer PRs to this repo merge without a required code-review checkpoint. The `security-review` skill exists at `sdlc-plugin/skills/security-review/SKILL.md` but nothing requires it to run before merge on this repo.
- `CLAUDE.md` instructs maintainers to "eat your own dog food," but the plugin's own discipline (security-review, surgical-edit, plan-gate) is enforced only in consuming repos via `sdlc-plugin/hooks/hooks.json` — not on the plugin repo itself.
- The repo currently has no `.github/workflows/code-review.yml` (only `release.yml` from RFC-002), so there is no merge-time review gate at all.

This is observable today: any maintainer can merge a PR touching `hooks/`, `skills/`, or `scripts/` with no review and no CI check.

---

## Proposal

### Scope

- **In scope:**
  - New §14 in `sdlc-plugin/AGENT-RULES.md` mandating code review before Build gate sign-off.
  - New Stop hook `.claude/hooks/code-review-gate.sh` (warn, exit 0).
  - New tracked Claude settings `.claude/settings.json` registering the hook.
  - New CI workflow `.github/workflows/code-review.yml` requiring ≥1 approved review on code PRs.
- **Out of scope:**
  - Any change to `sdlc-plugin/hooks/`, `sdlc-plugin/skills/`, or `sdlc-plugin/hooks/hooks.json`. Consuming-repo behavior is unchanged.
  - New skills, commands, or templates.
  - Phase order, gate naming, or plan-artifact field changes.

### Three layers

| Layer | File | Behavior |
|---|---|---|
| Rule | `sdlc-plugin/AGENT-RULES.md` §14 | Before signing a Build gate, invoke `security-review` skill + quality pass. Skip for doc-only diffs. |
| Hook (warn) | `.claude/hooks/code-review-gate.sh` | Stop hook. Detects non-doc changes via `git diff --name-only`; warns if `security-review-*.md` missing in `.claude/sdlc/test/`. Exits 0. |
| Hook registration | `.claude/settings.json` | Tracked project-level Claude settings. Registers the Stop hook for maintainer sessions. |
| CI (block) | `.github/workflows/code-review.yml` | Triggers on PR open/sync/ready and `pull_request_review` (submitted/dismissed). Diffs `${{ github.event.pull_request.base.sha }}...HEAD`. Doc-only → pass. Code → require ≥1 APPROVED review where `review.author.login != pr.author.login`. |

### Doc-only definition (canonical)

A PR is doc-only when **every** changed file matches:

```
*.md, docs/**, templates/**, agents/**, commands/**, .github/**
```

**Except:** `.claude/sdlc/plans/**` and `.claude/sdlc/gates/**` are **excluded** from the doc-only set. They are markdown files but represent substantive governance decisions — if they appear in a diff, the PR is treated as a code-PR and review is required. (Resolved: OQ-1.)

This single definition is referenced from the rule, the hook, and the workflow.

### Layer separation (load-bearing)

Maintainer artifacts → `.claude/`, `.github/`, `AGENT-RULES.md`.
Plugin artifacts (ship to consumers) → `sdlc-plugin/**`.
The two layers must not mix. This RFC establishes that pattern; future contributors should not place maintainer-only tooling under `sdlc-plugin/hooks/` or other plugin-shipped directories.

---

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Native GitHub branch protection (`require 1 approval`) | Cannot exclude doc-only PRs by path. Doc-only bypass is load-bearing for this prose-heavy repo. |
| Block (exit 2) at the Stop hook instead of warn | Inconsistent with repo philosophy — only `plan-gate.sh` blocks; everything else warns. False positives (e.g., review file just-renamed) would halt legitimate work. |
| Place the hook in `sdlc-plugin/hooks/` and gate on a `MAINTAINER=1` env flag | Risks leaking the hook into consuming repos via `scripts/package.sh`; pollutes the plugin's surface. Strict layer separation (`.claude/hooks/`) is cleaner. |
| Skip `AGENT-RULES.md §14`, rely on hook + CI only | The rule document is the canonical decision source; without an entry there, future contributors won't know the rule exists. |
| Add a maintainer `/review-mtr` command | Unnecessary — Claude can invoke the `security-review` skill directly. A new command would be one more thing to memorize. |

---

## Implementation plan

| PR | Files | What |
|---|---|---|
| PR-1 | `sdlc-plugin/AGENT-RULES.md` | Add §14: before signing Build gate, invoke `security-review` skill + quality pass; skip for doc-only diffs (per canonical definition above) |
| PR-2 | `.claude/hooks/code-review-gate.sh`, `.claude/settings.json` | Stop hook (warn, exit 0): detects non-doc changes via `git diff --name-only`; warns if no `security-review-*.md` present in `.claude/sdlc/test/`; tracked settings registration |
| PR-3 | `.github/workflows/code-review.yml` | CI workflow: doc-only bypass (plan/gate exclusion applied), ≥1 approved review, self-approval filter (`review.author.login != pr.author.login`); branch-protection requirement documented in file header (resolved: OQ-2) |

Hard deps: PR-3 after PR-2 (share the same doc-only glob logic). PR-1 is independent.

**Cross-RFC coordination — `.claude/settings.json` is shared with RFC-006 PR-5.** Either may land first:

- _If PR-2 lands first_ (the expected order per `docs/rfcs/README.md` ## Implementation queue): create `.claude/settings.json` with a fresh `hooks.Stop` block containing the `code-review-gate.sh` entry. RFC-006 PR-5 will later append its `hooks.PostToolUse` block.
- _If RFC-006 PR-5 has already merged_: the file already exists with a `hooks.PostToolUse` block. **Append** the new `hooks.Stop` block — do not recreate or overwrite the file.
- Either path: run `python3 -m json.tool .claude/settings.json` (or equivalent) before commit to confirm the file parses.

---

## Implementation

> Populate this section after all PRs are merged.

| PR / Commit | What it delivered |
|---|---|
| — | — |

---

## Related RFCs

- `RFC-002-release-packaging` — added `.github/workflows/release.yml`; this RFC adds a sibling workflow `code-review.yml` in the same directory.
- `RFC-003-hook-enforcement-alignment` — touches similar territory (hook severity and registration) but applies to consuming-repo hooks; this RFC is strictly maintainer-scoped.

---

## Second opinion

> Required before `status: accepted` can be set. Complete per `AGENT-RULES.md §3a`.

**Reviewer:** independent subagent (background review during planning, 2026-04-27)
**Date:** 2026-04-27
**Findings:**
1. Layer separation is clean; nothing leaks into consuming repos.
2. `.claude/settings.json` is the right place for tracked maintainer hooks — confirmed `.gitignore` does not exclude it.
3. CI workflow must use `${{ github.event.pull_request.base.sha }}...HEAD` for diff base — incorporated into proposal.
4. Hook glob must match what the `security-review` skill produces (`security-review-*.md`), not `code-review-*.md` — corrected in proposal.
5. Self-approval edge case: filter `review.author.login != pr.author.login` — incorporated.
6. Native branch protection considered as alternative — rejected because doc-only bypass needed.

**Decision:** proceed

---

## Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Should `.claude/sdlc/plans/*.md` and `.claude/sdlc/gates/*.md` be excluded from doc-only set? They're prose but represent substantive decisions. Proposed default: exclude (treat as code-PR if they appear in diff). | juan.delacruz@acme.com | **resolved** — exclude; see doc-only definition above |
| OQ-2 | Branch protection settings on `main` — does the workflow need to be marked "required" via repo settings for the gate to actually block merge? Confirm with repo admin before merge. | juan.delacruz@acme.com | **resolved** — yes, mark as required; PR-3 documents the required settings in the workflow file header |
