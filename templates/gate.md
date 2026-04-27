# Phase Gate: <phase>-<task-slug>

- **Phase:** plan | analyze | design | build | test | deploy | support
- **Task:** <task-slug>
- **Signed by:** <signer> <!-- Your name or email as it will appear in audit logs -->
- **Signed at:** <timestamp> <!-- ISO-8601 UTC, e.g. 2026-04-27T10:00:00Z -->
- **Work-item reference:** <work-item> <!-- URL of REQ / ticket / CR, or `no ticket REQ-<n>` in degraded mode -->

## Phase summary

<One paragraph: what was done, what artifacts were produced, what outstanding items exist.>

## Artifacts produced or updated

- …
- …

## Open items carried to next phase

- …

## Explicit waivers (if any)

- <rule waived>: <reason> — accepted by <name>

## Acknowledgment

<acknowledgment>
<!-- The user's raw sign-off message, quoted verbatim. Captured by the `gate-signoff` skill when signed via chat, or written by hand for /deploy and /fix-fast. -->

## Confirmation

I have reviewed the phase outputs and approve advancing to the next phase.

## Required sign-offs

<!--
Optional — remove this section entirely for single-signer gates.
Add one role per line when this gate requires multi-team approval.
Roles are free-form strings; use whatever your team calls the reviewers.

The approval-reconcile.sh hook warns at the end of each turn if sign-off files
are missing for any listed role. Sign-off files live at:
  .claude/sdlc/sign-offs/<REQ-ID>-<role>.md
Use templates/sign-off-multi.md as the starting point.

Example:
  - security
  - product
  - compliance
-->

