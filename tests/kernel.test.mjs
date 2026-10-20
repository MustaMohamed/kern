// tests/kernel.test.mjs: kernel lines a trim must not drop.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, assertContains } from './helpers/md.mjs';
import { kernelRows } from '../scripts/lib/kernel-rows.mjs';

test('kern paths never resolve from the current directory', () => {
  // A headless run without this clause looked for kern/kernel/routes.md under the project and skipped kern.
  assertContains('kernel/kernel.md', ['Settings and working files resolve from the main worktree root, never the current directory.']);
});

test('on a match the route, or the project skill an override names, is read before any other tool call, and the todo list is named by its tool', () => {
  // 2026-10-18, Claude Code 2.1.302: 11 of 12 headless runs read routes.md, then nearly all made a project call
  // before the route, and none opened a todo list; that Claude Code has TaskCreate, not TodoWrite. An override
  // must stay in the same sentence, or a model with a project skill for the job reads kern's route first.
  assertContains('kernel/kernel.md', ['On a match, Read the route, or the project skill Overrides below names for its job, before any other tool call, even one into the project,', '`TaskCreate`', '`TodoWrite`']);
  assertContains('kernel/kernel.md', ['Before a new task\'s first tool call or question, match the task against the table below']);
});

test('the kernel table holds every route row, so no task reads a second file to route', () => {
  // 2026-10-20, Claude Code 2.1.302, claude-sonnet-5-5: rows inline routed 14 of 15 adherence cases, the
  // routes.md hop 11 of 15 (Task 16d, the user's "Inline rows").
  const text = readFileSync(join(ROOT, 'kernel', 'kernel.md'), 'utf8');
  assert.deepEqual(kernelRows(text).map((r) => r.route), ['define', 'plan', 'execute-plan', 'implement', 'diagnose', 'prove-it', 'self-review', 'recall', 'technical-writing', 'context']);
  assert.doesNotMatch(text, /routes\.md/);
  assert.ok(!existsSync(join(ROOT, 'kernel', 'routes.md')), 'kernel/routes.md is gone');
});

test('a change routes even when the user calls it quick, and each new task reads its route again', () => {
  // 2026-10-20 behaviour runs: under pressure prompts most runs skipped routing, and in multi-diagnose the
  // second task never read the route again. Only a question context answers is exempt: recall's row prompt,
  // "Where did I leave off?", is a question that must still route (Task 16d review, Important 1).
  assertContains('kernel/kernel.md', [
    'A task that changes code, fixes a bug, commits or claims done matches a row, even a quick, small or obvious one; only a casual turn, a question context answers, or a user opt-out matches nothing.',
    'Each new task reads its route, even one read earlier.',
  ]);
});

test('the header says what ${CLAUDE_PLUGIN_ROOT} means in a kern file read by path', () => {
  // The session-start render fills {ROOT} with the plugin root, so the line names an absolute path.
  assertContains('kernel/kernel.md', ['In kern files read by path, ${CLAUDE_PLUGIN_ROOT} means {ROOT}.']);
});
