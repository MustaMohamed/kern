// tests/adherence.test.mjs: the adherence grader on recorded runs, and the runner's dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { adherenceFlags, adherenceMain, readSteps, stepLine, grade, rowPrompt, removeTemp, runFailure } from '../scripts/lib/adherence.mjs';
import { parseArgs } from '../scripts/lib/args.mjs';
import { KERNEL, guardedEnv, ran as runOf, result as resultEvent, started, use } from './helpers/eval-stub.mjs';
import { kernelRows, parseRow } from '../scripts/lib/kernel-rows.mjs';
import { loadModel } from '../scripts/lib/lint-rules.mjs';
import { pluginCopy, stage } from '../scripts/lib/behave.mjs';
import { workspace } from '../scripts/lib/claude-run.mjs';

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

// Task 17a G4: each of these was ignored, so it ran every case (--dryrun ran them for real). Each is now a usage
// error; the spawned runner keeps --dry-run and a stand-in claude, so one it failed to refuse still spends nothing.
test('Task 17a G4: the adherence runner refuses an unknown, valueless or repeated flag before anything runs', () => {
  const ids = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8')).map((c) => c.id);
  assert.deepEqual(parseArgs(['--case', 'row-diagnose', '--runs', '5', '--model', 'm', '--variant', 'routed', '--plugin', '/opt/k', '--dry-run', '--allow-dirty'], adherenceFlags(ids)),
    { case: 'row-diagnose', runs: 5, model: 'm', variant: 'routed', plugin: '/opt/k', dryRun: true, allowDirty: true });
  assert.deepEqual(parseArgs(['--transcript', 't.jsonl', '--route', 'diagnose', '--root', '/opt/k'], adherenceFlags(ids)), { transcript: 't.jsonl', route: 'diagnose', root: '/opt/k' });
  const env = guardedEnv();
  for (const a of [['--dryrun'], ['--case=row-diagnose'], ['--cases', 'row-diagnose'], ['--case'], ['--runs', '1.5'], ['--plugin'], ['row-diagnose'], ['--case', 'row-diagnose', '--case', 'neg-casual']]) {
    const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run', ...a], { encoding: 'utf8', env });
    assert.equal(r.status, 2, `${a.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^kernel-adherence: .*\nusage: node scripts\/kernel-adherence\.mjs /m, a.join(' '));
    assert.equal(r.stdout, '', `${a.join(' ')}: nothing ran`);
  }
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

// Task 16p item 4 (task-16-diagnosis-5, multi-diagnose): every Sonnet re-read that passed was a Read with
// `limit: 12` of skills/diagnose/SKILL.md, whose line 12 is the `## Steps` heading, so the grader passed reads
// that held no step. Given the route file's text, a read counts only when it covers the route's first step.
test('stepLine gives the line of the first step under ## Steps, or null', () => {
  assert.equal(stepLine(MD), 5);
  assert.equal(stepLine('# x\n\n## Inputs\n\n1. not a step\n'), null);
  assert.equal(stepLine('# x\n\n## Steps\n\nNo numbered line.\n\n## Inputs\n\n1. not a step\n'), null);
  const diagnose = readFileSync(join(ROOT, 'skills', 'diagnose', 'SKILL.md'), 'utf8');
  assert.equal(diagnose.split('\n')[stepLine(diagnose) - 1].slice(0, 9), '0. Defer:');
});

test('a Read whose limit or offset misses the first step is not a route read (Task 16p)', () => {
  const opts = { route: 'diagnose', steps, root: K, text: MD };
  const read = (input) => grade(ev(['Read', { file_path: route, ...input }]), opts);
  // MD: line 3 is `## Steps`, line 5 is step 0. A Read covers lines offset to offset+limit-1 (offset 0 or none: line 1).
  for (const input of [{ limit: 3 }, { limit: 4 }, { offset: 6 }, { offset: 6, limit: 5 }, { offset: 1, limit: 4 }]) {
    const g = read(input);
    assert.equal(g.pass, false, JSON.stringify(input));
    assert.match(g.reasons[0], /^read skills\/diagnose\/SKILL\.md only as lines \d+ to (\d+|the end), which miss its first step at line 5$/, JSON.stringify(input));
  }
  for (const input of [{}, { limit: 5 }, { offset: 5, limit: 1 }, { offset: 0, limit: 5 }, { offset: 2 }, { limit: 2000 }]) assert.equal(read(input).pass, true, JSON.stringify(input));
  // Without the route's text the grader cannot place the steps, so any read of the file counts, as before.
  assert.equal(grade(ev(['Read', { file_path: route, limit: 3 }]), { route: 'diagnose', steps, root: K }).pass, true);
  // A Skill call loads the whole skill.
  assert.equal(grade(ev(['Skill', { skill: 'kern:diagnose' }]), opts).pass, true);
});

test('a Bash read cut short with head, tail or sed -n before the first step is not a route read (Task 16p)', () => {
  const opts = { route: 'diagnose', steps, root: K, text: MD };
  const misses = [`head -n 4 ${route}`, `head -4 ${route}`, `head -n4 ${route}`, `head --lines=4 ${route}`, `head ${K}/x.md; sed -n '1,4p' ${route}`,
    `sed -n 6,12p ${route}`, `sed -n 4p ${route}`, `sed 4q ${route}`, `cat ${route} | head -n 4`, `cat ${route} 2>&1 | head -0`, `tail -n 3 ${route}`,
    `tail -n +6 ${route}`, `sed -n '1,40p' ${route} | head -3`, `cat ${route} | tail -n 2`, `git status; head -n 2 ${route}`];
  for (const command of misses) assert.equal(grade(ev(['Bash', { command }]), opts).pass, false, command);
  const reaches = [`cat ${route}`, `head -n 5 ${route}`, `head -20 ${route}`, `sed -n '1,$p' ${route}`, `sed -n '5,9p' ${route}`, `sed -n 5p ${route}`,
    `tail -n +5 ${route}`, `tail -n 20 ${route}`, `cat ${route} 2>&1 | head -40`, `head -n 4 ${route}; cat ${route}`, `sed -n '/Steps/,$p' ${route}`,
    `nl ${route}`, `head -c 400 ${route}`, `cat ${route} | grep -n Defer`];
  for (const command of reaches) assert.equal(grade(ev(['Bash', { command }]), opts).pass, true, command);
  // A negative case still fails on any read of a kern route, however short.
  assert.equal(grade(ev(['Read', { file_path: route, limit: 3 }]), { route: null, root: K, kind: 'negative' }).pass, false);
  assert.equal(grade(ev(['Bash', { command: `head -n 2 ${route}` }]), { route: null, root: K, kind: 'negative' }).pass, false);
});

test('a multi-turn case needs the second task to read the route to its first step (Task 16p)', () => {
  const opts = { route: 'diagnose', steps, root: K, kind: 'multi-turn', text: MD };
  const done = [{ type: 'result', subtype: 'success' }];
  const first = ev(['Read', { file_path: route }], todos(...steps));
  const short = grade([...first, ...done, ...ev(['Read', { file_path: route, limit: 3 }], ['Bash', { command: 'cat src/format.js' }])], opts);
  assert.equal(short.pass, false);
  assert.deepEqual(short.reasons, ['the second task did not read the route again: it read skills/diagnose/SKILL.md only as lines 1 to 3, which miss its first step at line 5']);
  assert.equal(grade([...first, ...done, ...ev(['Read', { file_path: route, limit: 3 }], ['Read', { file_path: route, offset: 4 }])], opts).pass, true);
  assert.equal(grade([...ev(['Read', { file_path: route, limit: 3 }]), ...done, ...ev(['Read', { file_path: route }])], opts).pass, false, 'the first task needs it too');
});

test('the runner and the transcript mode give the grader the route file\'s text', () => {
  const dir = mkdtempSync(join(tmpdir(), 'k-'));
  try {
    const file = join(dir, 'run.jsonl');
    writeFileSync(file, ev(['Read', { file_path: join(ROOT, 'skills', 'diagnose', 'SKILL.md'), limit: 12 }]).map((e) => JSON.stringify(e)).join('\n') + '\n');
    const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--transcript', file, '--route', 'diagnose'], { encoding: 'utf8' });
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /^FAIL diagnose \(0 hops, 0 before, todo: false\): read skills\/diagnose\/SKILL\.md only as lines 1 to 12, which miss its first step at line 14$/m);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('--plugin names another kern tree in the dry run, and a one-case or other-plugin run is diagnostic', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run', '--case', 'row-diagnose', '--plugin', '/opt/kern-old'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^row-diagnose: positive diagnose on node-bug: /m);
  assert.match(r.stdout, /^plugin: \/opt\/kern-old$/m);
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

// Task 16h item 5 (task-16-diagnosis-2 section 1, D3). The user, asked whether a follow-up on the bug just
// fixed is a new task that must read its route again, answered "No, it continues": "A follow-up on the bug
// just fixed is the same task. The case's second prompt becomes an unrelated bug, so it really tests 'each
// new task reads its route'. The kernel stays as is." The second prompt used to report the README's wrong
// total, a symptom of the sum bug the first task fixed. It now names a bug in another file with another
// cause, which no test shows, so the first task cannot meet it.
test('multi-diagnose: the second prompt names a bug the first task cannot touch, in a file of its own', () => {
  const c = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8')).find((x) => x.id === 'multi-diagnose');
  assert.deepEqual([c.kind, c.route], ['multi-turn', 'diagnose']);
  assert.equal(c.prompts[0], 'npm test fails on the sum test. Find out why and fix it.');
  assert.match(c.prompts[1], /src\/format\.js/);
  assert.doesNotMatch(c.prompts[1], /README|sum|also/i, 'the second prompt reads as a follow-up on the first bug');
  const src = stage(ROOT, c.files);
  let ws = null;
  try {
    ws = workspace(src, { name: 'billing-service' });
    const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== 'NODE_TEST_CONTEXT'));
    const run = (cmd) => spawnSync('bash', ['-c', cmd], { cwd: ws, env, encoding: 'utf8', timeout: 60000 });
    const money = "node --input-type=module -e \"import { money } from './src/format.js'; console.log(money(1234))\"";
    const before = run('node --test 2>&1');
    assert.notEqual(before.status, 0);
    assert.match(before.stdout, /not ok \d+ - sum adds/);
    assert.match(before.stdout, /# fail 1\n/, 'the first task meets only the sum bug');
    assert.equal(run(money).stdout, '123.40\n', 'money(1234) prints 123.40, as the second prompt says');
    assert.equal(run("printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js && node --test 2>&1").status, 0, 'the first fix makes the suite pass');
    assert.equal(run(money).stdout, '123.40\n', 'and leaves the second bug where it was');
  } finally {
    if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
    if (ws) rmSync(dirname(ws), { recursive: true, force: true });
  }
});

// The adherence runner through its seam (Task 17a): adherenceMain with a stub run, temp snapshot and results dirs and
// a stated tree, so no test writes into the repo's evals/ and no claude runs. A stub run's answer is picked per call:
// 'pass' reads the route, 'miss' reads nothing, 'invalid' exits 1, 'kernel' / 'quiet' are a kern-off case's runs with
// and without the kernel printed, and 'unloaded' lists no plugin.
const DAY = new Date('2026-10-22T12:00:00Z');
const CLEAN = { commit: 'c0ffee', dirty: false, changes: [] };
const rowCase = (id = 'row-x', extra = {}) => ({ id, kind: 'positive', route: 'diagnose', files: ['node-bug'], prompts: [`fix it (${id})`], ...extra });
const answer = (kind, opts) => {
  const dir = opts.pluginDirs[0];
  if (kind === 'invalid') return runOf([resultEvent('x')], 1);
  if (kind === 'unloaded') return runOf([...started([]), resultEvent('done')]);
  if (kind === 'short') return runOf([...started([dir]), use('Read', { file_path: `${dir}/skills/diagnose/SKILL.md`, limit: 12 }), resultEvent('done')]);
  if (kind === 'kernel' || kind === 'quiet') return runOf([...started([dir], kind === 'kernel' ? KERNEL : ''), resultEvent('done')]);
  return runOf([...started([dir]), ...(kind === 'pass' ? [use('Read', { file_path: `${dir}/skills/diagnose/SKILL.md` })] : []), resultEvent('done')]);
};
const driveAdherence = ({ argv = ['--runs', '1'], cases = [rowCase()], answers = ['pass'], tree = () => CLEAN, before = null } = {}) => {
  const dir = mkdtempSync(join(tmpdir(), 'am-'));
  const snapshots = join(dir, 'snapshots'); const results = join(dir, 'results');
  const committed = join(snapshots, 'adherence-routed-sonnet-5-5-2026-10-22.json');
  if (before !== null) { mkdirSync(snapshots, { recursive: true }); writeFileSync(committed, before); }
  const calls = []; const lines = []; const errors = [];
  const run = (opts) => { calls.push(opts); return answer(answers[(calls.length - 1) % answers.length], opts); };
  const code = adherenceMain({ root: ROOT, argv, env: {}, cases, run, version: () => '9.9.9 (stand-in)', tree, snapshots, results, log: (l) => lines.push(l), error: (l) => errors.push(l), now: DAY });
  const read = (f) => (existsSync(f) ? JSON.parse(readFileSync(f, 'utf8')) : null);
  return { code, calls, lines, errors, committed: existsSync(committed) ? readFileSync(committed, 'utf8') : null, results, read, done: () => rmSync(dir, { recursive: true, force: true }) };
};

test('Task 17a G5: adherence passes a case by caseResult, so an invalid run is left out, not counted as a failure', () => {
  // Lane G: at --runs 5, one invalid run, three passes and one fail was FAIL (3 of 5) though 3 of the 4 valid runs passed.
  const r = driveAdherence({ argv: ['--runs', '5'], answers: ['pass', 'miss', 'invalid', 'pass', 'pass'] });
  try {
    assert.equal(r.code, 0, r.lines.join('\n'));
    const s = JSON.parse(r.committed).results[0];
    assert.deepEqual([s.pass, s.passed, s.valid, s.invalid, s.runs], [true, 3, 4, 1, 5]);
    assert.deepEqual(s.detail.map((x) => [x.pass, x.invalid]), [[true, false], [false, false], [false, true], [true, false], [true, false]]);
    assert.match(r.lines[0], /^PASS row-x: 3\/4 \(1 invalid, not graded\), todo 0\/5: /);
  } finally { r.done(); }
  const two = driveAdherence({ argv: ['--runs', '3'], answers: ['pass', 'invalid', 'invalid'] });
  try { assert.equal(JSON.parse(two.committed).results[0].pass, false, 'two invalid runs of three fail the case, as behave\'s rule says'); } finally { two.done(); }
});

test('Task 17a G3: adherence keeps a --case, --plugin, all-invalid or stopped run off the committed snapshot', () => {
  const one = driveAdherence({ argv: ['--case', 'row-x', '--runs', '1'], before: 'earlier\n' });
  try {
    assert.equal(one.committed, 'earlier\n');
    const s = one.read(join(one.results, `adherence-routed-sonnet-5-5-2026-10-22-row-x-${ROOT.split('/').pop()}`, 'snapshot.json'));
    assert.deepEqual([s.complete, s.cases, s.kern], [true, ['row-x'], CLEAN]);
  } finally { one.done(); }
  const none = driveAdherence({ answers: ['invalid'], before: 'earlier\n' });
  try {
    assert.equal(none.committed, 'earlier\n');
    assert.match(none.lines.join('\n'), /no run was valid: no committed snapshot, and any earlier one stays/);
    assert.equal(none.read(join(none.results, 'adherence-routed-sonnet-5-5-2026-10-22', 'snapshot.json')).complete, true);
  } finally { none.done(); }
  const full = driveAdherence({ cases: [rowCase('row-x'), rowCase('row-y')], before: 'earlier\n' });
  try {
    const s = JSON.parse(full.committed);
    assert.deepEqual([s.complete, s.cases, s.kern, s.gating], [true, ['row-x', 'row-y'], CLEAN, true]);
    assert.equal(full.read(join(full.results, 'adherence-routed-sonnet-5-5-2026-10-22', 'snapshot.json')), null, 'no progress file is left');
  } finally { full.done(); }
  // --plugin grades another kern tree: diagnostic, beside the transcripts, with that tree's record too.
  const other = pluginCopy(ROOT);
  const OTHER = { commit: null, dirty: true, changes: [], problem: 'not a git checkout: x' };
  const old = driveAdherence({ argv: ['--plugin', other, '--runs', '1'], tree: (d) => (d === ROOT ? CLEAN : OTHER), before: 'earlier\n' });
  try {
    assert.equal(old.code, 0, old.errors.join('\n'));
    assert.equal(old.committed, 'earlier\n');
    const s = old.read(join(old.results, 'adherence-routed-sonnet-5-5-2026-10-22-all-kern', 'snapshot.json'));
    assert.deepEqual([s.plugin, s.kern, s.plugin_tree], [other, CLEAN, OTHER]);
  } finally { old.done(); rmSync(dirname(other), { recursive: true, force: true }); }
});

test('Task 17a G11: a full adherence run refuses a dirty kern tree unless --allow-dirty', () => {
  const dirty = { commit: 'c0ffee', dirty: true, changes: [' M kernel/kernel.md'] };
  const r = driveAdherence({ tree: () => dirty });
  try {
    assert.equal(r.code, 2);
    assert.match(r.errors.join('\n'), /^kernel-adherence: the kern tree is not a clean commit .*--allow-dirty/);
    assert.equal(r.calls.length, 0, 'nothing ran');
  } finally { r.done(); }
  const ok = driveAdherence({ argv: ['--runs', '1', '--allow-dirty'], tree: () => dirty });
  try { assert.deepEqual(JSON.parse(ok.committed).kern, dirty); } finally { ok.done(); }
});

test('Task 17a G10: an adherence run that did not load kern is invalid, and neg-kern-off must show kern absent', () => {
  const r = driveAdherence({ answers: ['unloaded'] });
  try {
    const d = r.read(join(r.results, 'adherence-routed-sonnet-5-5-2026-10-22', 'snapshot.json')).results[0].detail[0];
    assert.equal(d.invalid, true);
    assert.match(d.reasons[0], /is not in the run's init\.plugins/);
  } finally { r.done(); }
  const off = rowCase('neg-off', { kind: 'negative', route: null, settings: 'kern: off' });
  const printed = driveAdherence({ cases: [off], answers: ['kernel'] });
  try {
    const d = printed.read(join(printed.results, 'adherence-routed-sonnet-5-5-2026-10-22', 'snapshot.json')).results[0].detail[0];
    assert.deepEqual([d.invalid, d.reasons], [true, ['kern was meant to be off, but its SessionStart printed the kernel']]);
  } finally { printed.done(); }
  const quiet = driveAdherence({ cases: [off], answers: ['quiet'] });
  try { assert.equal(JSON.parse(quiet.committed).results[0].pass, true); } finally { quiet.done(); }
});

test('the runner grades each run on the route file\'s text, reports the todo list per run, and marks a run that did not happen invalid', () => {
  const r = driveAdherence({ argv: ['--runs', '3'], answers: ['short', 'pass', 'invalid'] });
  try {
    const s = JSON.parse(r.committed).results[0];
    assert.match(s.detail[0].reasons[0], /^read skills\/diagnose\/SKILL\.md only as lines 1 to 12, which miss its first step at line \d+$/);
    for (const k of ['pass', 'hops', 'before', 'todo', 'todoSteps', 'notes', 'reasons', 'problem', 'exit', 'invalid']) assert.ok(k in s.detail[1], k);
    assert.deepEqual([s.detail[1].pass, s.detail[1].todo, s.detail[2].invalid, s.detail[2].exit], [true, false, true, 1]);
    assert.match(s.detail[2].reasons[0], /^claude exited 1/);
  } finally { r.done(); }
});
