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

test('implement references', () => {
  assertHeadings('skills/implement/references/test-design.md', ['# Test design', '## Name the break', '## Test the real thing', '## Mocks need a reason', '## Mutation check', '## Tautological tests', '## Adversarial inputs', '## Behaviour, not implementation']);
  assertContains('skills/implement/references/test-design.md', ['probe --mutate']);
  assertMaxBytes('skills/implement/references/test-design.md', 5000);
  assertHeadings('skills/implement/references/slicing.md', ['# Slicing', '## Vertical slices', '## Seams', '## Scope discipline']);
  assertMaxBytes('skills/implement/references/slicing.md', 1800);
});
