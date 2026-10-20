import { test } from 'node:test';
import assert from 'node:assert/strict';
import { page } from '../src/pagination.js';

test('page 1 holds the first size items', () => {
  assert.deepEqual(page([1, 2, 3, 4, 5], 1, 2), [1, 2]);
});

test('the last page holds what is left', () => {
  assert.deepEqual(page([1, 2, 3, 4, 5], 3, 2), [5]);
});
