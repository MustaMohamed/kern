// The control flow of scripts/exec-eval.mjs, apart from claude, git and the filesystem so a test can
// drive it with an injected runner: argument checking, the order of results, the snapshot rule and the
// one place the exit code is decided.

import { execFileSync } from 'node:child_process';
import { chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { LOOP_FLAGS, UsageError, loopProblem, parseArgs as parseFlags } from './args.mjs';
import { ISOLATION, PERMISSIONS, pluginProblem, runProblem } from './claude-run.mjs';
import { openRun, readRecord, reuseNote, roundLine, timeStamp } from './eval-cache.mjs';
import { GRADERS, stubMissed } from './exec-grade.mjs';
import { limiter, ordered } from './pool.mjs';

export { UsageError };

// What a pass assumes about the host, recorded in every snapshot.
export const ASSUMES = 'Bash is pre-approved (--allowedTools Bash), so Claude Code never asks: a pass shows what kern allows, asks and denies, not the prompts a user who has not allowed Bash would see (kern gives git add no autopilot allow, for one)';

// caseEnv({ bin, path, log, pr, snapshot, trace }): the variables a case's claude run gets on top of the
// inherited ones: the gh stub first on PATH (exec-eval copies evals/exec/bin beside the workspace), its
// log and PR state, a gh token that cannot reach GitHub, KERN_SHELL_SNAPSHOT naming an empty file, so
// the hooks read no alias or function from the host's own shell snapshot, and KERN_EXEC_TRACE naming the
// case's hook trace (traceHooks), which childEnv passes on by its KERN_EXEC_ prefix.
export function caseEnv({ bin, path, log, pr, snapshot, trace }) {
  return { PATH: `${bin}:${path}`, KERN_EXEC_LOG: log, KERN_EXEC_PR: pr, GH_TOKEN: 'invalid', GH_HOST: 'example.invalid', KERN_SHELL_SNAPSHOT: snapshot,
    ...(trace ? { KERN_EXEC_TRACE: trace } : {}) };
}

// traceHooks(plugin, script): makes the plugin copy at plugin run each of its hooks through script
// (evals/exec/hooks/trace, written to the copy as hooks/trace): a hook `command` with `args` becomes
// `bash ${CLAUDE_PLUGIN_ROOT}/hooks/trace <command> <args>...`, every other field kept. The trace runs the
// hook unchanged and, while KERN_EXEC_TRACE names a file, appends one JSON line per call to it: the hook
// input, the Claude Code variables, kern's view of the session and the hook's output (Task 16l). Only the
// copy's hooks.json is rewritten; a hook with no args list throws rather than run untraced.
export function traceHooks(plugin, script) {
  const file = join(plugin, 'hooks', 'hooks.json');
  const config = JSON.parse(readFileSync(file, 'utf8'));
  for (const [event, matchers] of Object.entries(config.hooks)) {
    for (const h of matchers.flatMap((m) => m.hooks)) {
      if (h.type !== 'command' || typeof h.command !== 'string' || !Array.isArray(h.args)) throw new Error(`traceHooks: a ${event} hook has no command with an args list: ${JSON.stringify(h)}`);
      h.args = ['${CLAUDE_PLUGIN_ROOT}/hooks/trace', h.command, ...h.args];
      h.command = 'bash';
    }
  }
  copyFileSync(script, join(plugin, 'hooks', 'trace'));
  chmodSync(join(plugin, 'hooks', 'trace'), 0o755);
  writeFileSync(file, `${JSON.stringify(config, null, 2)}\n`);
}

// userSettingsProblem(home, env): why a run must not start, or ''. kern's hooks read the user layer
// $HOME/.claude/kern.yml directly, past --setting-sources, so a host scope_threshold or push.policy
// would change the outcomes; KERN_EXEC_ALLOW_USER_SETTINGS=1 runs anyway, and the snapshot says so.
export function userSettingsProblem(home, env) {
  const f = join(home || '', '.claude', 'kern.yml');
  if (!home || !existsSync(f) || env.KERN_EXEC_ALLOW_USER_SETTINGS === '1') return '';
  return `${f} exists, and kern's hooks in the run would read it; move it aside, or set KERN_EXEC_ALLOW_USER_SETTINGS=1 to run with it (the snapshot records that)`;
}

// snapshotBody({ model, claude, results, userSettings, tree }): what a full run's snapshot holds; tree is the
// kern tree it measured (treeRecord: HEAD, dirty and the changes; Task 17a G11), kept as kern.
export function snapshotBody({ model, claude, results, userSettings, tree = null }) {
  return { model, claude, isolation: ISOLATION, permissions: PERMISSIONS, assumes: ASSUMES,
    user_settings: userSettings ? 'a ~/.claude/kern.yml was present and read, allowed by KERN_EXEC_ALLOW_USER_SETTINGS=1' : 'none', kern: tree, results };
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

// writeTrace(dir, id, file): <dir>/<id>.trace.jsonl is a copy of the case's hook trace file, beside its
// events.
export function writeTrace(dir, id, file) {
  mkdirSync(dir, { recursive: true });
  copyFileSync(file, join(dir, `${id}.trace.jsonl`));
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
// turns autopilot on (a local command, which prints its own result event), then the case's turns: its
// `turns` list when it has one (pilot fix plan 2, Task 10), else its one `turn`.
export const casePrompts = (c) => [...(c.autopilot ? ['/kern:autopilot on'] : []), ...(c.turns ?? [c.turn])];

// gradeCase({ c, run, ghLog, git, configDir, plugin, graders, read }): a case's verdict. INVALID when the run
// may not be graded (runProblem, which also wants one result event per prompt of casePrompts), when, given
// plugin (the kern copy's path), the run did not load it or print the kernel (pluginProblem), when the
// gh stub missed a call, or, for a case that turns autopilot on, when kern's state for the run does not
// read autopilot: on (the run did not test autopilot, whatever it did); else the case's grader decides,
// and a grader that throws is INVALID too. An autopilot INVALID still runs the grader and keeps its
// verdict after its own reason, each as `grader: <reason>` (`grader: pass` when it passed), so the run
// says what it did as well as why it does not count.
export function gradeCase({ c, run, ghLog, git, configDir, plugin = null, graders = GRADERS, read }) {
  const invalid = (why) => ({ pass: false, invalid: true, reasons: [why] });
  const problem = runProblem(run, casePrompts(c).length) || (plugin ? pluginProblem(run.events, { plugins: [plugin], kernel: 'on' }) : '');
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

// parseArgs(args, ids): { only, dryRun, allowDirty }, and each loop flag given (LOOP_FLAGS: jobs, quick, changed,
// regrade, resume, noCache), read by the runners' shared parser (args.mjs). A --case with no value or an id no case
// has is a usage error, and so is any other word, or loop flags that do not go together (loopProblem): an
// unrecognised argument must never widen into a paid run of every case. --allow-dirty lets a full run measure a kern
// tree with uncommitted changes.
const LOOP_KEYS = new Set(Object.values(LOOP_FLAGS).map((x) => x.key));
export function parseArgs(args, ids) {
  const o = parseFlags(args, { '--case': { key: 'only', value: 'a case id', choices: ids, noun: 'case' }, '--dry-run': { key: 'dryRun' }, '--allow-dirty': { key: 'allowDirty' }, ...LOOP_FLAGS });
  const loop = loopProblem(o, { select: { only: '--case' } });
  if (loop) throw new UsageError(loop);
  return { only: o.only ?? null, dryRun: !!o.dryRun, allowDirty: !!o.allowDirty, ...Object.fromEntries(Object.entries(o).filter(([k]) => LOOP_KEYS.has(k))) };
}

// execParts(c): what case c reads, for its input hash and --changed (case-inputs.mjs): the kern skills its prompts
// call (/kern:<name>, /kern:autopilot on among them), the fixture repo, the gh stand-in and the hook trace, and its
// entry in evals/exec/cases.json.
export const execParts = (c) => ({ skills: [...new Set(casePrompts(c).flatMap((p) => [...p.matchAll(/\/kern:([a-z][a-z0-9-]*)/g)].map((m) => m[1])))],
  paths: ['evals/exec/fixtures/app/', 'evals/exec/bin/', 'evals/exec/hooks/'], entries: [{ file: 'evals/exec/cases.json', pick: (j) => (Array.isArray(j) ? j.find((x) => x.id === c.id) : undefined) }] });

// exitCode(results): 0 only when at least one case ran and every case that ran passed.
export const exitCode = (results) => (results.length > 0 && results.every((r) => r.pass) ? 0 : 1);

// runEval({ cases, only, dryRun, runCase, describe, readVersion, writeSnapshot, log, jobs, limit, snapshot, mode, unit }):
// reads the claude version first, so a failure there stops the run before any case is paid for; then runs the cases
// in a pool (pool.mjs): limit, or a limiter of jobs (6 by default). A case runs through unit(c, work) when unit is given
// (the result cache and --resume, which takes a slot of limit for work; its result may carry how it was got and
// cached, its provenance), else in a slot of its own; runEval logs and keeps the results in case order. The first fatal error stops new cases; running ones finish, and the error is thrown. snapshot says where
// the results go: 'committed' (a full run: written only with at least one valid case, so an all-INVALID run never
// replaces a same-day snapshot), 'beside' (a --quick or --changed run, mode naming it: always, beside the replies) or
// 'none' (a --case run); writeSnapshot(results, version, snapshot) writes it. It returns the exit code for every
// non-dry run alike. Each runCase gets a save({ reply, reason, events, trace }) to call before its workspace goes; it
// saves the reply, then the events when saveEvents is given, then the hook trace file when saveTrace is; the last line
// names the replies directory.
export async function runEval({ cases, only, dryRun, runCase, describe, readVersion, writeSnapshot, saveReply, saveEvents, saveTrace, repliesDir, log, jobs = 6,
  limit = limiter(jobs), snapshot = only ? 'none' : 'committed', mode = '--case', unit = (c, work) => limit.run(work) }) {
  const t0 = Date.now();
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
  const how = [];
  let stop = null;
  const fail = (e) => { if (!stop) { stop = e; limit.close(e); } throw e; };
  const emit = ordered(cases.length, (k, r) => {
    const { how: got, ...kept } = r;
    how.push({ how: got ?? 'ran' });
    results.push(kept);
    log(`${r.pass ? 'PASS' : r.invalid ? 'INVALID' : 'FAIL'} ${cases[k].id}${r.pass ? '' : `: ${r.reasons.join('; ')}`}${reuseNote([{ how: got }])}`);
  });
  const jobsDone = cases.map((c, k) => {
    // Best effort: a failed write is logged, never thrown, so it cannot end a paid run or hide a verdict.
    const attempt = (what, write) => {
      try {
        if (!/^[\w.-]+$/.test(c.id)) throw new Error('case id is not a safe file name');
        write();
      } catch (e) { log(`replies: could not write ${c.id}${what}: ${e.message}`); }
    };
    const save = ({ reply, reason, events, trace } = {}) => {
      attempt('', () => saveReply(c.id, reply, reason));
      if (events && saveEvents) attempt(' events', () => saveEvents(c.id, events));
      if (trace && saveTrace) attempt(' trace', () => saveTrace(c.id, trace));
    };
    return Promise.resolve(unit(c, () => runCase(c, save))).then((r) => emit(k, r)).catch(fail);
  });
  await Promise.allSettled(jobsDone);
  if (stop) throw stop;
  log(roundLine(how, Date.now() - t0, jobs));
  if (snapshot === 'none') log(`${mode} run: no snapshot written; a full run writes it`);
  else if (snapshot === 'beside') { writeSnapshot(results, version, 'beside'); log(`${mode} run: its snapshot is beside the replies`); } else if (!results.some((r) => !r.invalid)) log('no case was valid: no snapshot written, and any earlier one stays');
  else writeSnapshot(results, version, 'committed');
  log(`replies: ${repliesDir}`);
  return exitCode(results);
}

// saveWorkspace(dir, id, ws): a copy of a case's final workspace ws and its origin (ws.origin, when there is one) in
// <dir>/<id>.ws/, so --regrade can run the case's git-reading grader again (regradeExec).
export function saveWorkspace(dir, id, ws) {
  const out = join(dir, `${id}.ws`);
  rmSync(out, { recursive: true, force: true });
  for (const p of [ws, `${ws}.origin`].filter((x) => existsSync(x))) cpSync(p, join(out, p.split('/').pop()), { recursive: true, verbatimSymlinks: true });
}

// regradeExec({ dir, cases, log, now, graders }): --regrade. Each case that dir's run.json names is graded again by
// gradeCase with today's code and graders, from its saved record and files: its events, the gh stub's log, kern's
// state file for the session, and a temp copy of its workspace whose origin remote is set to the copy's origin. No
// session starts. A case with no record or no session keeps its saved verdict. The result goes to
// <dir>/regrade-<HHMMSS>.json, never evals/snapshots. Returns the exit code; a dir with no exec run.json throws a
// UsageError.
export async function regradeExec({ dir: path, cases, log, now, graders = GRADERS }) {
  const { m, dir } = openRun(path, 'exec');
  const byId = new Map(cases.map((c) => [c.id, c]));
  const results = [];
  for (const id of m.options.ids) {
    const c = byId.get(id);
    if (!c) { log(`SKIP ${id}: no case has this id now`); continue; }
    const rec = readRecord(dir, id);
    let r;
    if (!rec) r = { id, pass: false, invalid: true, reasons: ['no record: the case never finished'] };
    else if (!rec.session) r = rec.result;
    else r = { ...rec.result, ...regradeOne(dir, c, rec, graders) };
    results.push(r);
    log(`${r.pass ? 'PASS' : r.invalid ? 'INVALID' : 'FAIL'} ${id}${r.pass ? '' : `: ${r.reasons.join('; ')}`}`);
  }
  const file = join(dir, `regrade-${timeStamp(now)}.json`);
  writeFileSync(file, JSON.stringify({ regraded: { from: dir, at: now.toISOString() }, model: m.options.model, claude: m.claude, kern: m.kern, results }, null, 2) + '\n');
  log(`regrade: ${file}`);
  return exitCode(results);
}

// regradeOne(dir, c, rec, graders): { pass, invalid, reasons } for case c from its saved files (regradeExec).
function regradeOne(dir, c, rec, graders) {
  const invalid = (why) => ({ pass: false, invalid: true, reasons: [why] });
  let events;
  try { events = readFileSync(join(dir, `${c.id}.events.jsonl`), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)); } catch (e) { return invalid(`its events cannot be read: ${e.message}`); }
  const ghLog = existsSync(join(dir, `${c.id}.gh.log`)) ? readFileSync(join(dir, `${c.id}.gh.log`), 'utf8').split('\n').filter(Boolean) : [];
  const saved = join(dir, `${c.id}.ws`);
  if (!existsSync(saved)) return invalid('its workspace was not saved, so its git state cannot be read');
  const tmp = mkdtempSync(join(tmpdir(), 'xg-'));
  try {
    cpSync(saved, tmp, { recursive: true, verbatimSymlinks: true });
    const name = readdirSync(tmp).find((n) => !n.endsWith('.origin'));
    const ws = join(tmp, name);
    const git = (...a) => execFileSync('git', ['-C', ws, ...a], { encoding: 'utf8', timeout: 60 * 1000, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    if (existsSync(`${ws}.origin`)) git('remote', 'set-url', 'origin', `${ws}.origin`);
    const g = gradeCase({ c, run: { ...rec.session, events }, ghLog, git, configDir: dir, plugin: rec.session.plugin, graders,
      read: () => readFileSync(join(dir, `${c.id}.state`), 'utf8') });
    return { pass: g.pass, invalid: g.invalid || false, reasons: g.reasons };
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}
