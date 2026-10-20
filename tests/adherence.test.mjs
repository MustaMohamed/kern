// tests/adherence.test.mjs: the adherence grader on recorded runs, and the runner's dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readSteps, grade, rowPrompt, removeTemp, runFailure } from '../scripts/lib/adherence.mjs';
import { kernelRows, parseRow } from '../scripts/lib/kernel-rows.mjs';
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

test('one project call may come before the route, a second fails the run, and reads of routes.md do not count', () => {
  const one = grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(one.pass, true, one.reasons.join('; '));
  assert.equal(one.hops, 2);
  assert.equal(one.before, 1);
  const edit = grade(ev(['Edit', { file_path: '/p/a.js' }], ['Read', { file_path: route }]), { route: 'diagnose', steps, root: K });
  assert.equal(edit.pass, true, edit.reasons.join('; '));
  assert.equal(edit.hops, 1);
  const twice = grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Read', { file_path: `${K}/kernel/routes.md` }], ['Glob', { pattern: '**/*' }], ['Read', { file_path: route }]), { route: 'diagnose', steps, root: K });
  assert.equal(twice.pass, true, twice.reasons.join('; '));
  assert.equal(twice.before, 1);
  const two = grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Bash', { command: 'npm test' }], ['Bash', { command: 'ls' }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(two.pass, false);
  assert.deepEqual(two.reasons, ['two tool calls came before the route: Bash npm test, then Bash ls']);
  assert.equal(two.hops, 2);
  assert.equal(two.before, 2);
});

test('a Bash call is free before the route only when every part of it reads routes.md', () => {
  const opts = { route: 'diagnose', steps, root: K };
  const bundled = grade(ev(['Bash', { command: `cat ${K}/kernel/routes.md && ls src` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), opts);
  assert.equal(bundled.pass, false);
  assert.match(bundled.reasons.join(' '), /two tool calls came before the route/);
  const alone = grade(ev(['Bash', { command: `cat ${K}/kernel/routes.md && ls src` }], ['Read', { file_path: route }]), opts);
  assert.equal(alone.pass, true, alone.reasons.join('; '));
  assert.equal(alone.before, 1);
  const piped = grade(ev(['Bash', { command: `sed -n '1,80p' ${K}/kernel/routes.md 2>&1 | head -40` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), opts);
  assert.equal(piped.pass, true, piped.reasons.join('; '));
  assert.equal(piped.before, 1);
  const other = grade(ev(['Bash', { command: `cat ${K}/kernel/routes.md README.md` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), opts);
  assert.equal(other.pass, false);
});

test('a multi-turn case finds the route and its early calls in the first task only', () => {
  const opts = { route: 'diagnose', steps, root: K, kind: 'multi-turn' };
  const done = [{ type: 'result', subtype: 'success' }];
  const late = grade([...ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Bash', { command: 'npm test' }]), ...done, ...ev(['Read', { file_path: route }])], opts);
  assert.equal(late.pass, false);
  assert.match(late.reasons[0], /^never read skills\/diagnose\/SKILL\.md under the plugin root, nor called kern:diagnose, in the first task$/);
  const ok = grade([...ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), ...done, ...ev(['Read', { file_path: route }])], opts);
  assert.equal(ok.pass, true, ok.reasons.join('; '));
  assert.equal(ok.before, 1);
});

test('a multi-turn case splits its tasks at the first result a prompt started, not at a background task\'s (Task 16h)', () => {
  const opts = { route: 'diagnose', steps, root: K, kind: 'multi-turn' };
  const note = { type: 'result', subtype: 'success', origin: { kind: 'task-notification', producer: 'session-task', runId: 'r1' } };
  const done = { type: 'result', subtype: 'success' };
  const g = grade([...ev(['Bash', { command: 'npm test' }]), note, ...ev(['Read', { file_path: route }]), done, ...ev(['Read', { file_path: route }])], opts);
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.before, 1);
  const again = grade([...ev(['Read', { file_path: route }]), note, ...ev(['Read', { file_path: route }]), done, ...ev(['Bash', { command: 'cat README.md' }])], opts);
  assert.deepEqual(again.reasons, ['the second task did not read the route again'], 'a read in a background turn of the first task is not the second task\'s');
});

test('a bare skill name or a skill file outside the plugin root is not the route', () => {
  const bare = grade(ev(['Skill', { skill: 'recall' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(bare.pass, false);
  assert.match(bare.reasons[0], /never read/);
  const user = grade(ev(['Read', { file_path: '/home/u/.claude/skills/recall/SKILL.md' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(user.pass, false);
  assert.equal(grade(ev(['Skill', { skill: 'kern:recall' }], todos(...steps)), { route: 'recall', steps, root: K }).pass, true);
});

test('the todo list is reported, not graded: no list passes with todo false, a missing step is noted, and TaskCreate subjects count', () => {
  const none = grade(ev(['Read', { file_path: route }]), { route: 'diagnose', steps, root: K });
  assert.equal(none.pass, true, none.reasons.join('; '));
  assert.equal(none.todo, false);
  assert.equal(none.todoSteps, false);
  assert.deepEqual(none.notes, ['no todo list']);
  const gap = grade(ev(['Read', { file_path: route }], todos(steps[0], steps[2])), { route: 'diagnose', steps, root: K });
  assert.equal(gap.pass, true, gap.reasons.join('; '));
  assert.equal(gap.todo, true);
  assert.equal(gap.todoSteps, false);
  assert.match(gap.notes.join(' '), /step 1/);
  const g = grade(ev(['Read', { file_path: route }], ...steps.map((s) => ['TaskCreate', { subject: s }])), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.todo, true);
  assert.equal(g.todoSteps, true);
  assert.deepEqual(g.notes, []);
});

test('the runner reports the todo list per run, in the snapshot detail and for a transcript', () => {
  const src = readFileSync(join(ROOT, 'scripts', 'kernel-adherence.mjs'), 'utf8');
  assert.match(src, /runs\.push\(\{ pass: g\.pass, hops: g\.hops, before: g\.before, todo: g\.todo, todoSteps: g\.todoSteps, notes: g\.notes,/);
  // A run that did not happen, a result count off its prompt count among them, is marked invalid, not graded.
  assert.match(src, /runFailure\(run, c\.prompts\.length\)/);
  assert.match(src, /exit: run \? run\.status : null, invalid: !!failure \}\);/);
  const dir = mkdtempSync(join(tmpdir(), 'k-'));
  try {
    const file = join(dir, 'run.jsonl');
    writeFileSync(file, ev(['Read', { file_path: join(ROOT, 'skills', 'diagnose', 'SKILL.md') }]).map((e) => JSON.stringify(e)).join('\n') + '\n');
    const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--transcript', file, '--route', 'diagnose'], { encoding: 'utf8' });
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /^PASS diagnose \(1 hops, 0 before, todo: false\)$/m);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('negative cases pass only when no kern route is read; a project skill must be the one used', () => {
  assert.equal(grade(ev(['Bash', { command: 'git log -1' }]), { route: null, root: K, kind: 'negative' }).pass, true);
  assert.equal(grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }]), { route: null, root: K, kind: 'negative' }).pass, false);
  assert.deepEqual(grade(ev(['Skill', { skill: 'kern:recall' }]), { route: null, root: K, kind: 'negative' }).reasons, ['a kern route was read: Skill kern:recall']);
  const proj = { route: null, root: K, kind: 'negative', projectSkill: 'diagnose' };
  assert.equal(grade(ev(['Skill', { skill: 'diagnose' }]), proj).pass, true);
  assert.equal(grade(ev(['Read', { file_path: route }]), proj).pass, false);
  const listed = grade(ev(['TaskCreate', { subject: 'Look at the log' }], ['Bash', { command: 'git log -1' }]), { route: null, root: K, kind: 'negative' });
  assert.equal(listed.pass, true, listed.reasons.join('; '));
  assert.equal(listed.todo, true);
  assert.equal(listed.todoSteps, null);
});

test('a multi-turn case needs the route read again for the second task', () => {
  const once = ev(['Read', { file_path: route }], todos(...steps), ['Bash', { command: 'npm test' }]);
  assert.equal(grade(once, { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, false);
  assert.equal(grade([...once, { type: 'result', subtype: 'success' }, ...ev(['Read', { file_path: route }])], { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, true);
});

test('every kernel row has a positive case, and every listed case names a known fixture', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  const rows = kernelRows(loadModel(ROOT).kernelText).map((r) => r.route);
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

test('the inline-rows variant is gone: since Task 16d the routed kernel holds every row itself', () => {
  // tests/kernel.test.mjs pins the rows in the kernel table, the check this variant's test made on its copy.
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run', '--variant', 'inline-rows'], { encoding: 'utf8' });
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stderr, /^kernel-adherence: --variant inline-rows is gone: the kernel table holds every route row since Task 16d, so the routed run is that arm$/m);
  assert.equal(spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run', '--variant', 'routed'], { encoding: 'utf8' }).status, 0);
});

test('a negative case fails on a Read of any kernel-file route, derived from the kernel rows', () => {
  const text = loadModel(ROOT).kernelText;
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
  assert.equal(runFailure(ok, 1), '');
  assert.equal(runFailure({ ...ok, events: [{ type: 'result', subtype: 'error_max_turns' }] }, 1), '');
  assert.equal(runFailure({ ...ok, status: 1, events: [{ type: 'result', subtype: 'error_max_turns' }] }, 1), '');
  assert.match(runFailure({ ...ok, status: 1, stderr: 'API error\n', events: [] }, 1), /claude exited 1: API error/);
  assert.match(runFailure({ ...ok, events: [{ type: 'result', subtype: 'error_during_execution', is_error: true }] }, 1), /error_during_execution/);
  assert.match(runFailure({ ...ok, events: [] }, 1), /no events/);
});

test('a run whose result count differs from its prompt count fails with that reason, capped or not (Task 16e)', () => {
  const ok = { status: 0, badLines: 0, stderr: '', events: [] };
  const res = (subtype) => ({ type: 'result', subtype });
  // multi-diagnose on 2026-10-20: two prompts, one result event, so the second task never ran as a turn.
  const why = '2 prompts but 1 result event: each prompt must run as its own turn';
  assert.equal(runFailure({ ...ok, events: [res('success')] }, 2), why);
  assert.equal(runFailure({ ...ok, events: [res('error_max_turns')] }, 2), why, 'a cap does not excuse a missing turn');
  assert.equal(runFailure({ ...ok, status: 1, events: [res('error_max_turns')] }, 2), why);
  assert.match(runFailure({ ...ok, events: [res('success'), res('success')] }, 1), /^1 prompt but 2 result events/);
  assert.throws(() => runFailure({ ...ok, events: [res('success')] }), /needs the number of prompts sent/);
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

test('the runner exits 2 on a bad --case, --runs or --transcript usage, before anything runs', () => {
  const run = (...a) => spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), ...a], { encoding: 'utf8' });
  for (const a of [['--dry-run', '--case', 'bogus'], ['--dry-run', '--runs', '0'], ['--runs', 'x', '--dry-run'], ['--transcript', '/dev/null'], ['--transcript', '/dev/null', '--route', 'nope']]) {
    const r = run(...a);
    assert.equal(r.status, 2, `${a.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^kernel-adherence: /m);
  }
  assert.equal(run('--dry-run', '--case', 'row-diagnose').status, 0);
});

test('a two-prompt run is graded when its results are caps and successes, and fails on any other result', () => {
  const ok = { status: 0, badLines: 0, stderr: '', events: [] };
  const res = (subtype, extra = {}) => ({ type: 'result', subtype, ...extra });
  assert.equal(runFailure({ ...ok, events: [res('error_max_turns'), res('success')] }, 2), '');
  assert.match(runFailure({ ...ok, events: [res('error_during_execution', { is_error: true }), res('error_max_turns')] }, 2), /error_during_execution/);
  assert.match(runFailure({ ...ok, events: [res('error_max_turns'), res('success', { is_error: true })] }, 2), /is_error/);
});

test('removeTemp removes a directory under the OS temp dir and refuses anything else', () => {
  const d = mkdtempSync(join(tmpdir(), 'k-'));
  removeTemp(d);
  assert.ok(!existsSync(d));
  assert.throws(() => removeTemp(ROOT), /refusing to remove/);
  assert.throws(() => removeTemp(tmpdir()), /refusing to remove/);
  assert.ok(existsSync(join(ROOT, 'package.json')) || existsSync(join(ROOT, 'scripts')));
});

test('a Bash read of the route counts as reading it, as a Read call does, and /var and /private/var are one path', () => {
  const g1 = grade(ev(['Bash', { command: `cat ${route}` }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g1.pass, true, g1.reasons.join('; '));
  assert.equal(g1.hops, 1);
  const g2 = grade(ev(['Bash', { command: `sed -n '1,80p' ${K}/kernel/routes.md` }], ['Bash', { command: `git status; head -60 ${route}` }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g2.pass, true, g2.reasons.join('; '));
  assert.equal(g2.hops, 2);
  const tmp = '/private/var/folders/x/T/p-1/kern';
  const g3 = grade(ev(['Read', { file_path: '/var/folders/x/T/p-1/kern/skills/diagnose/SKILL.md' }], todos(...steps)), { route: 'diagnose', steps, root: tmp });
  assert.equal(g3.pass, true, g3.reasons.join('; '));
  assert.equal(grade(ev(['Bash', { command: `echo ${route}` }], todos(...steps)), { route: 'diagnose', steps, root: K }).pass, false);
  for (const command of [`cat > ${route}`, `cat <<EOF > ${route}`, `sed -i 's/a/b/' ${route}`, `tail -f ${route}`, `awk -f ${route} x`, `cat ${route} > /tmp/x`]) {
    assert.equal(grade(ev(['Bash', { command }], todos(...steps)), { route: 'diagnose', steps, root: K }).pass, false, command);
  }
  assert.equal(grade(ev(['Bash', { command: `cat ${route} 2>&1 | head -40` }], todos(...steps)), { route: 'diagnose', steps, root: K }).pass, true);
  assert.deepEqual(grade(ev(['Bash', { command: `cat ${K}/skills/define/SKILL.md` }]), { route: null, root: K, kind: 'negative' }).reasons, [`a kern route was read: Bash cat ${K}/skills/define/SKILL.md`]);
  assert.equal(grade(ev(['Bash', { command: `cat ${K}/skills/define/SKILL.md` }]), { route: null, root: K, kind: 'negative' }).pass, false);
  assert.equal(grade(ev(['Bash', { command: `cat ${K}/kernel/routes.md` }]), { route: null, root: K, kind: 'negative' }).pass, false);
});

test('--plugin names another kern tree in the dry run, and a one-case or other-plugin run is diagnostic', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run', '--case', 'row-diagnose', '--plugin', '/opt/kern-old'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^row-diagnose: positive diagnose on node-bug: /m);
  assert.match(r.stdout, /^plugin: \/opt\/kern-old$/m);
  const src = readFileSync(join(ROOT, 'scripts', 'kernel-adherence.mjs'), 'utf8');
  assert.match(src, /const out = partial \? join\(raw, 'snapshot\.json'\)/);
});

test('a Bash read of routes.md that also names project files by a glob, a brace or a relative name is the one early call', () => {
  const P = `${K}/kernel/routes.md`;
  for (const command of [`cat ${P} src/*.js`, `cat ${P} src/{a,b}.js`, `cat ${P} README.md`, `cat ${P} $R/x.js`]) {
    const g = grade(ev(['Bash', { command }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), { route: 'diagnose', steps, root: K });
    assert.equal(g.pass, false, command);
  }
  assert.equal(grade(ev(['Bash', { command: `sed -n '1,80p' ${P}` }], ['Bash', { command: 'npm test' }], ['Read', { file_path: route }]), { route: 'diagnose', steps, root: K }).pass, true);
});

test('the project skill counts when read by a relative path too', () => {
  const proj = { route: null, root: K, kind: 'negative', projectSkill: 'diagnose' };
  assert.equal(grade(ev(['Bash', { command: 'cat .claude/skills/diagnose/SKILL.md' }]), proj).pass, true);
  assert.equal(grade(ev(['Bash', { command: 'cat ./.claude/skills/diagnose/SKILL.md && npm test' }]), proj).pass, true);
});
