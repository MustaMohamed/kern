// tests/route-eval-rows.test.mjs
import { test } from 'node:test';
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

function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-rows-'));
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
const KERNEL = [
  '| Observable trigger | Route |',
  '|---|---|',
  '| Phase ends, or context is filling | Read {ROOT}/kernel/context.md |',
  '',
  'Then Read {ROOT}/kernel/routes.md. Several matches: define and diagnose before build.',
].join('\n');
const ROUTES = [
  '| Observable trigger | Route |',
  '|---|---|',
  '| Bug, failing test, unexpected output, crash or error | Read {KERN}/diagnose/SKILL.md |',
  '| Starting or resuming after a gap | Read {KERN}/recall/SKILL.md |',
].join('\n');

function fixture(extra = {}) {
  return repo({
    'kernel/kernel.md': KERNEL,
    'kernel/routes.md': ROUTES,
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
  assert.deepEqual(kernelRows(`${KERNEL}\n${ROUTES}`), [
    { when: 'Phase ends, or context is filling', route: 'context' },
    { when: 'Bug, failing test, unexpected output, crash or error', route: 'diagnose' },
    { when: 'Starting or resuming after a gap', route: 'recall' },
  ]);
  assert.deepEqual(kernelRows(''), []);
});

test('targets add the rows of both files after skills and before distractors', () => {
  const root = fixture({ 'evals/distractors.json': JSON.stringify([{ name: 'other', description: 'Something else entirely' }]) });
  assert.deepEqual(targets(root).map((t) => `${t.kind}:${t.name}`), ['skill:recall', 'row:row-context', 'row:row-diagnose', 'row:row-recall', 'distractor:other']);
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
  assert.deepEqual(JSON.parse(readFileSync(join(ROOT, 'evals', 'floors.json'), 'utf8')), { rank1: 85, heldout_rank1: 32 });
  const sha = createHash('sha256').update(readFileSync(join(ROOT, 'evals', 'heldout.json'))).digest('hex');
  assert.equal(sha, '9b5cb8271f50835c162805b42066d90206bd46ffd7b0af280992b3d5af2a54c0', 'evals/heldout.json is frozen: fix routing, never the prompts');
});

// A negative the lexical ranker cannot judge carries "grader": "model"; M2b's model-graded runner checks it.
const withGrader = (negative, positive = ['where did I leave off yesterday', 'catch me up on the work', 'resuming after a long gap']) => fixture({
  'evals/cases/recall.json': JSON.stringify({
    skill_name: 'recall',
    trigger: { positive: positive.map((p) => (typeof p === 'string' ? { prompt: p, top_k: 3 } : p)), negative },
    evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
  }),
  'evals/baseline.json': JSON.stringify({ min_rank1: 0 }),
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
