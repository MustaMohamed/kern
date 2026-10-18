import { test } from 'node:test';
import assert from 'node:assert/strict';
import { invoiceTotal, lineTotal } from '../src/invoice.js';

test('a line is quantity times unit price', () => {
  assert.equal(lineTotal({ qty: 3, unitPrice: 1.1 }), 3.3);
});

test('tax applies to the net total', () => {
  assert.equal(invoiceTotal([{ qty: 1, unitPrice: 10 }, { qty: 2, unitPrice: 5 }], 0.1), 22);
});
