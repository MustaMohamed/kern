#!/usr/bin/env node
// Behavioural evals: does kern behave as the skill says, under pressure and across a workflow?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/behave.mjs [--case <id>] [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]
// Writes evals/snapshots/behave-<model>-<date>.json (committed).
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, finalText, workspace } from './lib/claude-run.mjs';
import { caseResult, digest, graderPrompt, loadCases, parseVerdict, pluginCopy, stage, tryRun } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const GRADER = opt('--grader-model', 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const only = opt('--case', null);
const cases = loadCases(ROOT).filter((c) => !only || c.id === only);
if (only && !cases.length) { console.error(`behave: no case ${only}`); process.exit(2); }
if (args.includes('--dry-run')) {
  for (const c of cases) console.log(`${c.id}: ${c.prompts.length} turn(s) on ${c.files.join('+')}, ${c.expectations.length} expectation(s)${c.pressure.length ? `, pressure: ${c.pressure.join('+')}` : ''}`);
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
      const src = stage(ROOT, c.files);
      const cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
      if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
      const { run, problem } = tryRun({ cwd, prompts: c.prompts, pluginDirs: [plugin], model: MODEL, maxTurns: c.max_turns || 20 });
      if (run) writeFileSync(join(raw, `${c.id}-${i}.jsonl`), run.events.map((x) => JSON.stringify(x)).join('\n') + '\n');
      const gdir = mkdtempSync(join(tmpdir(), 'g-'));
      let verdict = null; let invalid = !!problem; let reason = problem;
      if (!invalid) {
        const g = tryRun({ cwd: gdir, prompts: [graderPrompt(c.expectations, digest(run.events))], model: GRADER, maxTurns: 1 });
        if (g.problem) { invalid = true; reason = `grader: ${g.problem}`; }
        else try { verdict = parseVerdict(finalText(g.run.events), c.expectations.length); } catch (e) { invalid = true; reason = e.message; }
      }
      runs.push({ invalid, reason, verdict, exit: run ? run.status : null });
      rmSync(dirname(cwd), { recursive: true, force: true }); rmSync(gdir, { recursive: true, force: true });
    }
    const r = caseResult(runs);
    results.push({ id: c.id, source: c.source, ...r, runs });
    const failed = c.expectations.filter((_, k) => runs.some((x) => x.verdict && !x.verdict[k].pass));
    save();
    console.log(`${r.pass ? 'PASS' : 'FAIL'} ${c.id}: ${r.passed}/${r.valid}${r.invalid ? ` (${r.invalid} invalid: ${runs.filter((x) => x.invalid).map((x) => x.reason).join(' | ')})` : ''}${failed.length ? `; missed: ${failed.join(' | ')}` : ''}`);
  }
} finally { rmSync(dirname(plugin), { recursive: true, force: true }); }
console.log(`snapshot: ${out}`);
process.exit(results.every((r) => r.pass) ? 0 : 1);
