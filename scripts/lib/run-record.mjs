// What every eval runner records about the kern tree it measures (Task 17a, G11): what pluginCopy leaves
// out, the tree's HEAD and uncommitted changes, the refusal of a dirty tree, and the one reader of
// `git status --porcelain -z` the runners share (P5 review, Minor 9).
import { execFileSync } from 'node:child_process';

// COPY_OMITS: what pluginCopy leaves out, so a run can read none of it.
// - top: top-level names. The answer keys (evals, tests, docs) and repo internals, and the files that
//   describe the graders or the cases: CHANGELOG.md, whose Unreleased lines name what each grader checks,
//   .github's CI steps and .gitignore, which name the evals (Task 16h review, M3). .claude holds no plugin file,
//   only local worktrees and settings, and an agent worktree there is a whole copy of the repo, evals included.
// - paths: the eval runners, whose names tell a model it is being evaluated, and the repo's own eval and
//   lint tooling (route-eval, seeded-diffs, lint-skills, ci-local and the libs only they use), which reads
//   evals/ and states what a case needs, and eval-all, which starts every runner by name. No hook, skill or kernel line runs any of it.
export const COPY_OMITS = {
  top: ['.git', '.upstream', 'node_modules', 'evals', 'tests', 'docs', '.superpowers', 'CHANGELOG.md', '.github', '.gitignore', '.claude'],
  paths: [...['h2h', 'behave', 'kernel-adherence', 'standing-cost', 'pilot', 'exec-eval', 'route-eval', 'seeded-diffs', 'lint-skills'].map((f) => `scripts/${f}.mjs`), 'scripts/ci-local', 'scripts/eval-all',
    ...['h2h', 'behave', 'adherence', 'pilot', 'exec-grade', 'exec-run', 'claude-run', 'claude-drive', 'reaper', 'lint-rules', 'kernel-rows', 'rank', 'args', 'run-record', 'pool', 'case-inputs', 'eval-cache'].map((f) => `scripts/lib/${f}.mjs`)],
};

// statusEntries(dir, args): `git -C dir status --porcelain=v1 -z <args>` as [{ xy, path }], in git's order. With
// -z each entry is "XY path", and a rename or copy is followed by its source path as an entry of its own, which is
// skipped. A git failure throws, as execFileSync does, its stderr kept.
export function statusEntries(dir, args = []) {
  const entries = execFileSync('git', ['-C', dir, 'status', '--porcelain=v1', '-z', ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).split('\0');
  const out = [];
  for (let i = 0; i < entries.length; i++) {
    const [xy, path] = [entries[i].slice(0, 2), entries[i].slice(3)];
    if (!path) continue;
    if (/[RC]/.test(xy)) i += 1;
    out.push({ xy, path });
  }
  return out;
}

// UNMEASURED: the top-level names whose changes no run measures: COPY_OMITS.top but evals (the cases, fixtures
// and keys a runner reads), and the runners' own output under evals.
const UNMEASURED = new Set(COPY_OMITS.top.filter((t) => t !== 'evals'));
const OUTPUT = /^evals\/(?:snapshots|results)\//;

// treeRecord(root): the kern tree a run measures, for its snapshot (Task 17a, G11): { commit, dirty, changes }.
// commit is HEAD; changes are the `git status --porcelain --untracked-files=all` lines of what a run measures:
// what pluginCopy copies, plus evals/ (cases, fixtures, keys) and the harness under scripts/, not the snapshots
// and results the runners write, nor docs, tests, notes or worktrees; dirty is true when there is one. A root
// git cannot read gives { commit: null, dirty: true, changes: [], problem }.
export function treeRecord(root) {
  let head, entries;
  try {
    head = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    entries = statusEntries(root, ['--untracked-files=all']);
  } catch (e) {
    return { commit: null, dirty: true, changes: [], problem: `not a git checkout: ${String(e.stderr || e.message).trim().split('\n')[0]}` };
  }
  const changes = entries.filter(({ path }) => !UNMEASURED.has(path.split('/')[0]) && !OUTPUT.test(path)).map(({ xy, path }) => `${xy} ${path}`);
  return { commit: head, dirty: changes.length > 0, changes };
}

// dirtyRefusal(tree): the usage message that stops a run of a tree with uncommitted changes it would measure, or
// '' for a clean tree. Each runner refuses with it every run that writes a committed snapshot, and h2h every run
// but a dry one, since its --category runs may be the evidence. --allow-dirty runs it anyway, and the snapshot
// records the changes.
export function dirtyRefusal(tree) {
  if (!tree.dirty) return '';
  const what = tree.problem || `${tree.changes.length} uncommitted change(s) a run would measure: ${tree.changes.slice(0, 5).join(', ')}${tree.changes.length > 5 ? ', ...' : ''}`;
  return `the kern tree is not a clean commit (${what}); commit first, or pass --allow-dirty to run anyway (the snapshot records the changes)`;
}
