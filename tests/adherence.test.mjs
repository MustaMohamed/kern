// tests/adherence.test.mjs: the adherence grader on recorded runs, and the runner's dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readSteps, grade, inlineRows, rowPrompt, runFailure } from '../scripts/lib/adherence.mjs';
import { kernelRows, parseRow, routeText } from '../scripts/lib/kernel-rows.mjs';
import { loadModel } from '../scripts/lib/lint-rules.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const K = '/opt/kern';
const MD = '# x\n\n## Steps\n\n0. Defer: if the kern settings block names an override.\n1. Stop the line and save the symptom.\n2. Build a loop.\n\n## Inputs\n\n1. not a step\n';
const steps = readSteps(MD);
const ev = (...uses) => uses.map(([name, input]) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name, input }] } }));
const todos = (...items) => ['TodoWrite', { todos: items.map((content) => ({ content, status: 'pending' })) }];
const route = `${K}/skills/diagnose/SKILL.md`;

test('readSteps returns only the numbered Steps lines', () => {
  assert.deepEqual(steps, ['Defer: if the kern settings block names an override.', 'Stop the line and save the symptom.', 'Build a loop.']);
});

test('one hop: the route is the first tool call, and the todos copy the steps', () => {
  const g = grade(ev(['Read', { file_path: route }], todos(steps[0], 'skip: the user gave the symptom', '2. Build a loop.'), ['Edit', { file_path: '/p/a.js' }]), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.hops, 1);
});

test('two hops: routes.md first, then the route', () => {
  const g = grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.hops, 2);
});

test('any other tool before the route fails, edits or not', () => {
  const g = grade(ev(['Bash', { command: 'npm test' }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, false);
  assert.match(g.reasons[0], /not the first tool call: first was Bash npm test/);
});

test('a bare skill name or a skill file outside the plugin root is not the route', () => {
  const bare = grade(ev(['Skill', { skill: 'recall' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(bare.pass, false);
  assert.match(bare.reasons[0], /never read/);
  const user = grade(ev(['Read', { file_path: '/home/u/.claude/skills/recall/SKILL.md' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(user.pass, false);
  assert.equal(grade(ev(['Skill', { skill: 'kern:recall' }], todos(...steps)), { route: 'recall', steps, root: K }).pass, true);
});

test('a missing step fails, and TaskCreate subjects count as todos', () => {
  assert.match(grade(ev(['Read', { file_path: route }], todos(steps[0], steps[2])), { route: 'diagnose', steps, root: K }).reasons.join(' '), /step 1/);
  const g = grade(ev(['Read', { file_path: route }], ...steps.map((s) => ['TaskCreate', { subject: s }])), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
});

test('negative cases pass only when no kern route is read; a project skill must be the one used', () => {
  assert.equal(grade(ev(['Bash', { command: 'git log -1' }]), { route: null, root: K, kind: 'negative' }).pass, true);
  assert.equal(grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }]), { route: null, root: K, kind: 'negative' }).pass, false);
  assert.deepEqual(grade(ev(['Skill', { skill: 'kern:recall' }]), { route: null, root: K, kind: 'negative' }).reasons, ['a kern route was read: Skill kern:recall']);
  const proj = { route: null, root: K, kind: 'negative', projectSkill: 'diagnose' };
  assert.equal(grade(ev(['Skill', { skill: 'diagnose' }]), proj).pass, true);
  assert.equal(grade(ev(['Read', { file_path: route }]), proj).pass, false);
});

test('a multi-turn case needs the route read again for the second task', () => {
  const once = ev(['Read', { file_path: route }], todos(...steps), ['Bash', { command: 'npm test' }]);
  assert.equal(grade(once, { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, false);
  assert.equal(grade([...once, { type: 'result', subtype: 'success' }, ...ev(['Read', { file_path: route }])], { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, true);
});

test('every kernel row has a positive case, and every listed case names a known fixture', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  const rows = kernelRows(routeText(loadModel(ROOT))).map((r) => r.route);
  for (const r of rows) assert.ok(cases.some((c) => c.kind === 'positive' && c.route === r), `no positive adherence case for row ${r}`);
  assert.ok(cases.filter((c) => c.kind === 'negative').length >= 4);
  assert.ok(cases.some((c) => c.kind === 'multi-turn'));
});

test('the runner lists its cases in dry-run mode without calling claude', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  for (const id of ['row-diagnose', 'row-define', 'neg-casual', 'neg-kern-off', 'neg-project-skill', 'multi-diagnose']) assert.match(r.stdout, new RegExp(`^${id}: `, 'm'));
  assert.match(r.stdout, /^row-diagnose: positive diagnose on node-bug: "npm test fails on the sum test; fix it."$/m);
  assert.match(r.stdout, /^row-execute-plan: positive execute-plan on node-bug\+approved-spec\+approved-plan: /m);
});

test('every case names fixture layers that exist, the first one a project', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  for (const c of cases) {
    assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', c.files[0], 'package.json')), `${c.id}: ${c.files[0]} has no package.json`);
    for (const f of c.files) assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', f)), `${c.id}: no fixture ${f}`);
  }
});

test('a positive case takes its prompt from the first routing eval of its row', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  for (const c of cases.filter((x) => x.kind === 'positive')) assert.equal(c.prompts, undefined, `${c.id} carries its own prompt`);
  assert.equal(rowPrompt(ROOT, 'diagnose'), JSON.parse(readFileSync(join(ROOT, 'evals', 'cases', 'row-diagnose.json'), 'utf8')).evals[0].prompt);
});

test('the inline-rows arm puts every routed row in the kernel table and drops routes.md', () => {
  const dir = inlineRows(ROOT);
  try {
    const k = readFileSync(join(dir, 'kernel', 'kernel.md'), 'utf8');
    assert.ok(!existsSync(join(dir, 'kernel', 'routes.md')));
    assert.doesNotMatch(k, /routes\.md/);
    for (const row of readFileSync(join(ROOT, 'kernel', 'routes.md'), 'utf8').split('\n').filter((l) => /\| Read \{KERN\}\//.test(l))) assert.ok(k.includes(row), row);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('a negative case fails on a Read of any kernel-file route, derived from the kernel rows', () => {
  const text = routeText(loadModel(ROOT));
  const files = text.split(/\r?\n/).map(parseRow).filter((r) => r && r.base === 'ROOT' && r.route).map((r) => r.path);
  assert.ok(files.includes('kernel/context.md'));
  for (const f of files) {
    const g = grade(ev(['Read', { file_path: `${K}/${f}` }]), { route: null, root: K, kind: 'negative' });
    assert.equal(g.pass, false, `a Read of ${f} passed a negative case`);
  }
});

test('a positive case with a routeFile reads that file, not skills/<route>/SKILL.md', () => {
  const file = `${K}/kernel/context.md`;
  const g = grade(ev(['Read', { file_path: file }], todos('Save the state.')), { route: 'context', routeFile: 'kernel/context.md', steps: ['Save the state.'], root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.hops, 1);
  assert.equal(grade(ev(['Read', { file_path: `${K}/skills/context/SKILL.md` }], todos('Save the state.')), { route: 'context', routeFile: 'kernel/context.md', steps: ['Save the state.'], root: K }).pass, false);
});

test('a run that errored is a failed run, a run capped by --max-turns is still graded', () => {
  const ok = { status: 0, badLines: 0, stderr: '', events: [{ type: 'result', subtype: 'success' }] };
  assert.equal(runFailure(ok), '');
  assert.equal(runFailure({ ...ok, events: [{ type: 'result', subtype: 'error_max_turns' }] }), '');
  assert.equal(runFailure({ ...ok, status: 1, events: [{ type: 'result', subtype: 'error_max_turns' }] }), '');
  assert.match(runFailure({ ...ok, status: 1, stderr: 'API error\n', events: [] }), /claude exited 1: API error/);
  assert.match(runFailure({ ...ok, events: [{ type: 'result', subtype: 'error_during_execution', is_error: true }] }), /error_during_execution/);
  assert.match(runFailure({ ...ok, events: [] }), /no events/);
});

test('a multi-turn case needs the route read in the second task, not twice in the first', () => {
  const opts = { route: 'diagnose', steps, root: K, kind: 'multi-turn' };
  const done = [{ type: 'result', subtype: 'success' }];
  const first = ev(['Read', { file_path: route }], todos(...steps), ['Read', { file_path: route }]);
  const twice = grade([...first, ...done, ...ev(['Bash', { command: 'npm test' }])], opts);
  assert.equal(twice.pass, false);
  assert.match(twice.reasons.join(' '), /second task did not read the route/);
  assert.equal(grade([...first, ...done, ...ev(['Read', { file_path: route }])], opts).pass, true);
});

test('both arms run on a plugin copy without the eval files, and a failed build leaves no copy', () => {
  const dir = inlineRows(ROOT);
  try {
    assert.equal(dir, realpathSync(dir));
    for (const f of ['scripts/kernel-adherence.mjs', 'scripts/lib/adherence.mjs', 'scripts/lib/claude-run.mjs', 'tests', 'docs', 'evals', '.superpowers']) assert.ok(!existsSync(join(dir, f)), `${f} is in the plugin copy`);
    assert.ok(existsSync(join(dir, 'skills', 'diagnose', 'SKILL.md')));
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
  const home = mkdtempSync(join(tmpdir(), 'k-'));
  const fake = join(home, 'src');
  mkdirSync(join(fake, 'kernel'), { recursive: true });
  writeFileSync(join(fake, 'kernel', 'kernel.md'), 'no routing sentence\n');
  writeFileSync(join(fake, 'kernel', 'routes.md'), '| a | Read {KERN}/x/SKILL.md |\n');
  const was = process.env.TMPDIR;
  const scratch = mkdtempSync(join(tmpdir(), 'k-'));
  process.env.TMPDIR = scratch;
  try {
    assert.throws(() => inlineRows(fake), /no longer has the Routing sentence/);
    assert.deepEqual(readdirSync(scratch), []);
  } finally {
    if (was === undefined) delete process.env.TMPDIR; else process.env.TMPDIR = was;
    rmSync(home, { recursive: true, force: true }); rmSync(scratch, { recursive: true, force: true });
  }
});

test('the runner exits 2 on a bad --case, --runs or --transcript usage, before anything runs', () => {
  const run = (...a) => spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), ...a], { encoding: 'utf8' });
  for (const a of [['--dry-run', '--case', 'bogus'], ['--dry-run', '--runs', '0'], ['--runs', 'x', '--dry-run'], ['--transcript', '/dev/null'], ['--transcript', '/dev/null', '--route', 'nope']]) {
    const r = run(...a);
    assert.equal(r.status, 2, `${a.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^kernel-adherence: /m);
  }
  assert.equal(run('--dry-run', '--case', 'row-diagnose').status, 0);
});
