# Shared messages — Configuration

Reference these message templates when a skill needs to surface a configuration issue. Use as-is or adapt to include specific key names. Consistent wording keeps the human's mental model stable across skills.

## Layer 2 — missing config key

> **Config key required:** `<key>` is not set in `config/tools.json`.
> Running `/configure --needs <key>` to set it up. Your original command will resume on success.

## Layer 3 — corrupted config

> **Config file invalid:** `config/tools.json` is not valid JSON.
> Run `/configure` to rebuild from scratch (your current file will be backed up) or open the file for manual repair.
> Edit and Write are blocked until the config is repaired.

## Missing optional key (warn-only)

> **Note:** `<key>` is not set — skipping `<step name>`. Set it in `config/tools.json` to enable this check.

## Config check passed

> Config check: all required keys present. Proceeding.
