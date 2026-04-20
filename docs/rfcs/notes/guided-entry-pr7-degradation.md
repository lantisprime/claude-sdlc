# PR 7 — Distributed Sign-Off: Degradation and Failure Modes

**Companion to:** RFC 0001
**Scope:** Implementation reference for `skills/gate-signoff/SKILL.md` and `templates/gate.md` changes in PR 7.

This note exists because PR 7's "graceful degradation" story is more nuanced than PR 5's. PR 5 had a single fallback: config absent means current behavior. PR 7 has multiple layers that can be present, misconfigured, or missing, and each requires a different correct response. Some degrade, some hand off, some intentionally refuse. Implementers should read this before writing the skill changes.

---

## The layers that can fail

PR 7 depends on a chain of assumptions. Any link can be missing:

| Layer | Required for | If missing |
|---|---|---|
| Git installed | Everything | Plugin already unusable — hard dependency of the repo |
| Inside a git repo | Commits, audit trail | Hand off to PR 5 |
| Git config `user.email` | Identity resolution | Try env var; if also missing, see identity rules below |
| `CLAUDE_SDLC_APPROVER_IDENTITY` env var | Identity override | Fall through to git config |
| `approvals.assignments` map | Role verification | Capture with `role_verified: false` |
| Remote configured | Distributing signatures | Commit locally, print push-later guidance |
| Push access to branch | Sharing signatures | Commit stands; human pushes via PR |
| `git commit -S` signing key | Opt-in cryptographic authorship | Sign unsigned, flag it |

---

## Decision tree

```
gate-signoff invoked
│
├─ Is this a git repo?
│    ├─ NO  → hand off: "Distributed sign-off requires git. Falling back
│    │        to in-session multi-role (PR 5). All approvers must sign
│    │        in this session."
│    └─ YES → continue
│
├─ Can we resolve signer identity?
│    │  (check env var CLAUDE_SDLC_APPROVER_IDENTITY,
│    │   then `git config user.email`)
│    │
│    ├─ NO  → is `approvals.assignments` configured?
│    │        ├─ NO  → DEGRADE: capture signature, set role_verified=false
│    │        └─ YES → REFUSE: "Cannot verify you are assigned to this
│    │                 role. Set git config user.email or
│    │                 CLAUDE_SDLC_APPROVER_IDENTITY, or ask the
│    │                 assigned approver to sign."
│    │
│    └─ YES → does identity match assignment for this role?
│              ├─ NO  → REFUSE: "Signing as '<role>' requires
│              │         '<assigned>'; got '<resolved>'."
│              └─ YES → continue
│
├─ Write signature block to gate file
│
├─ Auto-commit enabled? (config: approvals.auto_commit, default false)
│    ├─ YES → git add + git commit
│    └─ NO  → prompt: "Commit this signature now? [Y/n]"
│
├─ Is `git commit -S` requested? (config: approvals.require_signed_commits)
│    ├─ YES → attempt signed commit
│    │         ├─ SUCCESS → record commit_signed=true in gate block
│    │         └─ FAIL (no key)    → commit unsigned, record
│    │                                commit_signed=false, print warning
│    └─ NO  → regular commit, commit_signed field omitted
│
├─ Is there a remote configured?
│    ├─ NO  → print: "Signature committed locally. No remote configured;
│    │        share this branch manually."
│    └─ YES → attempt git push
│              ├─ SUCCESS            → "Signature pushed. Next approver
│              │                        can pull branch <name>."
│              ├─ REJECTED (protection) → "Signature committed locally
│              │                          to <branch>. Push rejected by
│              │                          branch protection. Open a PR."
│              └─ FAIL (network etc.) → "Signature committed locally.
│                                       Push failed: <reason>.
│                                       Try again later."
```

---

## Refuse vs. degrade vs. hand-off — the three response types

### Refuse

The plugin stops and prints a clear error. Used when continuing would violate the feature's purpose.

- Identity unresolvable *and* `assignments` is configured — degrading here would defeat having assignments at all
- Identity resolves but doesn't match the assigned role — the whole point of assignment checking

Refusal is not a gap or a missing feature. It is the feature doing its job. The RFC and user-facing docs should be explicit about this.

### Degrade

The plugin captures what it can and records the gap in the signature itself. Downstream reviewers can see the degradation and decide whether it's acceptable.

- Identity unresolvable *and* `assignments` absent → `role_verified: false`
- `git commit -S` requested but key missing → `commit_signed: false`
- No remote → local commit only, with a note

Degradation requires that the gap be visible in the gate file. Silent degradation is worse than refusal because it launders weak signals as strong ones.

### Hand off

The plugin explicitly tells the user "this isn't the right mode for your environment" and falls back to an adjacent feature.

- Not in a git repo → use PR 5 in-session multi-role

Hand-off is used when the prerequisites for PR 7 aren't met but another working path exists. Print the message so the user knows why the behavior changed.

---

## Test matrix

Each row should have at least one integration test before merging PR 7.

| Scenario | Expected behavior | Gate block state |
|---|---|---|
| Happy path: all layers present, identity matches | Sign, commit, push, all roles verified | `role_verified: true, commit_signed: false` |
| Happy path with GPG signing | As above, signed commit | `role_verified: true, commit_signed: true` |
| Not a git repo | Hand off to PR 5 | N/A (PR 5 format) |
| Git repo, no remote | Local commit, push-later message | `role_verified: true` |
| Git repo, remote exists, push rejected by branch protection | Local commit stands, PR-suggestion message | `role_verified: true` |
| No git config, no env var, no assignments | Capture with flag | `role_verified: false` |
| No git config, no env var, assignments present | Refuse | No gate block written |
| Identity resolved, wrong role | Refuse | No gate block written |
| Identity resolved, role matches, but chain already has this role signed | Skip to next unsigned role | Existing block untouched |
| All roles already signed | No-op, print "Already signed" | Existing blocks untouched |
| Partial gate file from prior session, signer is next in chain | Append only their block | Prior blocks untouched, new block added |
| Rebase-induced conflict on gate file | Each signature block is a separate hunk; normal git merge handles it | All blocks preserved |
| Two approvers sign on parallel branches, then merge | Both signature blocks land as independent hunks; merge produces a valid gate file | Both blocks preserved, no conflict |
| Tracker notification fails (offline, no token, 4xx/5xx) | Signature lands; local print fallback; gate block flags the gap | `role_verified: true, notification_sent: false` |
| `commit -S` requested, no GPG key | Unsigned commit, warning printed | `role_verified: true, commit_signed: false` |
| `commit -S` requested, GPG key present, keyring trust fails | Treat as success from plugin's POV; trust verification is the team's workflow | `role_verified: true, commit_signed: true` |

---

## Gate file format implications

For rebase-friendly and append-only behavior, signature blocks must be independent. Proposed shape:

```markdown
# Gate: build-rate-limit-headers

Plan version: 2
Status: awaiting-approvals

## Signatures

<!-- @@SIGNATURE tech_lead @@ -->
- Role: tech_lead
- Signer: alice@acme.com (resolved from git config)
- role_verified: true
- Work item: https://linear.app/acme/issue/PROJ-1234
- Acknowledgment: "https://linear.app/acme/issue/PROJ-1234"
- Signed at: 2026-04-22T10:15:00Z
- commit_signed: false
- notification_sent: true
<!-- @@END SIGNATURE tech_lead @@ -->

<!-- @@SIGNATURE architect @@ -->
- Role: architect
- Signer: bob@acme.com (resolved from git config)
- role_verified: true
- Work item: https://linear.app/acme/issue/PROJ-1234
- Acknowledgment: "https://linear.app/acme/issue/PROJ-1234"
- Signed at: 2026-04-22T10:18:00Z
- commit_signed: true
- notification_sent: true
<!-- @@END SIGNATURE architect @@ -->
```

The `@@SIGNATURE <role> @@` markers let the skill find, skip, or append blocks without full markdown parsing. Each block is self-contained so concurrent edits on different branches produce clean merges rather than structural conflicts.

---

## User-facing messages

Every refuse and degrade path needs a message that tells the user (a) what happened, (b) why, and (c) what to do next. Templates for the core cases:

**Refuse — identity unresolvable with assignments configured:**
```
Cannot verify you are assigned to role '<role>'.
Neither git config user.email nor CLAUDE_SDLC_APPROVER_IDENTITY
is set. Options:
  1. Run: git config --global user.email "you@example.com"
  2. Set: export CLAUDE_SDLC_APPROVER_IDENTITY="you@example.com"
  3. Ask the assigned approver '<assigned>' to sign instead.
```

**Refuse — identity mismatch:**
```
Signing as '<role>' requires identity '<assigned>'.
Your git identity is '<resolved>'.
If you are the correct approver, update your git config.
If you are not, the assigned approver must sign instead.
```

**Degrade — no assignments, no identity:**
```
Signature captured without identity verification.
Gate will record role_verified: false.
Reviewers can decide whether this signature is acceptable.
```

**Hand off — not a git repo:**
```
Distributed sign-off requires git.
This directory is not a git repo. Falling back to in-session
multi-role sign-off. All approvers must be present in this
session to sign in sequence.
```

**Degrade — no remote:**
```
Signature committed locally (<commit sha>).
No remote is configured. Share this branch with the next
approver manually, or push once a remote is added.
Next approver: <role> — <assigned>.
```

**Degrade — push rejected by branch protection:**
```
Signature committed locally to branch '<branch>' (<commit sha>).
Push was rejected by branch protection.
Open a pull request to land the signature:
  gh pr create --base main --head <branch>
```

---

## What this note does not cover

- Appeal paths, reviewer-of-reviewers, retrospective audits — deferred per RFC
- Cryptographic key management and keyring distribution — team workflow, not plugin concern
- Merge conflict resolution when two signers race — git handles structurally; the block format prevents content conflicts
- Revocation of a signature after the fact — git revert plus a new version per PR 4 is the current answer

---

*End of note.*
