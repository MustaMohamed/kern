import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/discount.js';

test('five percent off 10.01 rounds to 9.51', () => {
  assert.equal(applyDiscount(10.01, 5), 9.51);
});

test('ten percent off 33.33 rounds to 30', () => {
  assert.equal(applyDiscount(33.33, 10), 30);
});
