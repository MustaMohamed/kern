import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcTotal } from '../src/total.js';

test('lines add up', () => {
  assert.equal(calcTotal([{ qty: 2, price: 3 }]), 6);
});
