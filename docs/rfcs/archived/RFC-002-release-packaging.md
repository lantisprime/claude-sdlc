---
rfc_id: RFC-002
slug: release-packaging
title: Release Packaging & Marketplace Distribution
status: implemented
champion: charltond.ho
created: 2026-04-27
last_modified: 2026-04-27 (implemented)
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

**Anthropic registration not required.** Claude Code has two independent marketplace systems: the official Anthropic marketplace (`claude-plugins-official`, pre-loaded in every install) and self-hosted community marketplaces. Any public GitHub repo with a `.claude-plugin/marketplace.json` is a valid self-hosted marketplace — no submission or approval from Anthropic is needed. `/plugin marketplace add lantisprime/claude-sdlc` resolves directly from GitHub.

Submitting to Anthropic's official marketplace (`claude.ai/settings/plugins/submit`) is optional and out of scope for this RFC.

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

## Implementation plan

### PR-1 — `.claude-plugin/plugin.json`

**Before:**
```json
"devFiles": ["AGENT-RULES.md", "CLAUDE.md", "docs/", "tests/", "CHANGELOG.md"]
```

**After:**
```json
"_devFiles_comment": "Consumed by scripts/package.sh — excluded from consumer distribution. Not recognized by the Claude Code installer.",
"devFiles": ["AGENT-RULES.md", "CLAUDE.md", "docs/", "tests/", "CHANGELOG.md", "scripts/"]
```

Prerequisite for PR-3 — `scripts/` must be in `devFiles` before `package.sh` runs, otherwise the script would include itself in the distribution archive.

---

### PR-2 — `.claude-plugin/marketplace.json`

**Before:** file does not exist.

**After (new file):**
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

`ref` is set to `v1.1.0` as the initial value. On each release, PR-4's release job updates `ref` to the new tag and commits `marketplace.json` back to `main` with `[skip ci]`. This means `marketplace.json` is a committed file on `main` — not a generated artifact kept off-branch. Consumer install flow after this PR ships:

```bash
/plugin marketplace add lantisprime/claude-sdlc
/plugin install sdlc-plugin@claude-sdlc
```

Independent — can merge anytime after PR-1.

---

### PR-3 — `scripts/package.sh`

**Before:** file does not exist.

**After (new file, key structure):**
```bash
#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

PLUGIN_JSON=".claude-plugin/plugin.json"
VERSION=$(jq -r '.version' "$PLUGIN_JSON")
ARCHIVE="dist/sdlc-plugin-v${VERSION}.tar.gz"

# Exclusion list — two sources:
# 1. devFiles in plugin.json (repo-specific: AGENT-RULES.md, CLAUDE.md, docs/, tests/, CHANGELOG.md, scripts/)
# 2. Hardcoded infra files never appropriate for consumers
DEV_FILES=$(jq -r '.devFiles[]' "$PLUGIN_JSON")
INFRA_EXCLUDES=(".git/" ".github/" "config/tools.json" "dist/" ".DS_Store" ".claude/")

SKIP_TESTS=false
[[ "${1:-}" == "--skip-tests" ]] && SKIP_TESTS=true

validate() {
  # Gracefully degrade if claude CLI is not in PATH (e.g. CI environments without Claude Code installed)
  command -v claude >/dev/null 2>&1 || { echo "warn: claude not found, skipping plugin validate"; return 0; }
  claude plugin validate
}
run_tests()      { tests/run.sh --integration; }
build_manifest() { # prints included files after applying both exclusion sources; }
create_archive() { mkdir -p dist && tar czf "$ARCHIVE" <included files>; }
release_branch() { # force-pushes release branch — this is intentional; never push to release manually; }
tag_release()    { git tag "v${VERSION}" && git push origin "v${VERSION}"; }

if $DRY_RUN; then
  build_manifest
elif $SKIP_TESTS; then
  validate && build_manifest && create_archive && release_branch && tag_release
else
  validate && run_tests && build_manifest && create_archive && release_branch && tag_release
fi
```

Dry-run (`--dry-run`) prints the full file manifest without writing anything — use to verify the exclusion list before tagging a release.

`--skip-tests` skips `run_tests()` for the CI call in PR-4's release job (tests already passed in the `test` job — running them again inside `package.sh` is redundant). Local and manual release calls should always omit `--skip-tests`.

`validate()` degrades gracefully if `claude` is not in PATH: logs a warning and continues. `claude plugin validate` is a local safety net, not a hard CI gate.

`release_branch()` force-pushes — this is intentional. The `release` branch is CI-owned output. Never push to it manually; the force-push will overwrite any manual changes without warning. See §2 of `PACKAGING.md`.

Depends on PR-1 (`scripts/` must be in `devFiles` before packaging runs).

---

### PR-4 — `.github/workflows/release.yml`

**Before:** file does not exist.

**After (new file):**
```yaml
name: Release

on:
  push:
    branches: [main]
    tags: ["v*.*.*"]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run test suite
        run: tests/run.sh --integration

  release:
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Package
        run: scripts/package.sh --skip-tests
      - name: Verify archive exists
        run: |
          VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
          [ -f "dist/sdlc-plugin-v${VERSION}.tar.gz" ] || { echo "Archive not found"; exit 1; }
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: dist/sdlc-plugin-v*.tar.gz
      - name: Update marketplace ref
        run: |
          VERSION=${GITHUB_REF_NAME}
          jq --arg v "$VERSION" '.plugins[0].source.ref = $v' \
            .claude-plugin/marketplace.json > tmp.json && mv tmp.json .claude-plugin/marketplace.json
          jq . tmp.json > /dev/null || { echo "marketplace.json is invalid JSON after update"; exit 1; }
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .claude-plugin/marketplace.json
          git commit -m "chore: update marketplace ref to ${VERSION} [skip ci]"
          git push origin HEAD:main
```

Key points:
- `test` runs on every push to `main` and every tag push; `release` only runs on `v*.*.*` tags and only if `test` passes — a failing test suite blocks the release
- `package.sh` is called with `--skip-tests` because the `test` job already ran the suite; running it again inside the script is redundant
- Archive existence is verified before the GitHub Release step — if `package.sh` fails to produce the tar.gz, the job fails rather than creating an empty release
- `marketplace.json` is validated as parseable JSON after the jq update before committing — guards against a malformed filter producing invalid JSON on `main`
- `[skip ci]` on the `marketplace.json` commit prevents the push back to `main` from re-triggering the release workflow (circular trigger); this relies on GitHub honoring `[skip ci]` — a documented assumption

Depends on PR-3 (workflow calls `package.sh`).

---

### PR-5 — `docs/PACKAGING.md`

**Before:** file does not exist.

**After (new file, section outline):**

```
# Packaging & Release Guide

## 1. How the Claude Code plugin installer works
## 2. Release branch model
## 3. Release checklist
## 4. Dry-run: preview distribution manifest
## 5. Consumer install
## Prerequisites
```

Section detail:
- **§1** — why `devFiles` is not a native field; why `CLAUDE.md` and `AGENT-RULES.md` leak into consumer Claude context if shipped
- **§2** — the `release` branch is CI-owned output; **explicit warning: never push to `release` manually** — the release job force-pushes on every release and will overwrite any manual changes without warning; why infra exclusions (`.git/`, `.github/`, etc.) are kept hardcoded in `package.sh` rather than in `devFiles` (repo-specific vs. universal — prevents maintainer upkeep burden)
- **§3** — full release cycle with expected output: bump `version` in `plugin.json` → commit → `git tag v{version} && git push origin v{version}` → `test` job runs and must pass → `release` job runs: packages, creates GitHub Release with tar.gz, commits updated `marketplace.json` to `main` → verify GitHub Release has tar.gz attached → verify `marketplace.json` ref on `main` matches the new tag
- **§4** — `scripts/package.sh --dry-run`; run before tagging to confirm no devFiles leak into the archive
- **§5** — `/plugin marketplace add lantisprime/claude-sdlc` then `/plugin install sdlc-plugin@claude-sdlc`
- **Prerequisites** — `bats-core` (`brew install bats-core`), `jq` (`brew install jq`); note: `jq` is a local prerequisite only — it is installed by the CI release job automatically and does not need to be pre-installed on the runner
- **Troubleshooting** — common failures: `jq is required` (install jq locally); `warn: claude not found` (expected in CI — validation skipped, not a failure); `Archive not found` (package.sh failed silently — re-run with `bash -x scripts/package.sh` to trace); `[skip ci]` commit re-triggered workflow (GitHub behavior changed — manually cancel the triggered run)

Depends on PR-4 (documents the full system).

---

### Sequencing

```
PR-1 → PR-3 → PR-4 → PR-5
PR-2  (independent, can merge anytime after PR-1)
```

---

## Implementation

| PR | What it delivered |
|---|---|
| [#12](https://github.com/lantisprime/claude-sdlc/pull/12) | `_devFiles_comment` + `scripts/` added to `devFiles` in `.claude-plugin/plugin.json` |
| [#13](https://github.com/lantisprime/claude-sdlc/pull/13) | `.claude-plugin/marketplace.json` — self-hosted marketplace catalog |
| [#14](https://github.com/lantisprime/claude-sdlc/pull/14) | `scripts/package.sh` — packaging script with dry-run, --skip-tests, graceful claude CLI degradation |
| [#15](https://github.com/lantisprime/claude-sdlc/pull/15) | `.github/workflows/release.yml` — CI gate + release job with archive check and marketplace ref update |
| [#16](https://github.com/lantisprime/claude-sdlc/pull/16) | `docs/PACKAGING.md` — maintainer reference covering installer behaviour, release branch model, checklist, troubleshooting |

---

## Related RFCs

- none

---

## Second opinion

> Required before `status: accepted` can be set. Complete per `AGENT-RULES.md §3a`.

**Reviewer:** Claude Code (Explore subagent — independent review)
**Date:** 2026-04-27
**Findings:** No major gaps; all four RFC deliverables covered. Three risks identified and incorporated into the implementation plan: (1) circular trigger risk — release job's `marketplace.json` commit back to `main` could re-fire the release workflow; fix: `[skip ci]` on that commit; (2) `package.sh` JSON parsing without `jq` is fragile; fix: require `jq` as an explicit dependency; (3) OQ-2 intent (why infra exclusions are kept separate from `devFiles`) should be documented in `PACKAGING.md` to prevent future consolidation. OQ-1 (smoke test) correctly deferred. Sequencing of 5 PRs is correct.
**Decision:** proceed

---

## Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Should the smoke-test (install the packaged archive via `claude --plugin-dir` and call `claude plugin validate` against it) be added to the release workflow? | charltond.ho | open — deferred from v1; `claude plugin validate` is already called during packaging; a full install smoke-test requires an interactive Claude Code session, which is not automatable in standard CI |
| OQ-2 | Should `devFiles` entries in `plugin.json` be the sole exclusion list, or should the hardcoded infrastructure exclusions (`.github/`, `.git/`, etc.) also be moved into `plugin.json`? | charltond.ho | open — current proposal keeps them separate (repo-specific exclusions in `devFiles`, infrastructure exclusions hardcoded in the script); worth revisiting if the exclusion list grows |
