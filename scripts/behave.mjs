#!/usr/bin/env node
// Behavioural evals: does kern behave as the skill says, under pressure and across a workflow?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/behave.mjs [--case <id>] [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]
// Writes evals/snapshots/behave-<model>-<date>.json (committed). An expectation a case's `checks` names is decided
// by that scripted check, with no model (Task 16j); the rest get one grader call per run.
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, finalText } from './lib/claude-run.mjs';
import { caseResult, caseWorkspace, gradeRun, graderPrompt, loadCases, pluginCopy, treeState, tryRun } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const GRADER = opt('--grader-model', 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const only = opt('--case', null);
const cases = loadCases(ROOT).filter((c) => !only || c.id === only);
if (only && !cases.length) { console.error(`behave: no case ${only}`); process.exit(2); }
// shape(c): the workspace fields a case sets beyond its layers, for the dry run.
const shape = (c) => [c.origin && 'origin', c.branch && `branch ${c.branch}`, c.setup?.length && `${c.setup.length} setup command(s)`].filter(Boolean).join(', ');
if (args.includes('--dry-run')) {
  for (const c of cases) {
    const scripted = Object.keys(c.checks ?? {}).length;
    console.log(`${c.id}: ${c.prompts.length} turn(s) on ${c.files.join('+')}${shape(c) ? ` (${shape(c)})` : ''}, ${c.expectations.length} expectation(s)${scripted ? ` (${scripted} scripted)` : ''}${c.pressure.length ? `, pressure: ${c.pressure.join('+')}` : ''}`);
  }
  process.exit(0);
}
const results = [];
const out = join(ROOT, 'evals', 'snapshots', `behave-${MODEL.replace(/^claude-/, '')}-${new Date().toISOString().slice(0, 10)}.json`);
const save = () => {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, grader: GRADER, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, runs: RUNS, results }, null, 2) + '\n');
};
const plugin = pluginCopy(ROOT);
// Each run's events go to evals/results (gitignored), so a missed expectation can be read in the transcript.
const raw = join(ROOT, 'evals', 'results', `behave-${MODEL.replace(/^claude-/, '')}-${new Date().toISOString().slice(0, 10)}`);
mkdirSync(raw, { recursive: true });
try {
  for (const c of cases) {
    const runs = [];
    for (let i = 0; i < RUNS; i++) {
      const cwd = caseWorkspace(ROOT, c);
      const start = treeState(cwd);
      const { run, problem, events } = tryRun({ cwd, prompts: c.prompts, pluginDirs: [plugin], model: MODEL, maxTurns: c.max_turns || 20 });
      // The no-write check compares the workspace's git status at the run's start and end.
      let end;
      try { end = treeState(cwd); } catch (e) { end = { error: e.message }; }
      const tree = { start, end };
      // A run cut off by the timeout keeps the events it printed.
      const kept = run ? run.events : events;
      if (kept.length) writeFileSync(join(raw, `${c.id}-${i}.jsonl`), kept.map((x) => JSON.stringify(x)).join('\n') + '\n');
      writeFileSync(join(raw, `${c.id}-${i}.tree.json`), JSON.stringify(tree, null, 2) + '\n');
      const gdir = mkdtempSync(join(tmpdir(), 'g-'));
      let verdict = null; let invalid = !!problem; let reason = problem;
      if (!invalid) {
        try {
          verdict = gradeRun(c, run.events, tree, (ex, record) => {
            const g = tryRun({ cwd: gdir, prompts: [graderPrompt(ex, record)], model: GRADER, maxTurns: 1 });
            if (g.problem) throw new Error(`grader: ${g.problem}`);
            return finalText(g.run.events);
          });
        } catch (e) { if (e.fatal) throw e; invalid = true; reason = e.message; }
      }
      runs.push({ invalid, reason, verdict, exit: run ? run.status : null });
      rmSync(dirname(cwd), { recursive: true, force: true }); rmSync(gdir, { recursive: true, force: true });
    }
    const r = caseResult(runs);
    results.push({ id: c.id, source: c.source, checks: c.checks ?? {}, ...r, runs });
    const failed = c.expectations.filter((_, k) => runs.some((x) => x.verdict && !x.verdict[k].pass));
    save();
    console.log(`${r.pass ? 'PASS' : 'FAIL'} ${c.id}: ${r.passed}/${r.valid}${r.invalid ? ` (${r.invalid} invalid: ${runs.filter((x) => x.invalid).map((x) => x.reason).join(' | ')})` : ''}${failed.length ? `; missed: ${failed.join(' | ')}` : ''}`);
  }
} finally { rmSync(dirname(plugin), { recursive: true, force: true }); }
console.log(`snapshot: ${out}`);
process.exit(results.every((r) => r.pass) ? 0 : 1);
