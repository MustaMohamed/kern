import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setTimeout as sleep } from 'node:timers/promises';
import { processAll } from '../src/queue.js';

test('slow handlers are all awaited, in order', async () => {
  const out = await processAll([3, 1, 2], (n) => sleep(n * 5));
  assert.deepEqual(out, [3, 1, 2]);
});

test('a failing handler rejects the whole run', async () => {
  await assert.rejects(processAll([1, 2], async (n) => { if (n === 2) throw new Error('boom'); }), /boom/);
});
