# Shared messages — Plan

Reference these message templates when a skill needs to communicate plan state. Used by plan-gate.sh warnings and the plan skill's versioning flow.

## No plan found (gate block)

> **No plan found.** Edit and Write are blocked until a plan exists at `.claude/sdlc/plans/`.
> Run `/plan "<task description>"` to create one.

## Plan not signed (gate block)

> **Plan not signed.** The plan at `plans/<slug>.md` exists but has no `Signed at:` timestamp.
> Review the plan and sign the gate before proceeding.

## Material change detected — versioning prompt

> **Material change detected** in signed plan `<slug>.md` (Version `<N>`):
> - Changed: `<field names>`
>
> The current version will be archived as `<slug>.v<N>.md` (Status: superseded).
> A new Version `<N+1>` will be created. Prior sign-offs are on the archived file and do not carry forward.
>
> Proceed? [Y/n]

## Plan superseded — warning

> **Active plan is superseded.** `plans/<slug>.md` has `Status: superseded`.
> A newer version should exist. Check `plans/` and ensure you are working from the current version.

## Scope gate missing — warn only

> **No scope gate found.** It is recommended to sign `gates/scope-<project>.md` before planning.
> Run `/plan` and accept the scope-ingest prompt to create and sign it, or write `scope.md` directly.
