### Spec Compliance

- ✅ unslop body is upstream lines 5-105 unchanged. A diff against the upstream shows only the scripted first-sentence edit (skills/unslop/SKILL.md:9). Headings match the required five, in order.
- ✅ technical-writing body is upstream lines 8-106 under kern frontmatter, title, `## Steps` (skills/technical-writing/SKILL.md:27) and `## Standard`. A diff shows only the three scripted edits (jargon paragraph :47, Voice bullet :121, tabs sentence removed :124). Nine required H2s, in order.
- ✅ Both frontmatters are `disable-model-invocation: true`, descriptions under 120 characters.
- ✅ NOTICE lines 82-85 match the brief. pstack MIT attribution is already at NOTICE:11-12 with `licenses/pstack.LICENSE`. `unslop` needs no UPSTREAM.md entry (UPSTREAM.md:13).
- ✅ Kernel rows resolve. kernel/kernel.md:13 names `{KERN}/technical-writing/SKILL.md` and :30 names `{KERN}/unslop/SKILL.md`. `{KERN}` is `{ROOT}/skills` (:2). The first H2 of technical-writing is `## Steps`.
- ✅ No curly quotes, long dashes, machine paths or personal names in either file. `node --test tests/skills-writing.test.mjs`: 2 pass, 0 fail.
- ⚠️ Not run, per the rules: lint and licensing (the report carries them).

### Strengths

- The ports are byte-faithful outside the scripted edits, so upstream drift stays diffable.
- The test pins the heading order, the step 5 path and the removed tabs sentence. It would fail if any of them regressed.

### Issues

**Critical:** none.

**Important:** none.

**Minor**

1. skills/technical-writing/SKILL.md:104, "swarm logs" is pstack vocabulary a kern user will not recognise. Fix: "Do not paste run logs, SHA lists, or metric tables." This is a one-word change that deviates from "unchanged body", so it needs the brief's sign-off.
2. skills/unslop/SKILL.md:9 breaks the file's own rule 13 (:216, "no parentheses"). The brief-mandated edit "(chat replies follow the active kern voice first)" is a parenthetical. It also repeats "chat replies" twice in one sentence. Plan-mandated, but the test pins the text. Fix: change both the plan and the test to "Chat replies follow the active kern voice first. Everything else composed for a reader follows this file: subagent returns, ...". Or accept the parenthetical.
3. Same file, Shape table (:157) gives a Chat reply row with a shape, while the kernel (kernel.md:30) says "Chat follows the active voice. Persisted text follows unslop." The sentence at :9 half-reconciles this. The Chat reply row and the Adding soul rules ("Use 'I'", "Let some mess in", :190-191) still pull against terse voice modes. Adding soul is scoped to "human-facing prose", so the contradiction is mild. Fix, optional: reword the :9 sentence so it excludes chat replies instead of listing them.
4. skills/technical-writing/SKILL.md:113 says "Use periods, not semicolons", and unslop's own Shape table and Document rules use semicolons (unslop:153, :169). The skills do not contradict each other here. The rule applies to the text being written, not to the skill file itself. No action needed beyond awareness.
5. Spelling split: unslop's description says "catalogue" (:3), technical-writing's body says "catalog" (:121). Plan-mandated frontmatter versus upstream body. Fix: use "catalog" in the unslop description and update the brief.
6. skills/technical-writing/SKILL.md:112 and the worked example (:112-116) use "ratchet" and "proto". These are before-examples of the banned jargon and an illustrative repo, so they are intentional. "proto" is unexplained to a kern user but harmless.
7. NOTICE:84-85 (modes/terse.md, hooks/prompt-submit) are in the File map but belong to other tasks. Plan-mandated here. Both files exist, so the map is correct.
8. The implementer's concern 1, the test-5 `if` guard in the session-start test instead of `skip`, is outside this diff. It was not reviewed here.

Other upstream leftovers checked: no pstack command names, `/pstack` paths, Cursor or Sentry terms, or `docs/` paths. `grep` for `swarm|pstack` finds only item 1.

### Assessment

**Task quality:** Approved. The ports are faithful and the contracts hold. The only real leftover is "swarm logs", and the one self-contradiction (item 2) comes from the plan.
