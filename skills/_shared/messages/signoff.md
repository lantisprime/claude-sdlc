# Shared messages — Sign-offs

Reference these message templates when a skill needs to communicate sign-off state. Consistent wording across skills avoids confusion at gate boundaries.

## Pending sign-offs at session start

> **Pending sign-off:** You have a pending sign-off on gate `<gate-file>` as `<role>`.
> Review the gate and add your sign-off at `sign-offs/<REQ-ID>-<role>.md`.

## Gate requires sign-off before proceeding

> **Gate not signed:** `gates/<phase>-<slug>.md` must be signed before `/<next-command>` can run.
> Review the gate file, then run the `gate-signoff` skill to record your approval.

## All sign-offs collected

> All required sign-offs collected for `<REQ-ID>`. The gate is fully approved.

## Sign-off recorded

> Sign-off recorded: `sign-offs/<REQ-ID>-<role>.md` — signed by `<signer>` at `<timestamp>`.
