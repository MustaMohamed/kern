// tests/h2h.test.mjs: the head-to-head harness's pure parts and every fixture's shape. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, cpSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, workspace } from '../scripts/lib/claude-run.mjs';
import { armCopy, blindIds, factsLine, falseAlarms, finalFiles, gate, gateExit, gitFacts, graderPrompt, h2hFlags, h2hMain, loadTasks, outOfArea, parseGrades, redact, resultRow, taskWorkspace, touchedTasks, verdictLine } from '../scripts/lib/h2h.mjs';
import { parseArgs } from '../scripts/lib/args.mjs';
import { gitSandbox, guardedEnv, init as initOf, ran as runOf, result as resultEvent, started, use } from './helpers/eval-stub.mjs';

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

test('a --task run gives the gate every task of its category, so one graded task reads INCOMPLETE', () => {
  // Task 16n review, I2: the plan's recovery for a VOID is "re-run that task with --task <category/id>", and with
  // only the filtered tasks the gate printed PASS or FAIL for the whole category from that one task.
  const all = loadTasks(ROOT);
  const touched = touchedTasks(all, all.filter((t) => t.id === 'plan/rename-small'));
  assert.deepEqual(touched.map((t) => t.id), ['plan/archive-invoices', 'plan/reminder-seam', 'plan/rename-small', 'plan/scope-split']);
  assert.deepEqual(touchedTasks(all, all).map((t) => t.id), all.map((t) => t.id), 'a full run gates on every task');
  assert.deepEqual(touchedTasks(all, all.filter((t) => t.category === 'review')).map((t) => t.id), ['review/invoice-branch']);
  const r = (arm, score) => ({ task: 'plan/rename-small', category: 'plan', arm, score, falseAlarms: 0 });
  const v = gate([r('kern', 0.9), r('superpowers', 0.5)], touched);
  assert.equal(verdictLine(v[0]), 'INCOMPLETE plan: 1 of 4 tasks graded; no graded run: plan/archive-invoices, plan/reminder-seam, plan/scope-split');
  assert.equal(gateExit(v), 3);
});

test('a review result row keeps its decoy and unmatched counts, its extras and the grader\'s raw reply, and the gate still reads it', () => {
  // Task 16o: the 2026-10-22 snapshot kept only the sum, so the review diagnosis had to infer each split from `why`.
  const reply = '{"grades":[{"id":"arm-A","score":8,"matched":["b1","b2"],"decoys":["decoy:d3"],"extras":["extra:x1","extra:x3"],"unmatched":2,"why":"w"},{"id":"arm-B","score":6,"why":"v"}]}';
  const g = parseGrades(reply, ['arm-A', 'arm-B']);
  const t = { id: 'review/invoice-branch', category: 'review' };
  const git = { branch: 'feat/discounts', main: 'main', head: 'abc1234', commits: 2, recent: [] };
  const a = resultRow(t, 1, { arm: 'kern', id: 'arm-A', e: { outOfArea: 0 }, heldout: null, git }, g['arm-A'], reply);
  assert.deepEqual(a, { task: 'review/invoice-branch', category: 'review', run: 1, arm: 'kern', score: 0.8, falseAlarms: 3, heldout: null, git, matched: ['b1', 'b2'], why: 'w',
    decoys: 1, unmatched: 2, extras: 2, reply });
  assert.ok(!Object.values(a).includes('arm-A'), 'no blind id: keys stay out of snapshots');
  assert.equal(a.falseAlarms, a.decoys + a.unmatched, 'the split adds up to the sum, and extras are in neither');
  const b = resultRow(t, 1, { arm: 'control', id: 'arm-B', e: { outOfArea: 0 }, heldout: null, git }, g['arm-B'], reply);
  assert.deepEqual([b.decoys, b.unmatched, b.extras, b.falseAlarms, b.matched], [0, 0, 0, 0, []]);
  assert.equal(verdictLine(gate([a, b])[0]), 'FAIL review: kern 0.80 score, 3.00 false alarms; control 0.60, 0.00', 'the gate reads score and falseAlarms as before');
  // Other categories keep their rows as they were: no reply, no split.
  const p = resultRow({ id: 'plan/x', category: 'plan' }, 0, { arm: 'kern', id: 'arm-A', e: { outOfArea: 0 }, heldout: null, git }, { score: 7, unsupported: 1, why: 'u' }, '{}');
  assert.deepEqual(p, { task: 'plan/x', category: 'plan', run: 0, arm: 'kern', score: 0.7, falseAlarms: 1, heldout: null, git, matched: [], why: 'u' });
  const d = resultRow({ id: 'diagnose/x', category: 'diagnose' }, 0, { arm: 'kern', id: 'arm-A', e: { outOfArea: 1, floorHits: 1 }, heldout: false, git }, { score: 9 }, '{}');
  assert.deepEqual([d.score, d.falseAlarms, 'reply' in d], [0, 2, false], 'a failed heldout run scores 0');
});

test('an extra the grader misfiles under decoys is dropped before the decoys are counted', () => {
  // Task 16o review, M3: the decoy count was the length of whatever list the grader returned, so an extra listed
  // there, bare or as "extra:<id>", counted as a false alarm.
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const git = { branch: 'feat/discounts', main: 'main', head: 'abc1234', commits: 2, recent: [] };
  const x = { arm: 'kern', id: 'arm-A', e: { outOfArea: 0 }, heldout: null, git };
  const g = { score: 8, matched: ['b6'], decoys: ['decoy:d3', 'extra:x1', 'x2', 'd1'], extras: ['extra:x1', 'x3'], unmatched: 1, why: 'w' };
  const row = resultRow(t, 0, x, g, 'r');
  assert.equal(row.decoys, 2, 'd3 and d1 count; x1 and x2 do not');
  assert.equal(row.falseAlarms, 3);
  assert.equal(row.extras, 3, 'x1, x2 and x3, each once');
  // A decoy id is never dropped, and a task with no extra labels drops only an "extra:" entry.
  assert.equal(resultRow(t, 0, x, { score: 5, decoys: ['d3', 'decoy:d2'] }, 'r').decoys, 2);
  assert.equal(resultRow({ id: 'review/y', category: 'review', labels: [] }, 0, x, { score: 5, decoys: ['extra:x9', 'd3'] }, 'r').decoys, 1);
  assert.equal(resultRow({ id: 'review/y', category: 'review' }, 0, x, { score: 5, extras: 'x1' }, 'r').extras, 0, 'an extras value that is not a list counts nothing');
});

// Task 17a G2: parseGrades checked only the score, and resultRow added whatever counts the grader returned, so a
// count where a list belongs made false alarms 0, a string or NaN. Lane G's table of grader replies, then the
// counts by label kind.
test('Task 17a G2: a grader reply whose lists or counts are malformed voids the task-run', () => {
  const review = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const plan = loadTasks(ROOT).find((x) => x.category === 'plan');
  const diagnose = loadTasks(ROOT).find((x) => x.category === 'diagnose');
  const reply = (task, grade) => parseGrades(JSON.stringify({ grades: [{ id: 'arm-A', score: 7, why: 'w', ...grade }] }), ['arm-A'], task);
  const good = { matched: ['b1'], decoys: ['decoy:d1'], extras: [], unmatched: 0 };
  assert.equal(reply(review, good)['arm-A'].score, 7);
  for (const [grade, why] of [
    [{ ...good, decoys: 2 }, /decoys for arm-A is not a list of label ids/],
    [{ ...good, unmatched: '2' }, /unmatched for arm-A is not a whole number of at least 0/],
    [{ ...good, unmatched: ['foo'] }, /unmatched for arm-A is not a whole number/],
    [{ ...good, unmatched: -3 }, /unmatched for arm-A is not a whole number/],
    [{ ...good, unmatched: 1.5 }, /unmatched for arm-A is not a whole number/],
    [{ ...good, matched: ['b1', 'b9'] }, /matched for arm-A names b9, which is no label in the key/],
    [{ ...good, matched: ['none'] }, /names none, which is no label in the key/],
    [{ ...good, extras: ['bogus:x1'] }, /names bogus:x1, which is no label in the key/],
    [{ ...good, extras: 'x1' }, /extras for arm-A is not a list of label ids/],
    [{ matched: ['b1'], unmatched: 0 }, /arm-A has no decoys list/],
    [{ matched: ['b1'], decoys: [] }, /arm-A has no unmatched count/],
    [{ ...good, score: '7' }, /no valid score for arm-A/],
    [{ ...good, score: NaN }, /no valid score for arm-A/]]) {
    assert.throws(() => reply(review, grade), why, JSON.stringify(grade));
  }
  // A plan grade must count its unsupported claims; its lists are kept as given, since a plan has no key.
  assert.equal(reply(plan, { matched: [1, 'two'], unsupported: 0 })['arm-A'].score, 7);
  assert.throws(() => reply(plan, { unsupported: ['base: main'] }), /unsupported for arm-A is not a whole number of at least 0/);
  assert.throws(() => reply(plan, { matched: [] }), /arm-A has no unsupported count/);
  assert.equal(reply(diagnose, { matched: ['2', '3'] })['arm-A'].score, 7, 'a diagnose grade needs no count: its false alarms are measured');
  // Fix round 1 (P5 review, Important 1): a field the category never reads cannot void its task-run.
  for (const [task, grade] of [[plan, { unsupported: 0, unmatched: null }], [plan, { unsupported: 0, decoys: null }], [plan, { unsupported: 0, unmatched: 'n/a', decoys: 2, matched: 'x' }],
    [review, { ...good, unsupported: null }], [review, { ...good, extras: null }], [diagnose, { unmatched: -1, unsupported: 'none', decoys: ['none'] }]]) {
    assert.equal(reply(task, grade)['arm-A'].score, 7, `${task.category}: ${JSON.stringify(grade)}`);
  }
  assert.throws(() => reply(review, { ...good, decoys: ['none'] }), /decoys for arm-A names none, which is no label in the key/, 'a field the gate reads stays strict');
});

// Fix round 1 (P5 review, Important 1): the grader is told what an empty list or count is, and that "none" is no label.
test('the grader is told to give every field, [] or 0 when there is nothing, and never to list "none"', () => {
  const every = 'Give every field for every attempt: [] when no label matches, 0 when there is nothing to count.';
  const none = 'A finding that matches no label counts in "unmatched"; never list "none" in matched, decoys or extras.';
  const review = graderPrompt({ category: 'review', prompts: ['review it'], rubric: ['r'], labels: [{ id: 'b1', kind: 'bug' }] }, [{ id: 'arm-A', text: 'x' }]);
  assert.ok(review.includes(every) && review.includes(none), review);
  const plan = graderPrompt({ category: 'plan', prompts: ['plan it'], rubric: ['r'] }, [{ id: 'arm-A', text: 'x' }]);
  assert.ok(plan.includes(every) && !plan.includes(none), plan);
});

// Task 16q review, Important 1: the digest now shows a subagent's or forked skill's report (behave.mjs h2hResult), which
// the grader never saw before, so it is told those reports are evidence and the attempt's own reply holds its findings.
test('in every category the grader is told a subagent\'s or skill\'s report under its call is evidence, not the attempt\'s own output', () => {
  const rule = "A subagent's or skill's report shown under its call is evidence the attempt gathered, not its own output: grade findings and claims from the attempt's final reply (and, for a plan, its final files), and a finding the reply clears or rejects is not one.";
  for (const category of ['plan', 'diagnose', 'review']) {
    const p = graderPrompt({ category, prompts: ['p'], rubric: ['r'], labels: [] }, [{ id: 'arm-A', text: 'x' }]).split('\n');
    assert.match(p[1], /^Score each attempt 0 to 10 on the rubric\. Judge only what each attempt shows/, category);
    assert.equal(p[2], rule, `${category}: the line after "Judge only what each attempt shows"`);
    assert.equal(p.filter((l) => l === rule).length, 1, category);
  }
});

// Fix round 1 (P5 review, Minor 4): the files block has a total cap as well as a per-file one.
test('finalFiles cuts each file at perFile characters and the whole block at total, naming how many files it left out', () => {
  const d = workspace(join(ROOT, 'evals', 'h2h', 'plan', 'rename-small', 'repo'), { name: 'app' });
  try {
    mkdirSync(join(d, '.kern', 'plans'), { recursive: true });
    for (let i = 0; i < 6; i++) writeFileSync(join(d, '.kern', 'plans', `p${i}.md`), `${String(i).repeat(1000)}\n`);
    const all = finalFiles(d);
    assert.equal(all.split('\n\n').length, 6);
    const cut = finalFiles(d, 400, 2500);
    assert.match(cut, /^--- \.kern\/plans\/p0\.md\n0{400}\n\[cut: 601 more characters\]\n\n--- \.kern\/plans\/p1\.md\n/);
    assert.ok(cut.length <= 2500 + 40, `${cut.length}`);
    assert.match(cut, /\n\n\[cut: \d+ more files\]$/);
    const kept = (cut.match(/^--- /gm) || []).length;
    assert.equal(Number(cut.match(/\[cut: (\d+) more files\]$/)[1]), 6 - kept);
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
});

// Fix round 2 (P5 re-review, Minor A): git lists tracked changes, then untracked files, then ignored ones, so the cap
// cut kern's ignored .kern/plans/ first and the grader scored kern without its plan. Plan files now come first.
test('finalFiles lists every path with "plan" in it first, so each arm\'s plan survives the cap', () => {
  const d = workspace(join(ROOT, 'evals', 'h2h', 'plan', 'rename-small', 'repo'), { name: 'app' });
  try {
    for (const [f, text] of [...[0, 1, 2, 3].map((i) => [`src/gen${i}.js`, `${'x'.repeat(19000)}\n`]), ['.kern/plans/p.md', 'kern plan\n'],
      ['docs/plan.md', 'control plan\n'], ['docs/superpowers/plans/s.md', 'superpowers plan\n'], ['notes.md', 'notes\n']]) {
      mkdirSync(dirname(join(d, f)), { recursive: true });
      writeFileSync(join(d, f), text);
    }
    const out = finalFiles(d);
    const heads = [...out.matchAll(/^--- (\S+)/gm)].map((m) => m[1]);
    assert.deepEqual(heads.slice(0, 3).sort(), ['.kern/plans/p.md', 'docs/plan.md', 'docs/superpowers/plans/s.md'], heads.join(' '));
    assert.ok(out.includes('--- .kern/plans/p.md\nkern plan\n'), 'kern\'s plan is in the block');
    assert.match(out, /\[cut: \d+ more files\]$/, 'the cap still holds');
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
});

test('Task 17a G2: decoy and extra hits are counted by the label\'s kind in the key, from every list the grader used', () => {
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const git = { branch: 'feat/discounts', main: 'main', head: 'abc1234', commits: 2, recent: [] };
  const x = { arm: 'kern', id: 'arm-A', e: { outOfArea: 0 }, heldout: null, git };
  // Lane G: a decoy named under matched counted nothing, against 1 under decoys.
  const row = resultRow(t, 0, x, { score: 8, matched: ['b1', 'decoy:d1'], decoys: [], unmatched: 0 }, 'r');
  assert.deepEqual([row.decoys, row.falseAlarms, row.matched], [1, 1, ['b1']]);
  const both = resultRow(t, 0, x, { score: 8, matched: ['b2', 'd2'], decoys: ['d2', 'decoy:d3'], extras: ['b3', 'x2'], unmatched: 1 }, 'r');
  assert.deepEqual([both.decoys, both.extras, both.falseAlarms, both.matched], [2, 1, 3, ['b2', 'b3']], 'each label once, by its kind: d2 twice is one decoy, b3 under extras is a match');
});

// The SHA-free form of a facts record: each commit's time enters its hash, so only the SHAs may differ by arm.
const shaFree = (f) => ({ ...f, head: '<sha>', recent: f.recent.map((c) => c.replace(/^\S+/, '<sha>')) });

test('git facts are what Claude Code\'s git status context shows, read with plain git, and hold no remote', () => {
  // Task 16n review, I1: that context lists the current branch, the main branch, the git user, the status and the
  // recent commits; it lists no remote, so the grader is not told one.
  const at = (id) => loadTasks(ROOT).find((x) => x.id === id);
  const d = taskWorkspace(at('plan/archive-invoices'));
  try {
    const f = gitFacts(d);
    const head = spawnSync('git', ['-C', d, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' }).stdout.trim();
    assert.deepEqual(f, { branch: 'main', main: 'main', head, commits: 1, recent: [`${head} chore: initial import`] });
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
  // The review task has an origin, a feature branch and the change committed on it.
  const d2 = taskWorkspace(at('review/invoice-branch'));
  try {
    const f = gitFacts(d2);
    assert.deepEqual(shaFree(f), { branch: 'feat/discounts', main: 'main', head: '<sha>', commits: 2, recent: ['<sha> feat: discounts, CSV export and invoice lookup', '<sha> chore: initial import'] });
    assert.ok(!('remotes' in f));
  } finally { rmSync(dirname(d2), { recursive: true, force: true }); }
  // The runner reads them in the arm's workspace after the task's own setup and commit, and before the arm runs:
  // tested through h2hMain at the end of this file.
});

test('every task\'s git facts are the same for every arm but the SHAs, so they name no arm', () => {
  // Task 16n review, I1: the recent commit subjects go to the grader too, so each must be the same under every arm.
  for (const t of loadTasks(ROOT)) {
    const [a, b] = [taskWorkspace(t), taskWorkspace(t)];
    try {
      const [fa, fb] = [gitFacts(a), gitFacts(b)];
      assert.deepEqual(shaFree(fa), shaFree(fb), t.id);
      assert.ok(fa.recent.length >= 1, t.id);
      assert.doesNotMatch(factsLine(fa), /kern|superpowers|pocock|pstack|poteto|caveman|remote/i, t.id);
    } finally { for (const d of [a, b]) rmSync(dirname(d), { recursive: true, force: true }); }
  }
});

test('the grader is told the git facts each session was shown, so a claim that matches them is supported, and a remote claim still needs a command', () => {
  // 2026-10-22 head-to-head: the grader counted kern's true `base: main` as unsupported. The branch came from
  // Claude Code's git status context, which every arm sees and the grader does not (the user's "kern and grader").
  // Task 16n review, I1: that context shows no remote, so the grader is told none.
  const facts = { branch: 'main', main: 'main', head: '902f007', commits: 1, recent: ['902f007 chore: initial import'] };
  const general = "Each attempt's block opens with git facts read from its workspace before it started. Its session's git status showed it the branch, the main branch, HEAD's short SHA and the recent commits with their subjects, so a claim that matches those is supported, though no command printed it. It was not shown the remotes, so a claim about a remote still needs a command and its output. A claim that contradicts any fact is unsupported.";
  const plan = graderPrompt({ category: 'plan', prompts: ['plan it'], rubric: ['orders tasks'] }, [{ id: 'arm-A', text: 'x', git: facts }, { id: 'arm-B', text: 'y', git: { ...facts, head: 'abc1234', recent: ['abc1234 chore: initial import'] } }]);
  assert.ok(plan.includes(general), plan);
  assert.ok(plan.includes('Count the claims about the repo that neither the fixture files nor the git facts its session was shown support.'), plan);
  assert.ok(!plan.includes('that the fixture files do not support'));
  assert.ok(!plan.includes('They were visible to the attempt'));
  assert.ok(plan.includes('\n=== arm-A ===\nGit facts: branch main; main branch main; HEAD 902f007; 1 commit, newest first:\n  902f007 chore: initial import\nx'), plan);
  assert.ok(plan.includes('\n=== arm-B ===\nGit facts: branch main; main branch main; HEAD abc1234; 1 commit, newest first:\n  abc1234 chore: initial import\ny'), plan);
  assert.doesNotMatch(plan, /kern|superpowers|pocock|pstack|poteto|control/i);
  for (const category of ['diagnose', 'review']) {
    const three = { branch: 'feat/discounts', main: 'main', head: '1a2b3c4', commits: 3, recent: ['1a2b3c4 feat: c', '2b3c4d5 fix: b', '3c4d5e6 chore: a'] };
    const p = graderPrompt({ category, prompts: ['p'], rubric: ['r'], labels: [] }, [{ id: 'arm-A', text: 'x', git: three }]);
    assert.ok(p.includes(general), category);
    assert.ok(p.includes('\n=== arm-A ===\nGit facts: branch feat/discounts; main branch main; HEAD 1a2b3c4; 3 commits, newest first:\n  1a2b3c4 feat: c\n  2b3c4d5 fix: b\n  3c4d5e6 chore: a\nx'), p);
  }
  // The context lists five commits, so a longer history shows only that it has more.
  const seven = { ...facts, commits: 7, recent: ['a1 s1', 'a2 s2', 'a3 s3', 'a4 s4', 'a5 s5'] };
  assert.equal(factsLine(seven).split('\n')[0], 'Git facts: branch main; main branch main; HEAD 902f007; more than 5 commits, the 5 newest first:');
  assert.equal(factsLine({ ...facts, branch: '(detached HEAD)' }).split('\n')[0], 'Git facts: branch (detached HEAD); main branch main; HEAD 902f007; 1 commit, newest first:');
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

// Package D1 (2026-10-24): on the post17 run all 15 lost-awaits attempts and 12 of 15 clock-seam ones failed held-out
// with a fix their prompt allowed: held-out asserts input order and a positional `now` in milliseconds, and neither
// prompt said so. clock-seam's prompt also pushed every arm to delete the visible real-clock assertion, a floor-scan
// hit no arm could avoid. Each prompt now states what held-out asserts; a fix that meets it passes held-out and
// scans clean.
// attemptOf(t, { files, diff }): t's workspace after an attempt that applies diff (lines) or writes files, with
// held-out copied in: { heldout: t.test passed, hits: floor-scan's path:line and class }. The hits are for the diff
// h2h builds after the attempt (`git add -A -N`, then `git diff HEAD`), scanned from the workspace with an empty HOME.
function attemptOf(t, { files = {}, diff = [] }) {
  const d = taskWorkspace(t);
  const home = mkdtempSync(join(tmpdir(), 'fh-'));
  try {
    let hits = [];
    if (diff.length) {
      writeFileSync(join(dirname(d), 'fix.diff'), `${diff.join('\n')}\n`);
      const ap = sh(d, 'git apply ../fix.diff && git add -A -N && git diff HEAD > ../change.diff');
      assert.equal(ap.status, 0, ap.stderr);
      const scan = spawnSync('bash', [join(ROOT, 'scripts', 'floor-scan'), join(dirname(d), 'change.diff')], { cwd: d, encoding: 'utf8', env: { ...env, HOME: home } });
      assert.ok(scan.status === 0 || scan.status === 1, scan.stderr);
      hits = scan.stdout.split('\n').filter(Boolean).map((l) => l.split('\t').slice(0, 2).join(' '));
    }
    for (const [f, text] of Object.entries(files)) writeFileSync(join(d, f), text);
    cpSync(join(t.dir, 'heldout'), d, { recursive: true });
    return { heldout: sh(d, t.test).status === 0, hits };
  } finally { rmSync(dirname(d), { recursive: true, force: true }); rmSync(home, { recursive: true, force: true }); }
}

test('Package D1: lost-awaits states the order held-out asserts, so each in-order fix passes held-out and a completion-order one fails', () => {
  const t = loadTasks(ROOT).find((x) => x.id === 'diagnose/lost-awaits');
  assert.match(t.prompts[0], /It must return the items in the order given\./);
  // "in order" alone read as "one at a time"; an in-order Promise.all is a fix too.
  assert.match(t.rubric[2], /awaits every handler, returns the items in the order given, and a handler's failure rejects it/);
  const queue = (...body) => ({ 'src/queue.js': ['export async function processAll(items, handler) {', ...body, '}', ''].join('\n') });
  const shapes = {
    'for...of with await': [queue('  const done = [];', '  for (const item of items) {', '    await handler(item);', '    done.push(item);', '  }', '  return done;'), true],
    'Promise.all of the mapped items': [queue('  return Promise.all(items.map(async (item) => { await handler(item); return item; }));'), true],
    // Every post17 attempt's fix: it pushes in completion order.
    'Promise.all that pushes as each handler ends': [queue('  const done = [];', '  await Promise.all(items.map(async (item) => { await handler(item); done.push(item); }));', '  return done;'), false],
  };
  for (const [name, [files, pass]] of Object.entries(shapes)) assert.equal(attemptOf(t, { files }).heldout, pass, name);
});

test('Package D1: clock-seam states the millisecond now seam held-out calls and keeps the existing test, so a fix that meets it scans clean', () => {
  const t = loadTasks(ROOT).find((x) => x.id === 'diagnose/clock-seam');
  assert.match(t.prompts[0], /Keep the existing test\./);
  assert.match(t.prompts[0], /isExpired takes the current time as an optional second argument, now, in milliseconds\./);
  assert.doesNotMatch(t.prompts[0], /The test must not depend on the real clock/, 'the old wording pushed every arm to delete the visible test');
  const realClock = 'assert.equal(isExpired({ expiresAt: Math.floor(Date.now() / 1000) + 3600 }), false);';
  const fix = (now, cmp) => ['diff --git a/src/tokens.js b/src/tokens.js', '--- a/src/tokens.js', '+++ b/src/tokens.js', '@@ -1,4 +1,4 @@',
    ' // expiresAt is a unix time in seconds, as issued by the identity provider.',
    '-export function isExpired(token) {', '-  return Date.now() > token.expiresAt;',
    `+export function isExpired(token, now = ${now}) {`, `+  return ${cmp};`, ' }'];
  const testDiff = ['diff --git a/test/tokens.test.js b/test/tokens.test.js', '--- a/test/tokens.test.js', '+++ b/test/tokens.test.js'];
  const kept = [...testDiff, "@@ -5,3 +5,7 @@ import { isExpired } from '../src/tokens.js';",
    " test('a token that expires in an hour is not expired', () => {", `   ${realClock}`, ' });',
    '+', "+test('a token is expired after its expiry time, on a fixed clock', () => {",
    '+  assert.equal(isExpired({ expiresAt: 1700003600 }, 1700003601000), true);', '+});'];
  // The post17 shape: the real-clock line replaced by a fixed one, which floor-scan counts as a removed assertion.
  const replaced = [...testDiff, '@@ -5,3 +5,3 @@',
    " test('a token that expires in an hour is not expired', () => {", `-  ${realClock}`,
    '+  assert.equal(isExpired({ expiresAt: 1700003600 }, 1700000000000), false);', ' });'];
  const ms = fix('Date.now()', 'now > token.expiresAt * 1000');
  assert.deepEqual(attemptOf(t, { diff: [...ms, ...kept] }), { heldout: true, hits: [] });
  assert.deepEqual(attemptOf(t, { diff: [...ms, ...replaced] }), { heldout: true, hits: ['test/tokens.test.js:6 assertion-removed'] });
  assert.equal(attemptOf(t, { diff: [...fix('Math.floor(Date.now() / 1000)', 'now > token.expiresAt'), ...kept] }).heldout, false, 'a seconds seam fails held-out');
});

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
      assert.deepEqual(t.labels.map((x) => x.kind).filter((k) => !['bug', 'decoy', 'extra'].includes(k)), [], 'a label is a bug, a decoy or an extra');
      for (const x of t.labels.filter((l) => l.kind !== 'extra')) assert.ok(x.match, `${x.id}: a bug or decoy names its line`);
      // An extra that names a line sits on it too; one for an absence, such as a missing test, names none.
      for (const x of t.labels.filter((l) => l.match)) assert.ok((added[x.file] ?? []).some((l) => l.includes(x.match)), `${x.id}: "${x.match}" is not an added line of ${x.file}`);
    } finally { rmSync(d, { recursive: true, force: true }); }
  });
}

test('the review key lists CSV escaping, the missing exports/ directory and missing tests as extras (the user\'s "kern and key")', () => {
  // 2026-10-22: every arm raised CSV escaping in 15 of 15 sessions and each was charged a false alarm for it; the
  // user chose to change the key after the run, breaking the plan's rule that keys are fixed before any run.
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const extras = t.labels.filter((x) => x.kind === 'extra');
  assert.deepEqual(extras.map((x) => [x.id, x.file ?? null, x.match ?? null]), [
    ['x1', 'src/export.js', '${lines[i].sku},${lines[i].qty},${lines[i].unitPrice}'],
    ['x2', 'src/export.js', 'writeFileSync(path, toCsv(lines));'],
    ['x3', null, null],
  ]);
  assert.match(extras[0].what, /escap/);
  assert.match(extras[1].what, /exports\//);
  assert.match(extras[2].what, /toCsv/);
  assert.match(extras[2].what, /getInvoice/);
  assert.doesNotMatch(JSON.stringify(t.labels), /kern|superpowers|pocock|pstack|poteto|caveman|control/i, 'the key names no arm');
});

test('the review grader is told an extra counts neither as a match nor as a false alarm, and other categories are not', () => {
  const rule = 'A label of kind "extra" is a real issue the key accepts beyond the seeded bugs. A finding that matches an extra counts neither as a match nor as a false alarm: list its id in "extras", never in "matched", "decoys" or "unmatched", and let it neither raise nor lower the score.' +
    // Task 16o review, I2: an extra is optional, so leaving it out costs nothing, and rubric line 1 ("Each real problem is
    // named ...") counts only the bugs: on 2026-10-22 kern raised the missing exports/ directory as its own item and
    // superpowers folded it into its b6 finding.
    ' An attempt that does not raise an extra loses nothing for it, and a rubric line about real problems counts only the bug labels, never an extra.';
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  assert.match(t.rubric[0], /real problem/, 'rubric line 1 is the line the rule narrows');
  const p = graderPrompt(t, [{ id: 'arm-A', text: 'x' }, { id: 'arm-B', text: 'y' }]);
  // Fix round 2 (P5 re-review, Minor E): a finding that matches no label is counted, never named "none".
  assert.ok(p.includes('For each finding, name the label id it matches: a bug id, "decoy:<id>" for a decoy, "extra:<id>" for an extra, or count it in "unmatched".'), p);
  assert.ok(!p.includes('or "none"'), p);
  assert.ok(p.includes(rule), p);
  assert.ok(p.includes('"decoys":["d2"],"extras":["x1"],"unmatched":1'), 'the review reply example has extras');
  assert.ok(p.includes('"kind":"extra"'), 'the grader reads the extras in the labels');
  assert.doesNotMatch(p, /kern|superpowers|pocock|pstack|poteto|caveman|control/i);
  // The plan and diagnose prompts are unchanged by it (Task 16n's plan rerun reads the plan prompt).
  for (const category of ['plan', 'diagnose']) {
    const q = graderPrompt({ category, prompts: ['p'], rubric: ['r'] }, [{ id: 'arm-A', text: 'x' }]);
    assert.doesNotMatch(q, /extra/, category);
    assert.ok(q.includes('Reply with JSON only: {"grades":[{"id":"arm-A","score":7,"matched":["b1"],"decoys":["d2"],"unmatched":1,"unsupported":0,"why":"..."}]}.'), category);
  }
});

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

// Task 17a G4: each of these was ignored, so the run widened to every task or arm, and `--runs abc` ran nothing
// and then wrote a snapshot of failures. Each is now a usage error; the runner keeps --dry-run and a stand-in claude.
test('Task 17a G4: the h2h runner refuses an unknown, valueless or repeated flag, a bad --runs and an unknown arm', () => {
  const ids = loadTasks(ROOT).map((t) => t.id);
  const armIds = JSON.parse(readFileSync(join(ROOT, 'evals', 'h2h', 'arms.json'), 'utf8')).map((a) => a.id);
  assert.deepEqual(parseArgs(['--category', 'plan', '--task', 'plan/rename-small', '--arms', 'kern,control', '--runs', '2', '--model', 'm', '--grader-model', 'g', '--dry-run', '--allow-dirty'], h2hFlags(ids, armIds)),
    { category: 'plan', task: 'plan/rename-small', arms: ['kern', 'control'], runs: 2, model: 'm', grader: 'g', dryRun: true, allowDirty: true });
  const env = guardedEnv();
  const h2h = (...a) => spawnSync(process.execPath, [join(ROOT, 'scripts', 'h2h.mjs'), '--dry-run', ...a], { encoding: 'utf8', env });
  const run = (...a) => h2h('--arms', 'kern,control', ...a);
  for (const a of [['--dryrun'], ['--category=plan'], ['--task', 'plan/nope'], ['--category', 'planning'], ['--task'], ['--runs', 'abc'], ['--runs', '0'], ['plan'], ['--category', 'plan', '--category', 'review'], ['--arms', 'kern']]) {
    const r = run(...a);
    assert.equal(r.status, 2, `${a.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^h2h: .*\nusage: node scripts\/h2h\.mjs /m, a.join(' '));
    assert.equal(r.stdout, '', `${a.join(' ')}: nothing ran`);
  }
  for (const a of [['--arms', 'kern,kern2'], ['--arms']]) {
    const r = h2h(...a);
    assert.equal(r.status, 2, `${a.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^h2h: /m);
  }
  const ok = run('--category', 'review', '--runs', '1');
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(ok.stdout, 'review/invoice-branch: kern, control x 1 runs; 1 turn(s)\n');
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

// The h2h runner through its seam (Task 17a): h2hMain with a stub run, temp snapshot and results dirs, a stated
// tree and two arms, kern (from this repo) and the no-plugin control, so no test writes into the repo's evals/ and
// no claude runs. A stub arm run opens as its arm's session does; the stub grader gives every arm a valid grade.
const DAY = new Date('2026-10-22T12:00:00Z');
const CLEAN = { commit: 'c0ffee', dirty: false, changes: [] };
let taskN = 0;
// synthTask(category, extra): a task in a temp dir: repo/ holds src/a.js and docs/spec.md; a diagnose task also
// gets heldout/ and a test command.
const synthTask = (category, extra = {}) => {
  const dir = mkdtempSync(join(tmpdir(), 'ht-'));
  for (const [f, text] of [['repo/src/a.js', 'export const a = 1;\n'], ['repo/docs/spec.md', '# spec\n'], ['heldout/test/h.test.js', '// heldout\n']]) {
    mkdirSync(dirname(join(dir, f)), { recursive: true });
    writeFileSync(join(dir, f), text);
  }
  taskN += 1;
  return { id: `${category}/t${taskN}`, category, dir, prompts: [`do task ${taskN}`], rubric: ['does it'], area: ['src/**'], ...(category === 'diagnose' ? { test: 'true' } : {}), ...extra };
};
const blindOf = (prompt) => [...prompt.matchAll(/^=== (arm-[A-Z]) ===$/gm)].map((m) => m[1]);
const fields = { plan: { unsupported: 0 }, review: { matched: [], decoys: [], unmatched: 0 }, diagnose: {} };
const okGrades = (prompt, category) => JSON.stringify({ grades: blindOf(prompt).map((id) => ({ id, score: 7, why: 'w', ...fields[category] })) });
const kernArms = (pick, root = ROOT) => [{ id: 'kern', plugin: '.', dir: root }, { id: 'control', plugin: null, dir: null }].filter((a) => !pick || pick.includes(a.id));
const plainArm = (opts) => runOf(opts.pluginDirs.length ? [...started(opts.pluginDirs), resultEvent('done')] : [initOf([]), resultEvent('done')]);
const driveH2H = async ({ argv = ['--runs', '1'], tasks, arm = plainArm, grade = okGrades, tree = () => CLEAN, before = null, key = null, env = { PATH: process.env.PATH, CLAUDE_CONFIG_DIR: '/stand-in/eval-config' }, floorScan, parse,
  root = ROOT, dir = mkdtempSync(join(tmpdir(), 'hm-')), now = DAY, keep = false, keyWait } = {}) => {
  const snapshots = join(dir, 'snapshots'); const results = join(dir, 'results');
  const day = now.toISOString().slice(0, 10);
  const committed = join(snapshots, `h2h-sonnet-5-5-${day}.json`);
  const raw = join(results, `h2h-${day}`);
  if (before !== null) { mkdirSync(snapshots, { recursive: true }); writeFileSync(committed, before); }
  if (key !== null) { mkdirSync(raw, { recursive: true }); writeFileSync(join(raw, 'key.json'), typeof key === 'string' ? key : JSON.stringify(key)); }
  const calls = []; const graderPrompts = []; const lines = []; const errors = [];
  const byId = new Map(tasks.map((t) => [t.prompts[0], t]));
  const read = (f) => (existsSync(f) ? JSON.parse(readFileSync(f, 'utf8')) : null);
  const beside = (name) => read(join(raw, `snapshot-sonnet-5-5-${name}.json`));
  const run = (opts) => {
    calls.push(opts);
    if (!opts.prompts[0].startsWith('You grade')) return arm(opts, calls.length, { raw, beside });
    graderPrompts.push(opts.prompts[0]);
    // A runaway re-ask would spend paid grader calls without end; a test stops at the fifth.
    if (graderPrompts.length > 4 * tasks.length) throw new ClaudeRunError("stub grader: more grader calls than any test needs", true);
    const t = tasks.find((x) => opts.prompts[0].includes(x.prompts[0]));
    return runOf([resultEvent(grade(opts.prompts[0], t.category, byId))]);
  };
  let code; let thrown = null;
  try {
    code = await h2hMain({ root, argv, env, tasks, arms: (pick) => kernArms(pick, root), armIds: ['kern', 'control'], run, version: () => '9.9.9 (stand-in)', tree, snapshots, results,
      ...(floorScan ? { floorScan } : {}), ...(parse ? { parse } : {}), ...(keyWait ? { keyWait } : {}), log: (l) => lines.push(l), error: (l) => errors.push(l), now });
  } catch (e) { thrown = e; }
  return { code, thrown, calls, graderPrompts, lines, errors, raw, read, dir, results, committed: existsSync(committed) ? readFileSync(committed, 'utf8') : null,
    beside, done: () => { rmSync(dir, { recursive: true, force: true }); if (!keep) for (const t of tasks) if (t.dir.startsWith(tmpdir())) rmSync(t.dir, { recursive: true, force: true }); } };
};

test('Task 17a G1: a plan is graded from the files the run left, ignored .kern/ included, not from its first Write', async () => {
  // Lane G: kern wrote its plan to .kern/plans/, then edited it after plan-check and review; the grader saw the draft.
  const t = synthTask('plan');
  const arm = (opts) => {
    if (!opts.pluginDirs.length) {
      writeFileSync(join(opts.cwd, 'docs', 'plan.md'), 'control plan, final\n');
      return runOf([initOf([]), use('Write', { file_path: join(opts.cwd, 'docs', 'plan.md'), content: 'control plan, first draft' }), resultEvent('done')]);
    }
    mkdirSync(join(opts.cwd, '.kern', 'plans'), { recursive: true });
    writeFileSync(join(opts.cwd, '.kern', 'plans', 'p.md'), 'plan: names the second writer (edited after review)\n');
    return runOf([...started(opts.pluginDirs), use('Write', { file_path: join(opts.cwd, '.kern', 'plans', 'p.md'), content: 'plan: draft' }),
      use('Edit', { file_path: join(opts.cwd, '.kern', 'plans', 'p.md'), old_string: 'draft', new_string: 'names the second writer (edited after review)' }), resultEvent('done')]);
  };
  const r = await driveH2H({ tasks: [t], arm });
  try {
    assert.equal(r.code, 0, r.lines.join('\n'));
    const [prompt] = r.graderPrompts;
    const files = prompt.split('\n\nFiles written:\n').slice(1).map((s) => s.split('\n=== ')[0]);
    assert.equal(files.length, 2, 'each arm has a files block');
    assert.ok(files.some((f) => f.includes('--- .work/plans/p.md\nplan: names the second writer (edited after review)\n')), files.join('\n----\n'));
    assert.ok(files.some((f) => f.includes('--- docs/plan.md\ncontrol plan, final\n')), files.join('\n----\n'));
    assert.ok(!files.some((f) => /plan: draft|first draft/.test(f)), 'no Write input stands in for the final file');
  } finally { r.done(); }
});

test('Task 17a G3: a filtered h2h run, an all-VOID one or one that stops never writes the committed snapshot, and key.json is merged', async () => {
  const [p1, p2, v1] = [synthTask('plan'), synthTask('plan'), synthTask('review', { labels: [] })];
  const filtered = await driveH2H({ argv: ['--category', 'plan', '--runs', '1'], tasks: [p1, p2, v1], before: 'the day\'s full run\n', key: { 'earlier:seed': { kern: 'arm-B', control: 'arm-A' } } });
  try {
    assert.equal(filtered.committed, 'the day\'s full run\n');
    const s = filtered.beside('plan');
    assert.deepEqual([s.complete, s.cases, s.kern, s.voided, s.results.length, s.gate.map((g) => g.status)], [true, [p1.id, p2.id], CLEAN, [], 4, ['PASS']]);
    assert.deepEqual(s.arms, [{ id: 'kern', plugin: '.', commit: 'c0ffee' }, { id: 'control', plugin: null, commit: null }]);
    const key = JSON.parse(readFileSync(join(filtered.raw, 'key.json'), 'utf8'));
    assert.deepEqual(Object.keys(key), ['earlier:seed', `2026-10-22:${p1.id}:0`, `2026-10-22:${p2.id}:0`], 'the earlier key stays');
    assert.match(filtered.lines.join('\n'), /a filtered run: no committed snapshot; this one is beside the transcripts: .*snapshot-sonnet-5-5-plan\.json/);
  } finally { filtered.done(); }
  const [p3, v2] = [synthTask('plan'), synthTask('review', { labels: [] })];
  const full = await driveH2H({ tasks: [p3, v2], before: 'yesterday\n' });
  try {
    assert.equal(full.code, 0, full.lines.join('\n'));
    const s = JSON.parse(full.committed);
    assert.deepEqual([s.complete, s.cases, s.kern, s.voided, s.results.length], [true, [p3.id, v2.id], CLEAN, [], 4]);
  } finally { full.done(); }
  // Every grade malformed (a plan grade with no unsupported count): every task-run is VOID.
  const p4 = synthTask('plan');
  const none = await driveH2H({ tasks: [p4], grade: (prompt) => JSON.stringify({ grades: blindOf(prompt).map((id) => ({ id, score: 7 })) }), before: 'earlier\n' });
  try {
    assert.equal(none.committed, 'earlier\n');
    const s = none.beside('all');
    assert.deepEqual([s.complete, s.results, s.voided.map((v) => v.task)], [true, [], [p4.id]]);
    assert.match(s.voided[0].reason, /has no unsupported count/);
    assert.match(none.lines.join('\n'), /no task-run was graded: no committed snapshot, and any earlier one stays/);
  } finally { none.done(); }
  // A usage limit at the second task: the error stops the run; what was graded and its key are kept beside the runs.
  const [p5, p6] = [synthTask('plan'), synthTask('plan')];
  const stop = await driveH2H({ argv: ['--runs', '1', '--jobs', '1'], tasks: [p5, p6], before: 'earlier\n', arm: (opts, n) => { if (n > 3) throw new ClaudeRunError('claude stopped at a usage limit: x', true); return plainArm(opts); } });
  try {
    assert.match(String(stop.thrown?.message), /usage limit/);
    assert.equal(stop.committed, 'earlier\n');
    const s = stop.beside('all');
    assert.deepEqual([s.complete, s.cases, s.results.map((x) => x.task)], [false, [p5.id, p6.id], [p5.id, p5.id]]);
    assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(stop.raw, 'key.json'), 'utf8'))), [`2026-10-22:${p5.id}:0`]);
  } finally { stop.done(); }
});

test('Task 17a G13: a git failure in one arm\'s workspace voids that task-run only, and the run goes on', async () => {
  const t = synthTask('plan');
  // The first arm run leaves an index.lock behind, so `git add -A -N` fails in its workspace.
  const arm = (opts, n) => { if (n === 1) writeFileSync(join(opts.cwd, '.git', 'index.lock'), ''); return plainArm(opts); };
  const r = await driveH2H({ argv: ['--runs', '2'], tasks: [t], arm });
  try {
    assert.equal(r.code, 0, r.lines.join('\n'));
    const s = JSON.parse(r.committed);
    assert.deepEqual([s.voided.length, s.voided[0].run, s.results.map((x) => x.run)], [1, 0, [1, 1]]);
    assert.match(s.voided[0].reason, /^(kern|control): fatal: Unable to create .*index\.lock/);
  } finally { r.done(); }
});

test('Task 17a G9: heldout tests and floor-scan get childEnv, not the caller\'s environment, and a floor-scan error voids the task-run', async () => {
  const probe = mkdtempSync(join(tmpdir(), 'hp-'));
  const scan = join(probe, 'floor-scan');
  writeFileSync(scan, `env > "${probe}/scan.env"\nls -A "$HOME" | wc -l | tr -d ' ' > "${probe}/scan.home"\n[ -f "${probe}/break" ] && { echo 'floor-scan: bad input' >&2; exit 2; }\nexit 0\n`);
  const t = synthTask('diagnose', { test: `env > "${probe}/heldout.env"` });
  const arm = (opts) => { writeFileSync(join(opts.cwd, 'src', 'a.js'), 'export const a = 2;\n'); return plainArm(opts); };
  const env = { PATH: process.env.PATH, HOME: process.env.HOME, CLAUDE_CONFIG_DIR: '/stand-in/eval-config', KERN_P5_PROBE_TOKEN: 'secret', CLAUDE_CODE_SESSION_ID: 'caller-session' };
  try {
    const r = await driveH2H({ tasks: [t], arm, env, floorScan: scan });
    try {
      assert.equal(JSON.parse(r.committed).voided.length, 0, r.lines.join('\n'));
      for (const f of ['scan.env', 'heldout.env']) {
        const seen = readFileSync(join(probe, f), 'utf8');
        assert.match(seen, /^PATH=/m, f);
        assert.doesNotMatch(seen, /KERN_P5_PROBE_TOKEN|CLAUDE_CODE_SESSION_ID/, `${f}: the caller's own variables stay out`);
      }
      // Fix round 1 (P5 review, Minor 2): floor-scan reads $HOME/.claude/kern.yml ratchets, so it gets an empty
      // temp HOME, removed after, never the caller's.
      const home = readFileSync(join(probe, 'scan.env'), 'utf8').match(/^HOME=(.*)$/m)[1];
      assert.notEqual(home, process.env.HOME);
      assert.ok(home.startsWith(tmpdir()) || home.startsWith(realpathSync(tmpdir())), home);
      assert.equal(readFileSync(join(probe, 'scan.home'), 'utf8').trim(), '0', 'the HOME floor-scan saw was empty');
      assert.ok(!existsSync(home), 'and it is removed after the scan');
    } finally { r.done(); }
    writeFileSync(join(probe, 'break'), '');
    const t2 = synthTask('diagnose', { test: 'true' });
    const broken = await driveH2H({ tasks: [t2], arm, env, floorScan: scan });
    try {
      const s = broken.beside('all');
      assert.deepEqual([s.results.length, s.voided.length], [0, 1]);
      assert.match(s.voided[0].reason, /^(kern|control): floor-scan exited 2: floor-scan: bad input$/);
    } finally { broken.done(); }
  } finally { rmSync(probe, { recursive: true, force: true }); }
});

test('Task 17a G10: an h2h arm that did not load its plugin, or a non-kern arm that printed the kernel, voids the task-run', async () => {
  const t = synthTask('plan');
  const r = await driveH2H({ tasks: [t], arm: (opts) => runOf([initOf([]), resultEvent('done')]) });
  try { assert.match(r.beside('all').voided[0].reason, /^kern: the plugin at .*\/kern is not in the run's init\.plugins/); } finally { r.done(); }
  const t2 = synthTask('plan');
  const leak = await driveH2H({ tasks: [t2], arm: (opts) => runOf([...started(opts.pluginDirs), resultEvent('done')]) });
  try { assert.match(leak.beside('all').voided[0].reason, /^control: kern was meant to be off, but its SessionStart printed the kernel$/); } finally { leak.done(); }
});

test('Task 17a G11: every h2h run refuses a dirty kern tree unless --allow-dirty, a --category or --task run too', async () => {
  // Fix round 1 (P5 review, Minor 1): the confirming h2h runs are --category runs, and their snapshots are the evidence.
  const dirty = { commit: 'c0ffee', dirty: true, changes: ['?? skills/new/SKILL.md'] };
  for (const argv of [() => ['--runs', '1'], () => ['--category', 'plan', '--runs', '1'], (p) => ['--task', p.id, '--runs', '1'], () => ['--arms', 'kern,control']]) {
    const p = synthTask('plan');
    const r = await driveH2H({ argv: argv(p), tasks: [p], tree: () => dirty });
    try {
      assert.equal(r.code, 2, argv(p).join(' '));
      assert.match(r.errors.join('\n'), /^h2h: the kern tree is not a clean commit .*--allow-dirty/);
      assert.equal(r.calls.length, 0, 'nothing ran');
    } finally { r.done(); }
  }
  const dry = await driveH2H({ argv: ['--dry-run'], tasks: [synthTask('plan')], tree: () => dirty });
  try { assert.equal(dry.code, 0, 'a dry run measures nothing, so it is never refused'); } finally { dry.done(); }
  const ok = await driveH2H({ argv: ['--runs', '1', '--allow-dirty'], tasks: [synthTask('plan')], tree: () => dirty });
  try { assert.deepEqual(JSON.parse(ok.committed).kern, dirty); } finally { ok.done(); }
});

test('the runner gives the gate every task of the categories it ran, prints each verdict line and exits by gateExit', async () => {
  const [a, b] = [synthTask('plan'), synthTask('plan')];
  const r = await driveH2H({ argv: ['--task', a.id, '--runs', '1'], tasks: [a, b] });
  try {
    assert.equal(r.code, 3);
    assert.ok(r.lines.includes(`INCOMPLETE plan: 1 of 2 tasks graded; no graded run: ${b.id}`), r.lines.join('\n'));
  } finally { r.done(); }
});

test('each attempt carries the git facts read in its workspace before its run, and a review row keeps the grader\'s reply', async () => {
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  // The arm commits during its run; the facts the grader gets are from before it.
  const arm = (opts) => {
    spawnSync('git', ['-C', opts.cwd, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', 'commit', '-q', '--allow-empty', '-m', 'during the run'], { encoding: 'utf8' });
    return plainArm(opts);
  };
  const grade = (prompt) => JSON.stringify({ grades: blindOf(prompt).map((id) => ({ id, score: 6, matched: ['b1', 'decoy:d1'], decoys: [], extras: ['x1'], unmatched: 1, why: 'w' })) });
  const r = await driveH2H({ argv: ['--runs', '1'], tasks: [t], arm, grade });
  try {
    const [prompt] = r.graderPrompts;
    assert.equal([...prompt.matchAll(/^Git facts: branch feat\/discounts; main branch main; HEAD \w+; 2 commits, newest first:$/gm)].length, 2, prompt.slice(0, 3000));
    assert.doesNotMatch(prompt, /during the run/);
    const rows = JSON.parse(r.committed).results;
    assert.deepEqual(rows.map((x) => [x.decoys, x.unmatched, x.extras, x.falseAlarms, x.matched]), [[1, 1, 1, 2, ['b1']], [1, 1, 1, 2, ['b1']]]);
    assert.ok(rows.every((x) => x.reply === grade(prompt)));
    assert.ok(rows.every((x) => x.git.commits === 2));
  } finally { r.done(); }
});

test('the head-to-head grader reads digest(events) with tool results, the diff and the files written', async () => {
  const t = synthTask('plan');
  const r = await driveH2H({ tasks: [t] });
  try {
    const [prompt] = r.graderPrompts;
    for (const id of blindOf(prompt)) assert.ok(prompt.includes(`\n=== ${id} ===\n`));
    assert.match(prompt, /\n\nDiff:\n\(none\)/);
  } finally { r.done(); }
});

// Fix round 1 (P5 review, Important 1): a VOID throws away every arm session of the task-run, so a grade that fails
// to parse or validate is asked for once more, with the error, before the task-run is voided.
test('a grader reply that fails to parse or validate is re-asked once with the error, then the task-run is VOID', async () => {
  const bad = (prompt) => JSON.stringify({ grades: blindOf(prompt).map((id) => ({ id, score: 7 })) });
  const fixed = (prompt, category) => (prompt.includes('could not be used') ? okGrades(prompt, category) : bad(prompt));
  const t = synthTask('plan');
  const r = await driveH2H({ tasks: [t], grade: fixed });
  try {
    assert.equal(r.code, 0, r.lines.join('\n'));
    assert.equal(r.graderPrompts.length, 2);
    const [first, again] = r.graderPrompts;
    assert.ok(again.startsWith(first), 'the same prompt, then the note');
    assert.match(again.slice(first.length), /^\n\nA reply to this prompt could not be used: h2h grader: arm-[A-Z] has no unsupported count\. Reply again with JSON only/);
    const s = JSON.parse(r.committed);
    assert.deepEqual([s.voided, s.results.length], [[], 2]);
    assert.ok(s.results.every((x) => /has no unsupported count/.test(x.regrade)), 'each row says it was re-asked, and why');
  } finally { r.done(); }
  const t2 = synthTask('plan');
  const twice = await driveH2H({ tasks: [t2], grade: bad });
  try {
    assert.equal(twice.graderPrompts.length, 2, 'one re-ask, no more');
    const s = twice.beside('all');
    assert.match(s.voided[0].reason, /^h2h grader: arm-[A-Z] has no unsupported count \(asked twice; first: h2h grader: arm-[A-Z] has no unsupported count\)$/);
  } finally { twice.done(); }
  const t3 = synthTask('plan');
  const notJson = await driveH2H({ tasks: [t3], grade: (prompt, category) => (prompt.includes('could not be used') ? okGrades(prompt, category) : 'I cannot grade these.') });
  try { assert.equal(JSON.parse(notJson.committed).results.length, 2, 'a reply with no JSON is re-asked too'); } finally { notJson.done(); }
  // Fix round 2 (P5 re-review, Minor C): the re-ask is bounded by a count, not by the first error's message.
  const t4 = synthTask('plan');
  const silent = await driveH2H({ tasks: [t4], parse: () => { throw new Error(''); } });
  try {
    assert.equal(silent.thrown, null, String(silent.thrown));
    assert.equal(silent.graderPrompts.length, 2, 'an error with no message is re-asked once, no more');
    assert.match(silent.beside('all').voided[0].reason, /^h2h grader: the reply could not be used \(asked twice; first: h2h grader: the reply could not be used\)$/);
  } finally { silent.done(); }
});

// Fix round 1 (P5 review, Minor 3): only a child process's failure (git, floor-scan) voids a task-run; any other
// error is a harness fault, and it stops the run rather than turn every task-run into a VOID.
// Fix round 2 (P5 re-review, Minor D): root reads a mode-000 file, so the fault never happens; skipped there.
test('a harness fault in an arm\'s attempt stops the h2h run, and what was graded stays beside the runs', { skip: process.getuid?.() === 0 && 'root reads a mode-000 file' }, async () => {
  const t = synthTask('plan');
  const arm = (opts) => {
    mkdirSync(join(opts.cwd, '.kern'), { recursive: true });
    writeFileSync(join(opts.cwd, '.kern', 'locked.md'), 'x\n');
    chmodSync(join(opts.cwd, '.kern', 'locked.md'), 0o000);
    return plainArm(opts);
  };
  const r = await driveH2H({ tasks: [t], arm, before: 'earlier\n' });
  try {
    assert.equal(r.thrown?.code, 'EACCES', String(r.thrown));
    assert.equal(r.committed, 'earlier\n');
    assert.deepEqual([r.beside('all').complete, r.beside('all').voided], [false, []]);
  } finally { r.done(); }
});

// Fix round 1 (P5 review, Minor 5): key.json is the only map from the day's blind ids to arms.
test('a key.json that is not JSON stops the h2h run before anything runs, and is left as it was', async () => {
  const r = await driveH2H({ tasks: [synthTask('plan')], key: '{"2026-10-22:plan/x:0": {"kern": "arm-' });
  try {
    assert.equal(r.code, 2);
    assert.match(r.errors.join('\n'), /^h2h: .*key\.json is not JSON \(.*\); move it aside before a run$/);
    assert.equal(r.calls.length, 0, 'nothing ran');
    assert.equal(readFileSync(join(r.raw, 'key.json'), 'utf8'), '{"2026-10-22:plan/x:0": {"kern": "arm-');
  } finally { r.done(); }
});

// Fix round 1 (P5 review, Minor 6): a SIGINT or SIGTERM skips every finally, so each task-run's grades and keys are
// saved as it ends.
test('h2h saves its progress and merges key.json after each task-run, so a killed run keeps what it graded', async () => {
  const [p1, p2] = [synthTask('plan'), synthTask('plan')];
  let seen = null;
  // At p2's first arm run, p1's task-run is graded: read what a kill at that moment would leave.
  const arm = (opts, n, at) => {
    if (opts.prompts[0] === p2.prompts[0] && !seen) seen = { snapshot: at.beside('all'), key: JSON.parse(readFileSync(join(at.raw, 'key.json'), 'utf8')) };
    return plainArm(opts);
  };
  const r = await driveH2H({ argv: ['--runs', '1', '--jobs', '1'], tasks: [p1, p2], arm, key: { 'earlier:seed': { kern: 'arm-A', control: 'arm-B' } } });
  try {
    assert.equal(r.code, 0, r.lines.join('\n'));
    assert.deepEqual([seen.snapshot.complete, seen.snapshot.cases, seen.snapshot.results.map((x) => x.task)], [false, [p1.id, p2.id], [p1.id, p1.id]]);
    assert.deepEqual(Object.keys(seen.key), ['earlier:seed', `2026-10-22:${p1.id}:0`]);
    assert.equal(JSON.parse(r.committed).complete, true);
    assert.equal(r.beside('all'), null, 'a full run removes its progress file once the committed snapshot is written');
  } finally { r.done(); }
  // A filtered run's progress file is its snapshot, complete at the end.
  const p3 = synthTask('plan');
  const f = await driveH2H({ argv: ['--category', 'plan', '--runs', '1'], tasks: [p3] });
  try { assert.equal(f.beside('plan').complete, true); } finally { f.done(); }
});

// Fast rounds for h2h (--jobs, --quick, the cache, --resume, --regrade, --changed): the same seam.
const isGrader = (opts) => opts.prompts[0].startsWith('You grade');

test('a task-run\'s arms run side by side, and the rows come out as a run of one session at a time gives them', async () => {
  const [p1, p2] = [synthTask('plan'), synthTask('plan')];
  let held = 0; let most = 0;
  const arm = async (opts) => {
    held += 1; most = Math.max(most, held);
    await new Promise((r) => setTimeout(r, opts.prompts[0] === p1.prompts[0] ? 80 : 10));
    held -= 1;
    return plainArm(opts);
  };
  const wide = await driveH2H({ argv: ['--runs', '2', '--jobs', '4', '--no-cache'], tasks: [p1, p2], arm, keep: true });
  const mostWide = most;
  most = 0;
  const narrow = await driveH2H({ argv: ['--runs', '2', '--jobs', '1', '--no-cache'], tasks: [p1, p2], arm });
  try {
    assert.deepEqual([wide.code, narrow.code], [0, 0], wide.lines.join('\n'));
    assert.ok(mostWide > 1 && mostWide <= 4, `held ${mostWide} at once`);
    assert.equal(most, 1);
    const rows = (r) => JSON.parse(r.committed).results.map((x) => [x.task, x.run, x.arm, x.score, x.falseAlarms]);
    assert.deepEqual(rows(wide), rows(narrow));
    assert.match(wide.lines.join('\n'), /^round: .* wall; 8 session\(s\) run, 0 reused; --jobs 4$/m);
  } finally { wide.done(); narrow.done(); }
});

test('h2h --quick runs each task once into a results dir of its own, writes no committed snapshot, and runs on a dirty tree', async () => {
  const dirty = { commit: 'c0ffee', dirty: true, changes: ['?? skills/new/SKILL.md'] };
  const p = synthTask('plan');
  const r = await driveH2H({ argv: ['--quick'], tasks: [p], tree: () => dirty, before: 'the gate\n' });
  try {
    assert.equal(r.code, 0, r.errors.join('\n'));
    assert.equal(r.committed, 'the gate\n');
    const s = JSON.parse(readFileSync(join(r.results, 'h2h-2026-10-22-quick-120000', 'snapshot-sonnet-5-5-all.json'), 'utf8'));
    assert.deepEqual([s.runs, s.quick, s.complete, s.kern, s.results.length], [1, true, true, dirty, 2]);
    assert.match(r.lines.join('\n'), /a --quick run: no committed snapshot; this one is beside the transcripts/);
  } finally { r.done(); }
});

test('h2h reuses each unchanged arm attempt; the same day reuses the grade too, and a new day or a new key asks the grader again', async () => {
  const p = synthTask('review', { labels: [] });
  const first = await driveH2H({ tasks: [p], keep: true });
  try {
    assert.equal(first.code, 0, first.lines.join('\n'));
    const again = await driveH2H({ tasks: [p], dir: first.dir, keep: true });
    assert.deepEqual([again.calls.length, again.code], [0, 0], 'every attempt and the grade came from the cache');
    assert.deepEqual(JSON.parse(again.committed).results.map((x) => [x.arm, x.score]), JSON.parse(first.committed).results.map((x) => [x.arm, x.score]));
    const later = await driveH2H({ tasks: [p], dir: first.dir, now: new Date('2026-10-23T09:00:00Z'), keep: true });
    assert.deepEqual([later.calls.filter((o) => !isGrader(o)).length, later.graderPrompts.length, later.code], [0, 1, 0]);
    const ids = blindIds(['kern', 'control'], `2026-10-23:${p.id}:0`);
    for (const id of Object.values(ids)) assert.ok(existsSync(join(later.raw, `${p.id.replace('/', '--')}-0-${id}.jsonl`)), `a reused transcript carries the new blind id ${id}`);
    const rekeyed = await driveH2H({ tasks: [{ ...p, labels: [{ id: 'b1', kind: 'bug', what: 'x' }] }], dir: first.dir, keep: true });
    assert.deepEqual([rekeyed.calls.filter((o) => !isGrader(o)).length, rekeyed.graderPrompts.length], [0, 1], 'a new key changes the grade, not the attempts');
  } finally { first.done(); rmSync(p.dir, { recursive: true, force: true }); }
});

test('h2h --resume runs only the task-runs the stopped run lacks, and finishes it', async () => {
  const [p5, p6] = [synthTask('plan'), synthTask('plan')];
  const limit = (opts, n) => { if (n > 3) throw new ClaudeRunError('claude stopped at a usage limit: x', true); return plainArm(opts); };
  const stop = await driveH2H({ argv: ['--runs', '1', '--jobs', '1', '--no-cache'], tasks: [p5, p6], arm: limit, keep: true });
  try {
    assert.match(String(stop.thrown?.message), /usage limit/);
    const more = await driveH2H({ argv: ['--resume', stop.raw, '--no-cache'], tasks: [p5, p6], dir: stop.dir, keep: true });
    assert.equal(more.code, 0, more.errors.concat(more.lines).join('\n'));
    assert.deepEqual(more.calls.filter((o) => !isGrader(o)).map((o) => o.prompts[0]), [p6.prompts[0], p6.prompts[0]]);
    assert.equal(more.graderPrompts.length, 1);
    const s = JSON.parse(more.committed);
    assert.deepEqual([s.complete, s.results.map((x) => x.task)], [true, [p5.id, p5.id, p6.id, p6.id]]);
    assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(stop.raw, 'key.json'), 'utf8'))), [`2026-10-22:${p5.id}:0`, `2026-10-22:${p6.id}:0`]);
  } finally { stop.done(); for (const t of [p5, p6]) rmSync(t.dir, { recursive: true, force: true }); }
});

test('h2h --regrade reads each task-run\'s saved grader reply again with today\'s rules, and starts no session', async () => {
  const t = loadTasks(ROOT).find((x) => x.id === 'review/invoice-branch');
  const grade = (prompt) => JSON.stringify({ grades: blindOf(prompt).map((id) => ({ id, score: 6, matched: ['b1', 'decoy:d1'], decoys: [], extras: ['x1'], unmatched: 1, why: 'w' })) });
  const first = await driveH2H({ tasks: [t], grade });
  try {
    assert.equal(first.code, 0, first.lines.join('\n'));
    const regrade = (opts = {}) => driveH2H({ argv: ['--regrade', first.raw], tasks: [t], dir: first.dir, arm: () => { throw new Error('a regrade started a session'); }, ...opts });
    const out = () => JSON.parse(readFileSync(join(first.raw, 'regrade-sonnet-5-5-all-120000.json'), 'utf8'));
    const same = await regrade();
    assert.deepEqual([same.code, same.calls.length], [0, 0], same.errors.join('\n'));
    const before = JSON.parse(first.committed);
    assert.deepEqual(out().results.map((x) => [x.arm, x.score, x.falseAlarms, x.decoys]), before.results.map((x) => [x.arm, x.score, x.falseAlarms, x.decoys]));
    assert.deepEqual(out().gate, before.gate);
    const strict = await regrade({ parse: () => { throw new Error('h2h grader: today\'s rule refuses it'); } });
    assert.deepEqual([strict.code, out().results.length, out().voided.map((v) => v.reason)], [3, 0, ['h2h grader: today\'s rule refuses it']]);
    const bad = await driveH2H({ argv: ['--regrade', first.raw, '--runs', '1'], tasks: [t], dir: first.dir });
    assert.equal(bad.code, 2);
  } finally { first.done(); }
});

test('h2h --changed runs only the tasks whose category\'s kern skills changed', async () => {
  const root = gitSandbox(ROOT);
  const [p, d] = [synthTask('plan'), synthTask('diagnose')];
  try {
    writeFileSync(join(root, 'skills', 'plan', 'SKILL.md'), `${readFileSync(join(root, 'skills', 'plan', 'SKILL.md'), 'utf8')}\nOne more line.\n`);
    const r = await driveH2H({ argv: ['--changed', 'HEAD', '--runs', '1'], tasks: [p, d], root, keep: true });
    assert.equal(r.code, 0, r.errors.concat(r.lines).join('\n'));
    assert.deepEqual(r.calls.filter((o) => !isGrader(o)).map((o) => o.prompts[0]), [p.prompts[0], p.prompts[0]]);
    assert.equal(r.committed, null, 'a --changed run is a filtered run');
    r.done();
    const none = await driveH2H({ argv: ['--changed', 'HEAD~0', '--category', 'diagnose', '--dry-run'], tasks: [p, d], root, keep: true });
    assert.deepEqual([none.code, none.lines[0]], [0, '--changed HEAD~0: 0 of 1 tasks']);
    none.done();
  } finally { rmSync(dirname(root), { recursive: true, force: true }); for (const t of [p, d]) rmSync(t.dir, { recursive: true, force: true }); }
});

test('h2h runs of two categories at once share the day\'s dir: each keeps its own run file, and key.json holds both', async () => {
  const [p, v] = [synthTask('plan'), synthTask('review', { labels: [] })];
  const dir = mkdtempSync(join(tmpdir(), 'hm-'));
  const slow = async (opts) => { await new Promise((r) => setTimeout(r, 20)); return plainArm(opts); };
  const [plan, review] = await Promise.all([
    driveH2H({ argv: ['--category', 'plan', '--runs', '2'], tasks: [p, v], arm: slow, dir, keep: true }),
    driveH2H({ argv: ['--category', 'review', '--runs', '2'], tasks: [p, v], arm: slow, dir, keep: true }),
  ]);
  try {
    assert.deepEqual([plan.code, review.code], [0, 0], plan.lines.concat(review.lines).join('\n'));
    const key = JSON.parse(readFileSync(join(plan.raw, 'key.json'), 'utf8'));
    assert.deepEqual(Object.keys(key).sort(), [0, 1].flatMap((r) => [`2026-10-22:${p.id}:${r}`, `2026-10-22:${v.id}:${r}`]).sort());
    for (const c of ['plan', 'review']) assert.ok(existsSync(join(plan.raw, `run-sonnet-5-5-${c}.json`)), c);
    assert.ok(!existsSync(join(plan.raw, 'key.json.lock')), 'no lock left');
    const which = await driveH2H({ argv: ['--resume', plan.raw], tasks: [p, v], dir, keep: true });
    assert.equal(which.code, 2);
    assert.match(which.errors[0], /holds 2 runs: pass one of .*run-sonnet-5-5-plan\.json, .*run-sonnet-5-5-review\.json/);
    const named = await driveH2H({ argv: ['--resume', join(plan.raw, 'run-sonnet-5-5-review.json')], tasks: [p, v], dir, keep: true });
    assert.deepEqual([named.code, named.calls.length], [0, 0], 'the review run is complete, so its resume runs nothing');
    const regraded = await driveH2H({ argv: ['--regrade', join(plan.raw, 'run-sonnet-5-5-plan.json')], tasks: [p, v], dir, keep: true });
    assert.equal(regraded.code, 0, regraded.errors.join('\n'));
    assert.match(regraded.lines.at(-1), /regrade-sonnet-5-5-plan-120000\.json$/);
  } finally { rmSync(dir, { recursive: true, force: true }); for (const t of [p, v]) rmSync(t.dir, { recursive: true, force: true }); }
});

test('a fatal error in one arm waits for the other arm\'s session, which saves its record', async () => {
  const p = synthTask('plan');
  const arm = async (opts) => {
    if (!opts.pluginDirs.length) throw new ClaudeRunError('claude stopped at a usage limit: x', true);
    await new Promise((r) => setTimeout(r, 150));
    return plainArm(opts);
  };
  const r = await driveH2H({ argv: ['--runs', '1', '--no-cache'], tasks: [p], arm });
  try {
    assert.match(String(r.thrown?.message), /usage limit/);
    assert.ok(existsSync(join(r.raw, `${p.id.replace('/', '--')}-0-kern.result.json`)), 'the kern arm saved its record');
  } finally { r.done(); }
});

test('an h2h rubric edit in task.json asks the grader again but reruns no arm; a floor-scan rule edit reruns every arm', async () => {
  const root = gitSandbox(ROOT);
  const d = synthTask('diagnose');
  try {
    writeFileSync(join(d.dir, 'task.json'), JSON.stringify({ ...d, dir: undefined }));
    const arm = (opts) => { writeFileSync(join(opts.cwd, 'src', 'a.js'), 'export const a = 2;\n'); return plainArm(opts); };
    const first = await driveH2H({ tasks: [d], arm, root, keep: true });
    assert.equal(first.code, 0, first.lines.join('\n'));
    const t2 = { ...d, rubric: ['does it well'] };
    writeFileSync(join(d.dir, 'task.json'), JSON.stringify({ ...t2, dir: undefined }));
    const rubric = await driveH2H({ tasks: [t2], arm, root, dir: first.dir, keep: true });
    assert.deepEqual([rubric.calls.filter((o) => !isGrader(o)).length, rubric.graderPrompts.length], [0, 1]);
    writeFileSync(join(root, 'scripts', 'lib', 'floor-scan.awk'), `${readFileSync(join(root, 'scripts', 'lib', 'floor-scan.awk'), 'utf8')}\n# a rule changed\n`);
    const scan = await driveH2H({ tasks: [t2], arm, root, dir: first.dir, keep: true });
    assert.equal(scan.calls.filter((o) => !isGrader(o)).length, 2, 'both arms\' floor hits come from the new scanner');
    first.done();
  } finally { rmSync(dirname(root), { recursive: true, force: true }); rmSync(d.dir, { recursive: true, force: true }); }
});

// Opus re-review, Minors 2 and 6: a key.json write that fails is said and tried again at the next task-run, and an
// --arms run's seeds name its arms, so a run of other arms over the same tasks keeps its own key.
test('h2h tries a failed key.json merge again after the next task-run, and an --arms run keys its seeds by its arms', async () => {
  const [p1, p2] = [synthTask('plan'), synthTask('plan')];
  const dir = mkdtempSync(join(tmpdir(), 'hm-'));
  const raw = join(dir, 'results', 'h2h-2026-10-22');
  mkdirSync(join(raw, 'key.json.lock'), { recursive: true });
  writeFileSync(join(raw, 'key.json.lock', 'owner'), String(process.pid));
  const arm = (opts) => { if (opts.prompts[0] === p2.prompts[0]) rmSync(join(raw, 'key.json.lock'), { recursive: true, force: true }); return plainArm(opts); };
  const r = await driveH2H({ argv: ['--runs', '1', '--jobs', '1', '--arms', 'kern,control'], tasks: [p1, p2], arm, dir, keyWait: 100 });
  try {
    assert.equal(r.code, 0, r.lines.concat(r.errors).join('\n'));
    assert.ok(r.lines.some((l) => /^key\.json: could not merge .*held by another run.*; tried again after the next task-run$/.test(l)), r.lines.join('\n'));
    assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(raw, 'key.json'), 'utf8'))).sort(), [`2026-10-22:${p1.id}:0:arms-kern+control`, `2026-10-22:${p2.id}:0:arms-kern+control`]);
  } finally { r.done(); }
});

test('h2h --regrade of a run from before run files had names writes regrade-<HHMMSS>.json', async () => {
  const p = synthTask('plan');
  const first = await driveH2H({ tasks: [p], keep: true });
  try {
    renameSync(join(first.raw, 'run-sonnet-5-5-all.json'), join(first.raw, 'run.json'));
    const r = await driveH2H({ argv: ['--regrade', first.raw], tasks: [p], dir: first.dir, keep: true });
    assert.match(r.lines.at(-1), /\/regrade-120000\.json$/);
  } finally { first.done(); rmSync(p.dir, { recursive: true, force: true }); }
});
