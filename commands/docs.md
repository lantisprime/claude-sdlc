---
description: Update the SDLC artifact index, requirements traceability matrix, architecture manifest, and changelog after a phase change.
---

Invoke the `docs` skill. Refreshes:

- `.claude/sdlc/docs/index.md`
- `.claude/sdlc/docs/traceability.md`
- `.claude/sdlc/architecture/manifest.json`
- `CHANGELOG.md` (in the consuming repo root)
- Any user-facing docs affected by the change

Gaps in the traceability matrix are left visible, not papered over. The human decides whether to fill or waive.
