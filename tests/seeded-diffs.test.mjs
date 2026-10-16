// tests/seeded-diffs.test.mjs: the review seeded-diff set runs in CI with no miss and no false alarm.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, statSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { addyVerdict, scanProblem } from '../scripts/seeded-diffs.mjs';

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

test('a floor-scan or claim-check run is read only when it exits 0 or 1, 1 exactly with hits, and says nothing on stderr', () => {
  assert.equal(scanProblem('floor-scan', { status: 0, stdout: '', stderr: '' }), '');
  assert.equal(scanProblem('floor-scan', { status: 1, stdout: 'a.js:1\tdebug-print\tx\n', stderr: '' }), '');
  assert.match(scanProblem('floor-scan', { status: 127, stdout: '', stderr: 'floor-scan: line 37: awk: command not found\n' }), /^floor-scan exited 127: .*awk: command not found$/);
  assert.match(scanProblem('claim-check', { status: 0, stdout: '', stderr: 'awk: syntax error at source line 1\n' }), /^claim-check wrote to stderr: awk: syntax error/);
  assert.match(scanProblem('claim-check', { status: 1, stdout: '', stderr: '' }), /exited 1 with 0 hit line/);
  assert.match(scanProblem('floor-scan', { status: 0, stdout: 'a.js:1\tdebug-print\tx\n', stderr: '' }), /exited 0 with 1 hit line/);
  assert.match(scanProblem('floor-scan', { status: null, error: new Error('spawnSync bash ENOENT') }), /could not run: spawnSync bash ENOENT/);
});

test('the addy arm says error apply when a diff does not apply, so its guard never saw it', () => {
  assert.equal(addyVerdict({ status: 1, stderr: 'error: patch failed' }, null), 'error apply');
  assert.equal(addyVerdict({ status: 0 }, { status: 1 }), 'hit');
  assert.equal(addyVerdict({ status: 0 }, { status: 0 }), 'clean');
  assert.equal(addyVerdict({ status: 0 }, { status: 3 }), 'error 3');
});

test('with no awk on PATH, every diff is an error and none reads clean', () => {
  // Every command on PATH but awk, so floor-scan and claim-check crash the way an awk failure does.
  const bin = mkdtempSync(join(tmpdir(), 'noawk-'));
  const seen = new Set();
  for (const dir of (process.env.PATH || '').split(delimiter)) {
    let names = [];
    try { names = readdirSync(dir); } catch { continue; }
    for (const n of names) {
      if (seen.has(n) || /^(g|m|n)?awk$/.test(n)) continue;
      try { if (!statSync(join(dir, n)).isFile()) continue; } catch { continue; }
      seen.add(n);
      symlinkSync(join(dir, n), join(bin, n));
    }
  }
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/seeded-diffs.mjs', import.meta.url))], { encoding: 'utf8', env: { ...process.env, PATH: bin } });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.equal((r.stdout.match(/^error: /gm) || []).length, 20, r.stdout);
  assert.doesNotMatch(r.stdout, /\tkern clean/);
});
