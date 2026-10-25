import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatCurrency } from '../src/format.js';

test('formats US dollars', () => {
  assert.equal(formatCurrency(5, 'USD'), '$5.00');
});
