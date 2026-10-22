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
  assert.equal(s.length, 13);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['RED for the expected reason', 'NOTICED BUT NOT TOUCHING', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-new', 'adding `--branch <name>` when `branch.pattern` holds `{id}`', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'never guess a command', 'Do not commit.', 'wt-snap', 'wt-diff', 'kern-get', 'kern-detect', 'probe: mutation caught']);
  assertMaxBytes(SKILL, 5500);
});

test('implement runs define step 1\'s checks for a task with no agreed design, and asks when wt-new exits 2', () => {
  // 2026-10-20 workflow-define-fast-path-stored-data: a quick rename of a stored field routed to implement and
  // never met define's stored-data check; pressure-define-skip-approval run 2 worked around a wt-new exit 2
  // (task-16-diagnosis B2 and X1).
  const s = steps(readDoc(SKILL).body);
  // Task 16i review, I1: workflow-define-fast-path adds a double(n) export, and the skills spec expects the fast path
  // for it, so a new export is not a public API change; only a contract callers outside the repo depend on is.
  assert.ok(s[1].includes('A change to an existing public API (not a new export), stored data or authorization: say so, and ask whether to keep the fast path'), s[1]);
  assert.ok(s[2].includes('`wt-new` exit 2: say why and ask'), s[2]);
});

test('the entry check is step 1 on its own, with a plain condition, and only define\'s fixed-form line exempts a task', () => {
  // 2026-10-20 (task-16-diagnosis-2, Y2): the entry check opened a step that went on to say where to edit, and runs
  // did the where-to-edit half only: 3 of 3 workflow-define-fast-path runs and 2 of 3 of its stored-data variant.
  // pressure-define-skip-approval run 1's "this takes the fast path" passed for define's line, though it named no
  // choice. Task 16g review, M2: a diagnosed fix (diagnose step 7) and a kern:implementer worker, which cannot ask,
  // skip it.
  // Task 16k (task-16-diagnosis-3, Z1 and fix group 3): "after your reads and before any edit" held in 1 of 3
  // workflow-define-fast-path runs, which all read implement; the line moves to the route read, as the kernel's
  // `Skipped:` line, said before any tool call, held in 12 of 12.
  const s = steps(readDoc(SKILL).body);
  assert.match(s[1], /^1\. Entry check, main session only: unless an approved spec or plan covers this change, it fixes a cause diagnose found, or define said its `Building:` line, say `Building: <what>\. My choices: <each>\.` right after you read this file, before your next tool call; restate a choice your reads change before the first edit\. /);
  assert.ok(!s[1].includes('after your reads'), 'the old placement is gone');
  assert.ok(s[1].indexOf('`Building: <what>') < s[1].indexOf('A change to an existing public API'), 'the public API, stored data and authorization ask follows the line');
  assert.ok(!s[1].includes('wt-new'), 'where to edit is not in the entry check');
  assert.match(s[2], /^2\. Pick where to edit\. In a kern worktree, edit there\./);
  assert.match(s[3], /^3\. Resolve `test\.focused`/);
  assert.ok(s[7].includes('a command that step 3 could not resolve was asked for there'), s[7]);
  assertContains(SKILL, ['Stops at steps 1, 2, 3 and 8.']);
});

test('step 3 spells kern-detect\'s full path, since kern:implementer reads it under the subagent kernel', () => {
  // 2026-10-22 Opus audit, C-M9: trim a36c751 left `kern-detect <key>` bare, which leans on the main kernel's
  // `Scripts:` line; the subagent kernel has none, so a worker had to infer the path from kern-get beside it.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[3].includes('with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`.'), s[3]);
  assert.ok(s[3].includes('When both exit 3, ask the user; never guess a command.'), s[3]);
});

test('diagnose names implement\'s steps by their numbers', () => {
  // Task 16i split implement step 1, so each later step moved up one; diagnose cites two of them by number.
  const s = steps(readDoc(SKILL).body);
  const d = steps(readDoc('skills/diagnose/SKILL.md').body);
  assert.ok(d[2].includes('as `implement` step 3 does'), d[2]);
  assert.match(s[3], /^3\. Resolve `test\.focused`, `test\.full`/);
  assert.ok(d[8].includes('Make the patch as `implement` step 9 does (`wt-diff <wt> <tree-before>`'), d[8]);
  assert.ok(s[9].includes('`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>`'), s[9]);
});

test('implement references', () => {
  assertHeadings('skills/implement/references/test-design.md', ['# Test design', '## Name the break', '## Test the real thing', '## Mocks need a reason', '## Mutation check', '## Tautological tests', '## Adversarial inputs', '## Behaviour, not implementation']);
  assertContains('skills/implement/references/test-design.md', ['probe --mutate']);
  assertMaxBytes('skills/implement/references/test-design.md', 5000);
  assertHeadings('skills/implement/references/slicing.md', ['# Slicing', '## Vertical slices', '## Seams', '## Scope discipline']);
  assertMaxBytes('skills/implement/references/slicing.md', 1800);
});
