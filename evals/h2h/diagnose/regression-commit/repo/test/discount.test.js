import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/discount.js';

test('ten percent off a round total', () => {
  assert.equal(applyDiscount(100, 10), 90);
});
