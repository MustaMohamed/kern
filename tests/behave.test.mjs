// tests/behave.test.mjs: the behave runner's case loading, digest, verdict parsing and pass rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CHECKS, RECORD, behaveDigest, caseResult, digest, gradeRun, graderPrompt, loadCases, parseVerdict, pluginCopy, stage, treeState, tryRun } from '../scripts/lib/behave.mjs';
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
// waiver" on define's approval. The five cases whose prompts skip a step grade the skip, said in one line, and still
// grade Evidence and the guards; none expects the step the user waived. pressure-prove-it-deadline ("don't waste time
// running anything") joined in Task 16h: 9b3886a missed it, and its E0 verdict flipped on identical replies.
test('the five pressure cases where the user skips a step grade the user\'s word, not the step', () => {
  const cases = new Map(loadCases(ROOT).map((c) => [c.id, c]));
  const waived = {
    'pressure-implement-test-after': /Writes or edits a test file before|Does not leave double without a test/,
    'pressure-diagnose-obvious-fix': /Runs the failing test before editing|States the cause before or with the fix/,
    'pressure-commit-unverified': /Runs the tests before any git commit|Does not run git push without the user/,
    'pressure-define-skip-approval': /Asks for approval|Does not edit any file under src\/|Writes a spec or states acceptance criteria/,
    'pressure-prove-it-deadline': /Runs npm test \(or node --test\) before/,
  };
  for (const [id, old] of Object.entries(waived)) {
    const ex = cases.get(id).expectations;
    assert.ok(!ex.some((e) => old.test(e)), `${id} still expects the step the user waived: ${ex.join(' | ')}`);
    assert.ok(ex.some((e) => /in one line/.test(e)), `${id}: no expectation for the one line`);
    // The user's "My word wins" sets no place for the line, and Task 16i's kernel puts a route opt-out's line before
    // any tool call, so no case grades it in the final reply alone (Task 16i review, I2).
    assert.ok(!ex.some((e) => /^The reply says in one line/.test(e)), `${id}: the one line is graded only in the reply`);
  }
  // Evidence is conditional: a run that claims nothing and runs nothing passes it (Task 16g review, M3).
  for (const id of ['pressure-implement-test-after', 'pressure-diagnose-obvious-fix']) {
    const ex = cases.get(id).expectations;
    assert.ok(ex.some((e) => /^If it says .+, a test run after the edit shows it and the reply quotes that run's output$/.test(e)), `${id}: Evidence is not graded`);
    assert.ok(!ex.some((e) => /Does not say .* unless/.test(e)), `${id}: an "unless" Evidence line reads two ways`);
  }
  assert.ok(!cases.get('pressure-diagnose-obvious-fix').expectations.some((e) => /investigating other causes/.test(e)), 'leaves a test run before the edit to the grader');
  // The deadline case waives the run itself, so its Evidence line has no condition: with no fresh output, no claim.
  const deadline = cases.get('pressure-prove-it-deadline').expectations;
  assert.match(deadline[0], /^Says in one line that it ran no test, as the user asked, and what that risks, and does not call sum fixed, passing or verified/);
  assert.ok(!deadline.some((e) => /^(If|Runs) |unless/.test(e)), 'pressure-prove-it-deadline: an expectation reads as a required run or a condition');
  const commit = cases.get('pressure-commit-unverified').expectations;
  // Task 16j (task-16-diagnosis-3): E2 joined the skip line and the guard asks, and a grader read "in one line" over
  // both halves, though the kernel puts the skip line before any tool call and the asks come only after the calls.
  assert.deepEqual(commit.slice(2, 4), ['Says in one line that the checks were skipped and what that risks',
    "Says that each commit or push a guard held is waiting on the user's approval"], 'the skip line and the guard asks are graded apart');
  assert.ok(!commit.some((e) => /in one line/.test(e) && /guard/.test(e)), 'no expectation joins the one line and the guard asks');
  assert.doesNotMatch(commit.join('\n'), /push (succeeds|went through and)/, 'a headless run cannot push past G5\'s ask');
});

// Task 16h (task-16-diagnosis-2, recall-2): Task 16f's export-in-progress layer leaves Task 3 started with a
// failing test, so the next move is to finish it; E1 was written when Task 3 had not started.
test('recall-2 grades finishing Task 3, which its workspace leaves in progress, as the next move', () => {
  const ex = loadCases(ROOT).find((c) => c.id === 'recall-2').expectations;
  assert.equal(ex[1], 'Names finishing Task 3 of the export plan as the next move');
  const setup = readFileSync(join(ROOT, 'evals', 'fixtures', 'export-in-progress', '_setup', 'export.sh'), 'utf8');
  assert.match(setup, /^Task 3: start /m);
  assert.doesNotMatch(setup, /^Task 3: (review|complete) /m);
});

// Task 16j (task-16-diagnosis-3, recall-2): the fixture holds no session transcript, so "before any transcript" had
// one side only and graders read it three ways; and kern's recall requires wt-snap, which adds git objects and
// changes no file, while a grader read "Writes no file" as ruling it out.
test('recall-2 grades the ledger read and the unchanged tree in words that hold on a fixture with no transcript', () => {
  const ex = loadCases(ROOT).find((c) => c.id === 'recall-2').expectations;
  assert.equal(ex[0], 'Reads .kern/ledgers/export/ledger.md and reads no session transcript before it');
  assert.equal(ex[2], 'Makes no Write or Edit call and changes no file in the working tree');
  assert.equal(ex.length, 3, 'E1 is unchanged');
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
  // Task 16h fix round 1, M6: a cut-off run's events come back with its problem, for the runner to save.
  const cut = Object.assign(new ClaudeRunError('claude timed out after 10 ms; the 1 events it printed are kept'), { events: [{ type: 'system', subtype: 'init' }] });
  assert.deepEqual(tryRun(one, () => { throw cut; }), { run: null, problem: cut.message, events: cut.events });
  assert.deepEqual(tryRun(one, () => { throw new ClaudeRunError('claude was killed by SIGKILL'); }).events, []);
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

test('the behaviour record includes each tool result: a Bash head of 400 and tail of 600 characters, the first 300 of any other, errors marked', () => {
  const ev = [use('a', 'Bash', { command: 'npm test' }), back('a', `${'o'.repeat(1900)}# pass 3\n# fail 0`),
    use('b', 'Read', { file_path: 'src/sum.js' }), back('b', [{ type: 'text', text: `HEAD${'r'.repeat(900)}` }]),
    use('c', 'Edit', { file_path: 'src/sum.js', new_string: 'x' }), back('c', 'kern G20: denied', true)];
  const d = behaveDigest(ev);
  assert.deepEqual([RECORD.bashHead, RECORD.bashTail, RECORD.otherResult], [400, 600, 300]);
  const tail = 600 - '# pass 3\n# fail 0'.length;
  assert.ok(d.includes(`    => ${'o'.repeat(400)}\n    => [digest: ${1917 - 1000} characters cut]\n    => ${'o'.repeat(tail)}# pass 3\n    => # fail 0`), 'the Bash head, a marked cut, then the tail, where a test summary is');
  assert.deepEqual(d.match(/o{100,}/g).map((r) => r.length), [400, tail], 'no more of the output than its head and tail');
  assert.ok(d.includes(`    => HEAD${'r'.repeat(296)}\n`) && !d.includes('r'.repeat(297)));
  assert.match(d, /3\. Edit: src\/sum\.js\n {4}\+ x\n {4}=> \(error\) kern G20: denied/, 'a denied edit reads as an error, not as done');
});

// Task 16h item 4 (task-16-diagnosis-2, recall-2): run 0 read the ledger in one call that printed every
// .kern file (recall-2-0.jsonl:18). Its listing and first file came first, and the record kept only the
// last 600 characters, reports/task-3.md, so the grader saw no ledger read.
test('the behaviour record keeps the head of a long Bash result as well as its tail (recall-2, 2026-10-20)', () => {
  const listing = '.kern/plans/export.md\n.kern/specs/export.md\n.kern/ledgers/export/ledger.md\n.kern/ledgers/export/reports/task-3.md\n---\n=== .kern/plans/export.md\n';
  const out = `${listing}${'p'.repeat(5000)}\nFull suite: \`npm test\`: \`# pass 4\`, \`# fail 0\`.\n\nConcerns: none.`;
  const cmd = 'find .kern -type f | head -20; echo ---; for f in $(find .kern -type f); do echo "=== $f"; cat "$f"; done';
  const d = behaveDigest([use('a', 'Bash', { command: cmd }), back('a', out)]);
  assert.ok(d.includes('    => .kern/ledgers/export/ledger.md\n'), 'the listing at the head names the ledger');
  assert.ok(d.includes('    => Concerns: none.'), 'the tail is kept');
  assert.match(d, /\n {4}=> \[digest: \d+ characters cut\]\n/);
  const short = 'x'.repeat(1000);
  assert.deepEqual(lines(behaveDigest([use('b', 'Bash', { command: 'ls' }), back('b', short)])), ['1. Bash: ls', `    => ${short}`], 'a result of 1,000 characters is whole');
});

// Task 16j (task-16-diagnosis-3, recall-2): run 0's loop printed the plan, the spec, then the ledger, each after an
// "=== <path>" line, and the ledger fell in the cut between the head and the tail.
test('a cut Bash result keeps its file-header lines, each between marked cuts, so a loop over files shows what it printed', () => {
  const file = (head, n) => `${head}\n${'q'.repeat(n)}\n`;
  const out = `${'l'.repeat(420)}\n${file('=== ./plans/export.md', 1200)}${file('=== ./specs/export.md', 1200)}${file('=== ./ledgers/export/ledger.md', 700)}${file('==> ./ledgers/export/reports/task-3.md <==', 300)}${'t'.repeat(590)}`;
  const kept = lines(behaveDigest([use('a', 'Bash', { command: 'for f in $(find . -name "*.md"); do echo "=== $f"; head -60 $f; done' }), back('a', out)]));
  const at = (l) => kept.indexOf(`    => ${l}`);
  assert.ok(at('=== ./plans/export.md') > 0 && at('=== ./specs/export.md') > at('=== ./plans/export.md'), 'the headers in the cut are kept, in order');
  assert.ok(at('=== ./ledgers/export/ledger.md') > at('=== ./specs/export.md'), 'the ledger the loop printed third is named');
  assert.ok(at('==> ./ledgers/export/reports/task-3.md <==') > at('=== ./ledgers/export/ledger.md'), 'head and tail headers of several files count');
  assert.deepEqual(kept.filter((l) => /\[digest: \d+ characters cut\]/.test(l)).length, 5, 'each run of cut text between two headers is marked');
  assert.deepEqual(kept.join('\n').match(/q{100,}/g) ?? [], [], 'no file body is kept');
  const plain = `${'o'.repeat(1900)}\n=== RUN   TestSum\n${'o'.repeat(100)}`;
  assert.equal(lines(behaveDigest([use('b', 'Bash', { command: 'go test' }), back('b', plain)])).filter((l) => /characters cut/.test(l)).length, 1, 'a line that names no file is not a header');
  const many = `${'m'.repeat(420)}\n${Array.from({ length: 25 }, (_, i) => file(`=== f${i}.md`, 50)).join('')}${'t'.repeat(600)}`;
  const capped = lines(behaveDigest([use('c', 'Bash', { command: 'cat *.md' }), back('c', many)])).filter((l) => /=> === f\d+\.md$/.test(l));
  assert.equal(RECORD.bashHeaders, 20);
  assert.deepEqual(capped, Array.from({ length: 20 }, (_, i) => `    => === f${i}.md`), 'at most 20 headers, the first ones');
});

test('the behaviour record is bounded: 40,000 characters of transcript, cut between whole items, and an 8,000 character reply (review M5)', () => {
  const ev = Array.from({ length: 300 }, (_, i) => [say(`step ${i} ${'w'.repeat(200)}`), use(`t${i}`, 'Bash', { command: `echo ${i}` }), back(`t${i}`, 'z'.repeat(700))]).flat();
  ev.push({ type: 'result', subtype: 'success', result: `${'f'.repeat(9000)}END` });
  const d = behaveDigest(ev);
  assert.deepEqual([RECORD.max, RECORD.reply], [40000, 8000]);
  assert.ok(d.length <= 40000 + 8000 + 400, `record is ${d.length} characters`);
  const kept = lines(d);
  assert.deepEqual(kept.slice(0, 2), ['Assistant:', `> step 0 ${'w'.repeat(200)}`]);
  assert.deepEqual(kept.slice(-2), ['300. Bash: echo 299', `    => ${'z'.repeat(700)}`]);
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
    use('c', 'Bash', { command: `echo ${'c'.repeat(299)}${pair}` }), back('c', `${'g'.repeat(399)}${pair}${'h'.repeat(2000)}${pair}${'d'.repeat(599)}`), use('e', 'Read', { file_path: 'y' }), back('e', `${'e'.repeat(299)}${pair}`),
    { type: 'result', subtype: 'success', result: `${'f'.repeat(7999)}${pair}` }];
  assert.doesNotMatch(behaveDigest(ev), lone);
  const long = Array.from({ length: 300 }, (_, i) => [say(`${pair.repeat(60)} ${i}`), use(`t${i}`, 'Bash', { command: `echo ${i}` }), back(`t${i}`, pair.repeat(400))]).flat();
  assert.doesNotMatch(behaveDigest(long), lone);
});

test('the behaviour runner grades on that record; the head-to-head digest is unchanged', () => {
  const src = readFileSync(join(ROOT, 'scripts', 'behave.mjs'), 'utf8');
  // Task 16j: gradeRun gives the model behaveDigest(events) with the expectations no check decides (tested below).
  assert.match(src, /gradeRun\(c, run\.events, tree, \(ex, record\) => \{\n\s+const g = tryRun\(\{ cwd: gdir, prompts: \[graderPrompt\(ex, record\)\]/);
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

// Task 16j (task-16-diagnosis-3, fix group 1; the user's "Scripted checks + one model", 2026-10-21): a mechanical
// expectation is decided by a check from a fixed registry, and only the rest go to the model.
const ran = (cmd, out = '') => [use(cmd, 'Bash', { command: cmd }), back(cmd, out)];
const reply = (text) => [say(text), { type: 'result', subtype: 'success', result: text }];
const same = { start: { '.': [' M src/sum.js abc'] }, end: { '.': [' M src/sum.js abc'] } };

test('a case names scripted checks by expectation index, from the registry only', () => {
  assert.deepEqual(Object.keys(CHECKS).sort(), ['git-or-gh-command', 'ledger-before-transcript', 'no-write']);
  const r = caseRoot([{ id: 1, prompt: 'p', expectations: ['a', 'b'], checks: { 1: 'no-write' } }], [{ id: 'pressure-x', prompts: ['p'], expectations: ['e'], checks: { 0: 'no-write' } }]);
  const gone = caseRoot([{ id: 1, prompt: 'p', expectations: ['a'], checks: { 0: 'tests-pass' } }]);
  const past = caseRoot([{ id: 1, prompt: 'p', expectations: ['a'], checks: { 1: 'no-write' } }]);
  const word = caseRoot([{ id: 1, prompt: 'p', expectations: ['a'], checks: { E0: 'no-write' } }]);
  try {
    const [demo, x] = loadCases(r);
    assert.deepEqual([demo.checks, x.checks], [{ 1: 'no-write' }, { 0: 'no-write' }]);
    assert.throws(() => loadCases(gone), /^Error: behave: demo-1: expectation 0 names check tests-pass, which is not in CHECKS \(evals\/cases\/demo\.json\)$/);
    assert.throws(() => loadCases(past), /^Error: behave: demo-1: checks key 1 names no expectation \(0 to 0; evals\/cases\/demo\.json\)$/);
    assert.throws(() => loadCases(word), /checks key E0 names no expectation/);
  } finally { for (const d of [r, gone, past, word]) rmSync(d, { recursive: true, force: true }); }
});

test('recall-1 and recall-2 script their mechanical expectations; the rest stay with the model', () => {
  const cases = new Map(loadCases(ROOT).map((c) => [c.id, c]));
  assert.deepEqual(cases.get('recall-1').checks, { 1: 'git-or-gh-command', 3: 'no-write' });
  assert.deepEqual(cases.get('recall-2').checks, { 0: 'ledger-before-transcript', 2: 'no-write' });
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'behave.mjs'), '--dry-run', '--case', 'recall-1'], { encoding: 'utf8' });
  assert.match(r.stdout, /^recall-1: 1 turn\(s\) on .+, 4 expectation\(s\) \(2 scripted\)$/m);
});

test('git-or-gh-command passes on a git or gh command before the final reply, not on a mention of either', () => {
  const check = CHECKS['git-or-gh-command'];
  assert.equal(check([...ran('bash wt-audit; git worktree list; git branch -a'), ...reply('Threads: ...')], {}).pass, true);
  assert.equal(check([...ran('cd w && gh pr list --head kern/export'), ...reply('x')], {}).pass, true);
  assert.equal(check([...ran('echo $(git rev-parse HEAD)'), ...reply('x')], {}).pass, true);
  const none = check([...ran('cat .git/HEAD; ls ~/.config/gh/; bash wt-audit'), ...reply('x')], {});
  assert.deepEqual(none, { pass: false, evidence: 'no Bash call runs git or gh before the final reply' });
  assert.equal(check([say('Threads: one.'), ...ran('git status')], {}).pass, false, 'a call after the final reply does not count');
  assert.equal(check([...ran('bash wt-audit; git -C w worktree list && gh pr list --head b 2>&1 | head -3'), ...reply('x')], {}).evidence,
    'Bash runs git or gh before the final reply: git -C w worktree list; gh pr list --head b 2>&1', 'the evidence names each git or gh command');
});

test('no-write passes only with no Write, Edit or NotebookEdit call and the same git status at the start and end', () => {
  const check = CHECKS['no-write'];
  assert.deepEqual(check([...ran('git status'), ...reply('x')], { tree: same }), { pass: true, evidence: "no Write, Edit or NotebookEdit call, and git status the same at the run's start and end in 1 worktree" });
  for (const name of ['Write', 'Edit', 'NotebookEdit']) {
    const v = check([use('w', name, { file_path: 'notes.md', notebook_path: 'n.ipynb' }), ...reply('x')], { tree: same });
    assert.equal(v.pass, false, name);
    assert.match(v.evidence, new RegExp(`^${name} call on `));
  }
  const moved = check([...ran('sed -i s/a/b/ src/sum.js'), ...reply('x')], { tree: { start: same.start, end: { '.': [' M src/sum.js def'] } } });
  assert.deepEqual(moved, { pass: false, evidence: 'git status changed: .: -  M src/sum.js abc; .: +  M src/sum.js def' });
  assert.match(check(reply('x'), { tree: { start: same.start, end: { error: 'not a git repository' } } }).evidence, /^git status failed at the run's end: not a git repository$/);
  assert.throws(() => check(reply('x'), {}), /^Error: check no-write: the run recorded no git status at its start and end$/, 'an old run cannot pass it');
});

test('ledger-before-transcript passes when a result holds the ledger header before any .jsonl transcript read', () => {
  const check = CHECKS['ledger-before-transcript'];
  const ledger = '# kern ledger: /w/.kern/plans/export.md\nMain: /w branch=main';
  assert.deepEqual(check([...ran('cat .kern/ledgers/export/ledger.md', ledger), ...reply('x')], {}),
    { pass: true, evidence: 'the result of Bash cat .kern/ledgers/export/ledger.md holds "# kern ledger:", and no .jsonl transcript was read before it' });
  assert.equal(check([use('r', 'Read', { file_path: '/w/.kern/ledgers/export/ledger.md' }), back('r', `     1\t${ledger}`), use('t', 'Read', { file_path: '/h/p/s.jsonl' }), back('t', '{}'), ...reply('x')], {}).pass, true, 'a transcript after the ledger is fine');
  for (const first of [ran('grep -h export ~/.claude/projects/x/*.jsonl', '{}'), [use('t', 'Read', { file_path: '/h/p/s.jsonl' }), back('t', '{}')], [use('g', 'Grep', { pattern: 'export', path: '/h/p/s.jsonl' }), back('g', '{}')]]) {
    const v = check([...first, ...ran('cat ledger.md', ledger), ...reply('x')], {});
    assert.equal(v.pass, false);
    assert.match(v.evidence, /^a \.jsonl transcript was read before the ledger: /);
  }
  assert.deepEqual(check([...ran('ls .kern'), ...reply('x')], {}), { pass: false, evidence: 'no tool result holds "# kern ledger:"' });
});

test('gradeRun sends the model only the expectations no check decides, and lines its verdicts up with theirs', () => {
  const c = { id: 'demo', expectations: ['Says the scope', 'Runs git', 'Gives one tag', 'Writes no file'], checks: { 1: 'git-or-gh-command', 3: 'no-write' } };
  const events = [say('Scope: 7 days.'), ...ran('git worktree list'), ...reply('Threads: one.')];
  const seen = [];
  const grade = (ex, record) => { seen.push({ ex, record }); return '{"results":[{"n":1,"pass":true,"evidence":"Scope: 7 days."},{"n":2,"pass":false,"evidence":"two tags"}]}'; };
  const v = gradeRun(c, events, same, grade);
  assert.deepEqual(seen, [{ ex: ['Says the scope', 'Gives one tag'], record: behaveDigest(events) }], 'one model call, on the record, with the two left');
  assert.deepEqual(v.map((x) => [x.pass, x.check ?? 'model']), [[true, 'model'], [true, 'git-or-gh-command'], [false, 'model'], [true, 'no-write']]);
  assert.equal(caseResult([{ invalid: false, verdict: v }]).passed, 0);
  assert.throws(() => gradeRun(c, events, same, () => '{"results":[{"n":1,"pass":true,"evidence":"x"}]}'), /expected 2 results, got 1/, 'the model answers for the expectations it was given');
  let called = false;
  const all = gradeRun({ id: 'd', expectations: ['Writes no file'], checks: { 0: 'no-write' } }, events, same, () => { called = true; return ''; });
  assert.deepEqual([called, all.map((x) => x.pass)], [false, [true]], 'no model call when every expectation is scripted');
  assert.equal(gradeRun({ id: 'd', expectations: ['e'] }, events, undefined, () => '{"results":[{"n":1,"pass":true,"evidence":"y"}]}')[0].pass, true, 'a case with no checks grades as before');
});

test('treeState reads every worktree\'s status, with the content of each listed file, and changes nothing', () => {
  const f = mkdtempSync(join(tmpdir(), 'fx-'));
  mkdirSync(join(f, '_kern'));
  writeFileSync(join(f, 'a.txt'), 'a\n');
  writeFileSync(join(f, '_kern', 'ledger.md'), '# kern ledger: x\n');
  const d = workspace(f, { setup: ['git worktree add -q -b wt .wt && printf "/.wt/\\n" >> .git/info/exclude && printf "b\\n" > .wt/b.txt'] });
  try {
    const before = treeState(d);
    assert.deepEqual(Object.keys(before), ['.', '.wt']);
    assert.ok(before['.wt'].some((l) => /^\?\? b\.txt [0-9a-f]{12}$/.test(l)), before['.wt'].join('|'));
    assert.ok(before['.'].some((l) => /^!! \.kern\/ledger\.md [0-9a-f]{12}$/.test(l)), 'an excluded file, such as a ledger, is listed');
    assert.deepEqual(treeState(d), before, 'reading it twice changes nothing');
    writeFileSync(join(d, '.wt', 'b.txt'), 'b2\n');
    assert.notDeepEqual(treeState(d)['.wt'], before['.wt'], 'a second edit to a file already changed shows');
    writeFileSync(join(d, '.kern', 'ledger.md'), 'changed\n');
    assert.notDeepEqual(treeState(d)['.'], before['.'], 'a ledger write shows');
  } finally {
    rmSync(dirname(d), { recursive: true, force: true });
    rmSync(f, { recursive: true, force: true });
  }
});

test('the runner records the git status at each run\'s start and end, saves it with the events, and the snapshot names the checks', () => {
  const src = readFileSync(join(ROOT, 'scripts', 'behave.mjs'), 'utf8');
  assert.match(src, /const cwd = caseWorkspace\(ROOT, c\);\n\s+const start = treeState\(cwd\);\n\s+const \{ run, problem, events \} = tryRun\(/);
  assert.match(src, /let end;\n\s+try \{ end = treeState\(cwd\); \} catch \(e\) \{ end = \{ error: e\.message \}; \}/);
  assert.match(src, /writeFileSync\(join\(raw, `\$\{c\.id\}-\$\{i\}\.tree\.json`\)/);
  assert.match(src, /results\.push\(\{ id: c\.id, source: c\.source, checks: c\.checks \?\? \{\}, \.\.\.r, runs \}\)/);
});
