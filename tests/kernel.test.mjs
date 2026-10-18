// tests/kernel.test.mjs: kernel lines a trim must not drop.
import { test } from 'node:test';
import { assertContains } from './helpers/md.mjs';

test('kern paths never resolve from the current directory', () => {
  // A headless run without this clause looked for kern/kernel/routes.md under the project and skipped kern.
  assertContains('kernel/kernel.md', ['Settings and working files resolve from the main worktree root, never the current directory.']);
});
