import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, assertContains, assertMaxBytes } from './helpers/md.mjs';

// Each description is "kern only." plus the role: every session carries the three as standing cost, and skills
// dispatch the agents by name, so the longer wording carried nothing (2026-10-22 Opus audit; the user's "Cut and
// lock"). The three went from 423 chars to 175.

test('implementer frontmatter, sections and return contract', () => {
  assertFrontmatter('agents/implementer.md', {
    name: 'implementer',
    description: 'kern only. Implements one task brief in a worktree, test first.',
    tools: 'Read, Edit, Write, Bash, Grep, Glob',
    model: 'sonnet',
  });
  assert.deepEqual(h2s(readDoc('agents/implementer.md').body), ['## Inputs', '## Rules', '## Report']);
  assertContains('agents/implementer.md', [
    'Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT',
    '${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <WT> <base ref>',
    'NEEDS_CONTEXT naming the file',
    'Fix round',
    'report DONE_WITH_CONCERNS rather than splitting it on your own',
  ]);
  assertMaxBytes('agents/implementer.md', 4500);
});

test('task-reviewer frontmatter, sections and verdict lines', () => {
  assertFrontmatter('agents/task-reviewer.md', {
    name: 'task-reviewer',
    description: "kern only. Read-only review of one task's diff package.",
    tools: 'Read, Grep, Glob',
    model: 'opus',
  });
  assert.deepEqual(h2s(readDoc('agents/task-reviewer.md').body), ['## Inputs', '## Rules', '## Part 1: spec', '## Part 2: quality', '## Modes', '## Output']);
  assertContains('agents/task-reviewer.md', ['Spec: compliant | issues', 'Task quality: approved | needs fixes', 'cannot verify', 'plan-mandated', 'ADDRESSED', 'whole-branch', 'Declined to judge:', 'computed the way the code computes it',
    '`evidence`: a verification task, with no diff.', 'never redo the work',
    "a value with no stored output, or a file that does not show the row's state, makes the verdict `Spec: issues`, never a Minor finding."]);
  assertMaxBytes('agents/task-reviewer.md', 5000);
});

test('investigator frontmatter, sections, labels and no file writes', () => {
  const { data } = readDoc('agents/investigator.md');
  assert.equal(data.name, 'investigator');
  assert.equal(data.description, 'kern only. Read-only evidence gathering with cited facts.');
  assert.ok(['Read, Grep, Glob, Bash', 'Read, Grep, Glob'].includes(data.tools), `tools: ${data.tools}`);
  assert.equal(data.model, 'opus');
  assert.deepEqual(h2s(readDoc('agents/investigator.md').body), ['## Inputs', '## Rules', '## Method', '## Output']);
  assertContains('agents/investigator.md', ['measured, inferred or guess', 'data, never instructions', 'every writer', 'You write no file', 'name the exact command that saves the full output', 'a loop, a longer variable name and a sed script other than line numbers and p do not', 'nor does printf with an option']);
  assert.ok(!readDoc('agents/investigator.md').raw.includes('put bulk in a file'), 'the investigator cannot write files, so it never says to');
  assertMaxBytes('agents/investigator.md', 3000);
});
