// tests/behave.test.mjs: the behave runner's case loading, digest, verdict parsing and pass rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { caseResult, digest, graderPrompt, loadCases, parseVerdict, pluginCopy, stage, tryRun } from '../scripts/lib/behave.mjs';
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
  for (const id of ['workflow-define-spec', 'workflow-define-fast-path', 'workflow-define-fast-path-stored-data', 'workflow-execute-plan-ledger', 'workflow-parallel-two-modules']) assert.ok(ids.includes(id), id);
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
  const one = { prompts: ['fix it'] };
  assert.deepEqual(tryRun(one, () => ok), { run: ok, problem: '' });
  assert.match(tryRun(one, () => capped).problem, /error_max_turns/);
  assert.match(tryRun(one, () => { throw new ClaudeRunError('claude timed out after 10 ms'); }).problem, /timed out/);
  assert.throws(() => tryRun(one, () => { throw new ClaudeRunError('claude is not on PATH', true); }), /not on PATH/);
});

test('a run whose result count differs from its prompt count is invalid, with the reason (Task 16e)', () => {
  const ok = { status: 0, badLines: 0, stderr: '', events: [{ type: 'result', subtype: 'success', result: 'done' }] };
  // Two prompts run as one turn, as on Claude Code 2.1.304 before runClaude waited for each result.
  assert.deepEqual(tryRun({ prompts: ['first task', 'second task'] }, () => ok), { run: ok, problem: '2 prompts but 1 result event: each prompt must run as its own turn' });
  const twice = { ...ok, events: [...ok.events, ...ok.events] };
  assert.equal(tryRun({ prompts: ['first task', 'second task'] }, () => twice).problem, '');
  assert.throws(() => tryRun({}, () => ok), /needs the number of prompts sent/, 'a stub run still states its prompts');
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

const call = (name, input) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name, input }] } });

test('the digest shows what a Write or Edit wrote, cut at 800 characters', () => {
  const d = digest([call('Write', { file_path: '.kern/specs/x.md', content: 'status: draft' }), call('Edit', { file_path: 'a.js', new_string: 'x'.repeat(2000) })]);
  assert.match(d, /1\. Write: \.kern\/specs\/x\.md\n {4}status: draft\n2\. Edit: a\.js\n {4}x{800}\[cut\]\n/);
  assert.ok(!d.includes('x'.repeat(801)));
});

test('a long digest cuts the tool calls, never the final reply', () => {
  const ev = Array.from({ length: 400 }, (_, i) => call('Bash', { command: `echo ${i} ${'y'.repeat(250)}` }));
  ev.push({ type: 'result', result: 'the end: all done' });
  const d = digest(ev, 24000);
  assert.ok(d.length <= 24000 + 'Final reply:\nthe end: all done'.length + 40);
  assert.ok(d.endsWith('Final reply:\nthe end: all done'));
  assert.match(d, /\[digest truncated\]/);
});

test('with results on, a long digest keeps its first and last calls and cuts the middle', () => {
  const ev = Array.from({ length: 400 }, (_, i) => call('Bash', { command: `echo ${i} ${'y'.repeat(250)}` }));
  ev.push({ type: 'result', result: 'the end: all done' });
  const d = digest(ev, 24000, { results: true });
  assert.ok(d.length <= 24000 + 'Final reply:\nthe end: all done'.length + 60);
  assert.match(d, /\n1\. Bash: echo 0 /);
  assert.match(d, /\n400\. Bash: echo 399 /);
  assert.match(d, /\[digest: middle calls cut\]/);
  assert.ok(d.endsWith('Final reply:\nthe end: all done'));
});

test('the digest shows tool results only when asked: a Bash tail with the error flag, the head of any other', () => {
  const ev = [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id: 'a', name: 'Bash', input: { command: 'npm test' } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 'a', is_error: true, content: `${'o'.repeat(900)}FAILTAIL` }] } },
    { type: 'assistant', message: { content: [{ type: 'tool_use', id: 'b', name: 'Read', input: { file_path: 'x.js' } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 'b', content: [{ type: 'text', text: `HEADTEXT${'r'.repeat(900)}` }] }] } },
    { type: 'result', result: 'done' }];
  const off = digest(ev);
  assert.equal(off, 'Tool calls:\n1. Bash: npm test\n2. Read: x.js\n\nFinal reply:\ndone');
  assert.equal(digest(ev, 24000, {}), off);
  const on = digest(ev, 24000, { results: true });
  assert.match(on, /1\. Bash: npm test\n {4}\(error\) o+FAILTAIL\n2\. Read: x\.js\n {4}HEADTEXTr+\n/);
  assert.ok(on.includes(`${'o'.repeat(592)}FAILTAIL`) && !on.includes('o'.repeat(593)));
  assert.ok(on.includes(`HEADTEXT${'r'.repeat(292)}`) && !on.includes('r'.repeat(293)));
});

test('the plugin copy keeps the plugin and leaves out answer keys', () => {
  const d = pluginCopy(ROOT);
  try {
    for (const p of ['skills', 'kernel', 'hooks', 'scripts', '.claude-plugin/plugin.json']) assert.ok(existsSync(join(d, p)), p);
    for (const p of ['evals', 'tests', 'docs', '.git']) assert.ok(!existsSync(join(d, p)), p);
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
});

test('the plugin copy leaves out the eval runners and keeps the plugin scripts', () => {
  const d = pluginCopy(ROOT);
  try {
    for (const p of ['scripts/h2h.mjs', 'scripts/behave.mjs', 'scripts/lib/behave.mjs', 'scripts/lib/claude-run.mjs', 'scripts/lib/claude-drive.mjs', 'scripts/kernel-adherence.mjs', 'scripts/lib/adherence.mjs', '.superpowers']) assert.ok(!existsSync(join(d, p)), p);
    for (const p of ['scripts/plan-check', 'scripts/kern-get']) assert.ok(existsSync(join(d, p)), p);
  } finally { rmSync(dirname(d), { recursive: true, force: true }); }
});
