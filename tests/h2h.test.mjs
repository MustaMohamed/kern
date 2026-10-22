// tests/h2h.test.mjs: the head-to-head harness's pure parts and every fixture's shape. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, lstatSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { workspace } from '../scripts/lib/claude-run.mjs';
import { armCopy, blindIds, falseAlarms, gate, gateExit, gitFacts, graderPrompt, loadTasks, outOfArea, parseGrades, redact, verdictLine } from '../scripts/lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const arms = [{ id: 'kern', dir: '/w/kern' }, { id: 'superpowers', dir: '/w/kern/.upstream/superpowers' }, { id: 'pstack', dir: '/w/kern/.upstream/pstack/harness/pstack/claude-code' }, { id: 'control', dir: null }];

test('the arms are kern, the three upstream plugins and a no-plugin control', () => {
  const a = JSON.parse(readFileSync(join(ROOT, 'evals', 'h2h', 'arms.json'), 'utf8'));
  assert.deepEqual(a.map((x) => [x.id, x.plugin]), [['kern', '.'], ['superpowers', '.upstream/superpowers'], ['pstack', '.upstream/pstack/harness/pstack/claude-code'], ['pocock', '.upstream/pocock'], ['control', null]]);
});

test('blind ids are stable for a seed, opaque, and reshuffle across seeds', () => {
  const ids = ['kern', 'superpowers', 'pstack', 'pocock', 'control'];
  const a = blindIds(ids, 's1');
  assert.deepEqual(a, blindIds(ids, 's1'));
  assert.deepEqual(Object.values(a).sort(), ['arm-A', 'arm-B', 'arm-C', 'arm-D', 'arm-E']);
  const seen = new Set(Array.from({ length: 12 }, (_, i) => blindIds(ids, `s${i}`).kern));
  assert.ok(seen.size > 1, 'kern got the same blind id under 12 seeds');
});

test('redaction removes every name, path and namespaced skill that identifies an arm', () => {
  const t = redact('Read /w/kern/.upstream/superpowers/skills/tdd/SKILL.md; Read /w/kern/.upstream/pstack/harness/pstack/claude-code/skills/tdd/SKILL.md; Skill kern:diagnose; ' +
    'Skill mattpocock-skills:tdd; Skill pstack:poteto-mode; bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe; wrote .kern/ledgers/x.md; Using superpowers:brainstorming', arms);
  assert.doesNotMatch(t, /kern|superpowers|pocock|pstack|poteto|upstream|harness|CLAUDE_PLUGIN_ROOT|\/skills\//i);
  assert.equal(t.split('<plugin>/<plugin-file>').length - 1, 2, 'every arm reads as the same <plugin>/<plugin-file>');
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

test('a category with no graded run is incomplete when its tasks were loaded', () => {
  const v = gate([], [{ id: 'diagnose/x', category: 'diagnose' }]);
  assert.deepEqual(v, [{ category: 'diagnose', status: 'INCOMPLETE', pass: false, graded: 0, tasks: 1, ungraded: ['diagnose/x'], reason: '0 of 1 tasks graded; no graded run: diagnose/x' }]);
  const r = [{ task: 'diagnose/x', category: 'diagnose', arm: 'kern', score: 0.8, falseAlarms: 0 }, { task: 'diagnose/x', category: 'diagnose', arm: 'control', score: 0.4, falseAlarms: 0 }];
  assert.deepEqual(gate(r, [{ id: 'diagnose/x', category: 'diagnose' }]), gate(r));
  assert.equal(gate(r, [{ id: 'diagnose/x', category: 'diagnose' }, { id: 'review/y', category: 'review' }]).length, 2);
});

test('a category with an ungraded task is INCOMPLETE, never PASS or FAIL, and the exit code follows', () => {
  // 2026-10-22: rename-small and scope-split voided every run (a TLS-interception outage), and the gate still
  // printed a plan verdict from 2 of 4 tasks (task-16-h2h-plan-diagnosis, Task 16n).
  const tasks = ['plan/a', 'plan/b', 'plan/c', 'plan/d'].map((id) => ({ id, category: 'plan' }));
  const r = (task, arm, score, fa) => ({ task, category: 'plan', arm, score, falseAlarms: fa });
  const two = [r('plan/a', 'kern', 0.8, 0), r('plan/a', 'superpowers', 0.7, 0), r('plan/b', 'kern', 0.8, 0), r('plan/b', 'superpowers', 0.7, 0)];
  const [v] = gate(two, tasks);
  assert.equal(v.status, 'INCOMPLETE');
  assert.equal(v.pass, false);
  assert.equal(verdictLine(v), 'INCOMPLETE plan: 2 of 4 tasks graded; no graded run: plan/c, plan/d');
  assert.equal(gateExit([v]), 3);
  assert.equal(gate([r('plan/a', 'kern', 0.2, 5), r('plan/a', 'superpowers', 0.9, 0)], tasks)[0].status, 'INCOMPLETE', 'a losing part is not a FAIL');
  const all = (k) => tasks.flatMap((t) => [r(t.id, 'kern', k, 0), r(t.id, 'control', 0.5, 0)]);
  const pass = gate(all(0.8), tasks);
  assert.equal(pass[0].status, 'PASS');
  assert.equal(verdictLine(pass[0]), 'PASS plan');
  assert.equal(gateExit(pass), 0);
  const fail = gate(all(0.2), tasks);
  assert.equal(fail[0].status, 'FAIL');
  assert.match(verdictLine(fail[0]), /^FAIL plan: kern 0\.20 score/);
  assert.equal(gateExit(fail), 1);
  assert.equal(gateExit([...fail, v]), 1, 'a FAIL outranks an incomplete category');
  assert.equal(gateExit([...pass, v]), 3);
});

test('the runner gives the gate every loaded task, prints each verdict line and exits by gateExit', () => {
  const src = readFileSync(join(ROOT, 'scripts', 'h2h.mjs'), 'utf8');
  assert.ok(src.includes('const verdict = gate(results, tasks.map((t) => ({ id: t.id, category: t.category })));'), 'gate gets every loaded task');
  assert.ok(src.includes('for (const v of verdict) console.log(verdictLine(v));'));
  assert.ok(src.includes('process.exit(gateExit(verdict));'));
});

test('git facts are read with plain git from the workspace an arm starts in', () => {
  const plan = loadTasks(ROOT).find((x) => x.id === 'plan/archive-invoices');
  const d = workspace(join(plan.dir, 'repo'), { name: plan.project || 'app' });
  try {
    const f = gitFacts(d);
    assert.deepEqual({ branch: f.branch, commits: f.commits, remotes: f.remotes }, { branch: 'main', commits: 1, remotes: [] });
    assert.match(f.head, /^[0-9a-f]{7,}$/);
    assert.equal(f.head, spawnSync('git', ['-C', d, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).stdout.trim());
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
  const review = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const d2 = workspace(join(review.dir, 'repo'), { name: review.project || 'app', origin: !!review.origin, branch: review.branch || '', setup: review.setup || [] });
  try {
    const f = gitFacts(d2);
    assert.deepEqual({ branch: f.branch, commits: f.commits, remotes: f.remotes }, { branch: 'feat/discounts', commits: 1, remotes: ['origin'] });
  } finally { rmSync(dirname(d2), { recursive: true, force: true }); }
  // The runner reads them in the arm's workspace after the task's own commit and before the arm runs.
  const src = readFileSync(join(ROOT, 'scripts', 'h2h.mjs'), 'utf8');
  const at = src.indexOf('const facts = gitFacts(cwd);');
  assert.ok(at > src.indexOf("git('commit', '-qm', t.patch_message") && at < src.indexOf('tryRun({ cwd, prompts: t.prompts'), 'facts are read after the patch commit and before the run');
  assert.ok(src.includes('heldout, git: facts, text: redact('), 'each attempt carries its facts');
});

test('the grader is told the git facts each attempt saw, so a claim that matches them is supported, in every category', () => {
  // 2026-10-22 head-to-head: the grader counted kern's true `base: main` as unsupported. The branch came from
  // Claude Code's git status block, which every arm sees and the grader does not (the user's "kern and grader").
  const facts = { branch: 'main', commits: 1, remotes: [], head: '902f007' };
  const general = "Each attempt's block opens with the git facts its session showed it from the start, read with git from its workspace. They were visible to the attempt, so a claim that matches them is supported, though no command printed it.";
  const plan = graderPrompt({ category: 'plan', prompts: ['plan it'], rubric: ['orders tasks'] }, [{ id: 'arm-A', text: 'x', git: facts }, { id: 'arm-B', text: 'y', git: { ...facts, head: 'abc1234' } }]);
  assert.ok(plan.includes(general), plan);
  assert.ok(plan.includes("Count the claims about the repo that neither the fixture files nor the attempt's git facts support."), plan);
  assert.ok(!plan.includes('that the fixture files do not support'));
  assert.ok(plan.includes('\n=== arm-A ===\nGit facts: branch main; 1 commit; no remote; HEAD 902f007.\nx'), plan);
  assert.ok(plan.includes('\n=== arm-B ===\nGit facts: branch main; 1 commit; no remote; HEAD abc1234.\ny'), plan);
  assert.doesNotMatch(plan, /kern|superpowers|pocock|pstack|poteto|control/i);
  for (const category of ['diagnose', 'review']) {
    const p = graderPrompt({ category, prompts: ['p'], rubric: ['r'], labels: [] }, [{ id: 'arm-A', text: 'x', git: { branch: 'feat/discounts', commits: 2, remotes: ['origin'], head: '1a2b3c4' } }]);
    assert.ok(p.includes(general), category);
    assert.ok(p.includes('\n=== arm-A ===\nGit facts: branch feat/discounts; 2 commits; remote origin; HEAD 1a2b3c4.\nx'), p);
  }
});

test('redaction turns .kern/ into .work/ and hides a /private temp prefix', () => {
  assert.equal(redact('wrote .kern/ledgers/x.md', arms), 'wrote .work/ledgers/x.md');
  const a = [{ id: 'kern', dir: '/var/folders/x/p-1/kern' }];
  assert.equal(redact('Read /private/var/folders/x/p-1/kern/skills/a/SKILL.md', a), 'Read <plugin>/<plugin-file>');
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
      // The held-out tests alone, without the visible ones, so a visible failure cannot make this check pass.
      const d2 = workspace(join(t.dir, 'repo'), { name: t.project || 'app', branch: t.branch || '', setup: t.setup || [] });
      try {
        rmSync(join(d2, 'test'), { recursive: true, force: true });
        cpSync(join(t.dir, 'heldout'), d2, { recursive: true });
        assert.notEqual(sh(d2, t.test).status, 0, 'heldout tests pass before the fix');
      } finally { rmSync(dirname(d2), { recursive: true, force: true }); }
      cpSync(join(t.dir, 'heldout'), d, { recursive: true });
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
  assert.match(r.stdout, /^diagnose\/three-calls: kern, superpowers, pstack, pocock, control x 1 runs; 1 turn\(s\)$/m);
});

test('the fixture set is complete: 4 planning, 8 debugging and 1 review task', () => {
  const n = (c) => loadTasks(ROOT).filter((t) => t.category === c).length;
  assert.deepEqual([n('plan'), n('diagnose'), n('review')], [4, 8, 1]);
});

const upstream = existsSync(join(ROOT, '.upstream', 'superpowers', '.claude-plugin', 'plugin.json'));
test('an upstream arm runs from a copy outside the repo with no symlink back into it', { skip: !upstream && 'run scripts/fetch-upstream' }, () => {
  const root = realpathSync(ROOT);
  for (const a of JSON.parse(readFileSync(join(ROOT, 'evals', 'h2h', 'arms.json'), 'utf8')).filter((x) => x.plugin && x.id !== 'kern')) {
    const copy = armCopy(join(ROOT, a.plugin), a.id);
    try {
      assert.ok(!realpathSync(copy).startsWith(`${root}/`), `${a.id}: the copy is under the repo`);
      assert.equal(copy.split('/').pop(), a.id);
      assert.ok(existsSync(join(copy, '.claude-plugin', 'plugin.json')));
      assert.ok(!existsSync(join(copy, '.git')));
      const walk = (dir) => { for (const n of readdirSync(dir)) {
        const f = join(dir, n);
        const st = lstatSync(f);
        assert.ok(!st.isSymbolicLink(), `${a.id}: ${f} is a symlink`);
        if (st.isDirectory()) walk(f);
      } };
      walk(copy);
    } finally { rmSync(dirname(copy), { recursive: true, force: true }); }
  }
});
