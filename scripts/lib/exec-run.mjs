// The control flow of scripts/exec-eval.mjs, apart from claude, git and the filesystem so a test can
// drive it with an injected runner: argument checking, the order of results, the snapshot rule and the
// one place the exit code is decided.

import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { ISOLATION, PERMISSIONS } from './claude-run.mjs';

export class UsageError extends Error {}

// What a pass assumes about the host, recorded in every snapshot.
export const ASSUMES = 'Bash is pre-approved (--allowedTools Bash), so Claude Code never asks: a pass shows what kern allows, asks and denies, not the prompts a user who has not allowed Bash would see (kern gives git add no autopilot allow, for one)';

// caseEnv({ bin, path, log, pr, snapshot }): the variables a case's claude run gets on top of the
// inherited ones: the gh stub first on PATH, its log and PR state, a gh token that cannot reach
// GitHub, and KERN_SHELL_SNAPSHOT naming an empty file, so the hooks read no alias or function from the
// host's own shell snapshot.
export function caseEnv({ bin, path, log, pr, snapshot }) {
  return { PATH: `${bin}:${path}`, KERN_EXEC_LOG: log, KERN_EXEC_PR: pr, GH_TOKEN: 'invalid', GH_HOST: 'example.invalid', KERN_SHELL_SNAPSHOT: snapshot };
}

// userSettingsProblem(home, env): why a run must not start, or ''. kern's hooks read the user layer
// $HOME/.claude/kern.yml directly, past --setting-sources, so a host scope_threshold or push.policy
// would change the outcomes; KERN_EXEC_ALLOW_USER_SETTINGS=1 runs anyway, and the snapshot says so.
export function userSettingsProblem(home, env) {
  const f = join(home || '', '.claude', 'kern.yml');
  if (!home || !existsSync(f) || env.KERN_EXEC_ALLOW_USER_SETTINGS === '1') return '';
  return `${f} exists, and kern's hooks in the run would read it; move it aside, or set KERN_EXEC_ALLOW_USER_SETTINGS=1 to run with it (the snapshot records that)`;
}

// snapshotBody({ model, claude, results, userSettings }): what a full run's snapshot holds.
export function snapshotBody({ model, claude, results, userSettings }) {
  return { model, claude, isolation: ISOLATION, permissions: PERMISSIONS, assumes: ASSUMES,
    user_settings: userSettings ? 'a ~/.claude/kern.yml was present and read, allowed by KERN_EXEC_ALLOW_USER_SETTINGS=1' : 'none', results };
}

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

// runEval({ cases, only, dryRun, runCase, describe, readVersion, writeSnapshot, log }): reads the claude
// version first, so a failure there stops the run before any case is paid for; then runs the cases in
// order, writes the snapshot (results, version) only for a full run with at least one valid case, so an
// all-INVALID run never replaces a same-day snapshot, and returns the exit code for every non-dry run
// alike.
export function runEval({ cases, only, dryRun, runCase, describe, readVersion, writeSnapshot, log }) {
  if (dryRun) {
    for (const c of cases) log(describe(c));
    return 0;
  }
  let version;
  try { version = readVersion(); } catch (e) {
    log(`exec-eval: cannot read the claude version (${e.message.split('\n')[0]}); nothing ran`);
    return 1;
  }
  const results = [];
  for (const c of cases) {
    const r = runCase(c);
    results.push(r);
    log(`${r.pass ? 'PASS' : r.invalid ? 'INVALID' : 'FAIL'} ${c.id}${r.pass ? '' : `: ${r.reasons.join('; ')}`}`);
  }
  if (only) log('--case run: no snapshot written; a full run writes it');
  else if (!results.some((r) => !r.invalid)) log('no case was valid: no snapshot written, and any earlier one stays');
  else writeSnapshot(results, version);
  return exitCode(results);
}
