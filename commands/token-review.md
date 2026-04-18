---
description: Analyze SDLC token usage from .claude/sdlc/token-log.json (last run) and token-history.jsonl (rolling). Surfaces the biggest cost centers and concrete optimization candidates. Read-only.
---

Produce a token-usage review to guide skill/prompt optimization.

## Inputs

- `.claude/sdlc/token-log.json` — snapshot of the most recent session (overwritten each `Stop`)
- `.claude/sdlc/token-history.jsonl` — one JSON object per session, rolling

If neither file exists, tell the user token tracking is disabled and point them at `config/tools.json` → `token_tracking.enabled = true`. Do not invent data.

## Analysis to run

Use `Read` for small files. For `token-history.jsonl` over ~500 lines, use `jq` via `Bash` to avoid loading the whole file into context.

Report these sections, in this order:

1. **Last run summary**
   - Task slug and completion time
   - Per-phase table: `input | output | cache_creation | cache_read`
   - Totals row
   - Cache hit ratio per phase: `cache_read / (cache_read + cache_creation)`

2. **Cross-run trends** (only if ≥3 entries in history)
   - Mean output tokens per phase (across all runs)
   - Mean cache hit ratio per phase
   - Phases where output tokens are trending up over the last 5 runs (flag as regression candidates)

3. **Optimization candidates** — top 3, ranked by expected impact
   - For each: phase name, the signal that flagged it, one concrete suggestion (which skill/template to tighten, or which context to stop re-loading)
   - Example flags:
     - High `cache_creation` with low `cache_read` → context is churning; skill probably re-reads files on every invocation
     - High `output` relative to phase norm → skill's output structure too loose; tighten template
     - High `input` with low cache usage → prompt includes fresh content each call; candidate for system-prompt promotion

4. **Unattributed bucket** (if non-zero)
   - Flag it — means tokens were spent without a gate being signed, which is a process issue, not a token issue

## What NOT to do

- Do not propose pricing or dollar figures. The hook records raw tokens only; pricing coefficients are intentionally out of scope.
- Do not suggest edits to skills or templates directly from this command — surface candidates only. Actual changes go through the normal Plan → Build flow.
- Do not draw conclusions from a single run. Note sample size in the report; recommend ≥5 runs before acting on trends.
