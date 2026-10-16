#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, graded from the tool calls, the stub's call log and git state. Spends tokens: ask the
// user before a run. Usage: node scripts/exec-eval.mjs [--case <id>] [--dry-run]
// Each case's final reply goes to evals/results/exec-<date>/<id>.txt (gitignored), or (no reply: <why>) for
// an invalid case, and its stream-json events, tool results included, to <id>.events.jsonl beside it; the
// last line prints the directory; a --dry-run writes none. A case that turns autopilot on is INVALID when
// kern's state file for the run's session does not read autopilot: on at the end: it did not test autopilot.
// A full run writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version,
// the isolation flags, what a pass assumes and each case's result; a --case run, or a run where no case
// was valid, writes none. The Claude Code version is read before the first case, and a failure stops the
// run. A host ~/.claude/kern.yml refuses the run (exit 2) unless KERN_EXEC_ALLOW_USER_SETTINGS=1: kern's
// hooks read it past the isolation flags. The hooks read an empty shell snapshot, not the host's. Exit 0 only when every case that
// ran passed; 2 for a usage error, before anything runs. A claude run that exits non-zero, times out,
// ends early or cannot start is an invalid case, never a pass; a missing or non-executable claude stops.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, claudeVersion, finalText, runClaude, runSummary, toolUses, workspace } from './lib/claude-run.mjs';
import { GRADERS } from './lib/exec-grade.mjs';
import { UsageError, caseEnv, claudeConfigDir, dateStamp, gradeCase, parseArgs, runEval, snapshotBody, userSettingsProblem, writeEvents, writeReply } from './lib/exec-run.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const MODEL = process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5';
const all = JSON.parse(readFileSync(join(ROOT, 'evals', 'exec', 'cases.json'), 'utf8'));
for (const c of all) if (!GRADERS[c.id]) throw new Error(`no grader for ${c.id}`);

let opts;
try { opts = parseArgs(process.argv.slice(2), all.map((c) => c.id)); } catch (e) {
  if (!(e instanceof UsageError)) throw e;
  console.error(`exec-eval: ${e.message}\nusage: node scripts/exec-eval.mjs [--case <id>] [--dry-run]`);
  process.exit(2);
}
const cases = all.filter((c) => !opts.only || c.id === opts.only);
const userSettings = !opts.dryRun && userSettingsProblem(process.env.HOME, {}) !== '';
if (!opts.dryRun) {
  const problem = userSettingsProblem(process.env.HOME, process.env);
  if (problem) {
    console.error(`exec-eval: ${problem}`);
    process.exit(2);
  }
}

const DATE = dateStamp();
const REPLIES = join(ROOT, 'evals', 'results', `exec-${DATE}`);

function runCase(c, save) {
  const prompts = [...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn];
  const dir = workspace(join(ROOT, 'evals', 'exec', 'fixtures', 'app'), { name: 'invoice-app', origin: true, branch: c.branch, setup: c.setup || [] });
  try {
    if (c.settings) { mkdirSync(join(dir, '.claude'), { recursive: true }); writeFileSync(join(dir, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
    const log = join(dirname(dir), 'gh.log');
    writeFileSync(log, '');
    const snapshot = join(dirname(dir), 'empty-shell-snapshot.sh');
    writeFileSync(snapshot, '');
    let run;
    try {
      run = runClaude({
        // 60 turns: finish-branch runs its proof and a whole self-review before the size gate, and 30 was reached; the $3 budget still caps spend.
        cwd: dir, prompts, pluginDirs: [ROOT], model: MODEL, maxTurns: 60,
        env: caseEnv({ bin: join(ROOT, 'evals', 'exec', 'bin'), path: process.env.PATH, log, pr: c.pr || 'none', snapshot }),
      });
    } catch (e) {
      if (!(e instanceof ClaudeRunError) || e.fatal) throw e;
      save({ reason: e.message });
      return { id: c.id, pass: false, invalid: true, reasons: [e.message], exit: null, commands: [] };
    }
    const ghLog = readFileSync(log, 'utf8').split('\n').filter(Boolean);
    const git = (...a) => execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8', timeout: 60 * 1000 }).trim();
    const g = gradeCase({ c, run, ghLog, git, configDir: claudeConfigDir(process.env) });
    save({ ...(g.invalid ? { reason: g.reasons[0] } : { reply: finalText(run.events) }), events: run.events });
    return { id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status, ...runSummary(run.events),
      commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command) };
  } finally {
    rmSync(dirname(dir), { recursive: true, force: true });
    rmSync(`${dir}.origin`, { recursive: true, force: true });
  }
}

function writeSnapshot(results, claude) {
  const out = join(ROOT, 'evals', 'snapshots', `exec-${DATE}.json`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(snapshotBody({ model: MODEL, claude, results, userSettings }), null, 2) + '\n');
  console.log(`snapshot: ${out}`);
}

process.exit(runEval({
  cases, only: opts.only, dryRun: opts.dryRun, runCase, writeSnapshot, readVersion: claudeVersion, repliesDir: REPLIES, saveReply: (id, reply, reason) => writeReply(REPLIES, id, reply, reason),
  saveEvents: (id, events) => writeEvents(REPLIES, id, events), log: console.log,
  describe: (c) => `${c.id}: ${[...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn].map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`,
}));
