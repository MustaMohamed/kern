// tests/h2h.test.mjs: the head-to-head harness's pure parts and every fixture's shape. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { workspace } from '../scripts/lib/claude-run.mjs';
import { blindIds, falseAlarms, gate, graderPrompt, loadTasks, outOfArea, parseGrades, redact } from '../scripts/lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const arms = [{ id: 'kern', dir: '/w/kern' }, { id: 'superpowers', dir: '/w/kern/.upstream/superpowers' }, { id: 'control', dir: null }];

test('the arms are kern, both upstream plugins and a no-plugin control', () => {
  const a = JSON.parse(readFileSync(join(ROOT, 'evals', 'h2h', 'arms.json'), 'utf8'));
  assert.deepEqual(a.map((x) => [x.id, x.plugin]), [['kern', '.'], ['superpowers', '.upstream/superpowers'], ['pocock', '.upstream/pocock'], ['control', null]]);
});

test('blind ids are stable for a seed, opaque, and reshuffle across seeds', () => {
  const ids = ['kern', 'superpowers', 'pocock', 'control'];
  const a = blindIds(ids, 's1');
  assert.deepEqual(a, blindIds(ids, 's1'));
  assert.deepEqual(Object.values(a).sort(), ['arm-A', 'arm-B', 'arm-C', 'arm-D']);
  const seen = new Set(Array.from({ length: 12 }, (_, i) => blindIds(ids, `s${i}`).kern));
  assert.ok(seen.size > 1, 'kern got the same blind id under 12 seeds');
});

test('redaction removes every name, path and namespaced skill that identifies an arm', () => {
  const t = redact('Read /w/kern/.upstream/superpowers/skills/tdd/SKILL.md; Skill kern:diagnose; bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe; wrote .kern/ledgers/x.md; Using superpowers:brainstorming', arms);
  assert.doesNotMatch(t, /kern|superpowers|CLAUDE_PLUGIN_ROOT|\/skills\//i);
});

test('out-of-area files, false alarms and the per-category gate', () => {
  assert.deepEqual(outOfArea(['src/pricing.js', 'test/x.test.js', 'README.md'], ['src/pricing.js', 'test/**']), ['README.md']);
  assert.equal(falseAlarms('review', { decoyHits: 1, unmatched: 2 }), 3);
  assert.equal(falseAlarms('diagnose', { floorHits: 1, outOfArea: 1 }), 2);
  const r = (arm, score, fa) => ({ category: 'diagnose', arm, score, falseAlarms: fa });
  assert.equal(gate([r('kern', 0.8, 0), r('superpowers', 0.7, 0), r('control', 0.4, 1)])[0].pass, true);
  assert.equal(gate([r('kern', 0.8, 2), r('superpowers', 0.7, 1)])[0].pass, false, 'more false alarms than the best arm fails');
  assert.equal(gate([r('kern', 0.6, 0), r('control', 0.7, 0)])[0].pass, false, 'the control arm counts');
});

test('the grader prompt carries no arm name, and a malformed grade voids the run', () => {
  const t = { category: 'review', prompts: ['review it'], rubric: ['finds bugs'], labels: [{ id: 'b1' }] };
  const p = graderPrompt(t, [{ id: 'arm-A', text: 'x' }, { id: 'arm-B', text: 'y' }]);
  assert.match(p, /=== arm-A ===/);
  assert.doesNotMatch(p, /kern|superpowers|pocock|control/i);
  assert.equal(parseGrades('{"grades":[{"id":"arm-A","score":7}]}', ['arm-A'])['arm-A'].score, 7);
  assert.throws(() => parseGrades('{"grades":[{"id":"arm-A","score":11}]}', ['arm-A']), /no valid score for arm-A/);
  assert.throws(() => parseGrades('{"grades":[]}', ['arm-A']), /no valid score/);
});

// NODE_TEST_CONTEXT is dropped so a nested `node --test` reports for itself instead of to this runner.
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== 'NODE_TEST_CONTEXT'));
const sh = (cwd, cmd) => spawnSync('bash', ['-c', cmd], { cwd, env, encoding: 'utf8', timeout: 60000 });
for (const t of loadTasks(ROOT).filter((x) => x.category === 'diagnose')) {
  test(`${t.id}: the heldout tests fail on the repo and pass with reference.patch`, () => {
    // The same workspace an arm gets: a git repo, then the task's setup (history, branches).
    const d = workspace(join(t.dir, 'repo'), { name: t.project || 'app', branch: t.branch || '', setup: t.setup || [] });
    try {
      assert.equal(sh(d, t.test).status === 0, t.visible === 'pass', `visible tests should ${t.visible}`);
      cpSync(join(t.dir, 'heldout'), d, { recursive: true });
      assert.notEqual(sh(d, t.test).status, 0, 'heldout tests pass before the fix');
      const ap = sh(d, `git apply ${JSON.stringify(join(t.dir, 'reference.patch'))}`);
      assert.equal(ap.status, 0, ap.stderr);
      const r = sh(d, t.test);
      assert.equal(r.status, 0, r.stdout + r.stderr);
      assert.doesNotMatch(readFileSync(join(t.dir, 'reference.patch'), 'utf8'), /^\+\+\+ b\/test\//m, 'reference.patch must not touch tests');
      for (const k of ['prompts', 'test', 'area', 'rubric']) assert.ok(t[k], `task.json lacks ${k}`);
    } finally { rmSync(dirname(d), { recursive: true, force: true }); }
  });
}

for (const t of loadTasks(ROOT).filter((x) => x.category === 'review')) {
  test(`${t.id}: the change applies, its tests pass, and every label sits on an added line`, () => {
    const d = mkdtempSync(join(tmpdir(), 'h-'));
    try {
      cpSync(join(t.dir, 'repo'), d, { recursive: true });
      const patch = join(t.dir, t.patch);
      const ap = sh(d, `git apply ${JSON.stringify(patch)}`);
      assert.equal(ap.status, 0, ap.stderr);
      assert.equal(sh(d, t.test).status, 0, 'the seeded bugs must hide behind green tests');
      const added = {};
      let file = '';
      for (const l of readFileSync(patch, 'utf8').split('\n')) {
        if (l.startsWith('+++ b/')) file = l.slice(6);
        else if (l.startsWith('+') && !l.startsWith('+++')) (added[file] ??= []).push(l.slice(1));
      }
      assert.equal(t.labels.filter((x) => x.kind === 'bug').length, 6);
      assert.equal(t.labels.filter((x) => x.kind === 'decoy').length, 3);
      for (const x of t.labels) assert.ok((added[x.file] ?? []).some((l) => l.includes(x.match)), `${x.id}: "${x.match}" is not an added line of ${x.file}`);
    } finally { rmSync(d, { recursive: true, force: true }); }
  });
}

for (const t of loadTasks(ROOT).filter((x) => x.category === 'plan')) {
  test(`${t.id}: the spec and every trap file exist, and the rubric covers each trap`, () => {
    assert.ok(existsSync(join(t.dir, 'repo', t.spec)), `no spec at ${t.spec}`);
    assert.ok(t.traps.length >= 1 && t.rubric.length >= t.traps.length, 'fewer rubric lines than traps');
    for (const x of t.traps) assert.ok(existsSync(join(t.dir, 'repo', x.file)), `${x.id}: ${x.file} missing`);
    const r = sh(join(t.dir, 'repo'), 'node --test');
    assert.equal(r.status, 0, `the repo's own tests must pass: ${r.stdout}`);
  });
}

test('the runner lists task-arm pairs in dry-run mode when the upstream trees are present', { skip: !existsSync(join(ROOT, '.upstream', 'superpowers', '.claude-plugin', 'plugin.json')) && 'run scripts/fetch-upstream' }, () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'h2h.mjs'), '--dry-run', '--runs', '1'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^diagnose\/three-calls: kern, superpowers, pocock, control x 1 runs; 1 turn\(s\)$/m);
});

test('the fixture set is complete: 4 planning, 8 debugging and 1 review task', () => {
  const n = (c) => loadTasks(ROOT).filter((t) => t.category === c).length;
  assert.deepEqual([n('plan'), n('diagnose'), n('review')], [4, 8, 1]);
});
