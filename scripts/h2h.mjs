#!/usr/bin/env node
// Head-to-head evals: each task under each arm, then one blind grader call per task-run that sees the
// redacted attempts under opaque ids. The key (blind id to arm) is written only after grading, outside
// anything the grader reads. Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/h2h.mjs [--category plan|diagnose|review] [--task <category/id>] [--arms a,b]
//        [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]
// Raw runs and key.json go to evals/results/h2h-<date>/ (gitignored); the unblinded scores and the gate
// go to evals/snapshots/h2h-<model>-<date>.json (committed).
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, finalText, toolUses, workspace } from './lib/claude-run.mjs';
import { digest, pluginCopy, tryRun } from './lib/behave.mjs';
import { armCopy, blindIds, falseAlarms, gate, graderPrompt, loadArms, loadTasks, outOfArea, parseGrades, redact } from './lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const GRADER = opt('--grader-model', 'claude-opus-5-5');
const RUNS = Number(opt('--runs', '3'));
const pick = opt('--arms', null)?.split(',');
const arms = loadArms(ROOT, pick);
const tasks = loadTasks(ROOT).filter((t) => (!opt('--category') || t.category === opt('--category')) && (!opt('--task') || t.id === opt('--task')));
if (!tasks.length) { console.error('h2h: no task matched'); process.exit(2); }
if (args.includes('--dry-run')) {
  for (const t of tasks) console.log(`${t.id}: ${arms.map((a) => a.id).join(', ')} x ${RUNS} runs; ${t.prompts.length} turn(s)`);
  process.exit(0);
}
const date = new Date().toISOString().slice(0, 10);
const rev = (dir) => { try { return execFileSync('git', ['-C', dir, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(); } catch { return 'unknown: not a git checkout'; } };
const raw = join(ROOT, 'evals', 'results', `h2h-${date}`);
mkdirSync(raw, { recursive: true });
// The kern arm runs from a copy of the plugin without evals/, tests/ and the answer keys, so a model in that
// arm cannot read labels.json or heldout/ under its plugin root. The arm's commit comes from the real checkout.
const kernArm = arms.find((a) => a.id === 'kern');
const copy = kernArm ? pluginCopy(ROOT) : null;
if (kernArm) { kernArm.srcDir = kernArm.dir; kernArm.dir = copy; }
// Every other plugin arm runs from a copy too: outside the repo, symlinks resolved, no .git, so a model
// cannot walk up into the repo's evals/ or answer keys.
const armCopies = [];
const key = {}; const results = [];
try {
for (const a of arms) if (a.plugin && a.id !== 'kern') { a.srcDir = a.dir; a.dir = armCopy(a.dir, a.id); armCopies.push(a.dir); }
for (const t of tasks) {
  for (let r = 0; r < RUNS; r++) {
    const seed = `${date}:${t.id}:${r}`;
    const ids = blindIds(arms.map((a) => a.id), seed);
    const attempts = [];
    let voided = '';
    for (const a of arms) {
      const cwd = workspace(join(t.dir, 'repo'), { name: t.project || 'app', origin: !!t.origin, branch: t.branch || '', setup: t.setup || [] });
      const git = (...g) => execFileSync('git', ['-C', cwd, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...g], { encoding: 'utf8' });
      if (t.patch) { git('apply', join(t.dir, t.patch)); git('add', '-A'); git('commit', '-qm', t.patch_message || 'feat: the change under review'); }
      const { run, problem } = tryRun({ cwd, prompts: t.prompts, pluginDirs: a.dir ? [a.dir] : [], model: MODEL, maxTurns: t.max_turns || 40 });
      if (problem) { voided = `${a.id}: ${problem}`; rmSync(dirname(cwd), { recursive: true, force: true }); break; }
      git('add', '-A', '-N');
      const diff = git('diff', 'HEAD');
      const files = git('diff', '--name-only', 'HEAD').split('\n').filter(Boolean);
      const e = { outOfArea: outOfArea(files, t.area || []).length };
      let heldout = null;
      if (t.category === 'diagnose') {
        writeFileSync(join(dirname(cwd), 'change.diff'), diff);
        e.floorHits = diff ? spawnSync('bash', [join(ROOT, 'scripts', 'floor-scan'), join(dirname(cwd), 'change.diff')], { cwd, encoding: 'utf8' }).stdout.split('\n').filter(Boolean).length : 0;
        cpSync(join(t.dir, 'heldout'), cwd, { recursive: true });
        heldout = spawnSync('bash', ['-c', t.test], { cwd, encoding: 'utf8', timeout: 120000 }).status === 0;
      }
      writeFileSync(join(raw, `${t.id.replace('/', '--')}-${r}-${ids[a.id]}.jsonl`), run.events.map((x) => JSON.stringify(x)).join('\n'));
      // A plan lands in an ignored work directory, so the grader reads what each run wrote, not the diff.
      const wrote = t.category === 'plan' ? toolUses(run.events).filter((u) => u.name === 'Write').map((u) => `--- ${u.input.file_path}\n${u.input.content}`).join('\n\n') : '';
      attempts.push({ arm: a.id, id: ids[a.id], e, heldout, text: redact(`${digest(run.events, 24000, { results: true })}\n\nDiff:\n${diff || '(none)'}${wrote ? `\n\nFiles written:\n${wrote}` : ''}`, arms) });
      rmSync(dirname(cwd), { recursive: true, force: true });
    }
    if (voided) { console.log(`VOID ${t.id} run ${r}: ${voided}`); continue; }
    attempts.sort((x, y) => x.id.localeCompare(y.id));
    const gdir = mkdtempSync(join(tmpdir(), 'g-'));
    const graded = tryRun({ cwd: gdir, prompts: [graderPrompt(t, attempts)], model: GRADER, maxTurns: 1 });
    rmSync(gdir, { recursive: true, force: true });
    if (graded.problem) { console.log(`VOID ${t.id} run ${r}: grader: ${graded.problem}`); continue; }
    let grades;
    try { grades = parseGrades(finalText(graded.run.events), attempts.map((x) => x.id)); } catch (err) { console.log(`VOID ${t.id} run ${r}: ${err.message}`); continue; }
    key[seed] = ids;
    for (const x of attempts) {
      const g = grades[x.id];
      const e = { ...x.e, decoyHits: (g.decoys ?? []).length, unmatched: g.unmatched ?? 0, unsupported: g.unsupported ?? 0 };
      const score = t.category === 'diagnose' && !x.heldout ? 0 : g.score / 10;
      results.push({ task: t.id, category: t.category, run: r, arm: x.arm, score, falseAlarms: falseAlarms(t.category, e), heldout: x.heldout, matched: g.matched ?? [], why: g.why ?? '' });
    }
  }
}
} finally {
  if (copy) rmSync(dirname(copy), { recursive: true, force: true });
  for (const c of armCopies) rmSync(dirname(c), { recursive: true, force: true });
}
writeFileSync(join(raw, 'key.json'), JSON.stringify(key, null, 2) + '\n');
const verdict = gate(results, [...new Set(tasks.map((t) => t.category))]);
for (const v of verdict) console.log(`${v.pass ? 'PASS' : 'FAIL'} ${v.category}${v.reason ? `: ${v.reason}` : ''}`);
const out = join(ROOT, 'evals', 'snapshots', `h2h-${MODEL.replace(/^claude-/, '')}-${date}.json`);
writeFileSync(out, JSON.stringify({ model: MODEL, grader: GRADER, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, runs: RUNS,
  arms: arms.map((a) => ({ id: a.id, plugin: a.plugin, commit: a.dir ? rev(a.srcDir ?? a.dir) : null })), gate: verdict, results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
process.exit(verdict.every((v) => v.pass) ? 0 : 1);
