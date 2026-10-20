import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toCsv } from '../src/export.js';

test('toCsv writes a header line, then one line per row', () => {
  assert.equal(toCsv([{ a: 1, b: 2 }]), 'a,b\n1,2\n');
});

test('toCsv quotes a value holding a comma or a quote, doubling the quotes inside it', () => {
  assert.equal(toCsv([{ a: 'x,y', b: 'say "hi"' }]), 'a,b\n"x,y","say ""hi"""\n');
});
