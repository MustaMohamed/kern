#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, kern loaded from a plugin copy, graded from the tool calls, the stub's call log and git
// state. Spends tokens: ask the user before a run. Usage: node scripts/exec-eval.mjs [--case <id>] [--allow-dirty] [--dry-run]
// Each case's final reply goes to evals/results/exec-<date>/<id>.txt (gitignored), or (no reply: <why>) for
// an invalid case, and its stream-json events, tool results included, to <id>.events.jsonl beside it; the
// last line prints the directory; a --dry-run writes none. Each kern hook runs through a trace (traceHooks),
// whose lines go to <id>.trace.jsonl beside the events, a cut-off or invalid case's too. A case that
// turns autopilot on is INVALID when kern's state file for the run's session does not read autopilot: on
// at the end: it did not test autopilot.
// A full run writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version,
// the isolation flags, what a pass assumes, the kern tree it measured (HEAD and any uncommitted changes, as
// kern) and each case's result; a --case run, or a run where no case was valid, writes none. A full run
// refuses a kern tree with uncommitted changes it would measure (exit 2) unless --allow-dirty (Task 17a G11).
// The Claude Code version is read before the first case, and a failure stops the
// run. A host ~/.claude/kern.yml refuses the run (exit 2) unless KERN_EXEC_ALLOW_USER_SETTINGS=1: kern's
// hooks read it past the isolation flags. The hooks read an empty shell snapshot, not the host's. Exit 0 only when every case that
// ran passed; 2 for a usage error, before anything runs. A claude run that exits non-zero, times out,
// ends early or cannot start is an invalid case, never a pass; a missing or non-executable claude stops.
import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, NO_EVAL_CONFIG, claudeVersion, evalConfigProblem, finalText, runClaude, runSummary, toolUses, workspace } from './lib/claude-run.mjs';
import { pluginCopy } from './lib/behave.mjs';
import { dirtyRefusal, treeRecord } from './lib/run-record.mjs';
import { reaper } from './lib/reaper.mjs';
import { GRADERS } from './lib/exec-grade.mjs';
import { UsageError, caseEnv, casePrompts, claudeConfigDir, dateStamp, gradeCase, parseArgs, runEval, snapshotBody, traceHooks, userSettingsProblem, writeEvents, writeReply, writeTrace } from './lib/exec-run.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const MODEL = process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5';
const all = JSON.parse(readFileSync(join(ROOT, 'evals', 'exec', 'cases.json'), 'utf8'));
for (const c of all) if (!GRADERS[c.id]) throw new Error(`no grader for ${c.id}`);

let opts;
try { opts = parseArgs(process.argv.slice(2), all.map((c) => c.id)); } catch (e) {
  if (!(e instanceof UsageError)) throw e;
  console.error(`exec-eval: ${e.message}\nusage: node scripts/exec-eval.mjs [--case <id>] [--allow-dirty] [--dry-run]`);
  process.exit(2);
}
const cases = all.filter((c) => !opts.only || c.id === opts.only);
if (!opts.dryRun && evalConfigProblem(process.env)) {
  console.error(`exec-eval: ${NO_EVAL_CONFIG}`);
  process.exit(2);
}
const userSettings = !opts.dryRun && userSettingsProblem(process.env.HOME, {}) !== '';
const tree = opts.dryRun ? null : treeRecord(ROOT);
if (!opts.dryRun) {
  const problem = userSettingsProblem(process.env.HOME, process.env) || (!opts.only && !opts.allowDirty ? dirtyRefusal(tree) : '');
  if (problem) {
    console.error(`exec-eval: ${problem}`);
    process.exit(2);
  }
}

const DATE = dateStamp();
// kern runs from a copy, as in behave and adherence: no .git, evals, tests or docs, and none of the eval
// runners. From the live repo, a git work tree, a model that cd'd into the plugin's scripts/ got the repo's
// own settings back, and the run looked right (task-16-diagnosis-2 Y4, finish-pr-at-head on 2026-10-20).
// One copy serves every case; it is made at the first case, so a dry run or a failed version check makes none.
// The guard (reaper.mjs) removes the copy and the current case's folders if this process ends without its
// finally blocks: a Ctrl-C, SIGTERM or SIGHUP kills it while spawnSync waits on claude (Task 16h review, M2).
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
const REPLIES = join(ROOT, 'evals', 'results', `exec-${DATE}`);

function runCase(c, save) {
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
      run = runClaude({
        // 60 turns: finish-branch runs its proof and a whole self-review before the size gate, and 30 was reached; the $3 budget still caps spend.
        cwd: dir, prompts, pluginDirs: [kern], model: MODEL, maxTurns: 60,
        env: caseEnv({ bin, path: process.env.PATH, log, pr: c.pr || 'none', snapshot, trace }),
      });
    } catch (e) {
      if (!(e instanceof ClaudeRunError) || e.fatal) throw e;
      // A run cut off by the timeout keeps the events it printed.
      save({ reason: e.message, events: e.events, trace });
      return { id: c.id, pass: false, invalid: true, reasons: [e.message], exit: null, commands: [] };
    }
    const ghLog = readFileSync(log, 'utf8').split('\n').filter(Boolean);
    const git = (...a) => execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8', timeout: 60 * 1000 }).trim();
    const g = gradeCase({ c, run, ghLog, git, configDir: claudeConfigDir(process.env), plugin: kern });
    save({ ...(g.invalid ? { reason: g.reasons[0] } : { reply: finalText(run.events) }), events: run.events, trace });
    return { id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status, ...runSummary(run.events),
      commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command) };
  } finally {
    for (const p of temp) { rmSync(p, { recursive: true, force: true }); guard.drop(p); }
  }
}

function writeSnapshot(results, claude) {
  const out = join(ROOT, 'evals', 'snapshots', `exec-${DATE}.json`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(snapshotBody({ model: MODEL, claude, results, userSettings, tree }), null, 2) + '\n');
  console.log(`snapshot: ${out}`);
}

let code;
try {
  code = runEval({
    cases, only: opts.only, dryRun: opts.dryRun, runCase, writeSnapshot, readVersion: claudeVersion, repliesDir: REPLIES, saveReply: (id, reply, reason) => writeReply(REPLIES, id, reply, reason),
    saveEvents: (id, events) => writeEvents(REPLIES, id, events), saveTrace: (id, file) => writeTrace(REPLIES, id, file), log: console.log,
    describe: (c) => `${c.id}: ${casePrompts(c).map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`,
  });
} finally {
  if (plugin) { rmSync(dirname(plugin), { recursive: true, force: true }); guard.drop(dirname(plugin)); }
}
process.exit(code);
