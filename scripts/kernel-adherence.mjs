#!/usr/bin/env node
// Kernel adherence (design spec 11.1 tier 2, coverage gap 10): does a routed prompt make Claude read the
// route first and copy its steps into the todo list, and does a prompt that should not route stay quiet?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/kernel-adherence.mjs [--case <id>] [--runs N] [--model <m>] [--variant routed|inline-rows] [--dry-run]
//        node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]
// Writes evals/snapshots/adherence-<variant>-<model>-<date>.json (committed).
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, runClaude, runProblem, workspace } from './lib/claude-run.mjs';
import { grade, inlineRows, readSteps, rowPrompt } from './lib/adherence.mjs';
import { stage } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const VARIANT = opt('--variant', 'routed');
const only = opt('--case', null);
const routeFileOf = (c) => c.route_file || `skills/${c.route}/SKILL.md`;

if (args.includes('--transcript')) {
  const root = opt('--root', ROOT);
  const route = opt('--route', null);
  const events = readFileSync(opt('--transcript'), 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
  const file = route === 'context' ? 'kernel/context.md' : `skills/${route}/SKILL.md`;
  const g = grade(events, { route, routeFile: file, steps: readSteps(readFileSync(join(root, file), 'utf8')), root });
  console.log(`${g.pass ? 'PASS' : 'FAIL'} ${route} (${g.hops} hops)${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
  process.exit(g.pass ? 0 : 1);
}

const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8')).filter((c) => !only || c.id === only)
  .map((c) => ({ ...c, prompts: c.prompts ?? [rowPrompt(ROOT, c.route)] }));
if (args.includes('--dry-run')) {
  for (const c of cases) console.log(`${c.id}: ${c.kind} ${c.route || '-'} on ${c.files.join('+')}: ${c.prompts.map((p) => JSON.stringify(p)).join(' then ')}`);
  process.exit(0);
}
const root = VARIANT === 'inline-rows' ? inlineRows(ROOT) : ROOT;
const results = [];
for (const c of cases) {
  const steps = c.route ? readSteps(readFileSync(join(root, routeFileOf(c)), 'utf8')) : [];
  const runs = [];
  for (let i = 0; i < RUNS; i++) {
    const src = stage(ROOT, c.files);
    const cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
    if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
    if (c.settings) { mkdirSync(join(cwd, '.claude'), { recursive: true }); writeFileSync(join(cwd, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
    // A turn cap is expected here: routing is graded from the first calls, so a capped run is still graded and
    // its problem recorded. A run that did not happen (a timeout, a signal) fails the run, with the reason.
    let run = null; let problem = '';
    try { run = runClaude({ cwd, prompts: c.prompts, pluginDirs: [root], model: MODEL, maxTurns: c.kind === 'multi-turn' ? 16 : 8 }); problem = runProblem(run); }
    catch (e) { if (e.fatal) throw e; problem = e.message; }
    const g = run ? grade(run.events, { route: c.route, routeFile: c.route_file, steps, root, kind: c.kind, projectSkill: c.project_skill || null }) : { pass: false, hops: 0, reasons: [problem] };
    runs.push({ pass: g.pass, hops: g.hops, reasons: g.reasons, problem, exit: run ? run.status : null });
    rmSync(dirname(cwd), { recursive: true, force: true });
  }
  const passed = runs.filter((r) => r.pass).length;
  results.push({ id: c.id, kind: c.kind, route: c.route, passed, runs: runs.length, pass: passed * 3 >= runs.length * 2, detail: runs });
  console.log(`${passed * 3 >= runs.length * 2 ? 'PASS' : 'FAIL'} ${c.id}: ${passed}/${runs.length}${passed === runs.length ? '' : `: ${runs.filter((r) => !r.pass).map((r) => r.reasons.join(', ')).join(' | ')}`}`);
}
const date = new Date().toISOString().slice(0, 10);
const out = join(ROOT, 'evals', 'snapshots', `adherence-${VARIANT}-${MODEL.replace(/^claude-/, '')}-${date}.json`);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, variant: VARIANT, runs: RUNS,
  gating: VARIANT === 'routed' && !/haiku/.test(MODEL), results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
if (VARIANT === 'inline-rows') rmSync(dirname(root), { recursive: true, force: true });
process.exit(results.every((r) => r.pass) ? 0 : 1);
