# RFC: Opt-in Activation, Enhanced /start, and Suspend/Resume with Integrity Verification

**Status:** Implemented — 2026-04-26 accepted by Charlton Ho; all four components shipped (opt-in activation, enhanced /start, /suspend + suspend-snapshot.sh, re-enable reconciliation).  
**Date:** 2026-04-26  
**Touches:** hooks (13), skills (2 modified + 1 new), commands (1 modified + 1 new)

---

## 1. Summary

The plugin currently forces engagement on install. `env-detect.sh` emits a LAYER-0 directive that instructs Claude to invoke `/configure` before responding to the developer's first task. `plan-gate.sh` hard-blocks every `Edit`/`Write`/`MultiEdit` call until a plan artifact exists. Together, these create immediate friction for any developer who wants to evaluate the plugin before committing to its workflow.

This RFC proposes four coordinated changes:

1. **Opt-in activation** — the plugin is passive until the developer explicitly enables it via `/start`. Hooks do nothing until a `.enabled` marker exists.
2. **Enhanced `/start`** — absorbs the configure wizard (reduced to essentials, auto-detected where possible), replaces the 6-question intake with a single plain-English description, auto-generates `scope.md` and a plan draft, and shows a "what this armed" summary.
3. **`/suspend` command** — disables enforcement and snapshots governance artifacts (SHA-256, AES-256 encrypted) to detect tampering during the suspension window.
4. **Re-enable reconciliation** — on re-enable after suspension, Claude re-examines all plans and requirements, summarizes changes, and if the developer accepts, generates a new REQ ID that supersedes the old ones and restarts the planning phase. No hard block.

---

## 2. Goals and Non-goals

### Goals

- Frictionless install: developer can work with Claude normally until they opt in
- One command to enable: `/start` handles config, task intake, and artifact generation in a single flow
- Transparent suspend: developer can temporarily disable enforcement without losing governance state
- Audit-preserving re-enable: changes during suspension are reconciled through the planning process, not erased or blocked

### Non-goals

- Auto-enabling based on project type or file detection
- GUI or web-based configuration
- Changes to the 8-phase workflow, gate structure, or REQ ID format
- Changing fix-fast eligibility rules
- Multi-team sign-off configuration in `/start` (deferred to `/configure`)

---

## 3. Core Principles Alignment

| Principle | How this RFC upholds it |
|---|---|
| **Human in the lead** | Opt-in means the developer actively chooses enforcement. Re-enable reconciliation puts the human in control of whether suspension-period changes are acceptable — Claude summarizes, human decides. New REQ IDs are proposed, not written, until the human signs them in `/plan`. |
| **Reduce cognitive load** | `/start` absorbs configure by auto-detecting repo, CI, stack, and tracker. 6 intake questions collapse to 1. The developer sees detected values as facts, not prompts. |
| **Plan before code** | `plan-gate.sh` still hard-blocks edits once enabled. The opt-in model defers enforcement to when the developer chooses to engage — see §3.1 for the governance boundary statement. |
| **Surgical edits** | Not affected by this RFC. |
| **Work-item traceability** | REQ ID supersession on re-enable preserves traceability. Old REQ IDs remain active until the human explicitly signs a new one. The audit chain is unbroken. |
| **Graceful degradation** | Passive mode (not enabled) is graceful degradation by design. Suspended mode preserves all state and surfaces the gap clearly at session start. `secret-scan.sh` runs regardless of activation state — credential safety is not gated on opt-in. |

---

### 3.1 Governance Posture Declaration

This RFC changes the enforcement boundary. That change must be stated plainly.

**Before this RFC:** installing the plugin activates SDLC enforcement immediately. `env-detect.sh` instructs Claude to invoke `/configure` before the developer's first task. `plan-gate.sh` blocks edits from the first session.

**After this RFC:** enforcement begins only after the developer runs `/start`. A fresh install is passive — no hooks fire, no gates block.

**This is an intentional product tradeoff for adoption**, not a governance relaxation. The following constraints ensure enforcement is not weakened where it matters:

1. **Once enabled, enforcement is identical to the pre-RFC model.** No gate is removed. No block is relaxed. `plan-gate.sh` is as strict as before.
2. **`secret-scan.sh` is always-on.** Credential scanning runs regardless of `.enabled` state. Secrets are a safety concern, not an SDLC ceremony.
3. **Suspension is an auditable event, not an escape hatch.** It requires a stated reason, logs a window entry, and shows all active plans and unsigned gates before proceeding. The enforcement gap is always visible.
4. **Re-enable restores full enforcement posture.** The human must sign a new REQ ID in `/plan` before the old one is retired. No phase is silently skipped on re-enable.

---

## 4. Feature 1 — Opt-in Activation Model

### 4.1 The enabled marker

`/start` creates `.claude/sdlc/.enabled` as its first action. This file is the single source of truth for whether the plugin is active.

| Marker state | Plugin state |
|---|---|
| `.enabled` absent, `.suspended` absent | Fresh install — passive |
| `.enabled` present | Active — full enforcement |
| `.suspended` present | Explicitly suspended — passive |

### 4.2 Hook guard mechanism

Every enforcement hook gains a one-liner guard immediately after `set -euo pipefail`:

```bash
[ -f ".claude/sdlc/.enabled" ] || exit 0
```

**Exception — `secret-scan.sh`:** this hook does **not** receive the `.enabled` guard. It runs on every `Edit`/`Write`/`MultiEdit` call regardless of activation state. A developer who hasn't opted in can still accidentally commit a secret; credential scanning is a safety baseline, not SDLC ceremony.

**Suspended-state messaging:** hooks that are warn-type (exit 0, stderr output) should distinguish between "not yet enabled" and "suspended." When `.claude/sdlc/.suspended` exists, warn-type hooks emit a contextual line before exiting:

```
[SDLC] Workflow suspended — <check-name> check is paused.
```

This makes the enforcement gap visible rather than silent.

SessionStart hooks (`env-detect.sh`, `session-plan-check.sh`) have different logic — they show contextual messages rather than silently exiting.

### 4.3 Session state matrix

| State | `env-detect.sh` message | `session-plan-check.sh` message |
|---|---|---|
| Fresh install (no marker) | `[SDLC] claude-sdlc is installed. To enable the SDLC workflow, run /start.` | Silent |
| Suspended | `[SDLC] Workflow suspended. Run /start to re-enable.` | Silent |
| Enabled, no plans | Silent | `[SDLC] Workflow enabled. Run /plan to start your first task.` |
| Enabled, plan in progress | Silent | Existing session-plan-check logic (active task, next phase, pending sign-offs) |
| Enabled, all phases complete | Silent | `[session] Plan '<slug>' complete. Start a new task with /start.` |

### 4.4 LAYER-0 message update

`env-detect.sh` LAYER-0 directive changes from:

> Invoke the configure skill before responding to the user's first task request. After configure completes, offer to begin a task with /start.

To the passive awareness message only. Claude does not proactively invoke any skill on fresh install. The developer chooses when to engage.

---

## 5. Feature 2 — Enhanced `/start`

### 5.1 Conflict analysis with existing commands

Before this RFC, three commands shared overlapping responsibilities:

| Responsibility | `/configure` | `/start` (old) | `/start` (new) |
|---|---|---|---|
| Write `config/tools.json` | ✓ (8-question wizard) | — | ✓ (auto-detect + 2 prompts max) |
| Take task description | — | ✓ (6 questions) | ✓ (1 question) |
| Draft `scope.md` | — | — | ✓ |
| Draft plan artifact | — | hands off to `/plan` | ✓ (auto-generated) |
| Show hooks summary | — | — | ✓ |
| Create `.enabled` marker | — | — | ✓ |

Adding a separate `/quickstart` command would create two entry points for the same job. Option A — absorbing quickstart behavior into `/start` — keeps one front door. `/configure` remains available for power users who need manual reconfiguration or multi-team sign-off setup.

### 5.2 Step 0 — Config check and auto-detection

Runs only when `config/tools.json` is absent. Skipped entirely if config already exists.

**Auto-detection sequence (no prompts):**

| Signal | Detected value | Source |
|---|---|---|
| `.git` directory | `vcs: "git"` | filesystem |
| `git remote get-url origin` | repo slug (`owner/repo`) | git |
| `.github/workflows` present | `ci: "github-actions"` | filesystem |
| `.gitlab-ci.yml` present | `ci: "gitlab-ci"` | filesystem |
| `.circleci/config.yml` present | `ci: "circleci"` | filesystem |
| `Jenkinsfile` present | `ci: "jenkins"` | filesystem |
| `package.json` present | `language: "node"` | filesystem |
| `pyproject.toml` / `requirements.txt` | `language: "python"` | filesystem |
| `go.mod` present | `language: "go"` | filesystem |
| `Cargo.toml` present | `language: "rust"` | filesystem |
| `pom.xml` / `build.gradle` | `language: "java"` | filesystem |
| `jest`/`vitest` in devDependencies | `test.command` | package.json |
| `pytest` in pyproject.toml | `test.command` | pyproject.toml |
| `eslint` in devDependencies | `lint.command` | package.json |
| `ruff` in pyproject.toml | `lint.command` | pyproject.toml |
| Remote URL contains `github.com` | `tracker: "github"` | git remote |
| Remote URL contains `gitlab` | `tracker: "gitlab"` | git remote |
| Remote URL contains `bitbucket` | `tracker: "bitbucket"` | git remote |

All detected values are shown as facts — not questions. Only three things can require a prompt:

**Prompt 1 — Tracker confirm (always shown, pre-selected):**
```
Issue tracker (inferred: GitHub Issues) — correct? [Y/n/override]
```
If remote is absent or ambiguous:
```
Which issue tracker does this project use?
A) GitHub Issues  B) GitLab  C) Jira  D) Linear  E) None
(detected: none) _
```

**Prompt 2 — Auth token (only if tracker ≠ None):**
```
Paste your <tracker> token (stored locally, never committed).
Skip with Enter to omit: _
```

**Prompt 3 — Project slug (only if tracker detected but slug not parseable from remote):**
```
Project key or repo slug: _
```

Best case (GitHub/GitLab remote present): **1 prompt** (token only — tracker and slug auto-filled).  
Typical case (no remote): **3 prompts** maximum.  
Multi-team sign-off (Q4–Q8 in `/configure`): **deferred entirely** — not surfaced in `/start`.

After prompts, show diff and write `config/tools.json` on confirm.

### 5.3 Step 1 — Create `.enabled` marker

```bash
mkdir -p .claude/sdlc
touch .claude/sdlc/.enabled
```

Hooks are now armed. Runs immediately after config is written.

### 5.4 Step 2 — Task intake

Replace the 6-question intake with a single prompt:

```
What are you building or fixing — one sentence.
> add a login page
```

Auto-classify task type from keywords:

| Keywords | Classification |
|---|---|
| add / build / create / implement / new | `new-build` |
| fix / bug / broken / patch / correct | `fix` |
| change / update / migrate / refactor / modify | `change-request` |
| ambiguous | Ask: "Is this a new feature, a bug fix, or a change to existing behavior?" |

Fix-fast eligibility check remains — driven by auto-classified type plus a size follow-up if the description implies a small change.

### 5.5 Step 3 — Auto-generate artifacts

If `.claude/sdlc/scope.md` does not exist, create it from the description.  
Create `.claude/sdlc/plans/<slug>.md` with:

| Field | Source |
|---|---|
| `REQ-ID` | `REQ-001` (or next available REQ-N) |
| `Classification` | auto-classified from step 2 |
| `Stack` | detected in step 0 |
| `In-scope files` | heuristic from description keywords |
| `In-scope functions` | `TBD — refine in /plan` |
| `Out-of-scope` | standard safety list |
| `Estimate` | keyword-based: "add" → medium, "fix" → small |
| `Status` | `draft` |

### 5.6 Step 4 — "What this armed" summary

```
[SDLC] Workflow enabled.

  Repo:    github.com/owner/my-app
  CI:      github-actions
  Stack:   python / pytest / ruff / black
  Tracker: GitHub Issues → owner/my-app

  config/tools.json              → written
  .claude/sdlc/scope.md          → created  [draft — review in /plan]
  .claude/sdlc/plans/login.md    → REQ-001  [draft — review in /plan]
    classification: new-build              [suggested]
    estimate:       medium                 [suggested]
    in-scope files: 3 heuristic matches    [suggested — confirm in /plan]

Hooks now active:
  ✓ plan-gate        — blocks edits without a signed plan
  ✓ secret-scan      — catches credentials before they're written (always-on)
  ✓ diff-scope-check — warns if edits drift outside REQ-001 scope
  ✓ bash-safety      — flags destructive shell commands

Next: review the plan below, then run /plan to sign it.
All [draft] and [suggested] fields require your confirmation in /plan before they are authoritative.
```

Plan displayed inline. Handoff to `/plan` for review and sign-off.

---

## 6. Feature 3 — `/suspend` Command

### 6.1 Suspend flow

1. **Hard-block if not enabled:** if `.enabled` is absent, print `[SDLC] Workflow is not enabled — nothing to suspend.` and exit. Do not proceed.

2. **Require a suspension reason** (hard-block if empty):
   ```
   Reason for suspension (required): _
   ```

3. **Show active plans and unsigned gates:**
   ```
   Active plans:
     REQ-001  add-login-page  [build gate unsigned]
     REQ-000  scope-setup     [signed — all phases complete]

   Warning: REQ-001 has an unsigned build gate.
   Suspending will pause enforcement. The gate remains open until you re-enable and complete it.
   Proceed? [Y/n]
   ```

4. Run `suspend-snapshot.sh` — hash and encrypt governance artifacts.

5. **Log suspension window entry** to `token-tracker.sh` (or append to `.claude/sdlc/.suspension-log.jsonl` if token-tracker is absent):
   ```json
   {"event": "suspend", "at": "2026-04-26T14:32:00Z", "reason": "<reason>", "active_plans": ["REQ-001"]}
   ```

6. Rename `.claude/sdlc/.enabled` → `.claude/sdlc/.suspended`.

7. Confirm:
   ```
   [SDLC] Workflow suspended. Snapshot saved. Enforcement paused.
   Suspension logged. Run /start to re-enable.
   ```

### 6.2 Snapshot: what gets hashed

Two categories with different severity on re-enable:

| Category | Files | Severity if changed |
|---|---|---|
| **Governance artifacts** | `.claude/sdlc/plans/*.md`, `.claude/sdlc/gates/*.md`, `.claude/sdlc/sign-offs/*.md`, `.claude/sdlc/scope.md`, `config/tools.json` | Triggers reconciliation flow |
| **In-scope source files** | Files listed in active plan's `In-scope files` section | Scope drift warning only |

### 6.3 Encryption mechanism

**Hashing:** SHA-256 per file via `shasum -a 256` (macOS) or `sha256sum` (Linux).

**Manifest format (pre-encryption):**
```json
{
  "suspended_at": "2026-04-26T14:32:00Z",
  "governance": {
    ".claude/sdlc/plans/login-page.md":     {"sha256": "<hash>", "size": 4821, "mtime": 1745678400},
    ".claude/sdlc/gates/build-login-page.md": {"sha256": "<hash>", "size": 2103, "mtime": 1745678200},
    ".claude/sdlc/scope.md":               {"sha256": "<hash>", "size": 1540, "mtime": 1745670000},
    "config/tools.json":                   {"sha256": "<hash>", "size":  892, "mtime": 1745660000}
  },
  "source": {
    "src/auth/login.py":   {"sha256": "<hash>", "size": 3204, "mtime": 1745678100},
    "src/auth/session.py": {"sha256": "<hash>", "size": 1876, "mtime": 1745671000}
  }
}
```

**Encryption:**
```bash
openssl enc -aes-256-cbc -pbkdf2 \
  -k "$SUSPENSION_KEY" \
  -in manifest.json \
  -out .claude/sdlc/.suspension-snapshot.enc
```

**Key management:**
- On every suspend: generate a new 32-byte random key. Rotate unconditionally — never reuse a previous key.
- Store the current key as `suspension_key` in `config/tools.local.json` (already gitignored). Overwrite any previous value.
- Key expiry: if the stored key is older than 90 days (compare `suspended_at` in manifest), treat decryption as failed.
- On decryption failure (expired key, missing key, or corrupted snapshot): fall back to plain-manifest mode. Display prominently:
  ```
  [SDLC] WARNING: Snapshot decryption failed. Tamper detection is degraded.
  Proceeding with plain-manifest comparison only.
  Continue with weakened integrity check? [Y/n]
  ```
  Hard-block if the developer enters `n`. Do not silently proceed.

**Fallback if `openssl` absent:**
```
[SDLC] WARNING: openssl not found. Suspension snapshot will use plain SHA-256 manifest.
Tamper detection is weaker — changes to governance files may go undetected.
Continue with weakened integrity check? [Y/n]
```
Hard-block if the developer enters `n`. Never silently accept the weaker fallback.

**Snapshot location:** `.claude/sdlc/.suspension-snapshot.enc`

### 6.4 Session message during suspension

`env-detect.sh` emits:
```
[SDLC] Workflow suspended. Run /start to re-enable.
```

`session-plan-check.sh` is silent (enabled guard exits 0 when `.enabled` absent).

---

## 7. Feature 4 — Re-enable Reconciliation

### 7.1 `/start` behavior when `.suspended` marker detected

Different path from fresh install — skips the config wizard entirely. Config already exists.

### 7.2 Snapshot verification

1. Read `suspension_key` from `config/tools.local.json`
2. Decrypt `.suspension-snapshot.enc` (apply key expiry and failure handling per §6.3)
3. Recompute SHA-256 for every file in the manifest
4. Classify differences:

   | Change | Severity | Action |
   |---|---|---|
   | Governance artifact modified | High | Reconciliation required |
   | Sign-off file removed | High | Reconciliation required — treat same as governance change |
   | In-scope source: >20% size change OR >5 files changed | High | Escalate to reconciliation required |
   | In-scope source: below threshold | Low | Scope drift note only |
   | File in manifest no longer exists | High | Flagged — reconciliation required |
   | New governance files not in manifest | High | Flagged — reconciliation required |

   Removed sign-offs are governance changes. A missing sign-off file is not equivalent to a minor source edit — it means a previously approved gate was invalidated during the suspension window.

### 7.3 Re-examination

**Pass 1 — stat pre-filter:** `stat` (size + mtime) is run against all manifest files. Files where both values match the stored snapshot are skipped. Files where either value differs are flagged (set S1). Git mtime churn — rebase, stash pop, checkout — can inflate S1; pass 2 absorbs these false positives before the model loads anything.

**Pass 2 — SHA-256 confirm:** `shasum -a 256` is run on each file in S1 and compared against the stored hash. Files with matching hashes are discarded. The remaining confirmed-changed files form set S2.

**Bounded load — S2 + one-hop neighbors:** Claude loads S2 plus one-hop artifact neighbors, restricted to active plans. A plan is active if it has at least one unsigned, missing, stale, or conflicting required sign-off. Completed plans are excluded — their approval chains are closed; they are evidence, not active control state.

One-hop rules by file type:

| File type in S2 | Also load |
|---|---|
| `scope.md` | All active plans (capped — see below) |
| `plans/<slug>.md` | That plan's gates |
| `gates/<phase>-<slug>.md` | That gate's sign-offs |
| `sign-offs/<REQ-ID>-<role>.md` removed | Parent gate |
| Source file | Referencing plan's `In-scope files` section |

**scope.md safety valve:** Scope changes are global, so `scope.md` ∈ S2 expands re-examination to active plans. To keep this bounded on large-team repos, if the active-plan count exceeds 20, Claude loads only the 20 most-recently-modified active plans and their one-hop neighbors by default. It must warn that the scope re-examination was capped, list the omitted active-plan count, and offer an explicit option to expand to all active plans or to a named plan subset. This is a context safety valve, not a correctness shortcut: omitted plans are deferred, never marked safe.

With the bounded set loaded, Claude validates:
- Are active requirements still internally coherent?
- Which gates were modified and what changed?
- What source-level changes occurred within the plan's scope?

Deeper drift — changes not surfaced by this bounded load — is handled by existing mechanisms: `gate_hash` (§6.5) catches content drift in already-filed sign-offs; `approval-reconcile.sh` surfaces remaining gaps at the next phase advance. Re-examination answers "what do I need to reload to resume safely?" — it does not re-run the full governance system.

Produces a plain-language summary — no jargon, no gate file notation. Human-readable.

When multiple active plans are in scope, re-examination groups its output by REQ ID rather than emitting a flat file list. Each entry in the plan-keyed structure carries:

```text
REQ-ID:
  changed_files:     files in S2 belonging to this plan's governance or in-scope source set
  severity:          HIGH (governance artifact modified or sign-off removed) | LOW (source drift only)
  summary:           plain-language description of what changed
  revert_candidates: same as changed_files — echoed verbatim in rejection output
```

When only one plan is active, the structure degenerates to a single entry and the output follows the single-plan format in §7.4.

### 7.4 Reconciliation output

**Governance changes detected:**
```
[SDLC] Resuming after suspension — changes detected.

Files modified during suspension:
  .claude/sdlc/gates/build-login-page.md
  .claude/sdlc/sign-offs/REQ-001-qa.md
  src/auth/login.py

Re-examining requirements...

Changes summary:
  • Build gate: QA sign-off was removed
  • src/auth/login.py: expanded from 120 → 190 lines
    (outside original REQ-001 scope of 3 files)
  • No schema or API changes detected

Are these changes acceptable? [Y/n]
```

**If Y — REQ supersession proposed (not written yet):**
```
  Proposed: supersede REQ-001 → REQ-002.

  REQ-001 remains active. REQ-002 has not been written.

  To confirm:
    1. Run /plan — Claude will draft REQ-002 for your review.
    2. Sign REQ-002 in /plan as you would any new plan.
    3. REQ-001 is marked superseded only after REQ-002 is signed.

  Workflow re-enabled. Enforcement is active but plan-gate will
  require a signed plan — sign REQ-002 in /plan before editing.
```

- Claude does **not** write the new plan file at this step. REQ-002 is created only when the developer runs `/plan` and signs it.
- `/plan` receives the reconciliation context and pre-fills REQ-002 fields from REQ-001 + suspension diff.
- On REQ-002 sign-off: old plan file gets `Status: superseded` header and is renamed `login-page.v1.md`. New `login-page.md` contains REQ-002 with `Supersedes: REQ-001` field.
- Snapshot file deleted only after REQ-002 is signed.

**If N:**
```
  Workflow stays suspended.
  Revert the changes above manually and run /start to try again.
```

`.suspended` marker remains. Snapshot preserved.

**No governance changes (source drift below threshold):**
```
[SDLC] Resuming after suspension — no governance changes detected.

  Source files modified during suspension: 2  [below escalation threshold]
  ⚠ Suspension drift pending review — run /status to see affected files.

  Workflow re-enabled.
```

No new REQ ID. Resume from prior state. Snapshot deleted.

`/status` surfaces `⚠ suspension drift pending review` as a sticky item until the developer explicitly acknowledges it. The drift does not block work, but it remains visible in every `/status` output until reviewed.

**Multiple active plans (K > 1) — changed and clean:**

```
[SDLC] Resuming after suspension — changes detected.

3 active plans snapshotted — 2 changed, 1 verified clean.

━━ REQ-001  add-login-page  [HIGH] ━━━━━━━━━━━━━━━━━━━

  Files modified during suspension:
    .claude/sdlc/gates/build-login-page.md
    .claude/sdlc/sign-offs/REQ-001-qa.md
    src/auth/login.py

  Changes summary:
    • Build gate: QA sign-off was removed
    • src/auth/login.py: expanded from 120 → 190 lines
      (outside original REQ-001 scope of 3 files)
    • No schema or API changes detected

  Accept changes to REQ-001? [Y/n] _

━━ REQ-003  add-search-bar  [LOW] ━━━━━━━━━━━━━━━━━━━━

  Files modified during suspension:
    src/ui/search.py

  Changes summary:
    • src/ui/search.py: 8-line addition within REQ-003 scope
    • No governance artifacts changed

  Accept changes to REQ-003? [Y/n] _

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1 plan verified clean: REQ-002 (update-payments)
```

Prompts appear sequentially — one per changed plan. If any plan is rejected, the workflow stays suspended after all prompts complete:

```
  REQ-001 rejected. Workflow stays suspended.

  Revert these files and run /start to try again:
    .claude/sdlc/gates/build-login-page.md
    .claude/sdlc/sign-offs/REQ-001-qa.md
    src/auth/login.py
```

If all changed plans are accepted, a supersession is proposed for each, one at a time — follow the single-plan acceptance flow above for each. Re-enable follows after all supersessions are proposed.

### 7.5 REQ ID supersession rules

- Find highest existing `REQ-N` across all plan files
- Increment to `REQ-(N+1)`
- New plan inherits all fields from old plan, with:
  - `Supersedes: REQ-<previous>`
  - `Amended: <ISO timestamp>`
  - `Status: draft` (must be re-signed)
- All downstream gates for the old slug are preserved as historical record
- New gates created fresh for REQ-(N+1) slug

---

## 8. Files Touched

### Modified

| File | Change |
|---|---|
| `hooks/env-detect.sh` | Remove LAYER-0 "invoke configure" directive; add passive awareness and suspended messages |
| `hooks/session-plan-check.sh` | Enabled guard; fix "no plans" message to say `/plan` not `/start` |
| `hooks/plan-gate.sh` | Enabled guard |
| `hooks/work-item-validation.sh` | Enabled guard |
| `hooks/bash-safety.sh` | Enabled guard |
| `hooks/diff-scope-check.sh` | Enabled guard |
| `hooks/adjacent-function-detector.sh` | Enabled guard |
| `hooks/format-on-write.sh` | Enabled guard |
| `hooks/secret-scan.sh` | **No enabled guard** — always-on regardless of activation state |
| `hooks/modified-code-test-gate.sh` | Enabled guard |
| `hooks/phase-gate.sh` | Enabled guard |
| `hooks/token-tracker.sh` | Enabled guard |
| `hooks/approval-reconcile.sh` | Enabled guard |
| `skills/start/SKILL.md` | Full rewrite — Steps 0–4 as specified in §5 |
| `commands/start.md` | Update description to reflect opt-in model |

### New

| File | Purpose |
|---|---|
| `hooks/suspend-snapshot.sh` | Hash + encrypt governance artifacts on suspend; verify + diff on re-enable |
| `skills/suspend/SKILL.md` | Suspend skill — in-flight warning, snapshot trigger, marker rename |
| `commands/suspend.md` | `/suspend` command definition |

---

## 9. Open Questions

1. ~~**`secret-scan.sh` always-on?**~~ **Resolved:** `secret-scan.sh` is always-on. No `.enabled` guard. See §3.1 and §4.2.

2. ~~**`openssl` absence fallback.**~~ **Resolved:** weak fallback requires explicit `[Y/n]` confirmation. Never silently proceeds. Developer can hard-block by entering `n`. See §6.3.

3. ~~**Token tracker gap.**~~ **Resolved:** suspension logs a window entry to `token-tracker.sh` or `.suspension-log.jsonl`. Required, not optional. See §6.1.

4. ~~**Can `/suspend` be run before `/start`?**~~ **Resolved:** `/suspend` hard-blocks if `.enabled` is absent. Error: `[SDLC] Workflow is not enabled — nothing to suspend.` See §6.1.

5. ~~**Re-examination depth.** The reconciliation summary is generated by Claude reading current artifacts. On large projects with many plan files this could be slow. Consider a file-count heuristic to warn the developer of expected wait time.~~ **Resolved:** Two-pass stat pre-filter bounds what Claude loads. See §7.3 for the full mechanism. Short form: `stat` (size + mtime) pre-filters to changed candidates (S1); SHA-256 confirms to S2; Claude loads S2 plus one-hop artifact neighbors restricted to active plans. If `scope.md` ∈ S2 and active-plan count exceeds 20, re-examination is capped to the 20 most-recently-modified active plans with a warn + explicit expansion offer — a context safety valve, not a correctness shortcut; omitted plans are deferred, never marked safe. Completed plans are excluded unless `scope.md` ∈ S2 or the developer requests historical audit review.

6. ~~**Multiple active plans on suspend.**~~ **Resolved:** re-examination groups output by REQ ID (plan-keyed structure — see §7.3). Display and decision logic follow K, the count of changed active plans: K = 0 falls through to the existing clean path; K = 1 uses the existing single-plan flow; K > 1 shows each changed plan separately with its severity, changed files, summary, and an individual accept/reject prompt. Untouched plans collapse to a single `M plans verified clean` count line — not a per-plan roster. Rejection of any plan keeps the session suspended and prints that plan's `revert_candidates` as manual revert guidance; re-enable requires all prompts to be accepted. See §7.3 and §7.4.

---

## 10. References

- `docs/rfcs/guided-entry-session-resume-multi-role.md` — guided entry and session resume design
- `docs/rfcs/multi-team-approval.md` — multi-team sign-off and role vocabulary
- `docs/SDLC.md` — authoritative phase reference
- `hooks/hooks.json` — hook registration
- `skills/configure/SKILL.md` — full configure wizard (Q1–Q8, four-layer model)
- `skills/start/SKILL.md` — current start skill (to be replaced)
- `CLAUDE.md` §Hook strictness philosophy — block vs warn decision criteria

---

## Sign-off

| Date | Accepted by | Notes |
|---|---|---|
| 2026-04-26 | Charlton Ho (author) | All 6 open questions resolved. Implementation: 13 hook guards + `/suspend` skill + `/start` rewrite. |
