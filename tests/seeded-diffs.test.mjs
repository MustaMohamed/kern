// tests/seeded-diffs.test.mjs: the review seeded-diff set runs in CI with no miss and no false alarm.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('../evals/seeded-diffs/', import.meta.url));

test('every labelled diff exists, and there are 12 seeded moves and 8 decoys', () => {
  const labels = JSON.parse(readFileSync(`${DIR}labels.json`, 'utf8'));
  const diffs = readdirSync(DIR).filter((f) => f.endsWith('.diff')).map((f) => f.replace(/\.diff$/, '')).sort();
  assert.deepEqual(labels.map((l) => l.id).sort(), diffs);
  assert.equal(labels.filter((l) => l.expect.length).length, 12);
  assert.equal(labels.filter((l) => !l.expect.length).length, 8);
});

test('floor-scan and claim-check find every seeded move and no decoy', () => {
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/seeded-diffs.mjs', import.meta.url))], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^seeded-diffs: 0 missed, 0 false alarms on 20 diffs$/m);
});
