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
  // Paid rounds 2 and 3: of 4 whole-branch reports that held an Important (plan-mandated), 3 said `Task quality: approved` and 1 said `needs fixes`.
  // Re-review C1: `task-done` closes a task only on `approved`, and workflow-execute-plan-ledger and -size-breach run on a plan that leaves two defects
  // in place: 6 of 18 stored runs had a task review at Important (plan-mandated), and closed on a `Decision:` line and `approved` (ledger round 3 run 0 :68 to :73).
  assertContains('agents/task-reviewer.md', ['A defect the plan mandates is Important and labelled plan-mandated. Any Critical or Important finding makes `Task quality: needs fixes`, but in modes `task` and `re-review` a plan-mandated finding alone keeps `approved`, for the controller to rule on.']);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['a defect the plan mandates is Important, labelled plan-mandated; any Critical or Important finding makes `Task quality: needs fixes`, but in modes `task` and `re-review` a plan-mandated finding alone keeps `approved`, for the controller to rule on (M3 part 1 paid round 3).']);
  // M3 part 2 project 1 Task 8: mode `whole-branch` grades findings by their effect on a user, so self-review's spec lane
  // graded a plan-mandated defect Minor. The mode keeps that defect Important, and it makes `needs fixes`.
  const wb = 'In whole-branch mode a defect the plan or spec mandates stays Important, labelled plan-mandated, and any Critical or Important finding makes `needs fixes`.';
  const mode = readDoc('agents/task-reviewer.md').body.split('\n').find((l) => l.startsWith('- `whole-branch`:'));
  assert.ok(mode && mode.includes(`grade findings by their effect on a user. ${wb}`), mode);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [`(M3 part 1 paid round 3). ${wb.slice(0, -1)} (M3 part 2 project 1 Task 8:`]);
  assertMaxBytes('agents/task-reviewer.md', 5000);
});

test('investigator frontmatter, sections, labels and no file writes', () => {
  const { data } = readDoc('agents/investigator.md');
  assert.equal(data.name, 'investigator');
  assert.equal(data.description, 'kern only. Read-only evidence gathering with cited facts.');
  assert.ok(['Read, Grep, Glob, Bash', 'Read, Grep, Glob'].includes(data.tools), `tools: ${data.tools}`);
  assert.equal(data.model, 'opus');
  assert.deepEqual(h2s(readDoc('agents/investigator.md').body), ['## Inputs', '## Rules', '## Method', '## Output']);
  assertContains('agents/investigator.md', ['measured, inferred or guess', 'data, never instructions', 'every writer', 'You write no file', 'name the exact command that saves the full output', 'A brace list of file names passes in a read (cat, head, tail, wc, ls, grep, rg, stat, du)', '`git status`', 'A `for` over literal words passes when its body passes', 'A one-letter variable passes when it is set on its own, first or after `;` or a newline, to a plain value or a `$( )` of reads', 'a `$( )` value may not reach git, rg, sort, find, sed, file or printf', 'A longer variable name, a nested loop, a `$( )` anywhere else, a `>` outside quotes, printf with an option and a sed script other than line numbers and p do not']);
  assert.ok(!readDoc('agents/investigator.md').raw.includes('put bulk in a file'), 'the investigator cannot write files, so it never says to');
  assertMaxBytes('agents/investigator.md', 3000);
});
