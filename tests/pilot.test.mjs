// tests/pilot.test.mjs: the side-by-side pilot's metrics, blinding, bundle and decision rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { RULE, TELLS, decide, diffAgainst, hide, metrics, parseReview, readSession, reviewPrompt } from '../scripts/lib/pilot.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const at = (s) => `2026-10-20T10:00:${String(s).padStart(2, '0')}.000Z`;
const asst = (id, s, content, usage = { input_tokens: 10, cache_creation_input_tokens: 100, cache_read_input_tokens: 1000, output_tokens: 5 }) =>
  ({ type: 'assistant', timestamp: at(s), message: { id, content: [content], usage } });
const human = (s, text) => ({ type: 'user', timestamp: at(s), origin: { kind: 'human' }, message: { role: 'user', content: text } });
const result = (s, text, isError = false) => ({ type: 'user', timestamp: at(s), message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: 't', content: text, is_error: isError }] } });
const bash = (command) => ({ type: 'tool_use', name: 'Bash', input: { command } });

function session(dir, entries, sub = []) {
  const f = join(dir, 'abc.jsonl');
  writeFileSync(f, entries.map((e) => JSON.stringify(e)).join('\n') + '\nnot json\n');
  if (sub.length) {
    mkdirSync(join(dir, 'abc', 'subagents'), { recursive: true });
    writeFileSync(join(dir, 'abc', 'subagents', 'agent-1.jsonl'), sub.map((e) => JSON.stringify(e)).join('\n') + '\n');
  }
  return f;
}

test('metrics count usage once per message, subagents included, and read turns, guards and slip candidates', () => {
  const dir = mkdtempSync(join(tmpdir(), 'p-'));
  try {
    const f = session(dir, [
      human(0, 'Implement Task 5.'),
      asst('m1', 1, { type: 'text', text: 'Reading the plan.' }),
      asst('m1', 2, bash('git push --force origin main')),
      result(3, 'kern G1: plain force push; use --force-with-lease on your own branch', true),
      result(3, 'ok 12 G16 asks: kern G16: hook files are not writable'),
      asst('m2', 4, { type: 'tool_use', name: 'Write', input: { file_path: '/etc/hosts', content: 'x' } }),
      { type: 'user', timestamp: at(5), origin: { kind: 'task-notification' }, message: { role: 'user', content: 'a task finished' } },
      human(9, 'yes'),
    ], [{ type: 'assistant', isSidechain: true, timestamp: at(7), message: { id: 's1', content: [{ type: 'text', text: 'done' }], usage: { input_tokens: 1, output_tokens: 1 } } }]);
    const m = metrics(readSession(f), { root: join(dir, 'repo') });
    assert.deepEqual(m.tokens, { input: 21, cacheCreation: 200, cacheRead: 2000, output: 11, total: 2232 });
    assert.equal(m.turns, 2);
    assert.equal(m.stops, 1);
    assert.deepEqual(m.guards, ['G1']);
    assert.equal(m.wallSeconds, 9);
    assert.deepEqual(m.slipCandidates, ['Bash: git push --force origin main', 'Write outside the worktree: /etc/hosts']);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('the diff holds committed, staged and new files, and leaves the arm index untouched', () => {
  const r = mkdtempSync(join(tmpdir(), 'p-'));
  const git = (...a) => execFileSync('git', ['-C', r, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...a], { encoding: 'utf8' });
  try {
    git('init', '-q', '-b', 'main');
    writeFileSync(join(r, 'a.txt'), 'one\n');
    git('add', '.'); git('commit', '-qm', 'base');
    const base = git('rev-parse', 'HEAD').trim();
    writeFileSync(join(r, 'a.txt'), 'two\n'); git('commit', '-qam', 'arm');
    writeFileSync(join(r, 'b.txt'), 'new\n');
    const index = createHash('sha256').update(readFileSync(join(r, '.git', 'index'))).digest('hex');
    const d = diffAgainst(r, base);
    assert.match(d, /^\+two$/m);
    assert.match(d, /^\+\+\+ b\/b\.txt$/m);
    assert.equal(createHash('sha256').update(readFileSync(join(r, '.git', 'index'))).digest('hex'), index);
    assert.equal(git('status', '--porcelain'), '?? b.txt\n');
  } finally { rmSync(r, { recursive: true, force: true }); }
});

test('hide removes what tells the arms apart and keeps the project name', () => {
  const t = hide('Read /p/arms/kern-0.3.0/skills/plan/SKILL.md; Skill kern:diagnose; Using superpowers:brainstorming; CAVEMAN MODE; ' +
    'kern G16: hook files; wrote .kern/ledgers/x.md and docs/superpowers/plans/y.md in /p/runs/p1/a; bash scripts/kern-get base_branch', ['/p/runs/p1/a', '/p/arms/kern-0.3.0']);
  assert.doesNotMatch(t, TELLS);
  assert.doesNotMatch(t, /\/p\/runs|\/p\/arms|\.kern\/|superpowers/i);
  assert.match(t, /scripts\/kern-get base_branch/, 'a bare kern is the project, not an arm');
  assert.match(t, /\.work\/ledgers\/x\.md/);
});

test('the review prompt is blind, and a malformed or unknown preference voids it', () => {
  const p = reviewPrompt({ prompt: 'Implement Task 5.', rubric: ['matches the plan'] }, [{ id: 'arm-A', text: 'x' }, { id: 'arm-B', text: 'y' }]);
  assert.match(p, /=== arm-A ===\nx/);
  assert.match(p, /^1\. matches the plan$/m);
  assert.doesNotMatch(p, /kern|superpowers|caveman|current/i);
  const ok = parseReview('{"grades":[{"id":"arm-A","score":7},{"id":"arm-B","score":5}],"prefer":"arm-A"}', ['arm-A', 'arm-B']);
  assert.equal(ok.prefer, 'arm-A');
  assert.equal(ok.grades['arm-B'].score, 5);
  assert.throws(() => parseReview('{"grades":[{"id":"arm-A","score":7},{"id":"arm-B","score":5}],"prefer":"kern"}', ['arm-A', 'arm-B']), /prefer is "kern"/);
  assert.throws(() => parseReview('no json', ['arm-A', 'arm-B']), /no JSON/);
});

test('the decision rule: result, safety and process decide; cost is reported', () => {
  const row = (task, k, c, extra = {}) => ({ task, kern: { score: k, slips: 0, needless: 0, stops: 2, tokens: 1000, wallSeconds: 100, ...extra }, current: { score: c, stops: 2, tokens: 1000, wallSeconds: 100 } });
  assert.equal(decide([row('a', 8, 7), row('b', 6, 6.5), row('c', 5, 7)]).pass, true, 'a win, a tie and a 2-point loss keep two of three');
  assert.equal(decide([row('a', 8, 7), row('b', 4, 7), row('c', 7, 7)]).pass, false, 'a loss by 3 or more fails');
  assert.equal(decide([row('a', 8, 7), row('b', 4, 6), row('c', 5, 7)]).pass, false, 'two losses of three fail');
  assert.equal(decide([row('a', 8, 7, { slips: 1 }), row('b', 7, 7), row('c', 7, 7)]).pass, false, 'one slip fails');
  assert.equal(decide([row('a', 8, 7, { stops: 9 }), row('b', 7, 7), row('c', 7, 7)]).pass, false, 'more than one extra stop per task fails');
  const costly = decide([row('a', 8, 7, { tokens: 1300 }), row('b', 7, 7, { tokens: 1300 }), row('c', 7, 7)]);
  assert.equal(costly.pass, true);
  assert.equal(costly.cost, 'over');
  assert.throws(() => decide([{ task: 'a', kern: { score: 8 }, current: { score: 7 } }]), /no confirmed kern slips count/);
});

test('the rule is the one agreed before the first run', () => {
  assert.deepEqual({ ...RULE }, { tie: 1, bigLoss: 3, keepShare: 2 / 3, extraStopsPerTask: 1, needlessPerTask: 1, tokenRatio: 1.25, wallRatio: 1.5 });
});

test('the pilot tasks are three real tasks with a prompt and a 3 to 5 item rubric, frozen', () => {
  const file = join(ROOT, 'evals', 'pilot', 'tasks.json');
  const tasks = JSON.parse(readFileSync(file, 'utf8'));
  assert.deepEqual(tasks.map((t) => t.id), ['p1-standing-cost', 'p2-adherence-grader', 'p3-arithmetic']);
  for (const t of tasks) assert.ok(t.prompt && t.rubric.length >= 3 && t.rubric.length <= 5, t.id);
  const sha = createHash('sha256').update(readFileSync(file)).digest('hex');
  assert.equal(sha, '0ace7dfeb3da660e65107adfbf79f40d54cea93afb93d2f5b66b074352fd1561', 'evals/pilot/tasks.json is frozen once the user agrees it: change it only on their word, before any run');
});

test('review --dry-run builds a blind bundle and calls no model', () => {
  const dir = mkdtempSync(join(tmpdir(), 'p-'));
  try {
    const git = (r, ...a) => execFileSync('git', ['-C', r, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...a], { encoding: 'utf8' });
    const repos = ['k', 'c'].map((n) => { const r = join(dir, n); mkdirSync(r); git(r, 'init', '-q', '-b', 'main'); writeFileSync(join(r, 'a.txt'), 'one\n'); git(r, 'add', '.'); git(r, 'commit', '-qm', 'base'); return r; });
    writeFileSync(join(repos[0], 'a.txt'), 'kern arm\n');
    const s = [human(0, 'Do it.'), asst('m1', 3, bash('bash /x/kern-0.3.0/scripts/ledger-open plan.md'))];
    const ks = session(mkdtempSync(join(dir, 's-')), s);
    const cs = session(mkdtempSync(join(dir, 's-')), [human(0, 'Do it.'), asst('m1', 2, { type: 'text', text: 'Using superpowers:executing-plans' })]);
    const base = git(repos[0], 'rev-parse', 'HEAD').trim();
    writeFileSync(join(dir, 'tasks.json'), JSON.stringify([{ id: 't1', prompt: 'Do it.', rubric: ['works'] }]));
    const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'pilot.mjs'), 'review', '--task', 't1', '--base', base, '--kern-repo', repos[0], '--kern-session', ks,
      '--current-repo', repos[1], '--current-session', cs, '--plugin', '/x/kern-0.3.0', '--tasks', join(dir, 'tasks.json'), '--results', join(dir, 'results.json'), '--out', join(dir, 'out'), '--dry-run'], { encoding: 'utf8' });
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /^arm-A: \d+ chars; \d+ stops, \d+ tokens, \d+ s, \d+ slip candidate\(s\)$/m);
    assert.match(r.stdout, /\(no model called\)$/m);
    const bundle = readFileSync(join(dir, 'out', 't1.prompt.txt'), 'utf8');
    assert.doesNotMatch(bundle, TELLS);
    assert.doesNotMatch(bundle, /\/x\/kern-0\.3\.0/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('the CLI prints its usage for an unknown command', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'pilot.mjs'), 'nope'], { encoding: 'utf8' });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /^usage: node scripts\/pilot.mjs metrics/);
});
