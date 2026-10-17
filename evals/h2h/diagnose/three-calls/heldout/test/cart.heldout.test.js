import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cartTotal } from '../src/cart.js';
import { lineTotal } from '../src/pricing.js';

test('a repeated sku with a new quantity is priced fresh', () => {
  assert.equal(cartTotal([{ sku: 'a', qty: 1, price: 2 }, { sku: 'b', qty: 2, price: 3 }, { sku: 'a', qty: 3, price: 2 }]), 14);
});

test('the same sku at a new unit price is priced fresh', () => {
  assert.equal(lineTotal('c', 1, 5), 5);
  assert.equal(lineTotal('c', 1, 7), 7);
});
