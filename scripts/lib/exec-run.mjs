// The control flow of scripts/exec-eval.mjs, apart from claude, git and the filesystem so a test can
// drive it with an injected runner: argument checking, the order of results, the snapshot rule and the
// one place the exit code is decided.

export class UsageError extends Error {}

// parseArgs(args, ids): { only, dryRun }. A --case with no value or an id no case has is a usage
// error: an unrecognised argument must never widen into a paid run of every case.
export function parseArgs(args, ids) {
  let only = null, dryRun = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--dry-run') dryRun = true;
    else if (args[i] === '--case') {
      const v = args[i + 1];
      if (v === undefined || v.startsWith('--')) throw new UsageError('--case needs a case id');
      if (!ids.includes(v)) throw new UsageError(`no case named ${v}; cases: ${ids.join(', ')}`);
      only = v;
      i += 1;
    } else throw new UsageError(`unknown argument ${args[i]}`);
  }
  return { only, dryRun };
}

// exitCode(results): 0 only when at least one case ran and every case that ran passed.
export const exitCode = (results) => (results.length > 0 && results.every((r) => r.pass) ? 0 : 1);

// runEval({ cases, only, dryRun, runCase, describe, writeSnapshot, log }): runs the cases in order, writes
// the snapshot only for a full run, and returns the exit code for every non-dry run alike.
export function runEval({ cases, only, dryRun, runCase, describe, writeSnapshot, log }) {
  if (dryRun) {
    for (const c of cases) log(describe(c));
    return 0;
  }
  const results = [];
  for (const c of cases) {
    const r = runCase(c);
    results.push(r);
    log(`${r.pass ? 'PASS' : r.invalid ? 'INVALID' : 'FAIL'} ${c.id}${r.pass ? '' : `: ${r.reasons.join('; ')}`}`);
  }
  if (only) log('--case run: no snapshot written; a full run writes it');
  else writeSnapshot(results);
  return exitCode(results);
}
