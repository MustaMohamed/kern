// tests/eval-cache.test.mjs: the eval result cache, unit records and the run manifest (scripts/lib/eval-cache.mjs).
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { UsageError } from '../scripts/lib/args.mjs';
import { cacheGet, cachePut, filesVersion, readManifest, readRecord, unitKey, writeManifest, writeRecord } from '../scripts/lib/eval-cache.mjs';

const made = [];
after(() => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
const scratch = () => { const d = mkdtempSync(join(tmpdir(), 'ec-')); made.push(d); return d; };

test('unitKey is a sha256 of its parts, whatever their key order', () => {
  const a = unitKey({ runner: 'behave', case: 'x', model: 'm', run: 0 });
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.equal(unitKey({ run: 0, model: 'm', case: 'x', runner: 'behave' }), a);
  assert.notEqual(unitKey({ runner: 'behave', case: 'x', model: 'm', run: 1 }), a);
});

test('cachePut keeps a record and copies of its files; cacheGet gives them back by key, and nothing for another key', () => {
  const dir = scratch();
  const src = scratch();
  writeFileSync(join(src, 'x-0.jsonl'), '{"type":"result"}\n');
  const key = unitKey({ case: 'x' });
  assert.equal(cacheGet(join(dir, 'cache'), key), null);
  cachePut(join(dir, 'cache'), key, { verdict: [{ pass: true }] }, { 'run.jsonl': join(src, 'x-0.jsonl') });
  const hit = cacheGet(join(dir, 'cache'), key);
  assert.deepEqual(hit.record, { verdict: [{ pass: true }] });
  assert.equal(readFileSync(hit.files['run.jsonl'], 'utf8'), '{"type":"result"}\n');
  assert.equal(cacheGet(join(dir, 'cache'), unitKey({ case: 'y' })), null);
  cachePut(join(dir, 'cache'), key, { verdict: [{ pass: false }] });
  assert.deepEqual(cacheGet(join(dir, 'cache'), key).record, { verdict: [{ pass: false }] }, 'a later put replaces the entry');
  assert.deepEqual(readdirSync(join(dir, 'cache')).filter((n) => n.startsWith('.')), [], 'no temp folder left');
});

test('cacheGet treats an unreadable entry as a miss', () => {
  const dir = join(scratch(), 'cache');
  const key = unitKey({ case: 'z' });
  cachePut(dir, key, { ok: true });
  writeFileSync(join(dir, key.slice(0, 2), key, 'record.json'), '{ not json');
  assert.equal(cacheGet(dir, key), null);
});

test('writeRecord and readRecord keep one unit\'s record in a results dir; a missing or broken one reads as null', () => {
  const dir = scratch();
  writeRecord(dir, 'x-0', { key: 'k', valid: true });
  assert.deepEqual(readRecord(dir, 'x-0'), { key: 'k', valid: true });
  assert.ok(existsSync(join(dir, 'x-0.result.json')));
  assert.equal(readRecord(dir, 'x-1'), null);
  writeFileSync(join(dir, 'x-2.result.json'), 'oops');
  assert.equal(readRecord(dir, 'x-2'), null);
});

test('the manifest names the runner; reading it for another runner, or from a dir with none, is a usage error', () => {
  const dir = scratch();
  writeManifest(dir, { runner: 'behave', options: { runs: 3 } });
  assert.deepEqual(readManifest(dir, 'behave'), { runner: 'behave', options: { runs: 3 } });
  assert.throws(() => readManifest(dir, 'h2h'), (e) => e instanceof UsageError && /was written by behave, not h2h/.test(e.message));
  const empty = scratch();
  assert.throws(() => readManifest(empty, 'behave'), (e) => e instanceof UsageError && /no run\.json/.test(e.message));
  mkdirSync(join(empty, 'sub'));
  writeFileSync(join(empty, 'run.json'), '[');
  assert.throws(() => readManifest(empty, 'behave'), (e) => e instanceof UsageError && /not JSON/.test(e.message));
});

test('filesVersion hashes the named files\' content with the extra values, so an edit to any of them is a new version', () => {
  const dir = scratch();
  writeFileSync(join(dir, 'a.mjs'), 'one');
  writeFileSync(join(dir, 'b.mjs'), 'two');
  const v = filesVersion(dir, ['a.mjs', 'b.mjs'], { grader: 'opus' });
  assert.equal(filesVersion(dir, ['a.mjs', 'b.mjs'], { grader: 'opus' }), v);
  assert.notEqual(filesVersion(dir, ['a.mjs', 'b.mjs'], { grader: 'sonnet' }), v);
  writeFileSync(join(dir, 'b.mjs'), 'three');
  assert.notEqual(filesVersion(dir, ['a.mjs', 'b.mjs'], { grader: 'opus' }), v);
  assert.throws(() => filesVersion(dir, ['missing.mjs']), /ENOENT/);
});
