// tests/kernel.test.mjs: kernel lines a trim must not drop.
import { test } from 'node:test';
import { assertContains } from './helpers/md.mjs';

test('kern paths never resolve from the current directory', () => {
  // A headless run without this clause looked for kern/kernel/routes.md under the project and skipped kern.
  assertContains('kernel/kernel.md', ['Settings and working files resolve from the main worktree root, never the current directory.']);
});

test('on a match the route is read before any other tool call, and the todo list is named by its tool', () => {
  // 2026-10-18, Claude Code 2.1.302: 11 of 12 headless runs read routes.md, then nearly all made a project call
  // before the route, and none opened a todo list; that Claude Code has TaskCreate, not TodoWrite.
  assertContains('kernel/kernel.md', ["On a match, Read the route before any other tool call, the project's included", '`TaskCreate`', '`TodoWrite`']);
});
