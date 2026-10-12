// tests/route-eval.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildCorpus, rank } from '../scripts/lib/rank.mjs';
import { evaluate } from '../scripts/route-eval.mjs';

const skill = (name, desc) => `---\nname: ${name}\ndescription: ${desc}\n---\n\n## Steps\n\n1. a\n`;
function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-eval-'));
  for (const [p, c] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), typeof c === 'string' ? c : JSON.stringify(c));
  }
  return root;
}
const caseFile = (name, positive, negative) => ({
  skill_name: name,
  trigger: { positive: positive.map((prompt) => ({ prompt, top_k: 3 })), negative: negative.map((prompt) => ({ prompt })) },
  evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
});

test('rank orders by shared vocabulary', () => {
  const c = buildCorpus([{ name: 'tests', text: 'run failing tests suite' }, { name: 'deploy', text: 'deploy release production' }]);
  assert.equal(rank('my tests are failing', c)[0].name, 'tests');
});

test('zero-score prompt is an error, not a crash', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern', 'greeting kern', 'qqq zzz'], ['deploy prod', 'weather today']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 0 },
  });
  const r = evaluate(root, { minRank1: 0 });
  assert.equal(r.errors.length, 1);
  assert.match(r.errors[0], /shares no vocabulary/);
});

test('auto skill without a case file is an error', () => {
  const root = repo({ 'skills/a/SKILL.md': skill('a', 'Use when greeting kern'), 'evals/distractors.json': [], 'evals/baseline.json': { min_rank1: 0 } });
  assert.match(evaluate(root, { minRank1: 0 }).errors[0], /no eval case file/);
});

test('below minimums is an error', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern'], ['deploy prod']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 0 },
  });
  assert.ok(evaluate(root, { minRank1: 0 }).errors.some((e) => /below required minimums/.test(e)));
});

test('a distractor that outranks the skill fails the positive', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello or showing a plan'),
    'evals/cases/a.json': { ...caseFile('a', [], []), trigger: { positive: [{ prompt: 'write a plan for tasks', top_k: 1 }, { prompt: 'hello kern', top_k: 3 }, { prompt: 'greeting kern', top_k: 3 }], negative: [{ prompt: 'deploy prod' }, { prompt: 'weather today' }] } },
    'evals/distractors.json': [{ name: 'writing-plans', description: 'Use when writing a plan for multi-step tasks' }],
    'evals/baseline.json': { min_rank1: 0 },
  });
  const errors = evaluate(root, { minRank1: 0 }).errors;
  assert.ok(errors.some((e) => /positive prompt ranked #2/.test(e)), errors.join('\n'));
});

test('rank-1 rate below the baseline fails', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern', 'greeting kern', 'kern hello there'], ['deploy prod', 'weather today']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 100 },
  });
  assert.deepEqual(evaluate(root, { minRank1: 100 }).errors, []);
  assert.equal(evaluate(root, { minRank1: 101 }).errors.length, 1);
});

const POS = ['hello kern', 'greeting kern', 'kern hello there'];
const NEG = ['deploy prod', 'weather today'];
const two = (da, db, extra = {}) => repo({
  'skills/a/SKILL.md': skill('a', da),
  'skills/b/SKILL.md': skill('b', db),
  'evals/cases/a.json': caseFile('a', POS, NEG),
  'evals/cases/b.json': caseFile('b', POS, NEG),
  'evals/distractors.json': [],
  'evals/baseline.json': { min_rank1: 0 },
  ...extra,
});

test('collision between two auto skills is an error', () => {
  const r = evaluate(two('Use when greeting kern hello', 'Use when greeting kern hello'), { minRank1: 0 });
  assert.ok(r.errors.some((e) => /collision: /.test(e)), r.errors.join('\n'));
});

test('overlap between descriptions is a warning', () => {
  // similarity 0.62: between COLLISION_WARN 0.5 and COLLISION_ERROR 0.75
  const r = evaluate(two('Use when greeting kern hello version', 'Use when greeting kern hello installed'), { minRank1: 0 });
  assert.ok(r.warnings.some((w) => /overlap: /.test(w)), r.warnings.join('\n'));
  assert.ok(!r.errors.some((e) => /collision: /.test(e)), r.errors.join('\n'));
});

const withNegatives = (negative) => repo({
  'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
  'evals/cases/a.json': { ...caseFile('a', POS, []), trigger: { positive: POS.map((prompt) => ({ prompt, top_k: 3 })), negative } },
  'evals/distractors.json': [{ name: 'writing-plans', description: 'Use when writing a plan for multi-step tasks' }],
  'evals/baseline.json': { min_rank1: 0 },
});

test('skill ranked #1 for a negative prompt is an error', () => {
  const r = evaluate(withNegatives([{ prompt: 'greeting kern hello' }, { prompt: 'weather today' }]), { minRank1: 0 });
  assert.ok(r.errors.some((e) => /ranked #1 for negative prompt/.test(e)), r.errors.join('\n'));
});

test('declared owner must outrank the skill', () => {
  const ok = evaluate(withNegatives([{ prompt: 'write a plan for tasks', owner: 'writing-plans' }, { prompt: 'weather today' }]), { minRank1: 0 });
  assert.ok(!ok.errors.some((e) => /owner /.test(e)), ok.errors.join('\n'));
  const bad = evaluate(withNegatives([{ prompt: 'greeting kern hello', owner: 'writing-plans' }, { prompt: 'weather today' }]), { minRank1: 0 });
  assert.ok(bad.errors.some((e) => /owner .* does not outrank it/.test(e)), bad.errors.join('\n'));
});

test('unknown owner is an error', () => {
  const r = evaluate(withNegatives([{ prompt: 'weather today', owner: 'nope' }, { prompt: 'deploy prod' }]), { minRank1: 0 });
  assert.ok(r.errors.some((e) => /unknown owner "nope"/.test(e)), r.errors.join('\n'));
});
