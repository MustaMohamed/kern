// tests/licensing.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');

function upstreamRows() {
  return read('UPSTREAM.md').split('\n')
    .filter((l) => /^\| [a-z]+ \|/.test(l))
    .map((l) => l.split('|').slice(1, -1).map((c) => c.trim()));
}

test('kern itself is MIT', () => {
  assert.match(read('LICENSE'), /^MIT License\n\nCopyright \(c\) 2026 Mustafa Mohamed/);
});

test('every upstream source has a licence file and a NOTICE entry', () => {
  const rows = upstreamRows();
  assert.deepEqual(rows.map((r) => r[0]).sort(), ['addy', 'caveman', 'pocock', 'pstack', 'superpowers']);
  const notice = read('NOTICE');
  for (const [key, , , , copyright, , url] of rows) {
    assert.ok(existsSync(new URL(`../licenses/${key}.LICENSE`, import.meta.url)), `licenses/${key}.LICENSE`);
    assert.ok(notice.includes(url), `NOTICE names ${url}`);
    assert.ok(notice.includes(copyright), `NOTICE carries "${copyright}"`);
  }
});

test('NOTICE reproduces caveman NOTICE verbatim', () => {
  assert.ok(read('NOTICE').includes(read('licenses/caveman.NOTICE').trim()));
});

test('caveman licence is Apache-2.0', () => {
  assert.match(read('licenses/caveman.LICENSE'), /Apache License\s+Version 2\.0, January 2004/);
});

test('NOTICE has a file map section', () => {
  assert.match(read('NOTICE'), /^## File map$/m);
});
