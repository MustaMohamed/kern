// Head-to-head evals (design spec 11.1 tier 3): the same task, the same fixture and the same model under
// each arm (kern, the upstream plugins it learned from, and no plugin), graded blind.
// A task lives in evals/h2h/<category>/<task>/: task.json, repo/ (the project the arm sees), heldout/
// (tests copied in only at grading), reference.patch (diagnose: the fix the heldout tests accept) and
// labels.json (review: seeded bugs and decoys).
// Blinding rules from pstack skills/poteto-mode/playbooks/eval.md:5-13 (MIT; nothing the candidate sees names
// an eval; the judge sees sanitized labels and scores all arms in one pass); the no-plugin control from
// caveman evals/README.md:17 (Apache-2.0; ideas only).
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdtempSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export const CATEGORIES = ['plan', 'diagnose', 'review'];

// armCopy(dir, id): the plugin tree at dir copied to <tmp>/<random>/<id>, without .git and with symlinks
// resolved, so a run cannot reach back into the repo. The caller removes dirname(copy).
export function armCopy(dir, id) {
  const copy = join(mkdtempSync(join(tmpdir(), 'a-')), id);
  cpSync(dir, copy, { recursive: true, dereference: true, filter: (src) => src.split('/').pop() !== '.git' });
  return copy;
}

export function loadArms(root, only = null) {
  return JSON.parse(readFileSync(join(root, 'evals', 'h2h', 'arms.json'), 'utf8')).filter((a) => !only || only.includes(a.id)).map((a) => {
    if (a.plugin && !existsSync(join(root, a.plugin, '.claude-plugin', 'plugin.json'))) {
      throw new Error(`h2h: arm ${a.id} needs ${a.plugin}/.claude-plugin/plugin.json; run scripts/fetch-upstream`);
    }
    return { ...a, dir: a.plugin ? join(root, a.plugin) : null };
  });
}

export function loadTasks(root) {
  const out = [];
  for (const category of CATEGORIES) {
    const dir = join(root, 'evals', 'h2h', category);
    if (!existsSync(dir)) continue;
    for (const id of readdirSync(dir).filter((n) => existsSync(join(dir, n, 'task.json'))).sort()) {
      const t = JSON.parse(readFileSync(join(dir, id, 'task.json'), 'utf8'));
      if (t.category !== category) throw new Error(`h2h: ${category}/${id}/task.json says category ${t.category}`);
      const labels = join(dir, id, 'labels.json');
      out.push({ id: `${category}/${id}`, dir: join(dir, id), ...t, labels: existsSync(labels) ? JSON.parse(readFileSync(labels, 'utf8')) : undefined });
    }
  }
  return out;
}

// blindIds(armIds, seed): arm id to an opaque label, stable for one seed, different across seeds.
export function blindIds(armIds, seed) {
  const order = [...armIds].sort((a, b) => hash(`${seed}:${a}`).localeCompare(hash(`${seed}:${b}`)));
  return Object.fromEntries(order.map((a, i) => [a, `arm-${String.fromCharCode(65 + i)}`]));
}
const hash = (s) => createHash('sha256').update(s).digest('hex');

// redact(text, arms): remove what names an arm: plugin and skill names, plugin paths, namespaced skill
// calls, and kern's own script and ledger vocabulary. The grader must not tell the arms apart by name.
export function redact(text, arms) {
  let t = String(text).replace(/\.kern\//g, '.work/');
  for (const a of arms.filter((x) => x.dir).sort((x, y) => y.dir.length - x.dir.length)) t = t.split(`/private${a.dir}`).join('<plugin>').split(a.dir).join('<plugin>');
  t = t.replace(/\b(?:kern|superpowers|mattpocock-skills|mattpocock|pocock|pstack|poteto|caveman)\b(?::[\w-]+)?/gi, '<plugin>');
  t = t.replace(/(?:CLAUDE_PLUGIN_ROOT|KERN_[A-Z_]+)/g, '<plugin-var>');
  t = t.replace(/\/(?:skills|agents|kernel)\/[\w-]+(?:\/[\w./-]+)?/g, '/<plugin-file>');
  return t;
}

// outOfArea(files, area): changed files that no area glob covers. A glob is a path prefix or a path
// ending in /** (the whole directory).
export function outOfArea(files, area) {
  return files.filter((f) => !area.some((g) => (g.endsWith('/**') ? f.startsWith(g.slice(0, -2)) : f === g)));
}

// falseAlarms(category, evidence): the count the gate compares. review: findings the grader matched to
// a decoy, plus findings matched to nothing; diagnose: floor-scan hits plus files outside the task's
// area; plan: claims the grader marked unsupported by the fixture.
export function falseAlarms(category, e) {
  if (category === 'review') return (e.decoyHits ?? 0) + (e.unmatched ?? 0);
  if (category === 'diagnose') return (e.floorHits ?? 0) + (e.outOfArea ?? 0);
  return e.unsupported ?? 0;
}

// gate(results): per category, kern passes when its mean score is at least the strongest other arm's,
// and its mean false alarms are at most that arm's. The control arm counts as an arm.
export function gate(results, expected = []) {
  const by = {};
  for (const r of results) ((by[r.category] ??= {})[r.arm] ??= []).push(r);
  const mean = (xs, k) => xs.reduce((s, x) => s + x[k], 0) / xs.length;
  const missing = expected.filter((c) => !by[c]).map((category) => ({ category, pass: false, reason: 'no graded run' }));
  return Object.entries(by).map(([category, arms]) => {
    if (!arms.kern) return { category, pass: false, reason: 'no kern runs' };
    const others = Object.entries(arms).filter(([a]) => a !== 'kern').map(([arm, xs]) => ({ arm, score: mean(xs, 'score'), fa: mean(xs, 'falseAlarms') }));
    const best = others.sort((a, b) => b.score - a.score || a.fa - b.fa)[0];
    const kern = { score: mean(arms.kern, 'score'), fa: mean(arms.kern, 'falseAlarms') };
    if (!best) return { category, pass: false, reason: 'no other arm ran', kern };
    const pass = kern.score >= best.score && kern.fa <= best.fa;
    return { category, pass, kern, best, reason: pass ? '' : `kern ${kern.score.toFixed(2)} score, ${kern.fa.toFixed(2)} false alarms; ${best.arm} ${best.score.toFixed(2)}, ${best.fa.toFixed(2)}` };
  }).concat(missing);
}

export function graderPrompt(task, outputs) {
  return [
    `You grade ${outputs.length} anonymous attempts at the same ${task.category} task. You do not know which tool made which.`,
    'Score each attempt 0 to 10 on the rubric. Judge only what each attempt shows; a claim it does not support with a command and its output earns nothing.',
    ...(task.category === 'review' ? ['For each finding, name the label id it matches: a bug id, "decoy:<id>" for a decoy, or "none".'] : []),
    ...(task.category === 'plan' ? ['Count the claims about the repo that the fixture files do not support.'] : []),
    'Reply with JSON only: {"grades":[{"id":"arm-A","score":7,"matched":["b1"],"decoys":["d2"],"unmatched":1,"unsupported":0,"why":"..."}]}.',
    '', 'Task given to each attempt:', task.prompts.join('\n---\n'), '', 'Rubric:', ...task.rubric.map((r, i) => `${i + 1}. ${r}`),
    ...(task.category === 'review' ? ['', 'Labels:', JSON.stringify(task.labels)] : []),
    ...outputs.map((o) => `\n=== ${o.id} ===\n${o.text}`),
  ].join('\n');
}

// parseGrades(text, ids): one grade per blind id, or throws. A malformed reply voids the task-run.
export function parseGrades(text, ids) {
  const m = String(text).match(/\{[\s\S]*\}/);
  if (!m) throw new Error('h2h grader: no JSON object in the reply');
  const g = Object.fromEntries((JSON.parse(m[0]).grades ?? []).map((x) => [x.id, x]));
  for (const id of ids) {
    if (!g[id] || typeof g[id].score !== 'number' || g[id].score < 0 || g[id].score > 10) throw new Error(`h2h grader: no valid score for ${id}`);
  }
  return g;
}
