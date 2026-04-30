> **Status:** discussion

# pr-review workflow: red-X-while-waiting UX problem

Companion: none (post-RFC-006-PR-7 follow-up).

## Problem

`.github/workflows/pr-review.yml` (RFC-004 PR-5, registered in branch protection by RFC-006 PR-5 era) fires the `review-required` check on `pull_request:[opened, synchronize, ready_for_review, reopened]` AND on `pull_request_review:[submitted, dismissed]`. When a non-doc PR is first opened, no APPROVED non-author review exists yet, so the job fails (exit 1) — branch protection shows a red X on the PR.

Observed sequence on PR-48, PR-49, PR-50:

1. PR opened → workflow runs on `pull_request:opened` → fails (no approval yet).
2. Bot or user submits a review → workflow runs on `pull_request_review:submitted` → passes (or fails on `--comment`).
3. The original failed run from step 1 stays on the SHA. Branch protection sees both runs; merge stays blocked until the failed one is `gh run rerun`'d.

The user's UX complaint: "the review-required error is still happening." The red X is misleading — it suggests a defect, but the gate is doing its job (waiting for human approval per `user-preferences` Rule 17).

## Constraints

- The check `review-required` must remain in `branch protection > required status checks` (it's the enforcement layer for AGENT-RULES §14 / RFC-004's non-author-review rule).
- Doc-only PRs must continue to auto-pass on open (no human review needed for pure-docs changes — the `pr-review.yml` `Determine doc-only PR` step encodes the canonical glob).
- Branch protection's required-checks list is static — a check name is required-or-not regardless of PR contents.
- A workflow run terminates as success / failure / neutral / skipped / cancelled. There is no "permanently pending/yellow" final state; "yellow" appears only when (a) a required check has never run on the SHA, or (b) a run is in progress.

## Three options

### (b1) Skip workflow on PR open — simple

Remove `pull_request:` from the `on:` trigger. Keep only `pull_request_review:[submitted, dismissed]`.

**Effect:**
- On PR open: no `review-required` check runs. Branch protection shows it as **expected** (yellow pending). Merge blocked.
- On any review submission: workflow fires, evaluates approved-non-author count, passes or fails.

**Tradeoff:** doc-only PRs no longer auto-pass on open. They wait for a review submission (which may be a bot `--comment` review — but `--comment` doesn't satisfy the gate, so doc-only PRs would need a real `--approve` from someone non-author too). That's a UX regression for doc-only PRs.

**Code change:** ~5 lines in `pr-review.yml`. Trivial.

### (b2) Two separate checks

- `pr-doc-check` — runs on `pull_request:[opened, synchronize, ready_for_review, reopened]`. Passes if doc-only; fails or no-ops if non-doc.
- `pr-review-check` — runs only on `pull_request_review:[submitted, dismissed]`. Passes if APPROVED non-author review exists; fails otherwise.

**Effect:** non-doc PRs show `pr-review-check` as expected/yellow until first review event. Doc-only PRs auto-pass via `pr-doc-check`.

**Tradeoff:** branch protection's required-checks list cannot be conditional ("require pr-review-check only when not doc-only"). Either both checks are required (which means doc-only PRs need a `pr-review-check` to fire too — defeats auto-pass) or neither (defeats the whole gate). The clean version requires a clever bridge job that either passes on doc-only or hands off to the review check.

**Code change:** moderate. New workflow file or split into two jobs in the existing workflow with bridging logic. Branch-protection update needed to swap the required check name.

### (b3) Single check, conditionally-skipped job — REJECTED

Keep the single `review-required` check name (no branch-protection change). Restructure `pr-review.yml`:

- One always-run `setup` job: determines doc-only and emits an output.
- One `review-required` job whose top-level `if:` evaluates `doc_only == 'true' || event_name == 'pull_request_review'`.

**Why rejected:** second-opinion review (2026-04-30) confirmed via GitHub Docs that **a job skipped via top-level `if: false` reports `conclusion=skipped`, and `skipped` is treated as PASSING by branch-protection required-status-checks evaluation.** So under (b3), a non-doc PR opened with zero reviews would have its `review-required` job skipped, the gate would mark it as passed, and the PR would be mergeable without review. That's a worse failure mode than the current red X.

A "corrected b3" with always-running job + conditional `exit 1` only on review events has the same defect: branch protection uses the latest run on the SHA, so the passing PR-open run unblocks merge.

**Code change:** N/A — option discarded.

### (b4) GitHub-native `required_pull_request_reviews` — preferred direction

Surfaced by second-opinion review. Replace the custom `pr-review.yml` review-count logic with GitHub's native branch-protection setting:

```bash
gh api repos/lantisprime/claude-sdlc/branches/main/protection --method PUT --input - <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": ["test"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_last_push_approval": true
  },
  "restrictions": null
}
JSON
```

**Effect:**
- GitHub's native review gate: PRs cannot merge until ≥1 APPROVING non-author review on the head SHA. SHA-bound (`require_last_push_approval: true`) — pushing new commits invalidates the prior approval.
- The custom `pr-review.yml` workflow can be retired (or simplified to handle only doc-only auto-pass via a label-based path).
- No red X — GitHub UI shows "Review required" as a clean blocker, not a check failure.
- **Closes the latent SHA-binding gap** (current `required_pull_request_reviews: null` means approvals are not SHA-bound — surfaced as OQ-5 below).

**Tradeoffs:**
- Doc-only auto-pass: GitHub's native gate applies uniformly to all PRs. Options: (i) accept that doc-only PRs need one human review too; (ii) keep `pr-review.yml` purely as a doc-only auto-approver (problematic — would need bot `--approve`, which violates user-preferences Rule 17); (iii) build a CODEOWNERS / GitHub-App-based carve-out for doc paths.
- **This is a behavior change**, not a workflow tweak. Per AGENT-RULES.md §2, behavior-changing proposals warrant an RFC with second-opinion + acceptance gate. Should not be a discussion-note one-shot.

**Code change:** small (one branch-protection API call + optional workflow retirement). Decision-weight: large (changes the gate model and removes the doc-only auto-pass).

## Updated recommendation

(b3) is **unsafe** and discarded. Among the remaining options:

- **(b1)** — simplest correct fix to the red-X UX. Doc-only auto-pass regression accepted.
- **(b2)** — structural complexity makes it not worth the effort relative to (b1) or (b4).
- **(b4) — GitHub-native review gate** — preferred direction. Closes the latent SHA-binding gap, eliminates the custom workflow, provides a clean "Review required" UX. Cost: behavior change + loss of doc-only auto-pass.

**Recommendation: promote (b4) to a real RFC.** This is bigger than a discussion-note one-shot — it modifies the review gate model, supersedes part of RFC-004, and the doc-only auto-pass removal needs the second-opinion cycle to weigh alternatives.

If (b4) is later rejected, fall back to **(b1)** as the safe minimal fix.

## Second-opinion findings (2026-04-30)

Reviewer: independent subagent.

**OQ-1 verdict:** GitHub treats `if: false` job skips as `conclusion=skipped`; skipped checks count as **success** for required-status-check evaluation (GitHub Docs, "About status checks"). Therefore (b3) silently unblocks non-doc PRs with no reviews.

**Other findings:**

1. (b1)'s doc-only regression is real but narrow — concern, accepted.
2. Stale-failed-run problem partially mitigated by `concurrency.cancel-in-progress: true` (pr-review.yml line 43), but cancellation only fires when a *new* run starts on the same group; the original opened-event failure run already completed before any review event triggers it.
3. `pull_request_review:dismissed` correctly re-blocks in the current workflow and would re-block in (b1) — nit.
4. **`dismiss_stale_reviews` is OFF** in current branch-protection config (`required_pull_request_reviews: null`). Approvals survive `synchronize` pushes — a SHA-binding gap that exists independently of the red-X problem. Surfaced as OQ-5.
5. Surfaced alternative: GitHub-native `required_pull_request_reviews` as the cleanest path — added above as (b4).

**Confirmed correct in original note:** diagnosis of the red-X mechanic, duplicate-run sequence, static required-checks-list constraint.

**Missing from original note:** native review gate as a first-class option; SHA-binding gap; partial mitigation from `concurrency.cancel-in-progress`.

## Open questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-1 | Does GitHub Actions treat job-level `if: false` skips as "expected/pending" or "success" for required status checks? | charltond.ho | **closed** (2026-04-30) — second-opinion confirmed: skipped = success. (b3) is therefore unsafe. |
| OQ-2 | If (b3) ships, does the doc-only check live in a `setup` job? | charltond.ho | **closed** — moot, (b3) rejected. |
| OQ-3 | What happens on `pull_request_review:dismissed`? Fail (forcing re-approval) or stay silent? | charltond.ho | **closed** — current behavior re-blocks correctly; preserve in any chosen option. |
| OQ-4 | Bundle AGENT-RULES.md hook-exclusion fix with the red-X fix? | charltond.ho | open — depends on which option ships. (b4) RFC = separate; (b1) ship-now = could bundle. |
| OQ-5 | **Latent SHA-binding gap:** `required_pull_request_reviews: null` and `dismiss_stale_reviews: false` in current protection means approvals survive `synchronize` pushes. Address as part of (b4) RFC, or as a separate one-line protection update right now? | charltond.ho | open — surfaced by second-opinion review. |
| OQ-6 | If (b4) ships and the doc-only auto-pass is removed, do we accept that doc-only PRs need one human review too, or rebuild the auto-pass via CODEOWNERS / GitHub App / label-based bypass? | charltond.ho | open — design decision for the future RFC. |
| OQ-7 | Does (b4) supersede part of RFC-004 (specifically the non-author-review enforcement)? Or is it a refactor of how RFC-004's intent is implemented? | charltond.ho | open — affects whether the new RFC is `supersedes: RFC-004` or just a follow-on. |

## References

- `.github/workflows/pr-review.yml` — current workflow (RFC-004 PR-5).
- `user-preferences` repo, `github-workflow-discipline.md` (commit 7467df2) — codifies "Bot reviews; user approves" expectation.
- PR-48 (#48), PR-49 (#49), PR-50 (#50) — exhibit the duplicate-run + red-X pattern.
- `sdlc-plugin/AGENT-RULES.md §14` — non-author review rule that this workflow enforces.
