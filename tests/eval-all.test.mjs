// scripts/eval-all starts every eval runner at once (the user, 2026-10-23: "I want all in parallel to finish
// faster"). These tests use --dry-run only, so no runner starts a claude session.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const run = (args, t) => {
  const out = mkdtempSync(join(tmpdir(), 'eval-all-'));
  t.after(() => rmSync(out, { recursive: true, force: true }));
  const r = spawnSync('bash', [join(root, 'scripts', 'eval-all'), ...args], {
    cwd: root, encoding: 'utf8', env: { ...process.env, EVAL_ALL_OUT: out }, timeout: 240000,
  });
  return { ...r, out };
};

test('eval-all --dry-run starts all six runners at once and exits 0 when each does', (t) => {
  const r = run(['--dry-run', '--jobs', '2'], t);
  assert.equal(r.status, 0, r.stderr);
  for (const n of ['exec', 'behave', 'adherence-sonnet', 'adherence-haiku', 'h2h-plan', 'h2h-review']) {
    assert.match(r.stdout, new RegExp(`started ${n} \\(pid`));
    assert.match(r.stdout, new RegExp(`eval-all: ${n} +exit 0`));
  }
  assert.equal(readdirSync(r.out).filter((f) => f.endsWith('.log')).length, 6);
});

test('eval-all --only starts just the runners it names', (t) => {
  const r = run(['--dry-run', '--only', 'exec,h2h-review'], t);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /started exec /);
  assert.match(r.stdout, /started h2h-review /);
  assert.doesNotMatch(r.stdout, /started behave /);
});

test('eval-all refuses a mistyped flag, an unknown runner and a bad --jobs before starting anything', (t) => {
  for (const args of [['--dryrun'], ['--only', 'exec,nope', '--dry-run'], ['--jobs', '0', '--dry-run'], ['--changed']]) {
    const r = run(args, t);
    assert.equal(r.status, 2, `${args.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.doesNotMatch(r.stdout, /started /);
  }
});
