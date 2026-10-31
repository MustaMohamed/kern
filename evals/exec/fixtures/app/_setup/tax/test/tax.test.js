import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tax } from '../src/tax.js';

test('tax is a fifth of the net', () => {
  assert.equal(tax(10), 2);
});
