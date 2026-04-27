# Packaging & Release Guide

Reference for maintainers. Covers how the plugin is packaged, how releases are cut, and how consumers install it.

---

## Prerequisites

- **`jq`** — used by `scripts/package.sh` for JSON parsing (`brew install jq` / `apt install jq`)
- **`bats-core`** — used by the test suite (`brew install bats-core`)

`jq` is a local prerequisite only. The CI release job installs it automatically on the Ubuntu runner.

---

## 1. How the Claude Code plugin installer works

When a consumer runs `claude plugin install`, the installer clones the source repo and copies the entire directory into `~/.claude/plugins/cache/`. It does **not** recognize `devFiles` in `plugin.json` — that field is a custom convention consumed only by `scripts/package.sh`.

This means if you ship the repo as-is, every consumer receives:

- `CLAUDE.md` and `AGENT-RULES.md` — these files are loaded as Claude context when the plugin is active, injecting this repo's development instructions into consumers' sessions
- `docs/` — 13+ documentation files adding cache bloat
- `tests/` — bats fixtures consumers cannot run
- `.github/` — CI workflow files with no consumer value

`package.sh` solves this by producing a clean `release` branch containing only distributable files. Consumers who install from the `release` branch (via `marketplace.json`) receive only what the plugin needs to function.

---

## 2. Release branch model

The `release` branch contains only distributable files. It is **CI-owned output** — generated and force-pushed by `scripts/package.sh` on every release.

> **Never push to `release` manually.** The release job force-pushes on every release and will overwrite any manual changes without warning. If you need to fix something on the release branch, fix it in `main` and cut a new release.

The exclusion list that determines what goes into `release` draws from two sources kept separate intentionally:

| Source | Purpose |
|---|---|
| `devFiles` in `plugin.json` | Repo-specific dev files: docs, tests, scripts, CLAUDE.md, etc. Maintained by the repo owner. |
| Hardcoded in `package.sh` (`INFRA_EXCLUDES`) | Universal infrastructure files never appropriate for any consumer: `.git/`, `.github/`, `dist/`, `config/tools.json`, `.DS_Store`, `.claude/`. Kept hardcoded so they don't require maintainer upkeep in `plugin.json`. |

The `dist/` tag (`v{version}`) is immutable once created. `marketplace.json` pins to this tag, not to the `release` branch name.

---

## 3. Release checklist

Full release cycle, step by step:

1. **Bump `version`** in `.claude-plugin/plugin.json` (e.g. `1.1.0` → `1.2.0`)
2. **Preview the distribution manifest** — run `scripts/package.sh --dry-run` and confirm no devFiles appear in the output
3. **Commit the version bump** to `main`
4. **Push the tag:**
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
5. **Watch the release workflow** — the `test` job runs first; `release` only starts after `test` passes
6. **Verify the GitHub Release** — confirm `dist/sdlc-plugin-v1.2.0.tar.gz` is attached
7. **Verify `marketplace.json`** — confirm the `ref` field on `main` was updated to `v1.2.0` by the release job's `[skip ci]` commit

---

## 4. Dry-run: preview distribution manifest

Before tagging a release, preview exactly which files would be shipped:

```bash
scripts/package.sh --dry-run
```

This prints the full list of included files and exits without writing anything. Run this to confirm:
- No `CLAUDE.md`, `AGENT-RULES.md`, `docs/`, `tests/`, or `scripts/` in the manifest
- No `.github/` or other infra files

---

## 5. Consumer install

After `marketplace.json` and the release workflow are in place, consumers install with two commands:

```bash
# Add this repo as a self-hosted marketplace source
/plugin marketplace add lantisprime/claude-sdlc

# Install the plugin from it
/plugin install sdlc-plugin@claude-sdlc
```

No Anthropic approval is required. Claude Code supports self-hosted community marketplaces — any public GitHub repo with a `.claude-plugin/marketplace.json` is valid.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `error: jq is required` | `jq` not installed locally | `brew install jq` |
| `warn: claude CLI not found — skipping plugin validate` | `claude` not in PATH (expected in CI) | Not a failure; validation is a local safety net only |
| `error: Archive not found` | `package.sh` failed silently during `create_archive` | Re-run with `bash -x scripts/package.sh --skip-tests` to trace the failure |
| `[skip ci]` commit re-triggered the workflow | GitHub stopped honoring `[skip ci]` | Manually cancel the triggered run; open an issue to investigate |
| `error: marketplace.json invalid JSON after update` | `jq` filter produced malformed output | Run `jq --arg v "v1.2.0" '.plugins[0].source.ref = $v' .claude-plugin/marketplace.json` locally to debug |
