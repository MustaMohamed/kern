import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULTS, formatPrice } from '../src/format.js';

test('an option on one call does not change the next call', () => {
  formatPrice(1, { symbol: '£' });
  assert.equal(formatPrice(1), '$1.00');
});

test('the defaults are never changed', () => {
  formatPrice(1, { currency: 'JPY', symbol: '¥' });
  assert.deepEqual(DEFAULTS, { currency: 'USD', symbol: '$' });
});
