import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatPrice } from '../src/format.js';

test('formats in euros when asked', () => {
  assert.equal(formatPrice(5, { currency: 'EUR', symbol: '€' }), '€5.00');
});

test('formats in dollars', () => {
  assert.equal(formatPrice(5), '$5.00');
});
