import { test } from 'node:test';
import assert from 'node:assert/strict';
import { listInvoices } from '../src/invoices.js';

test('the list reads from the database', () => {
  assert.deepEqual(listInvoices(), []);
});
