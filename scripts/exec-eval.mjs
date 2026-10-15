#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, graded from the tool calls, the stub's call log and git state. Spends tokens: ask the
// user before a run. Usage: node scripts/exec-eval.mjs [--case <id>] [--dry-run]
// A full run writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version,
// the isolation flags and each case's result; a --case run writes none. Exit 0 only when every case that
// ran passed; 2 for a usage error, before anything runs. A claude run that exits non-zero, times out,
// ends early or cannot start is an invalid case, never a pass; a missing or non-executable claude stops.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, ClaudeRunError, claudeVersion, runClaude, runProblem, runSummary, toolUses, workspace } from './lib/claude-run.mjs';
import { GRADERS, stubMissed } from './lib/exec-grade.mjs';
import { UsageError, parseArgs, runEval } from './lib/exec-run.mjs';

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

function runCase(c) {
  const prompts = [...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn];
  const dir = workspace(join(ROOT, 'evals', 'exec', 'fixtures', 'app'), { name: 'invoice-app', origin: true, branch: c.branch, setup: c.setup || [] });
  try {
    if (c.settings) { mkdirSync(join(dir, '.claude'), { recursive: true }); writeFileSync(join(dir, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
    const log = join(dirname(dir), 'gh.log');
    writeFileSync(log, '');
    let run;
    try {
      run = runClaude({
        cwd: dir, prompts, pluginDirs: [ROOT], model: MODEL, maxTurns: 30,
        env: { PATH: `${join(ROOT, 'evals', 'exec', 'bin')}:${process.env.PATH}`, KERN_EXEC_LOG: log, KERN_EXEC_PR: c.pr || 'none', GH_TOKEN: 'invalid', GH_HOST: 'example.invalid' },
      });
    } catch (e) {
      if (!(e instanceof ClaudeRunError) || e.fatal) throw e;
      return { id: c.id, pass: false, invalid: true, reasons: [e.message], exit: null, commands: [] };
    }
    const ghLog = readFileSync(log, 'utf8').split('\n').filter(Boolean);
    const git = (...a) => execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8', timeout: 60 * 1000 }).trim();
    const missed = stubMissed(run.events, ghLog);
    let g;
    const problem = runProblem(run);
    if (problem) g = { pass: false, invalid: true, reasons: [problem] };
    else if (missed.length) g = { pass: false, invalid: true, reasons: [`the stub never logged \`gh ${missed[0]}\`: the Bash tool did not see evals/exec/bin first on PATH`] };
    else {
      try { g = GRADERS[c.id]({ events: run.events, ghLog, git, branch: c.branch }); }
      catch (e) { g = { pass: false, invalid: true, reasons: [`grader error: ${e.message}`] }; }
    }
    return { id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status, ...runSummary(run.events),
      commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command) };
  } finally {
    rmSync(dirname(dir), { recursive: true, force: true });
    rmSync(`${dir}.origin`, { recursive: true, force: true });
  }
}

function writeSnapshot(results) {
  const out = join(ROOT, 'evals', 'snapshots', `exec-${new Date().toISOString().slice(0, 10)}.json`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, results }, null, 2) + '\n');
  console.log(`snapshot: ${out}`);
}

process.exit(runEval({
  cases, only: opts.only, dryRun: opts.dryRun, runCase, writeSnapshot, log: console.log,
  describe: (c) => `${c.id}: ${[...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn].map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`,
}));
