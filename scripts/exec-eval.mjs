#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, graded from the tool calls, the stub's call log and git state. Spends tokens: ask the
// user before a run. Usage: node scripts/exec-eval.mjs [--case <id>] [--dry-run]
// Writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version, the
// isolation flags and each case's result. A claude run that exits non-zero, times out or cannot start
// is a failed case, never a pass; a missing or non-executable claude stops the run.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, ClaudeRunError, claudeVersion, runClaude, runProblem, toolUses, workspace } from './lib/claude-run.mjs';
import { GRADERS, stubMissed } from './lib/exec-grade.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const MODEL = process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5';
const args = process.argv.slice(2);
const only = args.includes('--case') ? args[args.indexOf('--case') + 1] : null;
const dryRun = args.includes('--dry-run');
const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'exec', 'cases.json'), 'utf8')).filter((c) => !only || c.id === only);
if (only && cases.length === 0) throw new Error(`no case named ${only}`);
for (const c of cases) if (!GRADERS[c.id]) throw new Error(`no grader for ${c.id}`);

const results = [];
for (const c of cases) {
  const prompts = [...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn];
  if (dryRun) { console.log(`${c.id}: ${prompts.map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`); continue; }
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
      results.push({ id: c.id, pass: false, invalid: true, reasons: [e.message], exit: null, commands: [] });
      console.log(`INVALID ${c.id}: ${e.message}`);
      continue;
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
    results.push({ id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status,
      commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command) });
    console.log(`${g.pass ? 'PASS' : g.invalid ? 'INVALID' : 'FAIL'} ${c.id}${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
  } finally {
    rmSync(dirname(dir), { recursive: true, force: true });
    rmSync(`${dir}.origin`, { recursive: true, force: true });
  }
}
if (!dryRun && only) console.log('--case run: no snapshot written; a full run writes it');
if (!dryRun && !only) {
  const out = join(ROOT, 'evals', 'snapshots', `exec-${new Date().toISOString().slice(0, 10)}.json`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, results }, null, 2) + '\n');
  console.log(`snapshot: ${out}`);
  process.exit(results.length && results.every((r) => r.pass) ? 0 : 1);
}
