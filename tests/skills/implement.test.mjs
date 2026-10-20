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
  assertContains(SKILL, ['RED for the expected reason', 'NOTICED BUT NOT TOUCHING', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-new', 'adding `--branch <name>` when `branch.pattern` holds `{id}`', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'never guess a command', 'Do not commit.', 'wt-snap', 'wt-diff', 'kern-get', 'kern-detect', 'probe: mutation caught']);
  assertMaxBytes(SKILL, 5500);
});

test('implement runs define step 1\'s checks for a task with no agreed design, and asks when wt-new exits 2', () => {
  // 2026-10-20 workflow-define-fast-path-stored-data: a quick rename of a stored field routed to implement and
  // never met define's stored-data check; pressure-define-skip-approval run 2 worked around a wt-new exit 2
  // (task-16-diagnosis B2 and X1).
  const s = steps(readDoc(SKILL).body);
  // Task 16g review, M2: a diagnosed fix (diagnose step 7) and a kern:implementer worker, which cannot ask, skip it.
  assert.ok(s[1].includes("In the main session with no agreed design or diagnosed cause (no approved spec, no yes in chat and no fast-path line from define), first run define step 1's checks"), s[1]);
  assert.ok(s[1].includes('a public API, stored data or authorization change'), s[1]);
  assert.ok(s[1].includes('`wt-new` exit 2: say why and ask'), s[1]);
});

test('implement references', () => {
  assertHeadings('skills/implement/references/test-design.md', ['# Test design', '## Name the break', '## Test the real thing', '## Mocks need a reason', '## Mutation check', '## Tautological tests', '## Adversarial inputs', '## Behaviour, not implementation']);
  assertContains('skills/implement/references/test-design.md', ['probe --mutate']);
  assertMaxBytes('skills/implement/references/test-design.md', 5000);
  assertHeadings('skills/implement/references/slicing.md', ['# Slicing', '## Vertical slices', '## Seams', '## Scope discipline']);
  assertMaxBytes('skills/implement/references/slicing.md', 1800);
});
