---
description: Guided setup for config/tools.json and config/tools.local.json. Replaces manual file editing for first-time setup and common reconfigurations. Auto-invoked on fresh install (Layer 0) and when a command finds its required config missing (Layer 2). Safe to run anytime for proactive changes.
---

Invoke the `configure` skill to set up or update the plugin's configuration.

**Flags:**

- `/configure` — full wizard (up to 8 questions; single-signer users see 3)
- `/configure --needs <key[,key...]>` — scoped mode, asks only about the specified fields; used by Layer 2 auto-invoke
- `/configure --check` — dry run: validates current config, reports what's missing or malformed, no prompts, no writes

The skill always shows a diff of the proposed change before writing. It never writes without explicit confirmation. Non-secret keys go to `config/tools.json` (version-controlled); auth tokens go to `config/tools.local.json` (added to `.gitignore` automatically).
