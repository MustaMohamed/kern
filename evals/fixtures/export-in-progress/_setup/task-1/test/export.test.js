import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toCsv } from '../src/export.js';

test('toCsv writes a header line, then one line per row', () => {
  assert.equal(toCsv([{ a: 1, b: 2 }]), 'a,b\n1,2\n');
});
