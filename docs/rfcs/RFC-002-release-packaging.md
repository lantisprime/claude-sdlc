---
rfc_id: RFC-002
slug: release-packaging
title: Release Packaging & Marketplace Distribution
status: draft
champion: charltond.ho
created: 2026-04-27
last_modified: 2026-04-27
supersedes: ~
superseded_by: ~
---

# RFC-002 — Release Packaging & Marketplace Distribution

## AI context

> This RFC establishes a release packaging and marketplace distribution process for the sdlc-plugin. The core problem is threefold: `devFiles` in `plugin.json` is a custom field the Claude Code installer ignores (it copies every file verbatim to the consumer's plugin cache, including `CLAUDE.md` which gets loaded as Claude context in consumer sessions), the repo has no `marketplace.json` so `claude plugin install` cannot resolve the plugin at all, and there is no CI gate preventing a broken release from reaching consumers. The key design decision is release-branch strategy (CI-generated clean branch, tagged per version) over `git-subdir` repo restructuring — this preserves the existing flat layout and `--plugin-dir` development workflow.

---

## Problem

Four gaps prevent the plugin from being distributed correctly through the Claude Code plugin system.

**Gap 1 — `devFiles` in `plugin.json` is unrecognized; the installer copies everything.**

`devFiles` was added to the manifest as a custom field to document which files should not be shipped to consumers. Claude Code's plugin installer does not recognize this field — it is not part of the [official manifest schema](https://code.claude.com/docs/en/plugins-reference#plugin-manifest-schema). When a consumer installs the plugin, the installer clones the source and copies the entire directory to `~/.claude/plugins/cache`. This means every consumer receives:

- `CLAUDE.md` and `AGENT-RULES.md` — these files are loaded as Claude context when the plugin is active; shipping them injects this repo's development instructions and anti-patterns into consumers' Claude sessions
- `docs/` — 13+ documentation files adding significant cache bloat
- `tests/` — bats test fixtures, helper scripts, and test bats files consumers cannot run
- `.github/` — CI workflow files consumers have no use for
- `CHANGELOG.md` — development history with no consumer value in the cache

**Gap 2 — No `marketplace.json`; `claude plugin install` cannot resolve the plugin.**

The official install path for a Claude Code plugin is `claude plugin install <name>@<marketplace>`. This requires the repo to contain a `.claude-plugin/marketplace.json` catalog. The repo has no such file. Current install instructions require a manual `git clone`, which bypasses the plugin system's version management, scope controls, and update notifications entirely.

**Gap 3 — No CI gate before release.**

There is no automated test run that must pass before a version is tagged and distributed. A broken tag reaches consumers with no warning.

**Gap 4 — No documented release process.**

The version bump → test → tag → publish flow is undocumented. The `version` field in `plugin.json` must be bumped for consumers to receive updates (if omitted, every commit SHA is a new version; if set, only explicit bumps trigger updates). No process documents which approach is intended or how to execute a release.

---

## Proposal

Four deliverables. Together they close all four gaps.

### Deliverable 1 — `.claude-plugin/marketplace.json`

Add a marketplace catalog to the repo. This makes the repo self-distributing: users add the marketplace with one command and install the plugin from it.

```json
{
  "name": "claude-sdlc",
  "metadata": {
    "owner": { "name": "lantisprime", "url": "https://github.com/lantisprime/claude-sdlc" }
  },
  "plugins": [
    {
      "name": "sdlc-plugin",
      "description": "Enforces an 8-phase SDLC workflow for Claude Code with human sign-off at every gate.",
      "source": {
        "source": "github",
        "repo": "lantisprime/claude-sdlc",
        "ref": "v1.1.0"
      }
    }
  ]
}
```

The `ref` field pins to a dist tag on the release branch (see Deliverable 2). The marketplace entry is updated by the packaging script on each release.

**Install flow for consumers (after this RFC ships):**

```bash
/plugin marketplace add lantisprime/claude-sdlc
/plugin install sdlc-plugin@claude-sdlc
```

### Deliverable 2 — `scripts/package.sh`

A bash packaging script run locally by maintainers and called by the release workflow. It has two modes:

**Dry-run mode** (`--dry-run`): prints the full manifest of files that *would* be included in the distribution, without writing anything. Used to verify the exclusion list before releasing.

**Release mode** (default): executes the full packaging pipeline:

1. **Validate** — calls `claude plugin validate` to check `plugin.json`, skill/agent frontmatter, and `hooks/hooks.json` for schema errors. Exits non-zero on any validation failure.
2. **Test** — calls `tests/run.sh`. Exits non-zero if any suite fails.
3. **Build manifest** — computes the include/exclude lists, prints a file manifest.
4. **Archive** — creates `dist/sdlc-plugin-v{version}.tar.gz` containing only distributable files.
5. **Release branch** — force-pushes a `release` branch containing only the distributable files.
6. **Dist tag** — creates a `v{version}` tag at the HEAD of the release branch.

**Exclusion logic:**

The script derives its exclusion list from two sources:
- `devFiles` in `plugin.json` (the repo-maintained list: `AGENT-RULES.md`, `CLAUDE.md`, `docs/`, `tests/`, `CHANGELOG.md`)
- A hardcoded list of infrastructure files never appropriate for consumers: `.git/`, `.github/`, `config/tools.json`, `dist/`, `.DS_Store`, `.claude/`

`devFiles` remains in `plugin.json` as the single source of truth for the repo-specific exclusion list. A `_comment` field is added alongside it clarifying that it is consumed by `package.sh`, not by the Claude Code installer.

**Release branch rules:**
- The `release` branch is generated output owned entirely by `package.sh`. Never commit to it manually — CI force-pushes it on every release, overwriting any manual changes.
- The dist tag (`v{version}`) is immutable once created; the marketplace entry pins to this tag, not the branch name.

### Deliverable 3 — `.github/workflows/release.yml`

A GitHub Actions workflow with two jobs:

**Job 1 — `test` (runs on every push to `main` and on every tag push):**
- Calls the logic from the existing `test.yml` workflow (does not duplicate it — references the same job steps or calls the workflow)
- Runs `tests/run.sh` including integration tests (`--integration`)

**Job 2 — `release` (runs only on tag push matching `v*.*.*`, depends on `test`):**
- Checks out the repo
- Calls `scripts/package.sh` (which re-runs validation + tests before packaging)
- Creates a GitHub Release with the `dist/sdlc-plugin-v{version}.tar.gz` archive attached
- Updates the `ref` in `.claude-plugin/marketplace.json` to the new tag and commits it to `main`

The `release` job only runs if `test` passes. A failing test suite blocks the release branch push, tag creation, and GitHub Release creation.

### Deliverable 4 — `docs/PACKAGING.md`

A reference document for maintainers covering:

- The Claude Code plugin install flow and why `devFiles` is not a native field
- The release branch model and why it is CI-owned
- Step-by-step release checklist: bump `version` in `plugin.json` → commit → tag → push tag → workflow runs → verify GitHub Release
- How to run `scripts/package.sh --dry-run` locally to preview the distribution manifest
- How to add the marketplace and install the plugin (the consumer-facing commands)

### Scope

- **In scope:** `.claude-plugin/marketplace.json`, `scripts/package.sh`, `.github/workflows/release.yml`, `docs/PACKAGING.md`, `_comment` addition to `plugin.json`'s `devFiles` field
- **Out of scope:** npm publish, Homebrew formula, separate release repo, auto-versioning beyond the existing `version` field, smoke-test install validation via live Claude Code session (see Open questions)

---

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Accept all files (no exclusion) | `CLAUDE.md` and `AGENT-RULES.md` are loaded as Claude context when the plugin is active — shipping them to consumers injects this repo's development instructions into their Claude sessions, producing confusing and potentially conflicting behavior |
| `git-subdir` source + repo restructure | Requires moving all plugin files into a subdirectory, restructuring the flat layout that works well for `--plugin-dir` development testing; larger change than a release branch with no functional advantage |
| Separate release repo | A second repo to maintain, manage access controls for, and keep in sync; the release branch achieves the same isolation within the same repo |
| GitHub auto-archives | Generated from the full repo at the tag commit; includes all devFiles and `.github/`; no way to configure file exclusions without an Actions workflow that produces and uploads a curated artifact — which is what this RFC adds |
| CI-only packaging (no local `package.sh`) | Blocks local validation and manual releases; contributors cannot verify the distribution manifest without pushing a tag; local tooling is essential for safe iteration |
| `.claudepluginignore` file | Not part of the Claude Code plugin spec — no such mechanism exists |
| npm source | Adds npm as a distribution dependency; changes the authoring model to require an npm publish step; overkill for a plugin with no JS runtime; git-based distribution already fits the repo's structure |

---

## Implementation

> Populate after implementation.

| PR / Commit | What it delivered |
|---|---|
| — | — |

Key files to create/modify:
- `.claude-plugin/marketplace.json` — new marketplace catalog
- `.claude-plugin/plugin.json` — add `_comment` to `devFiles` field
- `scripts/package.sh` — new packaging script
- `.github/workflows/release.yml` — new release workflow
- `docs/PACKAGING.md` — new packaging reference

---

## Related RFCs

- none

---

## Second opinion

> Required before `status: accepted` can be set. Complete per `AGENT-RULES.md §3a`.

**Reviewer:** <!-- name or "self-review" -->
**Date:** <!-- YYYY-MM-DD -->
**Findings:** <!-- gaps surfaced, alternatives missed, risks not captured — or "no gaps found" -->
**Decision:** <!-- proceed | revise first -->

---

## Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Should the smoke-test (install the packaged archive via `claude --plugin-dir` and call `claude plugin validate` against it) be added to the release workflow? | charltond.ho | open — deferred from v1; `claude plugin validate` is already called during packaging; a full install smoke-test requires an interactive Claude Code session, which is not automatable in standard CI |
| OQ-2 | Should `devFiles` entries in `plugin.json` be the sole exclusion list, or should the hardcoded infrastructure exclusions (`.github/`, `.git/`, etc.) also be moved into `plugin.json`? | charltond.ho | open — current proposal keeps them separate (repo-specific exclusions in `devFiles`, infrastructure exclusions hardcoded in the script); worth revisiting if the exclusion list grows |
