---
description: Front door for new users — asks six intake questions, checks fix-fast eligibility, then hands off to /plan with answers pre-filled. Use this instead of /plan if you're not sure where to start.
---

Invoke the `start` skill to guide the user through a short intake before planning begins.

The skill asks six questions, checks whether the task qualifies for `/fix-fast`, and then invokes the `plan` skill with the answers pre-filled as a Plan v0 draft. The human is responsible for reviewing the draft before signing the plan gate.

If the user already knows what they want and is comfortable with `/plan` directly, they don't need this command.
