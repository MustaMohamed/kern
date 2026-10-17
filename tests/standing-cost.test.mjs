// tests/standing-cost.test.mjs: token arithmetic and the dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inputTokens, median } from '../scripts/standing-cost.mjs';

test('input tokens count cached and uncached input, and a result without usage throws', () => {
  assert.equal(inputTokens({ input_tokens: 4, cache_creation_input_tokens: 1000, cache_read_input_tokens: 9000, output_tokens: 7 }), 10004);
  assert.equal(inputTokens({ input_tokens: 12 }), 12);
  assert.throws(() => inputTokens(undefined), /no usage.input_tokens/);
});

test('median of an odd and an even list', () => {
  assert.equal(median([5, 1, 3]), 3);
  assert.equal(median([4, 1, 3, 2]), 3);
});

test('a run count below 1 is refused before anything runs', () => {
  for (const runs of ['0', 'x']) {
    const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/standing-cost.mjs', import.meta.url)), '--runs', runs, '--dry-run'], { encoding: 'utf8' });
    assert.equal(r.status, 2, runs);
    assert.match(r.stderr, /--runs needs a whole number of at least 1/);
  }
});

test('the dry run calls no model', () => {
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/standing-cost.mjs', import.meta.url)), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^claude -p hello x 3 with --plugin-dir /);
});
