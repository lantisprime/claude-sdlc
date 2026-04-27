---
description: Pause SDLC enforcement. Snapshots governance artifacts (SHA-256, AES-256 encrypted) so tampering is detectable on re-enable. Requires a stated reason. Hard-blocks if the workflow is not currently enabled. Run /start to re-enable and reconcile any changes made during the suspension window.
---

Invoke the `suspend` skill to pause the SDLC workflow.

The skill requires a reason, shows active plans with unsigned gates, runs `hooks/suspend-snapshot.sh` to hash and encrypt governance artifacts, logs the suspension window, and renames `.enabled` → `.suspended`.

Run `/start` to re-enable. The start skill will verify the snapshot, surface any governance or source changes made during suspension, and — if changes are acceptable — propose REQ supersession before re-arming enforcement.
