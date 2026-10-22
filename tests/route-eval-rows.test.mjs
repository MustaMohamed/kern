// tests/route-eval-rows.test.mjs
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { targets, evaluate } from '../scripts/route-eval.mjs';
import { kernelRows } from '../scripts/lib/kernel-rows.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));

// Each repo() dir is removed when the file's tests are done.
const made = [];
after(() => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-rows-'));
  made.push(root);
  for (const [p, content] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), content);
  }
  return root;
}
const autoSkill = (name, desc) => `---\nname: ${name}\ndescription: ${desc}\n---\n\n# ${name}\n\n## Steps\n\n1. a\n`;
const pathSkill = (name) => `---\nname: ${name}\ndescription: d\ndisable-model-invocation: true\n---\n\n# ${name}\n\n## Steps\n\n1. a\n`;
const cases = (name, pos, neg) => JSON.stringify({
  skill_name: name,
  trigger: { positive: pos.map((prompt) => ({ prompt, top_k: 3 })), negative: neg.map((prompt) => ({ prompt })) },
  evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
});
// Since Task 16d every row is in the kernel table.
const KERNEL = [
  'Several matches: define and diagnose before build.',
  '',
  '| Observable trigger | Route |',
  '|---|---|',
  '| Bug, failing test, unexpected output, crash or error | Read {KERN}/diagnose/SKILL.md |',
  '| Starting or resuming after a gap | Read {KERN}/recall/SKILL.md |',
  '| Phase ends, or context is filling | Read {ROOT}/kernel/context.md |',
].join('\n');

function fixture(extra = {}) {
  return repo({
    'kernel/kernel.md': KERNEL,
    'skills/diagnose/SKILL.md': pathSkill('diagnose'),
    'skills/recall/SKILL.md': autoSkill('recall', 'Use when starting or resuming work after a gap and state must be rebuilt: where did I leave off, catch me up.'),
    'evals/cases/recall.json': cases('recall', ['where did I leave off yesterday', 'catch me up on the work', 'resuming after a long gap'], ['fix this crash', 'rename a variable']),
    'evals/cases/row-recall.json': cases('row-recall', ['resuming after a gap in the work', 'starting again after a gap', 'where did I leave off after the gap'], ['fix this crash', 'rename a variable']),
    'evals/cases/row-diagnose.json': cases('row-diagnose', ['the test is failing with an error', 'unexpected output from the bug', 'a crash with an error on startup'], ['catch me up', 'where did I leave off']),
    'evals/cases/row-context.json': cases('row-context', ['the context is filling up', 'this phase ends now', 'context is filling, what next'], ['fix this crash', 'catch me up']),
    ...extra,
  });
}

test('kernelRows parses skill and kernel-file routes and skips other lines', () => {
  assert.deepEqual(kernelRows(KERNEL), [
    { when: 'Bug, failing test, unexpected output, crash or error', route: 'diagnose' },
    { when: 'Starting or resuming after a gap', route: 'recall' },
    { when: 'Phase ends, or context is filling', route: 'context' },
  ]);
  assert.deepEqual(kernelRows(''), []);
});

test('targets add the kernel rows after skills and before distractors', () => {
  const root = fixture({ 'evals/distractors.json': JSON.stringify([{ name: 'other', description: 'Something else entirely' }]) });
  assert.deepEqual(targets(root).map((t) => `${t.kind}:${t.name}`), ['skill:recall', 'row:row-diagnose', 'row:row-recall', 'row:row-context', 'distractor:other']);
});

test('a row left in kernel/routes.md is not a target: no session reads that file', () => {
  const root = fixture({ 'kernel/routes.md': '| Old trigger | Read {KERN}/define/SKILL.md |\n' });
  assert.deepEqual(targets(root).filter((t) => t.kind === 'row').map((t) => t.name), ['row-diagnose', 'row-recall', 'row-context']);
});

test('a row and its own skill count as one owner', () => {
  const r = evaluate(fixture(), { minRank1: null });
  assert.deepEqual(r.errors, []);
  assert.equal(r.rank1Rate, 100);
});

test('a routed row without a case file is an error', () => {
  const root = fixture();
  rmSync(join(root, 'evals/cases/row-diagnose.json'));
  const r = evaluate(root, { minRank1: null });
  assert.ok(r.errors.some((e) => e.startsWith('row-diagnose: no eval case file')), JSON.stringify(r.errors));
});

test('held-out prompts give their own rate, held to their own floor', () => {
  const held = JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }, { owner: 'diagnose', prompt: 'catch me up' }]);
  const r = evaluate(fixture({ 'evals/heldout.json': held }), { minRank1: null, minHeldout: 60 });
  assert.equal(r.heldoutRate, 50);
  assert.ok(r.errors.some((e) => e.startsWith('held-out rank-1 rate 50% is below the floor 60%')), JSON.stringify(r.errors));
});

test('the fixed floors and the frozen held-out set are pinned', () => {
  // heldout_rank1 is the measured held-out rate (9 of 25): the lexical ranker is deterministic, so one lost hit fails.
  assert.deepEqual(JSON.parse(readFileSync(join(ROOT, 'evals', 'floors.json'), 'utf8')), { rank1: 85, heldout_rank1: 36 });
  const sha = createHash('sha256').update(readFileSync(join(ROOT, 'evals', 'heldout.json'))).digest('hex');
  assert.equal(sha, '9b5cb8271f50835c162805b42066d90206bd46ffd7b0af280992b3d5af2a54c0', 'evals/heldout.json is frozen: record held-out misses; never edit a row or description to win one');
});

// A negative the lexical ranker cannot judge carries "grader": "model"; M2b's model-graded runner checks it.
const withGrader = (negative, positive = ['where did I leave off yesterday', 'catch me up on the work', 'resuming after a long gap']) => fixture({
  'evals/cases/recall.json': JSON.stringify({
    skill_name: 'recall',
    trigger: { positive: positive.map((p) => (typeof p === 'string' ? { prompt: p, top_k: 3 } : p)), negative },
    evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
  }),
  'evals/baseline.json': JSON.stringify({ min_rank1: 0 }),
  'evals/floors.json': JSON.stringify({ rank1: 0, heldout_rank1: 0 }),
  'evals/heldout.json': JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }]),
});
const LEXICAL = [{ prompt: 'fix this crash' }, { prompt: 'rename a variable' }];

test('a model-graded negative is skipped by the lexical check and listed in the output', () => {
  const plain = evaluate(withGrader([...LEXICAL, { prompt: 'catch me up' }]), { minRank1: null });
  assert.ok(plain.errors.some((e) => e === 'recall: ranked #1 for negative prompt "catch me up"'), JSON.stringify(plain.errors));
  const root = withGrader([...LEXICAL, { prompt: 'catch me up', grader: 'model' }]);
  const r = evaluate(root, { minRank1: null });
  assert.deepEqual(r.errors, []);
  assert.deepEqual(r.modelGraded, [{ owner: 'recall', prompt: 'catch me up' }]);
  const cli = spawnSync(process.execPath, [join(ROOT, 'scripts', 'route-eval.mjs'), root], { encoding: 'utf8' });
  assert.equal(cli.status, 0, cli.stdout + cli.stderr);
  assert.match(cli.stdout, /^model-graded, not checked here: recall: "catch me up"$/m);
});

test('a positive that carries the grader flag is an error', () => {
  const r = evaluate(withGrader(LEXICAL, ['where did I leave off yesterday', 'catch me up on the work', { prompt: 'resuming after a long gap', top_k: 3, grader: 'model' }]), { minRank1: null });
  assert.ok(r.errors.some((e) => e.startsWith('recall: a positive prompt cannot carry "grader"')), JSON.stringify(r.errors));
});

test('only lexically checked negatives count toward the minimum', () => {
  const r = evaluate(withGrader([LEXICAL[0], { prompt: 'catch me up', grader: 'model' }]), { minRank1: null });
  assert.ok(r.errors.some((e) => e.startsWith('recall: below required minimums (3/1/1')), JSON.stringify(r.errors));
});

test('a negative with a grader other than model is an error', () => {
  const r = evaluate(withGrader([...LEXICAL, { prompt: 'add a CSV export', grader: 'modle' }]), { minRank1: null });
  assert.ok(r.errors.some((e) => e.startsWith('recall: unknown grader "modle"')), JSON.stringify(r.errors));
});

// Fix round 1: one row parser, owners folded by kind, and gates that never skip (D6).
test('kernelRows takes only the rows rule 6 accepts', () => {
  assert.deepEqual(kernelRows([
    '| Bug \\| crash | Read {KERN}/diagnose/SKILL.md |',
    '| a | b | Read {KERN}/diagnose/SKILL.md |',
    '| More | Read {ROOT}/kernel/routes.md |',
    '| Prose | Read `{KERN}/technical-writing/SKILL.md` |',
    'Then Read {KERN}/recall/SKILL.md first.',
    '| Gap | Read {KERN}/recall/SKILL.md |',
  ].join('\n')), [{ when: 'Gap', route: 'recall' }]);
});

test('only a kernel row folds into the skill it routes to; a distractor named row-<x> does not', () => {
  const root = repo({
    'skills/a/SKILL.md': autoSkill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': cases('a', ['hello kern', 'greeting kern', 'kern hello there'], ['deploy the release to production', 'weather today']),
    'evals/distractors.json': JSON.stringify([{ name: 'row-a', description: 'deploy the release to production servers' }]),
  });
  assert.deepEqual(evaluate(root, { minRank1: null }).errors, []);
});

test('held-out entries name a known owner', () => {
  const held = JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }, { owner: 'ghost', prompt: 'boo' }]);
  const r = evaluate(fixture({ 'evals/heldout.json': held }), { minRank1: null });
  assert.ok(r.errors.includes('heldout: no owner "ghost" for "boo"'), JSON.stringify(r.errors));
});

test('a missing, empty or malformed held-out set is an error once a floor is set', () => {
  const run = (extra) => evaluate(fixture(extra), { minRank1: null, minHeldout: 0 }).errors;
  assert.ok(run({}).includes('evals/heldout.json is missing, so the held-out floor cannot be checked'), JSON.stringify(run({})));
  for (const bad of ['[]', '{}', 'null', JSON.stringify([{ owner: 'recall' }])]) {
    const errors = run({ 'evals/heldout.json': bad });
    assert.ok(errors.some((e) => /^evals\/heldout\.json (must be a non-empty array|entry 0 is not)/.test(e)), `${bad}: ${JSON.stringify(errors)}`);
  }
  assert.ok(run({ 'evals/heldout.json': '[' }).some((e) => e.startsWith('evals/heldout.json: invalid JSON')));
});

test('no case positives under a rank-1 floor is an error', () => {
  const r = evaluate(repo({ 'skills/x/SKILL.md': pathSkill('x') }), { minRank1: 85 });
  assert.ok(r.errors.includes('no case positives to rank, so the rank-1 floor cannot be checked'), JSON.stringify(r.errors));
});

test('the model-graded negatives are pinned: flagging one more means editing this list', () => {
  assert.deepEqual(evaluate(ROOT, { minRank1: null }).modelGraded, [
    { owner: 'prove-it', prompt: 'Explain what fixed and passing mean in this commit message' },
    { owner: 'prove-it', prompt: 'What does a passing PR mean for subagent work' },
  ]);
});

// The CLI against a fixture root: the floors, the baseline and the held-out floor are each enforced, and a missing
// or malformed gate file stops the run with a message.
const HELD = JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }, { owner: 'diagnose', prompt: 'catch me up' }]);
function cli(gates) {
  // One recall positive ranks diagnose first, so the rank-1 rate is 92% (12 of 13).
  // A null entry leaves that file out.
  const files = {
    'evals/cases/recall.json': cases('recall', ['where did I leave off yesterday', 'catch me up on the work', 'resuming after a long gap', 'the failing test with an error after a gap'], ['fix this crash', 'rename a variable']),
    'evals/heldout.json': HELD,
    ...gates,
  };
  const root = fixture(Object.fromEntries(Object.entries(files).filter(([, v]) => v !== null)));
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'route-eval.mjs'), root], { encoding: 'utf8' });
  return { status: r.status, out: r.stdout, err: r.stderr };
}
const gate = (baseline, floors) => ({ 'evals/baseline.json': JSON.stringify({ min_rank1: baseline }), 'evals/floors.json': JSON.stringify(floors) });

test('the CLI enforces the baseline, the fixed rank-1 floor and the held-out floor', () => {
  const ok = cli(gate(0, { rank1: 0, heldout_rank1: 0 }));
  assert.equal(ok.status, 0, ok.out + ok.err);
  assert.match(ok.out, /^rank-1 rate: 92% /m);
  const floor = cli(gate(0, { rank1: 95, heldout_rank1: 0 }));
  assert.equal(floor.status, 1);
  assert.match(floor.out, /^error: rank-1 rate 92% is below the floor 95%$/m);
  const baseline = cli(gate(95, { rank1: 0, heldout_rank1: 0 }));
  assert.equal(baseline.status, 1);
  assert.match(baseline.out, /^error: rank-1 rate 92% is below the floor 95%$/m);
  const held = cli(gate(0, { rank1: 0, heldout_rank1: 60 }));
  assert.equal(held.status, 1);
  assert.match(held.out, /^error: held-out rank-1 rate 50% is below the floor 60%$/m);
});

test('the CLI fails with a message, never a default, when a gate file is missing or malformed', () => {
  const good = gate(0, { rank1: 0, heldout_rank1: 0 });
  const cases = [
    [{ ...good, 'evals/floors.json': null }, 'evals/floors.json is missing'],
    [{ ...good, 'evals/baseline.json': null }, 'evals/baseline.json is missing'],
    [{ ...good, 'evals/floors.json': '{}' }, 'evals/floors.json needs a finite number for rank1 and heldout_rank1'],
    [{ ...good, 'evals/floors.json': 'null' }, 'evals/floors.json needs a finite number for rank1 and heldout_rank1'],
    [{ ...good, 'evals/floors.json': '{ "rank1": null, "heldout_rank1": 32 }' }, 'evals/floors.json needs a finite number for rank1'],
    [{ ...good, 'evals/floors.json': '{ "rank1": "85", "heldout_rank1": 32 }' }, 'evals/floors.json needs a finite number for rank1'],
    [{ ...good, 'evals/baseline.json': '{}' }, 'evals/baseline.json needs a finite number for min_rank1'],
    [{ ...good, 'evals/floors.json': '{' }, 'evals/floors.json: invalid JSON'],
    [{ ...good, 'evals/heldout.json': null }, 'evals/heldout.json is missing, so the held-out floor cannot be checked'],
    [{ ...good, 'evals/heldout.json': '{}' }, 'evals/heldout.json must be a non-empty array of { owner, prompt }'],
  ];
  for (const [files, message] of cases) {
    const r = cli(files);
    assert.equal(r.status, 1, `${message}: ${r.out}${r.err}`);
    assert.ok(r.out.split('\n').some((l) => l.startsWith(`error: ${message}`)), `${message}: ${r.out}`);
    assert.equal(r.err, '', `no stack trace: ${r.err}`);
    assert.match(r.out, /route-eval: FAILED\n$/);
  }
});
