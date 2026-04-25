# Sign-off: <REQ-ID> — <role>

<!--
One file per signer, per role. Save to:
  .claude/sdlc/sign-offs/<REQ-ID>-<role>.md

To compute gate_hash:
  awk '/^## Required sign-offs/{exit} {print}' <gate-file> | shasum -a 256 | awk '{print $1}'

The hash covers gate content ABOVE the ## Required sign-offs heading only.
This means adding a new required role to the gate does not invalidate an existing sign-off,
but any change to the design content the signer reviewed will trigger a reconciler warning.

transport options: local | network-share | git | mcp
-->

---
req_id: <REQ-ID>
gate_ref: .claude/sdlc/gates/<phase>-<task-slug>.md
gate_hash: sha256:<hash>
role: <role>
signer: <name or email>
timestamp: <YYYY-MM-DDTHH:MM:SSZ>
transport: local
evidence: <path, URL, or description — prefer immutable refs: git SHA, archived email ID, signed PDF path>
---

I, <name> (<Role>), approve <REQ-ID> per gate `<phase>-<task-slug>`.

<Brief statement of what was reviewed and any caveats — be specific enough that an auditor
reading this file six months later understands what you assessed and what assumptions you made.>
