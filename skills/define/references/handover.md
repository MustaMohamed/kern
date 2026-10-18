# Handover

How define sorts the builder questions the spec reviewer returns, and what the user gets with the spec. Adapted from superpowers 7.0.0 skills/brainstorming/SKILL.md (MIT).

## Sort

- Answered: the conversation, the issue or the repo already settles it. Write the answer into the spec.
- Minor: a sensible builder could settle it without changing what gets built. Settle it, and mark it under Decisions as `kern's call`.
- The user's: only the user can answer it, and the answer changes what gets built. Ask them all in one message, most important first, each with your recommended answer; fold the answers into the spec and run plan-check again.

That is the only round of questions the review produces. When it returns nothing important left, say so in one line.

## Hand over

With the request for the yes, list kern's calls: each `kern's call` under Decisions and each Assumption marked assumed, so the user can check them while reading.
