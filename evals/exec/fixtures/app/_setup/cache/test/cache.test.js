import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { CACHE_VERSION, reportTotal } from '../src/cache.js';

const ROWS = [{ id: 'a', total: 120 }, { id: 'b', total: 80 }];

// withEntry(entry, fn): fn(dir) on a cache folder that holds entry, removed afterwards.
const withEntry = (entry, fn) => {
  const dir = mkdtempSync(join(tmpdir(), 'cache-'));
  try {
    writeFileSync(join(dir, 'entry.json'), JSON.stringify(entry));
    return fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

test('an entry of this version gives its total', () => {
  withEntry({ version: CACHE_VERSION, total: 150 }, (dir) => assert.equal(reportTotal(ROWS, dir), 150));
});

test('an entry of another version is ignored', () => {
  withEntry({ version: CACHE_VERSION + 1, total: 150 }, (dir) => assert.equal(reportTotal(ROWS, dir), 200));
});
