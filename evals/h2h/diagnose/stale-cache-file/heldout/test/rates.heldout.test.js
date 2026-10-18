import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { convert } from '../src/rates.js';

// The cache file is shared with the visible test: put it back as it was.
const FILE = '.cache/rates.json';
const before = existsSync(FILE) ? readFileSync(FILE, 'utf8') : null;
after(() => (before === null ? rmSync(FILE, { force: true }) : writeFileSync(FILE, before)));

test('an old-shape cache file falls back to the bundled rates', () => {
  mkdirSync('.cache', { recursive: true });
  writeFileSync('.cache/rates.json', '{ "usd": 1, "eur": 0.5 }');
  assert.equal(convert(10, 'EUR'), 9.2);
});

test('a current cache file is used', () => {
  mkdirSync('.cache', { recursive: true });
  writeFileSync('.cache/rates.json', JSON.stringify({ version: 2, rates: { USD: 1, EUR: 0.5 } }));
  assert.equal(convert(10, 'EUR'), 5);
});
