### Task 14: `mode` and `autopilot` skills

**Files:**
- Create: `skills/mode/SKILL.md`, `skills/autopilot/SKILL.md`
- Test: `tests/skills-control.test.mjs`

**Interfaces:**
- Consumes: the `kern mode:` line and the autopilot line from Task 8; `parseFrontmatter` from M0.
- Produces: slash skills `/kern:mode` and `/kern:autopilot` whose frontmatter matches skills spec B1 and B2 verbatim. Step 1 of each reads the hook line; neither ever writes state.

- [ ] **Step 1: Write the failing test**

`tests/skills-control.test.mjs`:
```js
// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';

const read = (name) => parseFrontmatter(readFileSync(join(import.meta.dirname, '..', 'skills', name, 'SKILL.md'), 'utf8'));

test('mode frontmatter matches spec B1', () => {
  const { data, error } = read('mode');
  assert.equal(error, null);
  assert.deepEqual(data, {
    name: 'mode',
    description: 'Switch voice (normal, terse) and surface (chat, auto, html) for this session, or show the current mode.',
    'disable-model-invocation': 'true',
    'argument-hint': '[terse|normal|chat|auto|html|default|status]',
    'allowed-tools': 'Read',
  });
});

test('autopilot frontmatter matches spec B2', () => {
  const { data } = read('autopilot');
  assert.deepEqual(data, {
    name: 'autopilot',
    description: "Turn this session's autopilot grant on or off, or show what it allows. Only a prompt you type can turn it on.",
    'disable-model-invocation': 'true',
    'argument-hint': '[on|off|status]',
    'allowed-tools': 'Read',
  });
});

test('both read the hook line first and never write the state file', () => {
  for (const name of ['mode', 'autopilot']) {
    const { body } = read(name);
    const steps = body.split('## Steps')[1].split('\n## ')[0];
    assert.match(steps, /^\n1\. Read the `kern mode:` line/, `${name} step 1`);
    assert.match(steps, /[Nn]ever write/, `${name} forbids writing state`);
  }
});

test('autopilot lists the floor and who can turn it on', () => {
  const { body } = read('autopilot');
  for (const s of ['Merge, deploy, review posting and tracker writes always need the user', 'Only the user, by typing `/kern:autopilot on`']) {
    assert.ok(body.includes(s), s);
  }
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test tests/skills-control.test.mjs`
Expected: FAIL with `ENOENT ... skills/mode/SKILL.md`.

- [ ] **Step 3: Write `skills/mode/SKILL.md`**

```markdown
---
name: mode
description: Switch voice (normal, terse) and surface (chat, auto, html) for this session, or show the current mode.
disable-model-invocation: true
argument-hint: "[terse|normal|chat|auto|html|default|status]"
allowed-tools: Read
---

# Mode

kern's prompt hook applies the switch before this skill loads. This skill only reports what the hook did.

## Steps
1. Read the `kern mode:` line the hook injected this turn.
2. No such line: reply "the mode hook did not run; nothing changed" and name the likely cause: bash missing, hooks disabled, or `kern: off` in the project settings. Never write or edit the session state file; guard G16 denies it.
3. `status`, or no argument: report voice, surface and autopilot. For each, give the default and where it comes from, using the Project settings block of the kernel (`mode.voice`, `mode.surface`, `autopilot`).
4. Surface `html` or `auto` while kern has no `visual` skill installed: add one line that visual pages arrive with the visual skill and replies stay in chat until then.
5. Reply in one line. The terse voice governs chat only. Files, commits, PR bodies and pages stay in plain prose.

## Words
`terse` and `normal` set the voice. `chat`, `auto` and `html` set the surface. `default` resets both to the settings defaults. `status` changes nothing. Words combine, as in `/kern:mode html terse`. An unknown word changes nothing.

A phrase that opens the prompt also switches, without this skill: "go terse", "terse mode", "back to normal", "html mode", "stop html", "chat only". A question or a negation, such as "don't go terse", never switches.
```

- [ ] **Step 4: Write `skills/autopilot/SKILL.md`**

```markdown
---
name: autopilot
description: Turn this session's autopilot grant on or off, or show what it allows. Only a prompt you type can turn it on.
disable-model-invocation: true
argument-hint: "[on|off|status]"
allowed-tools: Read
---

# Autopilot

A per-session grant for unattended runs. kern's prompt hook turns it on only from a command the user typed; this skill reports the result.

## Steps
1. Read the `kern mode:` line the hook injected this turn. No such line: reply "the hook did not run; autopilot is off". Never write the state file and never report "on" without the hook line.
2. `on`, and the line says `autopilot=on`: list what is allowed, what is denied, the floor, and how to stop (`/kern:autopilot off`, "stop autopilot", or `/clear`). Then ask for, or propose, a checkable stop predicate for the run, such as "stop when every task in the plan has a complete ledger line or one is parked".
3. `on`, and the hook reported "autopilot denied by <file>": name the file and the `autopilot: denied` key. Do not suggest changing it unless the user asks.
4. `status`: on or off, since when, the settings source of `autopilot`, and the `rebase.push` value.
5. `off`: confirm, then list the `parked:` lines in `WORK/ledgers/*/ledger.md` (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers` prints that directory) written since autopilot turned on.

## What autopilot allows
- Commit when the message passes the convention and attribution checks. `git add -A` stays denied.
- Push the current branch when it is not protected.
- Open a draft PR after the duplicate check.
- Push with `--force-with-lease` only when settings say `rebase.push: autopilot`, and only to your own branches.

Every other action that would ask is denied, because nobody is there to answer. Merge, deploy, review posting and tracker writes always need the user. Judgment calls are parked with the default chosen, and work that does not depend on them continues.

## Who can turn it on
Only the user, by typing `/kern:autopilot on`. Claude, a subagent, a skill, a background report, a scheduled task and another session cannot.
```

- [ ] **Step 5: Run the test and lint to verify they pass**

Run: `node --test tests/skills-control.test.mjs && node scripts/lint-skills.mjs`
Expected: `# pass 4`; `lint: clean`.

- [ ] **Step 6: Commit**

```bash
git add -- skills/mode/SKILL.md skills/autopilot/SKILL.md tests/skills-control.test.mjs
git commit -m "M1: add the mode and autopilot skills" -m "The hooks switch state; these skills report the result and never write it themselves."
```

---

