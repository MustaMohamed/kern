import { test } from 'node:test';
import assert from 'node:assert/strict';
import { label } from '../src/label.js';

test('label prefixes the invoice id', () => {
  assert.equal(label(7), 'INV-7');
});
