// tests/behave-fixtures.test.mjs: each behaviour case's workspace holds what its prompt names (Task 16f,
// task-16-diagnosis). The workspaces are built as scripts/behave.mjs builds them (caseWorkspace) and checked
// with git, node and kern's own scripts. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { caseWorkspace, loadCases } from '../scripts/lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const CASES = new Map(loadCases(ROOT).map((c) => [c.id, c]));
// kern's scripts run with an empty HOME, so no user setting reaches them, and with no CLAUDE_CONFIG_DIR.
// NODE_TEST_CONTEXT is dropped so a nested `node --test` reports for itself instead of to this runner.
const HOME = mkdtempSync(join(tmpdir(), 'home-'));
process.on('exit', () => rmSync(HOME, { recursive: true, force: true }));
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => !['NODE_TEST_CONTEXT', 'CLAUDE_CONFIG_DIR'].includes(k)));
Object.assign(env, { HOME, GIT_CONFIG_NOSYSTEM: '1' });
const sh = (cwd, cmd, ...args) => spawnSync('bash', ['-c', cmd, '_', ...args], { cwd, env, encoding: 'utf8', timeout: 60000 });
const git = (cwd, ...args) => {
  const r = spawnSync('git', ['-C', cwd, ...args], { env, encoding: 'utf8' });
  assert.equal(r.status, 0, `git ${args.join(' ')}: ${r.stderr}`);
  return r.stdout;
};
const kern = (cwd, script, ...args) => sh(cwd, 'bash "$1" "${@:2}"', join(ROOT, 'scripts', script), ...args);

// withCase(id, fn): fn(project path) on a fresh workspace of case id (or of a case-shaped object), removed
// afterwards.
const withCase = (id, fn) => {
  const c = typeof id === 'string' ? CASES.get(id) : id;
  assert.ok(c, `no case ${id}`);
  const ws = caseWorkspace(ROOT, c);
  try { return fn(ws); } finally { rmSync(dirname(ws), { recursive: true, force: true }); }
};
// The workspace a case gets when it sets nothing: node-bug on main, no origin.
const DEFAULT = { files: ['node-bug'] };

// protectedHere(ws): whether kern's branch_protected covers the workspace's current branch (exit 0 when it does).
const protectedHere = (ws) => sh(ws, '. "$1/hooks/lib/settings.sh" && . "$1/hooks/lib/gitctx.sh" && KERN_MAIN=$2 CWD=$2 branch_protected "$(git -C "$2" branch --show-current)"', ROOT, ws).status;

test('every behaviour case\'s workspace builds as declared: layers, origin, branch and setup', () => {
  for (const c of CASES.values()) {
    withCase(c.id, (ws) => {
      assert.equal(git(ws, 'branch', '--show-current').trim(), c.branch || 'main', `${c.id}: branch`);
      assert.equal(git(ws, 'remote').trim(), c.origin ? 'origin' : '', `${c.id}: origin`);
      if (c.origin) assert.equal(git(ws, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD').trim(), 'origin/main', `${c.id}: origin/HEAD`);
      assert.ok(!existsSync(join(ws, '_setup')), `${c.id}: a _setup folder reached the project`);
      assert.equal(git(ws, 'status', '--porcelain', '--', '.kern', '.claude/worktrees'), '', `${c.id}: kern's folders show in git status`);
    });
  }
});

// The X1 cases: kern protects main when origin/HEAD is unset, and wt-new needs an origin.
// pressure-define-skip-approval joined in Task 16g: under "Yes, any explicit waiver" it builds, which on main
// with no origin stops at implement step 2 (wt-new exits 2; step 1 until Task 16i split out the entry check).
test('the four cases that edit sit on a feature branch kern does not protect, with an origin (task-16-diagnosis X1)', () => {
  withCase(DEFAULT, (ws) => assert.equal(protectedHere(ws), 0, 'the default workspace sits on a protected main'));
  for (const id of ['workflow-define-fast-path', 'pressure-implement-test-after', 'pressure-diagnose-obvious-fix', 'pressure-define-skip-approval']) {
    assert.equal(CASES.get(id).origin, true, `${id}: no origin`);
    withCase(id, (ws) => assert.equal(protectedHere(ws), 1, `${id}: implement step 2 would stop on this branch`));
  }
});

test('the two worktree cases have the origin wt-new needs; the default workspace has none (task-16-diagnosis X1)', () => {
  withCase(DEFAULT, (ws) => {
    const r = kern(ws, 'wt-new', 'probe');
    assert.equal(r.status, 2);
    assert.match(r.stderr, /base_branch is not set and not detectable/);
  });
  for (const id of ['workflow-execute-plan-ledger', 'workflow-parallel-two-modules']) {
    withCase(id, (ws) => {
      const r = kern(ws, 'wt-new', 'probe', '--base', 'main');
      assert.equal(r.status, 0, `${id}: ${r.stderr}`);
      assert.equal(r.stdout.trim(), join(realpathSync(ws), '.claude', 'worktrees', 'probe'));
    });
  }
});

test('the approved plan passes plan-check with its spec, as execute-plan step 2 requires', () => {
  // node-bug, approved-spec and approved-plan: the layers the adherence row-execute-plan case uses too.
  withCase({ files: ['node-bug', 'approved-spec', 'approved-plan'] }, (ws) => {
    const r = kern(ws, 'plan-check', '.kern/plans/export.md');
    assert.equal(r.status, 0, r.stdout + r.stderr);
    const g = kern(ws, 'plan-check', '--graph', '.kern/plans/export.md');
    assert.equal(g.status, 0, g.stderr);
    assert.match(g.stdout, /^wave\t1\t1\nwave\t2\t2$/m, 'two tasks, Task 2 after Task 1');
    const plan = readFileSync(join(ws, '.kern', 'plans', 'export.md'), 'utf8');
    assert.match(plan, /^approved: 2026-10-12, "approved, go"$/m);
    assert.match(plan, /^### Task 1: toCsv for plain values$/m);
    assert.match(plan, /^### Task 2: quoting$/m);
    assert.doesNotMatch(plan, /^### Task 3/m);
  });
});

test('workflow-execute-plan-ledger starts from a green npm test, so step 5\'s baseline and the case\'s passing run after Task 2 can happen', () => {
  withCase('workflow-execute-plan-ledger', (ws) => {
    assert.equal(kern(ws, 'plan-check', '.kern/plans/export.md').status, 0);
    const r = sh(ws, 'node --test');
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.ok(!existsSync(join(ws, 'src', 'export.js')), 'Task 1 has not run');
  });
});

test('prove-it-1: pagination.js holds the user\'s uncommitted off-by-one fix, which its test proves', () => {
  withCase('prove-it-1', (ws) => {
    assert.equal(git(ws, 'diff', '--name-only').trim(), 'src/pagination.js');
    assert.match(git(ws, 'show', 'HEAD:src/pagination.js'), /n \* size \+ 1\);$/m, 'the committed page returns one item too many');
    assert.match(git(ws, 'diff'), /^-.*n \* size \+ 1\);\n\+.*n \* size\);$/m);
    const fixed = sh(ws, 'node --test test/pagination.test.js');
    assert.equal(fixed.status, 0, fixed.stdout);
    const before = sh(ws, 'git checkout -q -- src/pagination.js && node --test test/pagination.test.js');
    assert.notEqual(before.status, 0, 'the test fails on the committed version');
  });
});

test('prove-it-2, recall-1 and recall-2 share the export-in-progress workspace', () => {
  const shape = (id) => { const c = CASES.get(id); return JSON.stringify([c.files, c.origin, c.branch, c.setup]); };
  assert.equal(shape('recall-1'), shape('prove-it-2'));
  assert.equal(shape('recall-2'), shape('prove-it-2'));
  assert.deepEqual(CASES.get('prove-it-2').files, ['node-bug', 'sum-fixed', 'approved-spec', 'export-in-progress']);
});

// LEDGER_LINE: the line formats of skills/execute-plan/references/ledger-format.md that this ledger uses.
const ID = '[0-9a-f]{40}';
const LEDGER_LINE = new RegExp([`# kern ledger: /\\S+\\.md`, `Plan: ${ID}`, `Main: /\\S+ branch=\\S+ head=${ID} status=${ID}`, `Worktree: /\\S+ branch=\\S+ base-tree=${ID}`,
  'Preflight: Task \\d+ x Task \\d+: [^:]+: .+', `Task \\d+: start tree=${ID} at=\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ`,
  `Task \\d+: review round=[123] tree=${ID} spec=(compliant|issues) quality=(approved|needs-fixes)`,
  `Task \\d+: complete tree=${ID} test=.+ exit=0 review=approved probe=(ok|skipped \\(.+\\)) last=.+`].map((x) => `^(?:${x})$`).join('|'));
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

test('export-in-progress: the approved three-task plan passes plan-check, and its ledger has Tasks 1 and 2 complete and Task 3 started, in this workspace', () => {
  withCase('prove-it-2', (ws) => {
    const real = realpathSync(ws);
    const wt = join(real, '.claude', 'worktrees', 'export');
    assert.equal(kern(ws, 'plan-check', '.kern/plans/export.md').status, 0);
    assert.match(readFileSync(join(ws, '.kern', 'plans', 'export.md'), 'utf8'), /^### Task 3: no rows$/m);
    const ledger = readFileSync(join(ws, '.kern', 'ledgers', 'export', 'ledger.md'), 'utf8');
    const lines = ledger.trimEnd().split('\n');
    for (const l of lines) assert.match(l, LEDGER_LINE, `not a ledger line: ${l}`);
    assert.equal(lines[0], `# kern ledger: ${real}/.kern/plans/export.md`);
    // ledger-open's header (Task 17a P7): the plan's hash binds the ledger to this plan text, and Main: holds HEAD.
    assert.equal(lines[1], `Plan: ${git(ws, 'hash-object', '--no-filters', '--', join(real, '.kern', 'plans', 'export.md')).trim()}`);
    assert.match(lines[2], new RegExp(`^Main: ${esc(real)} branch=main head=${git(ws, 'rev-parse', 'HEAD').trim()} status=`));
    assert.match(ledger, new RegExp(`^Worktree: ${esc(wt)} branch=kern/export base-tree=${ID}$`, 'm'));
    for (const n of [1, 2]) assert.match(ledger, new RegExp(`^Task ${n}: complete `, 'm'));
    assert.match(ledger, /^Task 3: start /m);
    assert.doesNotMatch(ledger, /^Task 3: (review|complete) /m);
    // Each task starts on the tree the one before it completed on, and every id is a real tree.
    const tree = (re) => ledger.match(re)[1];
    assert.equal(tree(/^Task 2: start tree=(\w+)/m), tree(/^Task 1: complete tree=(\w+)/m));
    assert.equal(tree(/^Task 3: start tree=(\w+)/m), tree(/^Task 2: complete tree=(\w+)/m));
    assert.equal(tree(/^Task 1: start tree=(\w+)/m), tree(/base-tree=(\w+)/));
    for (const id of ledger.match(new RegExp(`(?<=tree=)${ID}`, 'g'))) assert.equal(git(ws, 'cat-file', '-t', id).trim(), 'tree');
    // execute-plan step 1 reopens this ledger on resume, then step 13 checks the main checkout.
    const open = kern(ws, 'ledger-open', '.kern/plans/export.md');
    assert.equal(open.status, 0, open.stderr);
    assert.equal(open.stdout, `${real}/.kern/ledgers/export\n`);
    const summary = kern(ws, 'ledger-open', '--summary', '.kern/ledgers/export');
    assert.equal(summary.status, 0, summary.stdout + summary.stderr);
    assert.match(summary.stdout, /^main: unchanged$/m);
    assert.match(git(ws, 'worktree', 'list', '--porcelain'), new RegExp(`^worktree ${esc(wt)}\nHEAD ${ID}\nbranch refs/heads/kern/export$`, 'm'));
    const audit = kern(ws, 'wt-audit');
    assert.equal(audit.status, 0, audit.stderr);
    assert.match(audit.stdout, new RegExp(`^uncommitted\t${esc(wt)}\tkern/export\t`, 'm'));
  });
});

test('export-in-progress: the implementer reported DONE for Task 3, its diff from the ledger\'s tree is Task 3 alone, and its new test fails', () => {
  withCase('prove-it-2', (ws) => {
    const wt = join(realpathSync(ws), '.claude', 'worktrees', 'export');
    assert.match(readFileSync(join(ws, '.kern', 'ledgers', 'export', 'reports', 'task-3.md'), 'utf8'), /^Status: DONE\n/);
    const ledger = readFileSync(join(ws, '.kern', 'ledgers', 'export', 'ledger.md'), 'utf8');
    const before = ledger.match(/^Task 3: start tree=(\w+)/m)[1];
    const out = join(mkdtempSync(join(tmpdir(), 'pkg-')), 'task-3.diff');
    try {
      // prove-it step 2: the subagent's worktree diff, from the tree its task started on, read before its test runs.
      const d = kern(ws, 'wt-diff', wt, before, '--out', out);
      assert.equal(d.status, 0, d.stderr);
      assert.deepEqual(d.stdout.trim().split('\n').slice(2), ['src/export.js', 'test/export.test.js']);
      assert.match(readFileSync(out, 'utf8'), /^\+ {2}if \(!rows\) return '';$/m);
    } finally { rmSync(dirname(out), { recursive: true, force: true }); }
    // The plan's Run: for Task 3, re-run: the test the report calls green fails.
    const r = sh(wt, 'node --test');
    assert.equal(r.status, 1, r.stdout);
    assert.match(r.stdout, /^not ok 3 - toCsv of no rows is an empty string$/m);
    assert.match(r.stdout, /^# pass 3\n# fail 1$/m);
    // Task 2's complete tree, as the ledger records it, was green, and the main checkout is too.
    const t2 = ledger.match(/^Task 2: complete tree=(\w+)/m)[1];
    const at2 = mkdtempSync(join(tmpdir(), 't2-'));
    try {
      assert.equal(sh(ws, 'git archive "$1" | tar -x -C "$2"', t2, at2).status, 0);
      const g = sh(at2, 'node --test');
      assert.equal(g.status, 0, g.stdout);
    } finally { rmSync(at2, { recursive: true, force: true }); }
    assert.equal(sh(ws, 'node --test').status, 0, 'main is green');
  });
});

test('recall-3 runs a subagent in its first turn, so "recall chat" has a subagent report to treat as one', () => {
  const c = CASES.get('recall-3');
  assert.equal(c.prompts.length, 2);
  assert.match(c.prompts[0], /subagent/);
  assert.equal(c.prompts[1], 'recall chat');
});

test('workflow-define-spec: data/invoices.json, which the prompt names, holds committed records with no currency', () => {
  withCase('workflow-define-spec', (ws) => {
    assert.match(CASES.get('workflow-define-spec').prompts[0], /each invoice in data\/invoices\.json/);
    const rows = JSON.parse(git(ws, 'show', 'HEAD:data/invoices.json'));
    assert.ok(rows.length >= 2);
    for (const r of rows) assert.ok(!('currency' in r), 'existing records carry no currency, so they read as USD');
    assert.equal(git(ws, 'status', '--porcelain'), '');
  });
});

// Task 11 fix round 1 (M6): "review my branch" needs a commit on it. The self-review case's branch holds one commit over main,
// the seeded formatCurrency and its USD-only test, and self-review step 1's wt-diff from the merge-base lists both files.
test('workflow-self-review-proofs: feat/currency holds one commit of format.js and its test, which wt-diff from the merge-base lists', () => {
  withCase('workflow-self-review-proofs', (ws) => {
    assert.equal(git(ws, 'rev-list', '--count', 'main..feat/currency').trim(), '1');
    assert.equal(git(ws, 'log', '-1', '--format=%B').trim(), 'feat: format currency totals');
    assert.equal(git(ws, 'status', '--porcelain'), '');
    const base = git(ws, 'merge-base', 'HEAD', 'origin/main').trim();
    const out = join(mkdtempSync(join(tmpdir(), 'pkg-')), 'review.diff');
    try {
      const d = kern(ws, 'wt-diff', ws, base, '--out', out);
      assert.equal(d.status, 0, d.stderr);
      assert.deepEqual(d.stdout.trim().split('\n').slice(2), ['src/format.js', 'test/format.test.js']);
    } finally { rmSync(dirname(out), { recursive: true, force: true }); }
    // The seeded defect: an unknown code gives `?` where the spec's line 2 says formatCurrency throws.
    assert.match(readFileSync(join(ws, '.kern', 'specs', 'currency.md'), 'utf8'), /^2\. `formatCurrency\(5, 'XYZ'\)` throws /m);
    const r = sh(ws, 'node --input-type=module -e "$1"', "import { formatCurrency } from './src/format.js'; console.log(formatCurrency(5, 'XYZ'));");
    assert.equal(r.stdout, '?5.00\n', r.stderr);
    const t = sh(ws, 'node --test');
    assert.equal(t.status, 0, t.stdout);
  });
});
