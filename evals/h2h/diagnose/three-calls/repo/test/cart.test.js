import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cartTotal } from '../src/cart.js';

test('two lines add up', () => {
  assert.equal(cartTotal([{ sku: 'a', qty: 1, price: 2 }, { sku: 'b', qty: 2, price: 3 }]), 8);
});
