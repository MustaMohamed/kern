import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tax } from '../src/tax.js';

test('tax is ten percent', () => {
  assert.equal(tax(10), 1);
});
