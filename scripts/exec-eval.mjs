#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, kern loaded from a plugin copy, graded from the tool calls, the stub's call log and git
// state. Spends tokens: ask the user before a run.
// Usage: node scripts/exec-eval.mjs [--case <id> | --changed <range>] [--quick] [--jobs N] [--no-cache] [--allow-dirty] [--dry-run]
//        node scripts/exec-eval.mjs --resume <replies dir> [--jobs N] [--no-cache]
//        node scripts/exec-eval.mjs --regrade <replies dir>
// Each case's final reply goes to evals/results/exec-<date>/<id>.txt (gitignored), or (no reply: <why>) for
// an invalid case, and its stream-json events, tool results included, to <id>.events.jsonl beside it; the
// last line prints the directory; a --dry-run writes none. Each kern hook runs through a trace (traceHooks),
// whose lines go to <id>.trace.jsonl beside the events, a cut-off or invalid case's too. A case that
// turns autopilot on is INVALID when kern's state file for the run's session does not read autopilot: on
// at the end: it did not test autopilot. Beside them go what --regrade reads: the gh stub's log (<id>.gh.log),
// kern's state file (<id>.state), the final workspace and origin (<id>.ws/) and the case's record (<id>.result.json),
// with run.json for the run's options.
// A full run writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version,
// the isolation flags, what a pass assumes, the kern tree it measured (HEAD and any uncommitted changes, as
// kern) and each case's result; a --case run, or a run where no case was valid, writes none. A full run
// refuses a kern tree with uncommitted changes it would measure (exit 2) unless --allow-dirty (Task 17a G11).
// --jobs N runs N cases at once (default 6). --quick and --changed <range> (only the cases whose inputs changed) are
// not full runs: each writes to evals/results/exec-<date>-<quick|changed>-<HHMMSS>/, with its snapshot beside the
// replies. A case whose inputs match a cached valid one is reused unless --no-cache; --resume <dir> runs only the cases
// that run lacks; --regrade <dir> grades its saved runs again and starts no session (regradeExec).
// The Claude Code version is read before the first case, and a failure stops the
// run. A host ~/.claude/kern.yml refuses the run (exit 2) unless KERN_EXEC_ALLOW_USER_SETTINGS=1: kern's
// hooks read it past the isolation flags. The hooks read an empty shell snapshot, not the host's. Exit 0 only when every case that
// ran passed; 2 for a usage error, before anything runs. A claude run that exits non-zero, times out,
// ends early or cannot start is an invalid case, never a pass; a missing or non-executable claude stops.
import { execFileSync } from 'node:child_process';
import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, claudeVersion, evalConfigProblem, finalText, runClaudeAsync, runSummary, toolUses, workspace } from './lib/claude-run.mjs';
import { pluginCopy } from './lib/behave.mjs';
import { caseInputs, changedCases, rangeSources, skillHashes, touchedSkills, treeSource } from './lib/case-inputs.mjs';
import { filesVersion, openRun, timeStamp, unitKey, unitStore, writeManifest } from './lib/eval-cache.mjs';
import { limiter } from './lib/pool.mjs';
import { dirtyRefusal, treeRecord } from './lib/run-record.mjs';
import { reaper } from './lib/reaper.mjs';
import { GRADERS } from './lib/exec-grade.mjs';
import { UsageError, caseEnv, casePrompts, claudeConfigDir, dateStamp, execParts, gradeCase, kernStateFile, parseArgs, regradeExec, runEval, saveWorkspace, sessionId, snapshotBody, traceHooks,
  userSettingsProblem, writeEvents, writeReply, writeTrace } from './lib/exec-run.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const all = JSON.parse(readFileSync(join(ROOT, 'evals', 'exec', 'cases.json'), 'utf8'));
for (const c of all) if (!GRADERS[c.id]) throw new Error(`no grader for ${c.id}`);
// EXEC_CODE: the files whose code runs and grades a case; their content is part of each case's cache key.
const EXEC_CODE = ['scripts/exec-eval.mjs', 'scripts/lib/exec-run.mjs', 'scripts/lib/exec-grade.mjs', 'scripts/lib/claude-run.mjs', 'scripts/lib/claude-drive.mjs', 'scripts/lib/behave.mjs'];

const usage = (msg) => {
  console.error(`exec-eval: ${msg}\nusage: node scripts/exec-eval.mjs [--case <id> | --changed <range>] [--quick] [--jobs N] [--no-cache] [--allow-dirty] [--dry-run]\n`
    + '       node scripts/exec-eval.mjs --resume <replies dir> [--jobs N] [--no-cache]\n       node scripts/exec-eval.mjs --regrade <replies dir>');
  process.exit(2);
};
let opts;
try { opts = parseArgs(process.argv.slice(2), all.map((c) => c.id)); } catch (e) {
  if (!(e instanceof UsageError)) throw e;
  usage(e.message);
}
if (opts.regrade !== undefined) {
  try { process.exit(await regradeExec({ dir: opts.regrade, cases: all, log: console.log, now: new Date() })); } catch (e) { if (e instanceof UsageError) usage(e.message); throw e; }
}
let resumeDir = null;
let manifest = null;
if (opts.resume !== undefined) {
  try { ({ m: manifest, dir: resumeDir } = openRun(opts.resume, 'exec')); } catch (e) { if (e instanceof UsageError) usage(e.message); throw e; }
  opts = { ...manifest.options, jobs: opts.jobs ?? manifest.options.jobs, noCache: !!opts.noCache };
}
// A resumed run keeps the model it started on, whatever KERN_EVAL_MODEL says now.
const MODEL = manifest?.options.model ?? (process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
let cases;
if (manifest) cases = all.filter((c) => manifest.options.ids.includes(c.id));
else if (opts.changed !== undefined) {
  try {
    const { before, after } = rangeSources(ROOT, opts.changed);
    cases = changedCases(all, execParts, before, after);
  } catch (e) { if (e instanceof UsageError) usage(e.message); throw e; }
  if (opts.dryRun) console.log(`--changed ${opts.changed}: ${cases.length} of ${all.length} cases`);
} else cases = all.filter((c) => !opts.only || c.id === opts.only);
const gating = !opts.only && opts.changed === undefined && !opts.quick;
const refusal = opts.dryRun ? '' : evalConfigProblem(process.env);
if (refusal) {
  console.error(`exec-eval: ${refusal}`);
  process.exit(2);
}
const userSettings = !opts.dryRun && userSettingsProblem(process.env.HOME, {}) !== '';
const tree = opts.dryRun ? null : treeRecord(ROOT);
if (!opts.dryRun) {
  const problem = userSettingsProblem(process.env.HOME, process.env) || (gating && !opts.allowDirty ? dirtyRefusal(tree) : '');
  if (problem) {
    console.error(`exec-eval: ${problem}`);
    process.exit(2);
  }
}
if (!opts.dryRun && !cases.length) {
  console.log(`--changed ${opts.changed}: no case reads a file that changed; nothing ran`);
  process.exit(0);
}

const now = new Date();
const DATE = manifest?.date ?? dateStamp(now);
const mode = opts.quick ? 'quick' : opts.changed !== undefined ? 'changed' : null;
// kern runs from a copy, as in behave and adherence: no .git, evals, tests or docs, and none of the eval
// runners. From the live repo, a git work tree, a model that cd'd into the plugin's scripts/ got the repo's
// own settings back, and the run looked right (task-16-diagnosis-2 Y4, finish-pr-at-head on 2026-10-20).
// One copy serves every case; it is made at the first case, so a dry run or a failed version check makes none.
// The guard (reaper.mjs) removes the copy and the cases' folders if this process ends without its finally
// blocks: a Ctrl-C, SIGTERM or SIGHUP kills it while it waits on claude (Task 16h review, M2).
// The copy's hooks.json runs each kern hook through evals/exec/hooks/trace (Task 16l); the repo's own
// hooks.json is never changed.
let plugin = null;
let guard = null;
const pluginDir = () => {
  if (!plugin) {
    guard = reaper();
    plugin = realpathSync(pluginCopy(ROOT));
    guard.add(dirname(plugin));
    traceHooks(plugin, join(ROOT, 'evals', 'exec', 'hooks', 'trace'));
  }
  return plugin;
};
const REPLIES = resumeDir ?? join(ROOT, 'evals', 'results', `exec-${DATE}${mode ? `-${mode}-${timeStamp(now)}` : ''}`);

// keep(id, from, name): a best-effort copy of one of a case's files into the replies dir, for --regrade.
const keep = (id, write) => { try { mkdirSync(REPLIES, { recursive: true }); write(); } catch (e) { console.log(`replies: could not keep ${id}'s files for --regrade: ${e.message}`); } };

async function runCase(c, save) {
  const prompts = casePrompts(c);
  const kern = pluginDir();
  const dir = workspace(join(ROOT, 'evals', 'exec', 'fixtures', 'app'), { name: 'invoice-app', origin: true, branch: c.branch, setup: c.setup || [] });
  const temp = [dirname(dir), `${dir}.origin`];
  for (const p of temp) guard.add(p);
  try {
    if (c.settings) { mkdirSync(join(dir, '.claude'), { recursive: true }); writeFileSync(join(dir, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
    const log = join(dirname(dir), 'gh.log');
    writeFileSync(log, '');
    const snapshot = join(dirname(dir), 'empty-shell-snapshot.sh');
    writeFileSync(snapshot, '');
    // One trace line per kern hook call, beside the workspace; saved with the events however the case ends.
    const trace = join(dirname(dir), 'trace.jsonl');
    writeFileSync(trace, '');
    // The gh stand-in goes beside the workspace, so PATH names no folder of the repo either.
    const bin = join(dirname(dir), 'bin');
    cpSync(join(ROOT, 'evals', 'exec', 'bin'), bin, { recursive: true });
    let run;
    try {
      run = await runClaudeAsync({
        // 60 turns: finish-branch runs its proof and a whole self-review before the size gate, and 30 was reached; the $3 budget still caps spend.
        cwd: dir, prompts, pluginDirs: [kern], model: MODEL, maxTurns: 60,
        env: caseEnv({ bin, path: process.env.PATH, log, pr: c.pr || 'none', snapshot, trace }),
      });
    } catch (e) {
      if (!(e instanceof ClaudeRunError) || e.fatal) throw e;
      // A run cut off by the timeout keeps the events it printed.
      save({ reason: e.message, events: e.events, trace });
      return { id: c.id, pass: false, invalid: true, reasons: [e.message], exit: null, commands: [], session: null };
    }
    const ghLog = readFileSync(log, 'utf8').split('\n').filter(Boolean);
    const git = (...a) => execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8', timeout: 60 * 1000 }).trim();
    const configDir = claudeConfigDir(process.env);
    const g = gradeCase({ c, run, ghLog, git, configDir, plugin: kern });
    save({ ...(g.invalid ? { reason: g.reasons[0] } : { reply: finalText(run.events) }), events: run.events, trace });
    // What --regrade reads besides the events: the stub's log, kern's state for the session, and the final workspace.
    keep(c.id, () => {
      copyFileSync(log, join(REPLIES, `${c.id}.gh.log`));
      const state = sessionId(run.events) && kernStateFile(configDir, sessionId(run.events));
      rmSync(join(REPLIES, `${c.id}.state`), { force: true });
      if (state && existsSync(state)) copyFileSync(state, join(REPLIES, `${c.id}.state`));
      saveWorkspace(REPLIES, c.id, dir);
    });
    return { id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status, ...runSummary(run.events),
      commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command),
      session: { status: run.status, badLines: run.badLines, stderr: run.stderr.slice(-4000), plugin: kern },
      touched: Object.fromEntries(touchedSkills(run.events, hashes, [kern]).map((n) => [n, hashes.get(n)])) };
  } finally {
    for (const p of temp) { rmSync(p, { recursive: true, force: true }); guard.drop(p); }
  }
}

function writeSnapshot(results, claude, where) {
  const out = where === 'committed' ? join(ROOT, 'evals', 'snapshots', `exec-${DATE}.json`) : join(REPLIES, 'snapshot.json');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(snapshotBody({ model: MODEL, claude, results, userSettings, tree }), null, 2) + '\n');
  if (where === 'committed') console.log(`snapshot: ${out}`);
}

// Each case is a unit (eval-cache.mjs): a valid one whose key matches a cached one is reused, its files copied in.
const limit = limiter(opts.jobs ?? 6);
let claude = null;
let store = null;
let inputs = null;
let hashes = null;
// fresh(rec): every kern skill the case's run read is unchanged since.
const fresh = (rec) => Object.entries(rec.touched ?? {}).every(([n, h]) => hashes.get(n) === h);
const keyOf = (c) => unitKey({ runner: 'exec', inputs: inputs.get(c.id), case: c, model: MODEL, code, claude, userSettings });
const readVersion = () => {
  claude = claudeVersion();
  writeManifest(REPLIES, { runner: 'exec', date: DATE, started: manifest?.started ?? now.toISOString(), ...(manifest ? { resumed: [...(manifest.resumed ?? []), now.toISOString()] } : {}),
    claude, kern: tree, options: { model: MODEL, jobs: opts.jobs ?? 6, only: opts.only, quick: !!opts.quick, ...(opts.changed !== undefined ? { changed: opts.changed } : {}),
      allowDirty: !!opts.allowDirty, ids: cases.map((c) => c.id) } });
  store = unitStore({ raw: REPLIES, cache: join(ROOT, 'evals', 'results', 'cache', 'exec'), from: basename(REPLIES), noCache: !!opts.noCache, resume: !!manifest, limit });
  const src = treeSource(ROOT);
  hashes = skillHashes(src);
  inputs = new Map(cases.map((c) => [c.id, caseInputs(src, execParts(c)).hash]));
  const stale = manifest ? cases.filter((c) => store.stale(c.id, keyOf(c), fresh)).length : 0;
  if (stale) console.log(`--resume: ${stale} case(s) of that run no longer match its inputs, the runner's code, the Claude Code version or a kern skill they read, so they are not kept`);
  return claude;
};
const code = filesVersion(ROOT, EXEC_CODE);
const unit = async (c, work) => {
  const rec = await store.unit({
    name: c.id, files: ['txt', 'events.jsonl', 'trace.jsonl', 'gh.log', 'state', 'ws'].map((x) => `${c.id}.${x}`),
    key: keyOf(c), fresh,
    work: async () => { const { session, touched, ...result } = await work(); return { valid: !result.invalid, result, session, touched }; },
  });
  return { ...rec.result, ...(rec.cached ? { cached: rec.cached } : {}), how: rec.how };
};

let exit;
try {
  exit = await runEval({
    cases, only: opts.only, dryRun: opts.dryRun, runCase, writeSnapshot, readVersion, repliesDir: REPLIES, saveReply: (id, reply, reason) => writeReply(REPLIES, id, reply, reason),
    saveEvents: (id, events) => writeEvents(REPLIES, id, events), saveTrace: (id, file) => writeTrace(REPLIES, id, file), log: console.log, jobs: opts.jobs ?? 6, limit, unit,
    snapshot: gating ? 'committed' : opts.only ? 'none' : 'beside', mode: opts.only ? '--case' : opts.quick ? '--quick' : '--changed',
    describe: (c) => `${c.id}: ${casePrompts(c).map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`,
  });
} finally {
  if (plugin) { rmSync(dirname(plugin), { recursive: true, force: true }); guard.drop(dirname(plugin)); }
}
process.exit(exit);
