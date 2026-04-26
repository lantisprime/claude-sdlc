# RFC: Opt-in Activation, Enhanced /start, and Suspend/Resume with Integrity Verification

**Status:** Draft  
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
| **Human in the lead** | Opt-in means the developer actively chooses enforcement. Re-enable reconciliation puts the human in control of whether suspension-period changes are acceptable — Claude summarizes, human decides. |
| **Reduce cognitive load** | `/start` absorbs configure by auto-detecting repo, CI, stack, and tracker. 6 intake questions collapse to 1. The developer sees detected values as facts, not prompts. |
| **Plan before code** | `plan-gate.sh` still hard-blocks edits once enabled. The opt-in model does not weaken this — it defers it to when the developer has chosen to engage. |
| **Surgical edits** | Not affected by this RFC. |
| **Work-item traceability** | REQ ID supersession on re-enable preserves traceability. Old REQ IDs are marked superseded, not deleted. The audit chain is unbroken. |
| **Graceful degradation** | Passive mode (not enabled) is graceful degradation by design. Suspended mode preserves all state and surfaces the gap clearly at session start. |

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

This covers all 11 enforcement hooks. SessionStart hooks (`env-detect.sh`, `session-plan-check.sh`) have different logic — they show contextual messages rather than silently exiting.

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
  .claude/sdlc/scope.md          → created
  .claude/sdlc/plans/login.md    → REQ-001 drafted

Hooks now active:
  ✓ plan-gate        — blocks edits without a signed plan
  ✓ secret-scan      — catches credentials before they're written
  ✓ diff-scope-check — warns if edits drift outside REQ-001 scope
  ✓ bash-safety      — flags destructive shell commands

Next: review the plan below, then run /plan to sign it.
```

Plan displayed inline. Handoff to `/plan` for review and sign-off.

---

## 6. Feature 3 — `/suspend` Command

### 6.1 Suspend flow

1. Check for in-flight work — warn if active unsigned gates exist:
   ```
   Warning: add-login-page has an unsigned build gate.
   Suspending will pause enforcement but not clear this state.
   Proceed? [Y/n]
   ```
2. Run `suspend-snapshot.sh` — hash and encrypt governance artifacts
3. Rename `.claude/sdlc/.enabled` → `.claude/sdlc/.suspended`
4. Confirm:
   ```
   [SDLC] Workflow suspended. Snapshot saved.
   Run /start to re-enable.
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
    ".claude/sdlc/plans/login-page.md": "<sha256>",
    ".claude/sdlc/gates/build-login-page.md": "<sha256>",
    ".claude/sdlc/scope.md": "<sha256>",
    "config/tools.json": "<sha256>"
  },
  "source": {
    "src/auth/login.py": "<sha256>",
    "src/auth/session.py": "<sha256>"
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
- On first suspend: generate 32-byte random key, store as `suspension_key` in `config/tools.local.json` (already gitignored)
- On subsequent suspends: reuse existing key
- Fallback if `openssl` absent: warn developer, store plain manifest with a SHA-256 self-hash for basic tamper detection

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
2. Decrypt `.suspension-snapshot.enc`
3. Recompute SHA-256 for every file in the manifest
4. Classify differences:
   - Governance artifact changed → reconciliation required
   - In-scope source file changed → scope drift, noted
   - File in manifest no longer exists → flagged
   - New governance files not in manifest → flagged

### 7.3 Re-examination

Claude reads all current plans, gates, sign-offs, and scope.md. Compares current state against the snapshot diff. Validates:
- Are requirements still internally coherent?
- Which gates were modified and what changed?
- What source-level changes occurred within the plan's scope?

Produces a plain-language summary — no jargon, no gate file notation. Human-readable.

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

**If Y — REQ supersession:**
```
  REQ-001 marked superseded.
  REQ-002 created → .claude/sdlc/plans/login-page.md
    (Supersedes: REQ-001, amended after suspension 2026-04-26T14:55:00Z)

  Workflow re-enabled. Run /plan to review and sign REQ-002.
```

- Old plan file: `Status: superseded` header added, file renamed to `login-page.v1.md`
- New plan file: `login-page.md` with REQ-002, `Supersedes: REQ-001` field
- Snapshot file deleted

**If N:**
```
  Workflow stays suspended.
  Revert the changes above manually and run /start to try again.
```

`.suspended` marker remains. Snapshot preserved.

**No governance changes (source drift only):**
```
[SDLC] Resuming after suspension — no governance changes detected.

  Source files modified during suspension: 3
  (scope drift noted — run /status to review)

  Workflow re-enabled.
```

No new REQ ID. Resume from prior state. Snapshot deleted.

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
| `hooks/secret-scan.sh` | Enabled guard |
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

1. **`secret-scan.sh` always-on?** There is an argument that credential scanning should be active regardless of the `.enabled` state — a developer who hasn't opted in can still accidentally commit a secret. Counter-argument: the opt-in model should be clean and symmetric. Deferred for a follow-up RFC.

2. **`openssl` absence fallback.** The plain-manifest + self-hash fallback is weaker than AES-256. Should we require `openssl` and block suspend if absent, or accept the weaker fallback silently? Current proposal: warn clearly, proceed with weak fallback.

3. **Token tracker gap.** `token-tracker.sh` has no record of work done during suspension. Should suspend log a "suspension window" entry in the token log so the gap is visible? Low priority, noted here for completeness.

4. **Can `/suspend` be run before `/start`?** Currently meaningless — if `.enabled` doesn't exist, there's nothing to suspend. Proposal: if developer runs `/suspend` before `/start`, print "Workflow is not enabled — nothing to suspend." and exit.

5. **Re-examination depth.** The reconciliation summary is generated by Claude reading current artifacts. On large projects with many plan files this could be slow. Consider a file-count heuristic to warn the developer of expected wait time.

6. **Multiple active plans on suspend.** The snapshot hashes all governance artifacts across all active plans. The reconciliation summary covers all of them. If only one plan was active and the other was untouched, the summary should call that out clearly to avoid confusion.

---

## 10. References

- `docs/rfcs/guided-entry-session-resume-multi-role.md` — guided entry and session resume design
- `docs/rfcs/multi-team-approval.md` — multi-team sign-off and role vocabulary
- `docs/SDLC.md` — authoritative phase reference
- `hooks/hooks.json` — hook registration
- `skills/configure/SKILL.md` — full configure wizard (Q1–Q8, four-layer model)
- `skills/start/SKILL.md` — current start skill (to be replaced)
- `CLAUDE.md` §Hook strictness philosophy — block vs warn decision criteria
