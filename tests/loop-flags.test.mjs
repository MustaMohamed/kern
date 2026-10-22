// tests/loop-flags.test.mjs: the flags every eval runner shares for fast rounds (args.mjs LOOP_FLAGS, loopProblem).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LOOP_FLAGS, UsageError, loopProblem, parseArgs } from '../scripts/lib/args.mjs';

const flags = { ...LOOP_FLAGS, '--case': { key: 'case', value: 'a case id' }, '--runs': { key: 'runs', value: 'count' }, '--dry-run': { key: 'dryRun' } };
const read = (...a) => parseArgs(a, flags);

test('LOOP_FLAGS reads --jobs as a count, --changed, --regrade and --resume as values, --quick and --no-cache as switches', () => {
  assert.deepEqual(read('--jobs', '4', '--quick', '--no-cache', '--changed', 'HEAD~1..HEAD'), { jobs: 4, quick: true, noCache: true, changed: 'HEAD~1..HEAD' });
  assert.deepEqual(read('--regrade', 'evals/results/x'), { regrade: 'evals/results/x' });
  assert.deepEqual(read('--resume', 'evals/results/x', '--jobs', '2'), { resume: 'evals/results/x', jobs: 2 });
  for (const bad of [['--jobs', '0'], ['--jobs'], ['--changed'], ['--regrade', '--quick']]) assert.throws(() => read(...bad), UsageError, bad.join(' '));
});

test('loopProblem refuses the combinations that would not mean one thing', () => {
  const p = (...a) => loopProblem(read(...a), { select: ['case'] });
  assert.equal(p('--quick', '--jobs', '3', '--changed', 'HEAD'), '');
  assert.equal(p('--resume', 'd', '--jobs', '2', '--no-cache'), '');
  assert.equal(p('--regrade', 'd'), '');
  assert.match(p('--regrade', 'd', '--jobs', '2'), /^--regrade <dir> takes no other flag/);
  assert.match(p('--regrade', 'd', '--dry-run'), /^--regrade <dir> takes no other flag/);
  assert.match(p('--resume', 'd', '--runs', '1'), /^--resume <dir> takes only --jobs and --no-cache/);
  assert.match(p('--resume', 'd', '--quick'), /^--resume <dir> takes only --jobs and --no-cache/);
  assert.match(p('--quick', '--runs', '2'), /^--quick runs each case once/);
  assert.match(p('--changed', 'HEAD', '--case', 'x'), /^--changed picks the cases itself/);
});
