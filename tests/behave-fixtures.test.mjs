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
test('the three cases that edit sit on a feature branch kern does not protect, with an origin (task-16-diagnosis X1)', () => {
  withCase(DEFAULT, (ws) => assert.equal(protectedHere(ws), 0, 'the default workspace sits on a protected main'));
  for (const id of ['workflow-define-fast-path', 'pressure-implement-test-after', 'pressure-diagnose-obvious-fix']) {
    assert.equal(CASES.get(id).origin, true, `${id}: no origin`);
    withCase(id, (ws) => assert.equal(protectedHere(ws), 1, `${id}: implement step 1 would stop on this branch`));
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
