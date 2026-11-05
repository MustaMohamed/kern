import { test } from 'node:test';
import assert from 'node:assert/strict';
import { invoiceView } from '../src/invoice-view.js';

test('the invoice screen names the invoice and shows its total', () => {
  const html = invoiceView({ id: 'INV-7', total: 12 });
  assert.match(html, /<h1>Invoice INV-7<\/h1>/);
  assert.match(html, /Total: 12/);
});
