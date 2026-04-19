# When NOT to use this plugin

The plugin trades velocity for discipline. That trade is wrong for some kinds of work. This page names those cases explicitly so teams can self-select out for the right reasons.

---

## Who this plugin is not for

### 1. Spikes, prototypes, and exploratory work

Code you plan to delete is not code that benefits from a plan-gate. The point of a spike is "let me just try something and see what breaks." `plan-gate.sh` blocks `Edit`/`Write` until a plan exists; `work-item-validation.sh` requires a REQ ID or ticket. Both are correct for code you intend to merge and wrong for code you intend to throw away.

**Symptom:** you're pasting the same placeholder ticket 10 times a day, or writing one-line plans like "try the thing" just to unblock edits.

### 2. Solo developers and early-stage startups optimizing for speed

The plugin's payoff is traceability, audit evidence, and scope discipline across a team. None of those are load-bearing for a solo dev shipping to zero users. The 7 sign-offs per task become pure overhead.

**Symptom:** you're the only person who will ever read the gate files.

### 3. Research and prototyping teams

Research code lives and dies by iteration speed. An 8-phase gate on every experiment is an adoption failure waiting to happen.

**Symptom:** "phase" isn't a concept your team uses; your definition of done is "we learned something," not "it ships."

### 4. Teams without clear requirements

If your PM doesn't write clear requirements, you'll hit Phase 2's halt (`/analyze` asks clarifying questions when input is vague) on every task and blame the tool. The plugin surfaces the problem; it doesn't fix it.

**Symptom:** you and your PM are already fighting about scope before you type a command.

### 5. Mid-sized tasks that fall between `/fix-fast` and the full 8 phases

`/fix-fast` covers ≤ 2 files, ≤ 50 LOC, no schema/API/security/UX changes. A 3-file refactor or a 70-line API-touching change has to go through all 8 phases. If most of your team's work lives in this zone, the plugin will feel heavy most of the time.

---

## Who this plugin *is* for

- **Regulated industries** — financial services, healthcare, gov — where audit evidence is not optional
- **Enterprise teams** with mandatory audit trails or compliance reviews
- **Teams already suffering from AI-generated PR churn** — runaway Claude sessions, scope creep, unexplained edits
- **Junior-heavy rosters** that benefit from enforced discipline as scaffolding
- **Teams that have seen a surprising Claude API bill** — `/token-review` + phase budgets make cost legible

If none of the above describes you, the plugin is probably not worth the friction. That's fine.

---

## The honest version of the tradeoff

The README says the plugin "trades a little velocity for a lot of discipline." On average, across the happy path, that's true. It's also true that:

- Per-task overhead is real: 7 sign-offs, plan-before-edit, work-item-before-build
- Onboarding cost is front-loaded: a new engineer's first week is slower; the payoff lands in weeks 2–4
- Velocity *gains* come from smaller PRs, fewer runaway AI loops, earlier detection of vague requirements, and automatic audit evidence — not from any single phase being fast

If your team's work is mostly in the payoff zone, the plugin is a good trade. If it's mostly in the overhead zone, opt out.

---

## Related reading

- [README](../README.md) — quick-start and core principles
- [docs/SDLC.md](SDLC.md) — the authoritative phase reference
- [docs/USER-MANUAL.md](USER-MANUAL.md) — scenario walkthroughs
- [docs/claude-sdlc-enterprise-adoption.md](claude-sdlc-enterprise-adoption.md) — role/cost/audit story in detail
