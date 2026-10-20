// The control flow of scripts/exec-eval.mjs, apart from claude, git and the filesystem so a test can
// drive it with an injected runner: argument checking, the order of results, the snapshot rule and the
// one place the exit code is decided.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { ISOLATION, PERMISSIONS, runProblem } from './claude-run.mjs';
import { GRADERS, stubMissed } from './exec-grade.mjs';

export class UsageError extends Error {}

// What a pass assumes about the host, recorded in every snapshot.
export const ASSUMES = 'Bash is pre-approved (--allowedTools Bash), so Claude Code never asks: a pass shows what kern allows, asks and denies, not the prompts a user who has not allowed Bash would see (kern gives git add no autopilot allow, for one)';

// caseEnv({ bin, path, log, pr, snapshot }): the variables a case's claude run gets on top of the
// inherited ones: the gh stub first on PATH (exec-eval copies evals/exec/bin beside the workspace), its
// log and PR state, a gh token that cannot reach GitHub, and KERN_SHELL_SNAPSHOT naming an empty file, so
// the hooks read no alias or function from the host's own shell snapshot.
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

// dateStamp(date): the UTC day, YYYY-MM-DD, that names the snapshot file and the replies directory.
export const dateStamp = (date = new Date()) => date.toISOString().slice(0, 10);
export const replyDate = dateStamp;

// writeReply(dir, id, reply, reason): <dir>/<id>.txt holds the case's final reply, the text the graders
// read; with no reply it holds the one line (no reply: <reason>).
export function writeReply(dir, id, reply, reason) {
  mkdirSync(dir, { recursive: true });
  const body = reply?.trim() ? (reply.endsWith('\n') ? reply : `${reply}\n`) : `(no reply: ${reason || 'the run ended with no assistant text'})\n`;
  writeFileSync(join(dir, `${id}.txt`), body);
}

// writeEvents(dir, id, events): <dir>/<id>.events.jsonl holds the run's stream-json events, one per line,
// tool results included, so a deny reason the model never repeated can be read after the run.
export function writeEvents(dir, id, events) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${id}.events.jsonl`), events.map((e) => `${JSON.stringify(e)}\n`).join(''));
}

// claudeConfigDir(env): the config dir the child claude uses, which childEnv passes through.
export const claudeConfigDir = (env) => env.CLAUDE_CONFIG_DIR || join(env.HOME || homedir(), '.claude');

// sessionId(events): the session id the stream's system/init events name, or '' when there is none or
// they name more than one.
export function sessionId(events) {
  const ids = new Set(events.filter((e) => e?.type === 'system' && e.subtype === 'init' && typeof e.session_id === 'string').map((e) => e.session_id));
  return ids.size === 1 ? [...ids][0] : '';
}

// kernStateFile(configDir, sid): kern's state file for session sid when kern is loaded with --plugin-dir,
// whose CLAUDE_PLUGIN_DATA is <config dir>/plugins/data/kern-inline.
export const kernStateFile = (configDir, sid) => join(configDir, 'plugins', 'data', 'kern-inline', 'sessions', `${sid}.state`);

// autopilotProblem(events, configDir, read): why kern's hooks did not hold autopilot on at the end of the
// run, or ''. It reads the session's state file the way state_get does: the last `autopilot: ` line.
export function autopilotProblem(events, configDir, read = (f) => readFileSync(f, 'utf8')) {
  const why = "autopilot was not on in kern's hooks";
  const sid = sessionId(events);
  if (!sid) return `${why}: the stream has no single session id in a system/init event, so kern's state cannot be read`;
  if (!/^[A-Za-z0-9_-]+$/.test(sid)) return `${why}: ${JSON.stringify(sid)} is not a session id kern uses`;
  const f = kernStateFile(configDir, sid);
  let text;
  try { text = read(f); } catch (e) { return `${why}: cannot read ${f} (${e.code || e.message})`; }
  const v = [...text.matchAll(/^autopilot: (.*)$/gm)].pop()?.[1];
  return v === 'on' ? '' : `${why}: ${f} says autopilot: ${v ?? '(unset)'}`;
}

// casePrompts(c): the prompts a case sends, each its own turn: `/kern:autopilot on` first when the case
// turns autopilot on (a local command, which prints its own result event), then the case's turn.
export const casePrompts = (c) => [...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn];

// gradeCase({ c, run, ghLog, git, configDir, graders, read }): a case's verdict. INVALID when the run
// may not be graded (runProblem, which also wants one result event per prompt of casePrompts), when the
// gh stub missed a call, or, for a case that turns autopilot on, when kern's state for the run does not
// read autopilot: on (the run did not test autopilot, whatever it did); else the case's grader decides,
// and a grader that throws is INVALID too. An autopilot INVALID still runs the grader and keeps its
// verdict after its own reason, each as `grader: <reason>` (`grader: pass` when it passed), so the run
// says what it did as well as why it does not count.
export function gradeCase({ c, run, ghLog, git, configDir, graders = GRADERS, read }) {
  const invalid = (why) => ({ pass: false, invalid: true, reasons: [why] });
  const problem = runProblem(run, casePrompts(c).length);
  if (problem) return invalid(problem);
  const missed = stubMissed(run.events, ghLog);
  if (missed.length) return invalid(`the stub never logged \`gh ${missed[0]}\`: the Bash tool did not see the gh stand-in from evals/exec/bin first on PATH`);
  let g;
  try { g = graders[c.id]({ events: run.events, ghLog, git, branch: c.branch }); } catch (e) { g = invalid(`grader error: ${e.message}`); }
  const off = c.autopilot ? autopilotProblem(run.events, configDir, read) : '';
  if (!off) return g;
  const graded = g.invalid ? g.reasons : g.pass ? ['grader: pass'] : g.reasons.map((r) => `grader: ${r}`);
  return { pass: false, invalid: true, reasons: [off, ...graded] };
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
// alike. Each runCase gets a save({ reply, reason, events }) to call before its workspace goes; it saves the
// reply, then the events when saveEvents is given; the last line names the replies directory.
export function runEval({ cases, only, dryRun, runCase, describe, readVersion, writeSnapshot, saveReply, saveEvents, repliesDir, log }) {
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
    // Best effort: a failed write is logged, never thrown, so it cannot end a paid run or hide a verdict.
    const attempt = (what, write) => {
      try {
        if (!/^[\w.-]+$/.test(c.id)) throw new Error('case id is not a safe file name');
        write();
      } catch (e) { log(`replies: could not write ${c.id}${what}: ${e.message}`); }
    };
    const save = ({ reply, reason, events } = {}) => {
      attempt('', () => saveReply(c.id, reply, reason));
      if (events && saveEvents) attempt(' events', () => saveEvents(c.id, events));
    };
    const r = runCase(c, save);
    results.push(r);
    log(`${r.pass ? 'PASS' : r.invalid ? 'INVALID' : 'FAIL'} ${c.id}${r.pass ? '' : `: ${r.reasons.join('; ')}`}`);
  }
  if (only) log('--case run: no snapshot written; a full run writes it');
  else if (!results.some((r) => !r.invalid)) log('no case was valid: no snapshot written, and any earlier one stays');
  else writeSnapshot(results, version);
  log(`replies: ${repliesDir}`);
  return exitCode(results);
}
