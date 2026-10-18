import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeCustomers } from '../src/merge.js';

test('a customer in both lists is merged once', async () => {
  const out = await mergeCustomers([{ id: 1, name: 'Ada' }], [{ id: 1, email: 'ada@example.com' }, { id: 2, name: 'Lin' }]);
  assert.equal(out.length, 2);
});
