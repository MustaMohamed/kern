import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addInvoice, listInvoices } from '../src/invoices.js';

test('an added invoice is listed', () => {
  addInvoice({ id: 'a' });
  assert.equal(listInvoices().length, 1);
});
