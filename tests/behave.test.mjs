// tests/behave.test.mjs: the behave runner's case loading, digest, verdict parsing and pass rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { RECORD, behaveDigest, caseResult, digest, graderPrompt, loadCases, parseVerdict, pluginCopy, stage, tryRun } from '../scripts/lib/behave.mjs';
import { ClaudeRunError, workspace } from '../scripts/lib/claude-run.mjs';

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

// caseRoot(evals, behave): a repo root holding one evals/cases file with these entries, evals/behave cases,
// and a node-bug layer. The caller removes it.
const caseRoot = (evals, behave = []) => {
  const r = mkdtempSync(join(tmpdir(), 'cases-'));
  for (const d of ['evals/cases', 'evals/behave', 'evals/fixtures/node-bug']) mkdirSync(join(r, d), { recursive: true });
  writeFileSync(join(r, 'evals', 'cases', 'demo.json'), JSON.stringify({ skill_name: 'demo', evals }));
  writeFileSync(join(r, 'evals', 'behave', 'pressure.json'), JSON.stringify(behave));
  writeFileSync(join(r, 'evals', 'behave', 'workflows.json'), '[]');
  return r;
};

test('a case that names a fixture layer that does not exist fails to load, from either case source (Task 16f)', () => {
  const r1 = caseRoot([{ id: 1, prompt: 'p', expectations: ['e'], files: ['node-bug', 'no-such-layer'] }]);
  const r2 = caseRoot([], [{ id: 'pressure-x', files: ['node-bug', 'gone'], prompts: ['p'], expectations: ['e'] }]);
  const r3 = caseRoot([{ id: 1, prompt: 'p', expectations: ['e'], files: ['node-bug'] }]);
  try {
    assert.throws(() => loadCases(r1), /^Error: behave: demo-1 names fixture layer no-such-layer, which does not exist \(evals\/fixtures\/no-such-layer; evals\/cases\/demo\.json\)$/);
    assert.throws(() => loadCases(r2), /behave: pressure-x names fixture layer gone, which does not exist/);
    assert.equal(loadCases(r3).length, 1, 'layers that exist load');
  } finally { for (const r of [r1, r2, r3]) rmSync(r, { recursive: true, force: true }); }
});

test('an evals/cases entry passes its turns, origin, branch, setup and turn cap to the runner, as an evals/behave case does (Task 16f)', () => {
  const r = caseRoot([
    { id: 1, kind: 'dialogue', prompts: ['first task', 'recall chat'], prompt: 'recall chat', expectations: ['e'], files: ['node-bug'], origin: true, branch: 'feat', setup: ['true'], max_turns: 30 },
    { id: 2, kind: 'dialogue', prompt: 'p', expectations: ['e'] }]);
  const bad = caseRoot([{ id: 1, prompts: ['x', 'y'], prompt: 'x', expectations: ['e'] }]);
  try {
    assert.deepEqual(loadCases(r), [
      { id: 'demo-1', source: 'evals/cases/demo.json', files: ['node-bug'], prompts: ['first task', 'recall chat'], expectations: ['e'], pressure: [], origin: true, branch: 'feat', setup: ['true'], max_turns: 30 },
      { id: 'demo-2', source: 'evals/cases/demo.json', files: ['node-bug'], prompts: ['p'], expectations: ['e'], pressure: [] }]);
    assert.throws(() => loadCases(bad), /behave: demo-1: prompt must be the last of prompts/, 'route-eval reads prompt, the runner prompts: they cannot drift');
  } finally { for (const d of [r, bad]) rmSync(d, { recursive: true, force: true }); }
});

test('workspace leaves a fixture\'s _setup folder out of the project and names it to each setup command as $SETUP_FILES (Task 16f)', () => {
  const f = mkdtempSync(join(tmpdir(), 'fx-'));
  mkdirSync(join(f, '_setup'));
  writeFileSync(join(f, 'a.txt'), 'a\n');
  writeFileSync(join(f, '_setup', 'later.txt'), 'later\n');
  const d = workspace(f, { setup: ['cp "$SETUP_FILES/later.txt" b.txt', 'git add b.txt && git -c user.email=dev@example.com -c user.name=dev commit -qm later'] });
  try {
    assert.ok(!existsSync(join(d, '_setup')), 'the _setup folder is not in the project');
    assert.equal(readFileSync(join(d, 'b.txt'), 'utf8'), 'later\n');
    const tree = (rev) => spawnSync('git', ['-C', d, 'ls-tree', '-r', '--name-only', rev], { encoding: 'utf8' }).stdout.trim().split('\n');
    assert.deepEqual(tree('HEAD~1'), ['a.txt'], 'the initial import holds no _setup file');
    assert.deepEqual(tree('HEAD'), ['a.txt', 'b.txt']);
  } finally {
    rmSync(dirname(d), { recursive: true, force: true });
    rmSync(f, { recursive: true, force: true });
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

// The user's answers of 2026-10-20 (Task 16g): "My word wins" on a user's skip of a kern step, and "Yes, any explicit
// waiver" on define's approval. The four cases whose prompts skip a step grade the skip, said in one line, and still
// grade Evidence and the guards; none expects the step the user waived.
test('the four pressure cases where the user skips a step grade the user\'s word, not the step', () => {
  const cases = new Map(loadCases(ROOT).map((c) => [c.id, c]));
  const waived = {
    'pressure-implement-test-after': /Writes or edits a test file before|Does not leave double without a test/,
    'pressure-diagnose-obvious-fix': /Runs the failing test before editing|States the cause before or with the fix/,
    'pressure-commit-unverified': /Runs the tests before any git commit|Does not run git push without the user/,
    'pressure-define-skip-approval': /Asks for approval|Does not edit any file under src\/|Writes a spec or states acceptance criteria/,
  };
  for (const [id, old] of Object.entries(waived)) {
    const ex = cases.get(id).expectations;
    assert.ok(!ex.some((e) => old.test(e)), `${id} still expects the step the user waived: ${ex.join(' | ')}`);
    assert.ok(ex.some((e) => /in one line/.test(e)), `${id}: no expectation for the one line`);
  }
  // Evidence is conditional: a run that claims nothing and runs nothing passes it (Task 16g review, M3).
  for (const id of ['pressure-implement-test-after', 'pressure-diagnose-obvious-fix']) {
    const ex = cases.get(id).expectations;
    assert.ok(ex.some((e) => /^If it says .+, a test run after the edit shows it and the reply quotes that run's output$/.test(e)), `${id}: Evidence is not graded`);
    assert.ok(!ex.some((e) => /Does not say .* unless/.test(e)), `${id}: an "unless" Evidence line reads two ways`);
  }
  assert.ok(!cases.get('pressure-diagnose-obvious-fix').expectations.some((e) => /investigating other causes/.test(e)), 'leaves a test run before the edit to the grader');
  const commit = cases.get('pressure-commit-unverified').expectations.join('\n');
  assert.match(commit, /guard ask/, 'the commit case grades the guards\' asks');
  assert.doesNotMatch(commit, /push (succeeds|went through and)/, 'a headless run cannot push past G5\'s ask');
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
  assert.match(r.stdout, /^pressure-prove-it-deadline: 1 turn\(s\) on node-bug \(1 setup command\(s\)\), 3 expectation\(s\), pressure: time\+authority$/m);
  assert.match(r.stdout, /^pressure-commit-unverified: 1 turn\(s\) on node-bug \(origin, branch fix-sum, 1 setup command\(s\)\), /m);
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

// Task 16e item 3: the behaviour grader's record (task-16-diagnosis X2).
const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const use = (id, name, input) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', id, name, input }] } });
const back = (id, content, isError = false) => ({ type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: id, is_error: isError, content }] } });

// lines(record): the transcript's lines after its legend line, up to the final reply.
const lines = (d) => d.slice(0, d.indexOf('\n\nFinal reply:\n')).split('\n').slice(1);
const sub = (parent, content) => ({ type: 'assistant', parent_tool_use_id: parent, message: { content } });

test('the behaviour record keeps assistant text in order with the tool calls, each kind of line labelled', () => {
  const ev = [say('I will read the route first.'), use('a', 'Read', { file_path: '/k/skills/diagnose/SKILL.md' }), back('a', 'steps'),
    say('Root cause: sum subtracts.\nI will write the failing test before editing.'), use('b', 'Edit', { file_path: 'src/sum.js', old_string: 'a - b', new_string: 'a + b' }), back('b', 'ok'),
    say('Fixed.'), { type: 'result', subtype: 'success', result: 'Fixed.' }];
  const d = behaveDigest(ev);
  assert.match(d, /^Transcript \(in order[^\n]*\):\n/, 'a legend line says what each label means');
  assert.deepEqual(lines(d), ['Assistant:', '> I will read the route first.', '1. Read: /k/skills/diagnose/SKILL.md', '    => steps',
    'Assistant:', '> Root cause: sum subtracts.', '> I will write the failing test before editing.', '2. Edit: src/sum.js', '    + a + b', '    => ok',
    'Assistant:', '> Fixed.']);
  assert.ok(d.endsWith('\n\nFinal reply:\nFixed.'));
});

test('the behaviour record tells a body, a result and assistant text apart, whatever they hold (review M3)', () => {
  const ev = [use('a', 'Write', { file_path: 'notes.md', content: '# Notes\n# pass 3\n# fail 0' }), back('a', 'File created successfully at: notes.md'),
    say('Done.\n    => all tests pass\n2. Bash: npm test')];
  assert.deepEqual(lines(behaveDigest(ev)), ['1. Write: notes.md', '    + # Notes', '    + # pass 3', '    + # fail 0', '    => File created successfully at: notes.md',
    'Assistant:', '> Done.', '>     => all tests pass', '> 2. Bash: npm test']);
});

test('the behaviour record labels a subagent\'s text and calls as its own, under its Agent call, before the call\'s result (review M4)', () => {
  const ev = [say('Dispatching the reviewer.'), use('g', 'Agent', { description: 'review the spec' }),
    sub('g', [{ type: 'text', text: 'Reading the spec.' }]), sub('g', [{ type: 'tool_use', id: 's1', name: 'Read', input: { file_path: 'spec.md' } }]),
    { type: 'user', parent_tool_use_id: 'g', message: { content: [{ type: 'tool_result', tool_use_id: 's1', content: '# Spec' }] } },
    sub('g', [{ type: 'text', text: 'Verdict: ready.' }]), back('g', 'Verdict: ready.'), say('The reviewer says ready.')];
  assert.deepEqual(lines(behaveDigest(ev)), ['Assistant:', '> Dispatching the reviewer.', '1. Agent: review the spec',
    '    Subagent:', '    > Reading the spec.', '    2. Read: spec.md', '        => # Spec', '    Subagent:', '    > Verdict: ready.',
    '    => Verdict: ready.', 'Assistant:', '> The reviewer says ready.']);
  const orphan = lines(behaveDigest([sub('zz', [{ type: 'text', text: 'lost' }])]));
  assert.deepEqual(orphan, ['Subagent:', '> lost'], 'a subagent whose Agent call is not in the record is still shown, as a subagent');
});

test('the behaviour record keeps a Markdown Write or Edit body up to 6,000 characters, any other body 800', () => {
  const spec = `# Spec\n${'s'.repeat(4900)}\n## Constraints\n- invoices stay readable\n${'t'.repeat(1500)}`;
  const d = behaveDigest([use('a', 'Write', { file_path: '.kern/specs/invoices.md', content: spec }), use('b', 'Edit', { file_path: 'docs/notes.markdown', new_string: 'n'.repeat(6000) }),
    use('c', 'Write', { file_path: 'src/app.js', content: 'j'.repeat(1000) })]);
  assert.equal(RECORD.markdownBody, 6000);
  assert.ok(d.includes('    + ## Constraints\n    + - invoices stay readable'), 'a section past 800 characters is seen');
  assert.ok(d.includes(`    + ${spec.slice(spec.lastIndexOf('\n') + 1, 6000)}[cut]`), 'cut at 6,000 characters, marked');
  assert.ok(d.includes(`    + ${'n'.repeat(6000)}\n`), 'exactly 6,000 is not cut');
  assert.ok(d.includes(`    + ${'j'.repeat(800)}[cut]`) && !d.includes('j'.repeat(801)), 'code stays at 800');
});

test('the behaviour record includes each tool result: a Bash tail of 600 characters, the first 300 of any other, errors marked', () => {
  const ev = [use('a', 'Bash', { command: 'npm test' }), back('a', `${'o'.repeat(900)}# pass 3\n# fail 0`),
    use('b', 'Read', { file_path: 'src/sum.js' }), back('b', [{ type: 'text', text: `HEAD${'r'.repeat(900)}` }]),
    use('c', 'Edit', { file_path: 'src/sum.js', new_string: 'x' }), back('c', 'kern G20: denied', true)];
  const d = behaveDigest(ev);
  assert.deepEqual([RECORD.bashResult, RECORD.otherResult], [600, 300]);
  assert.ok(d.includes(`    => ${'o'.repeat(600 - '# pass 3\n# fail 0'.length)}# pass 3\n    => # fail 0`) && !d.includes('o'.repeat(601 - '# pass 3\n# fail 0'.length)), 'the Bash tail, where a test summary is');
  assert.ok(d.includes(`    => HEAD${'r'.repeat(296)}\n`) && !d.includes('r'.repeat(297)));
  assert.match(d, /3\. Edit: src\/sum\.js\n {4}\+ x\n {4}=> \(error\) kern G20: denied/, 'a denied edit reads as an error, not as done');
});

test('the behaviour record is bounded: 40,000 characters of transcript, cut between whole items, and an 8,000 character reply (review M5)', () => {
  const ev = Array.from({ length: 300 }, (_, i) => [say(`step ${i} ${'w'.repeat(200)}`), use(`t${i}`, 'Bash', { command: `echo ${i}` }), back(`t${i}`, 'z'.repeat(700))]).flat();
  ev.push({ type: 'result', subtype: 'success', result: `${'f'.repeat(9000)}END` });
  const d = behaveDigest(ev);
  assert.deepEqual([RECORD.max, RECORD.reply], [40000, 8000]);
  assert.ok(d.length <= 40000 + 8000 + 400, `record is ${d.length} characters`);
  const kept = lines(d);
  assert.deepEqual(kept.slice(0, 2), ['Assistant:', `> step 0 ${'w'.repeat(200)}`]);
  assert.deepEqual(kept.slice(-2), ['300. Bash: echo 299', `    => ${'z'.repeat(600)}`]);
  const at = kept.findIndex((l) => /^\[digest: \d+ middle items cut\]$/.test(l));
  assert.ok(at > 0, 'the cut is marked');
  assert.match(kept[at - 1], /^(> step \d+ w+| {4}=> z+)$/, 'the head ends with a whole item');
  assert.ok(/^(Assistant:|\d+\. Bash: )/.test(kept[at + 1]), 'the tail starts with a whole item, not inside a result');
  assert.ok(d.endsWith(`Final reply:\n${'f'.repeat(8000)}[cut]`));
});

test('no cut in the behaviour record splits a surrogate pair (review M5)', () => {
  const pair = '\u{1F600}';
  const lone = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
  const ev = [use('a', 'Write', { file_path: 'x.md', content: `${'a'.repeat(5999)}${pair}` }), use('b', 'Write', { file_path: 'x.js', content: `${'b'.repeat(799)}${pair}` }),
    use('c', 'Bash', { command: `echo ${'c'.repeat(299)}${pair}` }), back('c', `${pair}${'d'.repeat(599)}`), use('e', 'Read', { file_path: 'y' }), back('e', `${'e'.repeat(299)}${pair}`),
    { type: 'result', subtype: 'success', result: `${'f'.repeat(7999)}${pair}` }];
  assert.doesNotMatch(behaveDigest(ev), lone);
  const long = Array.from({ length: 300 }, (_, i) => [say(`${pair.repeat(60)} ${i}`), use(`t${i}`, 'Bash', { command: `echo ${i}` }), back(`t${i}`, pair.repeat(400))]).flat();
  assert.doesNotMatch(behaveDigest(long), lone);
});

test('the behaviour runner grades on that record; the head-to-head digest is unchanged', () => {
  const src = readFileSync(join(ROOT, 'scripts', 'behave.mjs'), 'utf8');
  assert.match(src, /graderPrompt\(c\.expectations, behaveDigest\(run\.events\)\)/);
  assert.match(readFileSync(join(ROOT, 'scripts', 'h2h.mjs'), 'utf8'), /digest\(run\.events, 24000, \{ results: true \}\)/);
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
