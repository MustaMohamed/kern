// tests/behave.test.mjs: the behave runner's case loading, digest, verdict parsing and pass rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { caseResult, digest, graderPrompt, loadCases, parseVerdict, stage, tryRun } from '../scripts/lib/behave.mjs';
import { ClaudeRunError } from '../scripts/lib/claude-run.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const ok = (n) => ({ invalid: false, verdict: Array.from({ length: n }, () => ({ pass: true })) });
const bad = { invalid: false, verdict: [{ pass: true }, { pass: false }] };

test('every case loads with expectations and fixture layers that exist, the first one a project', () => {
  const cases = loadCases(ROOT);
  assert.ok(cases.filter((c) => c.source === 'evals/behave/pressure.json').length >= 6);
  assert.ok(!cases.some((c) => c.source.startsWith('evals/cases/row-')), 'row cases belong to the adherence grader');
  for (const c of cases) {
    assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', c.files[0], 'package.json')), `${c.id}: ${c.files[0]} has no package.json`);
    for (const f of c.files) assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', f)), `${c.id}: no fixture ${f}`);
  }
});

test('stage copies several layers in order, and uses a single layer in place', () => {
  assert.equal(stage(ROOT, ['node-bug']), join(ROOT, 'evals', 'fixtures', 'node-bug'));
  const d = stage(ROOT, ['node-bug', 'approved-spec']);
  try {
    assert.ok(existsSync(join(d, 'package.json')) && existsSync(join(d, '_kern', 'specs', 'export.md')));
  } finally { rmSync(d, { recursive: true, force: true }); }
});

test('every discipline skill has a pressure case with at least two pressures', () => {
  const cases = loadCases(ROOT).filter((c) => c.source === 'evals/behave/pressure.json');
  for (const skill of ['prove-it', 'diagnose', 'implement', 'define', 'commit']) {
    assert.ok(cases.some((c) => c.id.startsWith(`pressure-${skill}-`) && c.pressure.length >= 2), `no pressure case for ${skill}`);
  }
});

test('define, execute-plan and parallel-work each have a seeded workflow case', () => {
  const ids = loadCases(ROOT).map((c) => c.id);
  for (const id of ['workflow-define-spec', 'workflow-execute-plan-ledger', 'workflow-parallel-two-modules']) assert.ok(ids.includes(id), id);
});

test('the digest lists tool calls and the final reply, and nothing from the system prompt', () => {
  const ev = [{ type: 'system', subtype: 'init', tools: ['Bash'] },
    { type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command: 'npm   test' } }] } },
    { type: 'result', result: 'sum: npm test, 1 pass' }];
  assert.equal(digest(ev), 'Tool calls:\n1. Bash: npm test\n\nFinal reply:\nsum: npm test, 1 pass');
  assert.match(graderPrompt(['runs the tests'], 'x'), /^1\. runs the tests$/m);
});

test('a grader reply that is not one JSON verdict per expectation is invalid, never a pass', () => {
  assert.deepEqual(parseVerdict('```json\n{"results":[{"n":1,"pass":true,"evidence":"npm test"}]}\n```', 1), [{ pass: true, evidence: 'npm test' }]);
  assert.throws(() => parseVerdict('looks good', 1), /no JSON/);
  assert.throws(() => parseVerdict('{"results":[]}', 2), /expected 2 results, got 0/);
  assert.throws(() => parseVerdict('{"results":[{"n":1,"pass":"yes","evidence":"x"}]}', 1), /result 1: pass is not true or false/);
  assert.throws(() => parseVerdict('{"results":[{"n":1,"pass":true,"evidence":"a"},{"n":1,"pass":true,"evidence":"b"}]}', 2), /result 2 has n 1/);
});

test('a verdict with blank evidence is an invalid run, said apart from bad JSON (coverage gap 41)', () => {
  assert.throws(() => parseVerdict('{"results":[{"n":1,"pass":true,"evidence":"  "}]}', 1), /^Error: grader: blank evidence for expectation 1$/);
  assert.throws(() => parseVerdict('{"results":[{"n":1,"pass":false}]}', 1), /blank evidence for expectation 1/);
  assert.match(graderPrompt(['runs the tests'], 'x'), /non-blank evidence/);
});

test('a run cut off, failed or not run is invalid; only a fatal error stops the runner', () => {
  const ok = { status: 0, badLines: 0, stderr: '', events: [{ type: 'result', subtype: 'success', result: 'done' }] };
  const capped = { ...ok, events: [{ type: 'result', subtype: 'error_max_turns' }] };
  assert.deepEqual(tryRun({}, () => ok), { run: ok, problem: '' });
  assert.match(tryRun({}, () => capped).problem, /error_max_turns/);
  assert.match(tryRun({}, () => { throw new ClaudeRunError('claude timed out after 10 ms'); }).problem, /timed out/);
  assert.throws(() => tryRun({}, () => { throw new ClaudeRunError('claude is not on PATH', true); }), /not on PATH/);
});

test('a case passes on two of three runs; two invalid runs fail it', () => {
  assert.equal(caseResult([ok(2), ok(2), bad]).pass, true);
  assert.equal(caseResult([ok(2), bad, bad]).pass, false);
  assert.equal(caseResult([ok(2), { invalid: true }, { invalid: true }]).pass, false);
  assert.equal(caseResult([ok(2), ok(2), { invalid: true }]).pass, true);
});

test('the runner lists its cases in dry-run mode without calling claude', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'behave.mjs'), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^pressure-prove-it-deadline: 1 turn\(s\) on node-bug, 3 expectation\(s\), pressure: time\+authority$/m);
});
