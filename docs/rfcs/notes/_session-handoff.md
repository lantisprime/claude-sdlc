# Session handoff

> **Status:** current working state (overwritten each session)

**Date:** 2026-04-26
**Scope:** This session: opt-in activation RFC — OQ-5 resolved (two-pass stat pre-filter + bounded re-examination), OQ-6 resolved (plan-keyed re-examination + per-plan prompts), RFC accepted.
**Related:**
- [`opt-in-activation-suspend-resume.md`](../opt-in-activation-suspend-resume.md) — **Accepted** 2026-04-26; all 6 OQs resolved
- [`multi-team-approval.md`](../multi-team-approval.md) — Accepted; fully implemented (HEAD `beea344`)
- [`scope-ingest.md`](../scope-ingest.md) — Implemented (2026-04-25)

---

## Binding decisions this session

### OQ-5 resolved — two-pass stat pre-filter (2026-04-26)

Re-examination at re-enable is now bounded:

- **Pass 1 (stat):** size + mtime against all manifest files → S1 (changed candidates). Git mtime churn inflates S1; pass 2 absorbs false positives.
- **Pass 2 (SHA-256):** confirms S1 against stored hashes → S2 (confirmed changed).
- **Load:** S2 + one-hop artifact neighbors, active plans only. Active = at least one unsigned/missing/stale/conflicting required sign-off. Completed plans excluded (evidence, not control state).
- **One-hop rules:** `scope.md` → all active plans (capped); plan → its gates; gate → its sign-offs; removed sign-off → parent gate; source file → referencing plan's In-scope section.
- **scope.md safety valve:** active-plan count > 20 → load 20 most-recently-modified + warn + explicit expansion offer. Omitted plans deferred, never marked safe.
- **Manifest schema:** each entry now `{"sha256": "<hash>", "size": <bytes>, "mtime": <unix>}`.
- Deeper drift handled by `gate_hash` (§6.5) + `approval-reconcile.sh`.

Committed: `b23a1d7` — pushed to `main`.

### OQ-6 resolved — plan-keyed re-examination (2026-04-26)

Re-examination groups output by REQ ID (plan-keyed structure: `changed_files`, `severity`, `summary`, `revert_candidates`). Decision logic follows K (changed-plan count):

- **K = 0** — fall through to existing clean path
- **K = 1** — existing single-plan flow (unchanged)
- **K > 1** — per-plan output blocks with `[HIGH]`/`[LOW]` severity labels, individual accept/reject prompt per changed plan. Untouched plans collapse to `M plans verified clean`. Any rejection: session stays suspended + that plan's `revert_candidates` printed for manual revert. Re-enable requires all prompts accepted.

### RFC accepted (2026-04-26)

Status updated Draft → Accepted. Sign-off block added (§ Sign-off at bottom of RFC).

---

## Open items

### Implementation (ready to start)

13 hook guards (`.enabled` check), `/suspend` command + skill, `/start` skill rewrite (Steps 0–4 per §5), `hooks/suspend-snapshot.sh`.

---

## Commits this session

- `b23a1d7` — rfc(opt-in): resolve OQ-5 with two-pass stat pre-filter and bounded re-examination
- (pending) — rfc(opt-in): resolve OQ-6 and accept RFC

---

## To resume in a new session

1. Paste `_repo-context.md` first
2. Paste this file second
3. Start implementation: 13 hook guards are the natural first PR (mechanical, low-risk, unblocks everything else)
