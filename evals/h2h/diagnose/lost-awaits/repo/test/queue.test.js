import { test } from 'node:test';
import assert from 'node:assert/strict';
import { processAll } from '../src/queue.js';

test('every item is processed', async () => {
  const out = await processAll([1, 2, 3], async (n) => n);
  assert.equal(out.length, 3);
});
