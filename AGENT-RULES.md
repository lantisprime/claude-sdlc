# Repo Agent Rules

> **Scope:** This file is for maintainers of the plugin repo itself. It does not apply to consuming repos using the installed plugin. If you are working inside a repo that has the plugin installed, follow the commands and skills the plugin surfaces — do not load this file.

Load this file at the start of any session that involves adding or modifying plugin artifacts (skills, hooks, commands, templates, config). It is the authoritative decision source for working on this repo. `CLAUDE.md` is the explanatory version — read it only when you need the rationale behind a rule.

For RFC lifecycle work, load `docs/rfcs/AGENT-RULES.md` instead of (or in addition to) this file.

---

## 0. Before doing anything

1. Read `docs/references/_repo-context.md` — it tells you the current capability counts, active RFCs, and anti-patterns. Fix stale facts there before making decisions that depend on them.
2. `CLAUDE.md` is auto-loaded by the harness; do not re-read it unless you need the rationale for a specific design decision.
3. Confirm what artifact type you are modifying before touching any file.

---

## 1. Core principles — do not erode

These are load-bearing. A change that violates any of these is the wrong change.

1. **Human in the lead.** Every phase ends at a signed gate file. Subagents and hooks propose; humans approve. Never auto-advance a phase.
2. **Plan before code.** `plan-gate.sh` blocks `Edit`/`Write` when no plan exists. This rule is non-negotiable.
3. **Surgical edits.** Only plan-listed files and functions. No adjacent-function edits. No "while I'm here" cleanups.
4. **Work-item traceability.** Every build references a REQ ID, ticket, or signed CR.
5. **Graceful degradation.** Missing integrations → local markdown/JSON artifacts. Never silently skip a check.
6. **Stack-agnostic.** Tool names live in `config/tools.json` only. Never hardcode formatter, linter, runner, or scanner names anywhere else.

---

## 2. Phase workflow quick reference

| # | Phase | Command | Gate file pattern |
|---|-------|---------|------------------|
| 1 | Plan | `/plan` | `.claude/sdlc/gates/plan-*.md` |
| 2 | Analyze | `/analyze` | `.claude/sdlc/gates/analyze-*.md` |
| 3 | Design | `/design` | `.claude/sdlc/gates/design-*.md` |
| 4 | Build | `/build` | `.claude/sdlc/gates/build-*.md` |
| 5 | Test | `/test` | `.claude/sdlc/gates/test-*.md` |
| 6 | Deploy | `/deploy` | `.claude/sdlc/gates/deploy-*.md` |
| 7 | Support | `/support` | `.claude/sdlc/gates/support-*.md` |
| 8 | Docs | `/docs` | cross-cutting, no dedicated gate |

`/fix-fast` collapses Plan + Analyze + Design for bug-only tasks. Eligibility is strict: bug fix only, ≤2 files, ≤50 LOC, no schema/API/security/UX changes. Do not widen these limits.

The next phase refuses to start until the prior gate file is signed by a human.

---

## 3. Adding a new skill

1. Plan the skill: what does it enable, when does it trigger, what does it NOT do?
2. Create `skills/<name>/SKILL.md` with YAML frontmatter — `name:` and `description:` are required.
3. Write `description:` as a pushy trigger list — concrete phrases that map to this skill. Vague descriptions cause misfires; overly narrow ones cause misses.
4. Keep the body under ~500 lines. Move reference detail into sub-files and link to them.
5. Add the skill to the `README.md` skill table.
6. If it is a phase skill or cross-cutting concern, add it to `docs/SDLC.md` as well.
7. Test triggers: run 2–3 representative prompts in a throwaway session to confirm the description fires the skill as intended before calling it done.
8. Update the skill capability count in `docs/references/_repo-context.md`.
9. See §11 for all index files to update.

---

## 4. Adding a new hook

1. Decide the event type: `PreToolUse`, `PostToolUse`, `Stop`, or `SessionStart`.
2. Decide severity — **warn (exit 0) is the default.** Block (exit 2) only when the consequence is severe: no plan at all, unsigned CR, confirmed secret. Document the justification in the script.
3. Write the shell script in POSIX-ish bash with `set -euo pipefail`.
4. Check tool dependencies: if the hook calls an external tool, confirm it is either always-present (git, POSIX sh) or add a graceful-degradation path that exits 0 when the tool is absent.
5. Register the hook in `hooks/hooks.json` with the appropriate matcher.
6. Test against a repo where hooks actually run — hook misbehavior is hard to catch without exercising them live.
7. Update the hook count in `docs/references/_repo-context.md`.
8. See §11 for all index files to update.

---

## 5. Adding or modifying a command

**Adding:**
1. Create `commands/<name>.md` — one file per command.
2. Prefer triggering an existing skill over adding a new command. Only add a command when the human needs an explicit named entry point.
3. Do not add commands the human has to memorize when a skill would do.
4. Add the command to the `README.md` command table and to `docs/SDLC.md`.
5. Update the command count in `docs/references/_repo-context.md`.

**Modifying:**
1. Update the description and triggering behavior in `commands/<name>.md`.
2. Before renaming a command, search the repo for any skill, hook, or template that references the old name.
3. See §11 for all index files to update.

---

## 6. Modifying a template

1. Before changing any heading or field name, search the repo for all consumers — hooks and skills parse templates verbatim by heading text.
2. `diff-scope-check.sh` and `adjacent-function-detector.sh` parse plan artifact fields by exact heading name. Renaming a heading breaks them.
3. If a structural change is unavoidable, update all consumer references in the same commit — never in a follow-up.
4. Update the template count in `docs/references/_repo-context.md` when adding or removing templates.
5. See §11 for all index files to update.

---

## 7. Config schema changes

1. `config/tools.example.json` is the authoritative schema. Users copy it to `tools.json` — backward compatibility matters across versions.
2. New keys must include an inline `_comment` field explaining the expected value and effect.
3. Update every skill and hook that consumes the new key in the same change.
4. Update `docs/references/_repo-context.md` if the change affects any described behavior.

---

## 8. Version bumping

Update `plugin.json` after any non-trivial change:

| Change type | Version bump |
|-------------|-------------|
| New skill, hook, command, or template (non-breaking addition) | Minor |
| Breaking change to gate-file shape, plan artifact field names, or phase order | Major |
| Bug fix or documentation only | Patch |

Before tagging a release, add a `[X.Y.Z] — YYYY-MM-DD` entry to `CHANGELOG.md` covering all changes since the previous release. Use sub-sections (`### Added`, `### Changed`, `### Fixed`, `### Documentation`) as relevant. The changelog commit must land on `main` before the tag is pushed — `release.yml` does not update it automatically.

---

## 9. When a new feature ships

After any implementation that adds or changes user-visible plugin behavior:

1. Read `docs/USER-MANUAL.md` — update every section affected by the new feature (new commands, changed artifact paths, new behaviors, new configuration options).
2. Read `README.md` — update the quick-start, command table, or capability list if the feature is user-visible.
3. If the feature introduces new terms, add them to `docs/GLOSSARY.md`.
4. If the feature adds a phase skill or cross-cutting concern, update `docs/SDLC.md`.
5. See §11 for all index files to update.

These doc updates ship in the same PR as the feature — never as a follow-up.

---

## 10. RFC work

Load `docs/rfcs/AGENT-RULES.md` — it is the authoritative decision source for creating, transitioning, and archiving RFCs. Do not rely on memory or this file for RFC lifecycle rules.

---

## 11. Index files to keep in sync

After any mutation, update the relevant rows:

| Mutation | Files to update |
|----------|----------------|
| Add skill | `README.md` (skill table), `docs/SDLC.md` (if phase/cross-cutting), `docs/references/_repo-context.md` (capability count) |
| Add hook | `hooks/hooks.json` (registration), `README.md`, `docs/references/_repo-context.md` (hook count) |
| Add/modify command | `README.md` (command table), `docs/SDLC.md`, `docs/references/_repo-context.md` (command count) |
| Add/remove template | `README.md`, `docs/references/_repo-context.md` (template count) |
| Any feature ship | `docs/USER-MANUAL.md`, `README.md`, `docs/GLOSSARY.md` (new terms), `docs/SDLC.md` (phase/cross-cutting) |
| RFC status change | See `docs/rfcs/AGENT-RULES.md` §11 |

---

## 12. Anti-patterns

**Implementation — things that look like improvements but aren't:**

- Auto-advancing a phase (breaks "human in the lead")
- Widening `/fix-fast` eligibility beyond bug-only / ≤2 files / ≤50 LOC / no schema/API/security/UX changes
- Promoting a warn-level hook to block without evidence and documented justification in the script
- Silently skipping a check when an integration is missing
- Hardcoding tool names instead of routing through `config/tools.json`
- Adding a command the human has to memorize when a skill would do
- Refactoring across files in the same change
- Touching adjacent functions while editing a plan-listed function

**Writing and framing — in documentation, RFCs, or any repo prose:**

- Inflated metaphors ("Trojan Horse for autonomy", "velocity unlock", etc.)
- Manufactured personas or job titles used as rhetorical devices
- Formulaic triplet structures when a single clear sentence does the job
- False severity escalation (calling warnings "blockers", advisory findings "critical")
- Unsupported compliance assertions — this plugin does not deliver SOC2, PCI-DSS, or HIPAA guarantees
- Aspirational framing that outruns what the repo actually does — ground every claim in observable behavior (a hook, a skill, a template, an artifact path)

---

## 13. Testing

**Prerequisites:** `bats-core` (`brew install bats-core` or `npm install -g bats`), `python3` or `node`.

```bash
# Unit tests only (skips @integration-tagged bats tests)
tests/run.sh

# Include integration tests
tests/run.sh --integration

# Single bats file
bats tests/hooks/plan_gate.bats
```

**For skills, commands, and templates** (not covered by the bats suite):

1. Install the plugin into a throwaway repo.
2. Run a representative task end-to-end (new build, fix, CR).
3. Observe which hooks fire, which skills trigger, where friction appears.
4. Adjust descriptions, matchers, and thresholds based on what you observe.

**Validation targets:**

| Metric | Target |
|--------|--------|
| Plan-first compliance | 100% |
| Work-item validation | 100% |
| Scope discipline (files touched ÷ files in scope) | 1.0 |
| Adjacent-function modifications per task | 0 |
| Test scope ratio (tests modified ÷ code modified) | ≈ 1.0 |

---

## 14. Pre-merge multi-reviewer gate

Before signing a Build gate file (`.claude/sdlc/gates/build-*.md`) on a non-doc PR, run the four maintainer review agents in parallel. Doc-only PRs skip this section entirely.

**Doc-only definition (canonical — same as RFC-004):** a PR is doc-only when every changed file matches `*.md`, `docs/**`, `templates/**`, `agents/**`, `commands/**`, or `.github/**`. Exception: `.claude/sdlc/plans/**` and `.claude/sdlc/gates/**` are excluded — if either appears in the diff, the PR is treated as a code-PR and review is required.

**Procedure for non-doc PRs:**

1. Spawn all four review agents in a single tool-call batch (parallel, not serial):
   - `.claude/agents/maintainer-security-reviewer.md`
   - `.claude/agents/maintainer-code-quality-reviewer.md`
   - `.claude/agents/maintainer-test-adequacy-reviewer.md`
   - `.claude/agents/maintainer-dependency-reviewer.md`
2. Wait for all four artifacts to be written under `.claude/sdlc/test/`:
   - `security-review-<task-slug>.md`
   - `code-quality-review-<task-slug>.md`
   - `test-adequacy-review-<task-slug>.md`
   - `dependency-review-<task-slug>.md`
3. Read each artifact's `**Verdict:**` line:
   - `clean` or `not-applicable` → no further action.
   - `concerns:[…]` → either fix the concerns in the diff (and re-spawn the affected agent) or record an explicit waiver with rationale in the Build gate file before signing.
4. Sign the Build gate only when every artifact is `clean`, `not-applicable`, or explicitly waived.

**Reinforcement layers:**
- Hook: `.claude/hooks/pre-merge-review-gate.sh` (Stop, warn) checks artifact presence and warns if any are missing on a non-doc PR. The hook does not enforce parallel invocation or verdict-gating — those are §14 procedural rules maintained by the human + Claude session.
- CI: `.github/workflows/pr-review.yml` requires ≥1 GitHub APPROVED human review (`review.author.login != pr.author.login`) before merge. §14 covers AI-agent review; CI covers human peer review. Both layers must pass.

Design rationale and the alternatives considered live in `docs/rfcs/RFC-004-maintainer-code-review-enforcement.md`.
