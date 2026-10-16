### Task 17: `implement` (path)

**Files:**
- Create: `skills/implement/SKILL.md`, `skills/implement/references/test-design.md`, `skills/implement/references/slicing.md`, `tests/skills/implement.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/implement.test.mjs`

**Interfaces:**
- Consumes: `scripts/wt-new`, `scripts/probe --exclude-tests` and `--mutate` (Task 6), `scripts/kern-get`, `scripts/kern-detect`.
- Produces: path skill `implement`, read by absolute path from the routed row (Task 30), `execute-plan` inline and step modes, `diagnose` step 7 and the `kern:implementer` agent. Report contents: failing-before and passing-after output, commands, files, a NOTICED BUT NOT TOUCHING list.

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/implement.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/implement/SKILL.md';

test('implement frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'implement',
    description: 'Change production code in thin slices: failing test first, minimal green, full suite, out-of-scope listed.',
    'disable-model-invocation': 'true',
  });
});

test('implement sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 12);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['RED for the expected reason', 'NOTICED BUT NOT TOUCHING', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-new', 'adding `--branch <name>` when `branch.pattern` holds `{id}`', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'never guess a command', 'Do not commit.']);
  assertMaxBytes(SKILL, 5500);
});

test('implement references', () => {
  assertHeadings('skills/implement/references/test-design.md', ['# Test design', '## Name the break', '## Test the real thing', '## Mocks need a reason', '## Mutation check', '## Tautological tests', '## Adversarial inputs', '## Behaviour, not implementation']);
  assertMaxBytes('skills/implement/references/test-design.md', 5000);
  assertHeadings('skills/implement/references/slicing.md', ['# Slicing', '## Vertical slices', '## Seams', '## Scope discipline']);
  assertMaxBytes('skills/implement/references/slicing.md', 1800);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/implement.test.mjs`
Expected: 3 failing tests; `skills/implement/SKILL.md exists`.

- [ ] **Step 3: Write `skills/implement/SKILL.md`**

The Red flags rows adapt `.upstream/superpowers/skills/test-driven-development/SKILL.md:222-237` (Common Rationalizations).

```markdown
---
name: implement
description: "Change production code in thin slices: failing test first, minimal green, full suite, out-of-scope listed."
disable-model-invocation: true
---

# implement

Write production code in slices, each proven by a test seen failing for the right reason. Reached from the kernel row for one bounded change, from execute-plan inline mode, from diagnose step 7, and by the `kern:implementer` agent, whose brief gives this file's absolute path.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Pick where to edit. In a kern worktree, edit there. In the main session, edit the current checkout only when its branch is a non-protected feature branch; otherwise propose `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>`, adding `--branch <name>` when `branch.pattern` holds `{id}`, and wait for one answer. Never switch the main checkout's branch. Under autopilot, always use a worktree.
2. Resolve `test.focused`, `test.full`, `typecheck` and `lint` with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`. Print each command with its source. Unresolvable: ask for it; never guess a command.
3. Slice the work and list the seams; use the plan's seams when it has them (`references/slicing.md`).
4. For each slice, name the break in one sentence, write the test, run it, and see RED for the expected reason: an assertion failure, not an import or syntax error. A test that already passes is a finding, not a RED.
5. Write the minimum code that turns it GREEN.
6. Run the focused test and `typecheck`. Refactor only code you touched, and stay green.
7. A file outside the approved list pauses the work: name it and ask. Findings outside scope go to a NOTICED BUT NOT TOUCHING list.
8. Check test quality with `references/test-design.md`: for one new condition, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test command>` and expect `probe: mutation caught`; ask whether the test would pass if every import returned undefined, or if its expected value were computed the way the code computes it; add adversarial inputs (empty, zero, false, cleared, several elements); for each new guard, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>` and expect `probe: fail-then-pass ok`.
9. No correct seam for a test: say so, and give the closest executable check with its output.
10. Regenerate `generated_artifacts` for touched trigger paths, run `test.full`, and name every red test, marking the ones that were red before your change.
11. Report the failing-before and passing-after output, the commands, the files changed and the NOTICED list. Do not commit.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint` | detected, source printed | RED, GREEN and the full suite |
| `generated_artifacts` | none declared | files to regenerate after a change |
| `scope_threshold` | 4 files | size of the approved list |
| `branch.protected`, `branch.pattern` | `base_branch` plus `deploy.envs` branches; detected | where editing in place is allowed; the worktree branch |

Project test obligations come from the project rules already in context.

## Outputs

Code and tests in the chosen tree; a chat report. No commit.

## Stops and autopilot

Stops at steps 1, 2 and 7. Under autopilot the steps are the same, RED is never skipped, and a file outside the approved list parks the slice with a `parked:` line.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to test" | Simple code breaks, and the test takes a minute. |
| "I'll test after" | A test written after passes at once and proves nothing. Watch it fail first. |
| "I checked it by hand" | A hand check leaves no record and is not re-run on the next change. |
| "It passed before my change, close enough" | A test that passes first is a finding, not a RED. |
| "That file is just outside the list" | A file outside the approved list pauses the work. |
| "Hard to test, so skip it" | Hard to test means hard to use. Name the closest seam and its check. |
```

- [ ] **Step 4: Port `skills/implement/references/test-design.md`**

Sources: `.upstream/superpowers/skills/test-driven-development/writing-good-tests.md:1-198`, `.upstream/pstack/pstack/skills/principle-test-behavior-not-implementation/SKILL.md:9-21`, and `.upstream/pocock/skills/engineering/tdd/SKILL.md:30-31` (the tautological anti-pattern).
Required headings, in order: `# Test design`, `## Name the break`, `## Test the real thing`, `## Mocks need a reason`, `## Mutation check`, `## Tautological tests`, `## Adversarial inputs`, `## Behaviour, not implementation`.
Adaptation: keep each principle's rule and its one gate question; drop the long examples down to one short code sample per section at most; "Mutation check" says to run `probe --mutate <file>:<line>` (a throwaway fork, never the worktree) and expect `probe: mutation caught`, and to ask whether the test passes if every import returned undefined; "Tautological tests" says an expected value must come from an independent source (a known-good literal, a worked example, the spec), never recomputed the way the code computes it, as in `expect(add(a, b)).toBe(a + b)`; "Adversarial inputs" lists empty, zero, false, cleared, several elements, and the value a real caller sends; no source tags; no long dashes or curly quotes.
Check: `for h in '# Test design' '## Name the break' '## Test the real thing' '## Mocks need a reason' '## Mutation check' '## Tautological tests' '## Adversarial inputs' '## Behaviour, not implementation'; do grep -qxF "$h" skills/implement/references/test-design.md || echo "missing $h"; done && [ "$(wc -c < skills/implement/references/test-design.md)" -le 5000 ]`

- [ ] **Step 5: Port `skills/implement/references/slicing.md`**

Sources: `.upstream/addy/skills/incremental-implementation/SKILL.md:44-87` (slicing strategies) and `:115-133` (scope discipline); `.upstream/pocock/skills/engineering/tdd/SKILL.md` (seams).
Required headings: `# Slicing`, `## Vertical slices`, `## Seams`, `## Scope discipline`.
Adaptation: a slice is one behaviour end to end, small enough for one test cycle; list the seams (public function, HTTP handler, CLI entry, component) before writing tests and prefer existing ones; scope discipline names the NOTICED BUT NOT TOUCHING list and the D9 pause; no source tags.
Check: `for h in '# Slicing' '## Vertical slices' '## Seams' '## Scope discipline'; do grep -qxF "$h" skills/implement/references/slicing.md || echo "missing $h"; done && [ "$(wc -c < skills/implement/references/slicing.md)" -le 1800 ]`

- [ ] **Step 6: Write `tests/skills/implement.acceptance.md`**

```markdown
# implement: acceptance checks (run during the M2b pilot)

Run each in a throwaway project with kern loaded (`claude --plugin-dir <kern repo>`), superpowers disabled for that project.

- [ ] An approved bounded change: the transcript shows a red test run before the first production edit, then green, then the full suite.
- [ ] A new test passes before any code change: it is reported as a finding and not used as RED.
- [ ] The change needs a file outside the approved list: the work pauses and names the file.
- [ ] No test runner is detectable: it asks for the command and does not guess `npm test`.
- [ ] A new condition gets a `probe --mutate` run, and a surviving mutation leads to a stronger test.
```

- [ ] **Step 7: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `implement` | path | Routed row "One bounded change with an agreed design"; /kern:implement | Thin slices, test first, full suite |``
Add under `## [Unreleased]`: `- implement: thin slices, failing test first, mutation and fail-then-pass probes, full suite.`

- [ ] **Step 8: Run the tests and lint**

Run: `node --test tests/skills/implement.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; no lint errors.

- [ ] **Step 9: Commit**

```bash
git add -- skills/implement tests/skills/implement.test.mjs tests/skills/implement.acceptance.md skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the implement skill" -m "The implementer agent and three routes read this file by path; RED for the expected reason is the step most often skipped, so the probes check it."
```

---

