#!/usr/bin/env node
// Kernel adherence (design spec 11.1 tier 2, coverage gap 10): does a routed prompt make Claude read the
// route with at most one other call before it, and does a prompt that should not route stay quiet? Each
// run also reports whether it opened a todo list holding the route's steps; that does not gate.
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/kernel-adherence.mjs [--case <id>] [--runs N] [--model <m>] [--variant routed] [--dry-run]
//        node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]
// Writes evals/snapshots/adherence-<variant>-<model>-<date>.json (committed).
import { existsSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, runClaude, runProblem, workspace } from './lib/claude-run.mjs';
import { grade, readSteps, removeTemp, rowPrompt, runFailure } from './lib/adherence.mjs';
import { pluginCopy, stage } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const VARIANT = opt('--variant', 'routed');
const only = opt('--case', null);
// --plugin grades another kern tree (an older tag's worktree, for one); the cases still come from this repo.
const PLUGIN = opt('--plugin', ROOT);
// A run of one case or of another plugin is diagnostic: its snapshot stays beside its transcripts, not in evals/snapshots.
const partial = !!only || PLUGIN !== ROOT;
const routeFileOf = (c) => c.route_file || `skills/${c.route}/SKILL.md`;
const usage = (msg) => { console.error(`kernel-adherence: ${msg}`); process.exit(2); };
const allCases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
// The F3 A/B's inline-rows arm is now the kernel itself (Task 16d, the user's "Inline rows").
if (VARIANT === 'inline-rows') usage('--variant inline-rows is gone: the kernel table holds every route row since Task 16d, so the routed run is that arm');
if (VARIANT !== 'routed') usage(`--variant ${VARIANT}: the only variant is routed`);

if (args.includes('--transcript')) {
  const root = opt('--root', ROOT);
  const route = opt('--route', null);
  if (!route) usage('--transcript needs --route <route>');
  const events = readFileSync(opt('--transcript'), 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
  const file = routeFileOf(allCases.find((c) => c.route === route) || { route });
  if (!existsSync(join(root, file))) usage(`no route file ${file} under ${root}`);
  const text = readFileSync(join(root, file), 'utf8');
  const g = grade(events, { route, routeFile: file, steps: readSteps(text), text, root });
  console.log(`${g.pass ? 'PASS' : 'FAIL'} ${route} (${g.hops} hops, ${g.before} before, todo: ${g.todo}${g.todo ? `, steps: ${g.todoSteps}` : ''})${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
  process.exit(g.pass ? 0 : 1);
}

if (!Number.isInteger(RUNS) || RUNS < 1) usage('--runs needs a whole number of at least 1');
if (only && !allCases.some((c) => c.id === only)) usage(`no case ${only}; the cases are ${allCases.map((c) => c.id).join(', ')}`);
const cases = allCases.filter((c) => !only || c.id === only)
  .map((c) => ({ ...c, prompts: c.prompts ?? [rowPrompt(ROOT, c.route)] }));
if (args.includes('--dry-run')) {
  for (const c of cases) console.log(`${c.id}: ${c.kind} ${c.route || '-'} on ${c.files.join('+')}: ${c.prompts.map((p) => JSON.stringify(p)).join(' then ')}`);
  if (PLUGIN !== ROOT) console.log(`plugin: ${PLUGIN}`);
  process.exit(0);
}
if (PLUGIN !== ROOT && !existsSync(join(PLUGIN, 'kernel', 'kernel.md'))) usage(`--plugin ${PLUGIN} holds no kernel/kernel.md`);
const root = realpathSync(pluginCopy(PLUGIN));
const results = [];
// Each run's events go to evals/results (gitignored), so a failed case can be read, not only its grade.
const raw = join(ROOT, 'evals', 'results', `adherence-${VARIANT}-${MODEL.replace(/^claude-/, '')}-${new Date().toISOString().slice(0, 10)}${partial ? `-${only || 'all'}-${basename(PLUGIN)}` : ''}`);
mkdirSync(raw, { recursive: true });
try {
  for (const c of cases) {
    // The route's text, so a read of it counts only when it reaches the route's first step (Task 16p).
    const text = c.route ? readFileSync(join(root, routeFileOf(c)), 'utf8') : null;
    const steps = text ? readSteps(text) : [];
    const runs = [];
    for (let i = 0; i < RUNS; i++) {
      const src = stage(ROOT, c.files);
      let cwd = null;
      try {
        cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
        if (c.settings) { mkdirSync(join(cwd, '.claude'), { recursive: true }); writeFileSync(join(cwd, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
        // A turn cap is expected here: routing is graded from the first calls, so a capped run is still graded and
        // its problem recorded. Any other run that did not happen (a timeout, a signal, a non-zero exit, a result
        // count that differs from the prompt count) fails the run, with the reason.
        let run = null; let problem = ''; let failure = ''; let events = [];
        try { run = runClaude({ cwd, prompts: c.prompts, pluginDirs: [root], model: MODEL, maxTurns: c.kind === 'multi-turn' ? 16 : 8 }); problem = runProblem(run, c.prompts.length); failure = runFailure(run, c.prompts.length); events = run.events; }
        catch (e) { if (e.fatal) throw e; problem = failure = e.message; events = e.events ?? []; }
        // A run cut off by the timeout keeps the events it printed.
        if (events.length) writeFileSync(join(raw, `${c.id}-${i}.jsonl`), events.map((x) => JSON.stringify(x)).join('\n') + '\n');
        const g = run && !failure ? grade(run.events, { route: c.route, routeFile: c.route_file, steps, text, root, kind: c.kind, projectSkill: c.project_skill || null }) : { pass: false, hops: 0, before: 0, todo: null, todoSteps: null, notes: [], reasons: [failure] };
        runs.push({ pass: g.pass, hops: g.hops, before: g.before, todo: g.todo, todoSteps: g.todoSteps, notes: g.notes, reasons: g.reasons, problem, exit: run ? run.status : null, invalid: !!failure });
      } finally {
        if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
        if (cwd) rmSync(dirname(cwd), { recursive: true, force: true });
      }
    }
    const passed = runs.filter((r) => r.pass).length;
    results.push({ id: c.id, kind: c.kind, route: c.route, passed, runs: runs.length, pass: passed * 3 >= runs.length * 2, detail: runs });
    const invalid = runs.filter((r) => r.invalid).length;
    console.log(`${passed * 3 >= runs.length * 2 ? 'PASS' : 'FAIL'} ${c.id}: ${passed}/${runs.length}${invalid ? ` (${invalid} invalid, not graded)` : ''}, todo ${runs.filter((r) => r.todo).length}/${runs.length}${passed === runs.length ? '' : `: ${runs.filter((r) => !r.pass).map((r) => r.reasons.join(', ')).join(' | ')}`}`);
  }
} finally { removeTemp(dirname(root)); }
const date = new Date().toISOString().slice(0, 10);
const out = partial ? join(raw, 'snapshot.json') : join(ROOT, 'evals', 'snapshots', `adherence-${VARIANT}-${MODEL.replace(/^claude-/, '')}-${date}.json`);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, variant: VARIANT, runs: RUNS, plugin: PLUGIN,
  gating: VARIANT === 'routed' && !/haiku/.test(MODEL), results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
process.exit(results.every((r) => r.pass) ? 0 : 1);
