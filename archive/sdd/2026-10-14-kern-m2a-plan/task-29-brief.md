### Task 29: Reply and voice rules (coverage gaps 14, 15 and 16)

**Files:**
- Modify: `kernel/kernel.md` (Reply section), `kernel/kernel-subagent.md` (Return line), `modes/terse.md` (two rules), `modes/terse-subagent.md`, `CHANGELOG.md`
- Test: `tests/voice.test.mjs`, `tests/hooks/session-start.bats`, `tests/hooks/subagent-start.bats`, `tests/skills-control.test.mjs` (the terse rule count)

**Interfaces:**
- Consumes: the M1 kernel and modes; lint rule 7's budgets.
- Produces: the kernel's Reply section says no is an acceptable answer (gap 15, `.upstream/pstack/pstack/skills/poteto-mode/SKILL.md:89`) and that chat in either voice skips the main AI tells (gap 14, from `skills/unslop/SKILL.md` patterns 9, 13, 15, 16, 20, 22 and 23); the subagent kernel's Return line asks for no preamble, praise or closing offer and no longer says "Put bulk in a file and return its path." (both pre-flights: SubagentStart injects it into every agent, and the investigator and task-reviewer cannot write a file; each writer agent's own body says where its report goes, as the implementer's does); terse rules 10 and 11 keep existing comments as payload and show only changed code with context (gap 16, `.upstream/caveman/skills/caveman/SKILL.md:58`). Rendered sizes after Task 30: kernel 3,487 chars with no settings, 3,926 with the longest; subagent kernel with terse about 1,092 of 1,200 in rule 7's count (1,131 before the bulk sentence was dropped, measured by pre-flight 2).

- [ ] **Step 1: Write the failing tests**

`tests/voice.test.mjs`:

```js
// tests/voice.test.mjs: the voice rules coverage gaps 14 and 16 added.
import { test } from 'node:test';
import { assertContains } from './helpers/md.mjs';

test('terse keeps existing comments and shows only changed code', () => {
  assertContains('modes/terse.md', [
    '10. Existing comments in a file you edit are payload: keep each one unless you were asked to change it.',
    '11. Code shown in chat is the changed lines plus one or two lines of context, unless the user asks for the whole file or the file is new.',
  ]);
  assertContains('modes/terse-subagent.md', ['the existing comments in files you edit exact']);
});

test('the normal voice skips the main AI tells, in the kernel and in subagent returns', () => {
  assertContains('kernel/kernel.md', ['No is an acceptable answer: say when a scope, proposal or plan is weak, and why.', 'in either voice skip the main AI tells: openers, closing offers, praise, bold-label lists, long dashes, filler.']);
  assertContains('kernel/kernel-subagent.md', ['with no preamble, praise or closing offer']);
});
```

Append to `tests/hooks/session-start.bats`:

```bash
@test "the Reply section carries the candor line and the AI-tell line" {
  start startup
  [[ "$output" == *"No is an acceptable answer: say when a scope, proposal or plan is weak, and why."* ]] || false
  [[ "$output" == *"in either voice skip the main AI tells"* ]] || false
}
```

Append to `tests/hooks/subagent-start.bats`:

```bash
@test "subagent returns skip preamble, praise and closing offers, and no agent is told to write a bulk file" {
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"kern:investigator"')"
  ctx=$(context_of "$output")
  [[ "$ctx" == *"with no preamble, praise or closing offer"* ]] || false
  [[ "$ctx" != *"Put bulk in a file"* ]] || false
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/voice.test.mjs; tests/run-bats tests/hooks/session-start.bats tests/hooks/subagent-start.bats`
Expected: both node tests fail on the missing lines; the two new bats tests fail; the rest pass.

- [ ] **Step 3: Edit the kernel and the modes**

In `kernel/kernel.md`, Reply section, replace `Chat follows the active voice. Persisted` with:

```markdown
No is an acceptable answer: say when a scope, proposal or plan is weak, and why. Chat follows the active voice; in either voice skip the main AI tells: openers, closing offers, praise, bold-label lists, long dashes, filler. Persisted
```

In `kernel/kernel-subagent.md`, replace the Return line with:

```markdown
Return: verdict first, then deltas and file paths, with no preamble, praise or closing offer.
```

In `modes/terse.md`, after rule 9, add:

```markdown
10. Existing comments in a file you edit are payload: keep each one unless you were asked to change it.
11. Code shown in chat is the changed lines plus one or two lines of context, unless the user asks for the whole file or the file is new.
```

Replace `modes/terse-subagent.md` with:

```markdown
Voice: terse. Verdict or answer first, short sentences, no ceremony. Keep code, commands, paths, errors and the existing comments in files you edit exact. Files you write use plain prose.
```

In `tests/skills-control.test.mjs`, test `terse mode tells the voice to answer only what was asked, in numbered order`, the rule numbers now run to 11. Replace `assert.deepEqual(nums, ['1', '2', '3', '4', '5', '6', '7', '8', '9']);` with:

```js
  assert.deepEqual(nums, ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']);
```

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Kernel: no is an acceptable answer, and chat in either voice skips the main AI tells; terse keeps existing comments and shows only changed code.`

- [ ] **Step 4: Run the tests and lint**

Run: `node --test tests/voice.test.mjs tests/skills-control.test.mjs && tests/run-bats tests/hooks/session-start.bats tests/hooks/subagent-start.bats && node scripts/lint-skills.mjs`
Expected: `# fail 0`; every bats test passes (the 4,000-char kernel test and the 1,200-char subagent test included); lint prints no errors (rule 7 and rule 11).

- [ ] **Step 5: Commit**

```bash
git add -- kernel/kernel.md kernel/kernel-subagent.md modes/terse.md modes/terse-subagent.md tests/voice.test.mjs tests/skills-control.test.mjs tests/hooks/session-start.bats tests/hooks/subagent-start.bats CHANGELOG.md
git commit -m "M2: add candor and AI-tell lines, and two terse payload rules" -m "unslop covered persisted text only; the normal voice and subagent returns now skip the main tells, and terse no longer drops comments from edited files."
```

---

