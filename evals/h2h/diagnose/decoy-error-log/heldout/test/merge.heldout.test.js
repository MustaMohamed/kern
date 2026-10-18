import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeCustomers } from '../src/merge.js';

test('customer 0 is kept', async () => {
  const out = await mergeCustomers([{ id: 0, name: 'Root' }], [{ id: 1, name: 'Ada' }]);
  assert.deepEqual(out.map((c) => c.id).sort(), [0, 1]);
});

test('a record with no id at all is still skipped', async () => {
  const out = await mergeCustomers([{ name: 'nobody' }], [{ id: 0, name: 'Root' }]);
  assert.deepEqual(out.map((c) => c.id), [0]);
});
