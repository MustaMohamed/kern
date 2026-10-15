// tests/voice.test.mjs: the voice rules coverage gaps 14 and 16 added.
import { test } from 'node:test';
import { assertContains } from './helpers/md.mjs';

test('terse keeps existing comments and shows only changed code', () => {
  assertContains('modes/terse.md', [
    '10. Existing comments in a file you edit are payload: keep each one unless you were asked to change it.',
    '11. Code shown in chat is the changed lines plus one or two lines of context, unless the user asks for the whole file or the file is new.',
  ]);
  assertContains('modes/terse-subagent.md', ['the existing comments in files you edit exact']);
});

test('the normal voice skips the main AI tells, in the kernel and in subagent returns', () => {
  assertContains('kernel/kernel.md', ['No is an acceptable answer: say when a scope, proposal or plan is weak, and why.', 'in either voice skip the main AI tells: openers, closing offers, praise, bold-label lists, long dashes, filler.']);
  assertContains('kernel/kernel-subagent.md', ['with no preamble, praise or closing offer']);
});
