// Grade a headless Claude Code run for kernel adherence (design spec 11.1 tier 2, coverage gap 10).
// A routed task passes only when its first tool call, todo tools aside, reads the route: a Read of
// <plugin root>/skills/<route>/SKILL.md or a Skill call to kern:<route>, or that second when the first
// is a Read of <plugin root>/kernel/routes.md; and the first todo list holds the route's steps in order.
// A bare skill name, or a skill file outside the plugin root, is not kern's route.
// Pass rule adapted from superpowers tests/explicit-skill-requests/run-test.sh:103-118 (MIT).
import { readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import { runProblem, toolUses } from './claude-run.mjs';
import { pluginCopy } from './behave.mjs';

// rowPrompt(root, route): a positive case's prompt is its row's first routing eval, so the two cannot drift.
export const rowPrompt = (root, route) => JSON.parse(readFileSync(join(root, 'evals', 'cases', `row-${route}.json`), 'utf8')).evals[0].prompt;

// runFailure(run): why a run counts as not having happened, or '' when it may be graded. A run capped by
// --max-turns is still graded (routing shows in the first calls), so its problem is not a failure; any other
// problem (a non-zero exit, no events, an error result) is. runProblem reports the cap as an error_max_turns
// result, but a non-zero exit comes first in its message, so the cap is read from the result event itself.
export function runFailure(run) {
  const problem = runProblem(run);
  const results = run.events.filter((e) => e?.type === 'result');
  // Every result must be a cap or a clean success (a two-prompt run has two), and at least one a cap.
  const cap = (e) => e.subtype === 'error_max_turns';
  const capped = run.badLines === 0 && results.length > 0 && results.some(cap) && results.every((e) => cap(e) || (e.subtype === 'success' && e.is_error !== true));
  if (capped) return '';
  const bad = results.find((e) => !cap(e) && (e.subtype !== 'success' || e.is_error === true));
  return problem && bad && run.status === 0 && run.badLines === 0 ? `the run ended with ${bad.subtype ?? 'a result with no subtype'}${bad.is_error === true ? ' (is_error)' : ''}` : problem;
}

// removeTemp(dir): rmSync that refuses a path outside the OS temp dir, so a wrong root can never delete a repo or its parent.
export function removeTemp(dir) {
  const base = realpathSync(tmpdir());
  if (!realpathSync(dir).startsWith(base + sep)) throw new Error(`refusing to remove ${dir}: not under ${base}`);
  rmSync(dir, { recursive: true, force: true });
}

// inlineRows(root): a copy of the plugin whose kernel table holds the routed rows itself and whose Routing
// rule no longer reads kernel/routes.md: the other arm of the F3 A/B. The copy is pluginCopy(root), so it has
// no eval files either. Returns the copy's root (through realpath: tmpdir() is a symlink on macOS and readOf
// compares plain paths), under a temp directory the caller removes with rmSync(dirname(dir)).
export function inlineRows(root) {
  const dir = realpathSync(pluginCopy(root));
  try {
    const rows = readFileSync(join(dir, 'kernel', 'routes.md'), 'utf8').split('\n').filter((l) => /^\| .* \| Read \{KERN\}\//.test(l));
    const kernel = join(dir, 'kernel', 'kernel.md');
    const before = readFileSync(kernel, 'utf8');
    const after = before
      .replace(', then Read {ROOT}/kernel/routes.md and match its rows when the task builds, fixes, plans, reviews, resumes or claims done', '')
      .replace(/(\|---\|---\|\n)/, `$1${rows.join('\n')}\n`);
    if (after === before || after.includes('routes.md') || !rows.length) throw new Error('inlineRows: the kernel no longer has the Routing sentence or the table this variant edits');
    writeFileSync(kernel, after);
    rmSync(join(dir, 'kernel', 'routes.md'));
    return dir;
  } catch (e) { rmSync(dirname(dir), { recursive: true, force: true }); throw e; }
}

export const TODO_TOOLS = new Set(['TodoWrite', 'TaskCreate', 'TaskUpdate', 'TaskList', 'TaskGet']);
const EDITS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);

export function readSteps(skillText) {
  const lines = skillText.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim() === '## Steps');
  if (start < 0) return [];
  const out = [];
  for (const l of lines.slice(start + 1)) {
    if (/^## /.test(l)) break;
    const m = l.match(/^\d+\.\s+(.*)$/);
    if (m) out.push(m[1]);
  }
  return out;
}

export const normalize = (s) => s.toLowerCase()
  .replace(/^\s*skip:\s*/, '')
  .replace(/^\s*\d+[.)]\s*/, '')
  .replace(/[`*_]/g, '')
  .replace(/\s+/g, ' ')
  .trim();

// macOS gives the temp dir as /var/... and its realpath as /private/var/...; both name one file.
const canon = (p) => resolve(p).replace(/^\/private(?=\/var\/)/, '');
// A Bash segment that prints a file: since Claude Code 2.1.302 a model often reads a skill with cat or sed.
const READERS = /^(?:cat|head|tail|sed|less|more|awk|nl|bat)$/;
const bashReads = (u) => (u.name === 'Bash' && typeof u.input.command === 'string'
  ? u.input.command.split(/&&|\|\||;|\||\n/).flatMap((seg) => {
    // A segment that writes the file, follows it or runs it as a program is not a read the model sees: an
    // output redirect (stderr ones aside), sed -i, tail -f, awk -f.
    const s = seg.replace(/\d?>&\d|2>\s*\/dev\/null/g, '');
    const words = s.trim().split(/\s+/);
    if (!READERS.test(words[0] || '') || s.includes('>') || words.some((w) => /^-(?:i|f|F)|^--(?:in-place|follow)/.test(w))) return [];
    return words.slice(1).map((w) => w.replace(/^['"]|['"]$/g, '')).filter((w) => w.startsWith('/'));
  })
  : []);
const readsOf = (u) => (u.name === 'Read' && typeof u.input.file_path === 'string' ? [u.input.file_path] : bashReads(u)).map(canon);
const readOf = (u, path) => readsOf(u).includes(canon(path));
// routeCall: u reads the route's file (skills/<route>/SKILL.md, or routeFile for a kernel-file route such
// as kernel/context.md) under the plugin root, or calls the Skill tool with kern:<route>.
export const routeCall = (u, route, root, routeFile = `skills/${route}/SKILL.md`) => readOf(u, `${root}/${routeFile}`) || (u.name === 'Skill' && u.input.skill === `kern:${route}`);
export const routesCall = (u, root) => readOf(u, `${root}/kernel/routes.md`);
const anyKernRoute = (u, root) => readsOf(u).some((f) => f.startsWith(`${canon(join(root, 'skills'))}/`) && f.endsWith('/SKILL.md')) ||
  routesCall(u, root) || readOf(u, `${root}/kernel/context.md`) || (u.name === 'Skill' && /^kern:/.test(String(u.input.skill || '')));

function todoItems(uses) {
  const firstEdit = uses.findIndex((u) => EDITS.has(u.name));
  const todo = uses.find((u) => u.name === 'TodoWrite');
  if (todo) return (todo.input.todos ?? []).map((t) => t.content ?? '');
  return uses.filter((u, i) => u.name === 'TaskCreate' && (firstEdit === -1 || i < firstEdit)).map((u) => u.input.subject ?? '');
}

// grade(events, { route, routeFile, steps, root, kind, projectSkill }): { pass, reasons, items, hops }.
// kind: positive (default), negative (no kern route at all; with projectSkill, that project skill is
// used instead, and only the job's own kern route counts as a hit) or multi-turn (positive, and the route
// is read again for the second task).
export function grade(events, { route, routeFile, steps = [], root, kind = 'positive', projectSkill = null }) {
  const uses = toolUses(events);
  const work = uses.filter((u) => !TODO_TOOLS.has(u.name));
  const reasons = [];
  if (kind === 'negative') {
    const hit = work.find((u) => (projectSkill ? routeCall(u, projectSkill, root) : anyKernRoute(u, root)));
    if (hit) reasons.push(`a kern route was read: ${hit.name} ${hit.input.file_path || hit.input.skill || hit.input.command}`);
    if (projectSkill && !work.some((u) => (u.name === 'Skill' && u.input.skill === projectSkill) ||
      readsOf(u).some((f) => f.endsWith(`/.claude/skills/${projectSkill}/SKILL.md`)))) {
      reasons.push(`the project skill ${projectSkill} was not used`);
    }
    return { pass: reasons.length === 0, reasons, items: [], hops: 0 };
  }
  let hops = 0;
  const hit = (u) => routeCall(u, route, root, routeFile);
  if (work[0] && hit(work[0])) hops = 1;
  else if (work[0] && routesCall(work[0], root) && work[1] && hit(work[1])) hops = 2;
  else if (!work.some(hit)) reasons.push(`never read ${routeFile || `skills/${route}/SKILL.md`} under the plugin root, nor called kern:${route}`);
  else reasons.push(`the route was not the first tool call: first was ${work[0]?.name} ${work[0]?.input.file_path || work[0]?.input.command || work[0]?.input.skill || ''}`.trim());
  const items = todoItems(uses);
  const missing = [];
  steps.forEach((step, i) => {
    const item = items[i];
    const key = normalize(step).slice(0, 24);
    if (!(item !== undefined && (/^\s*skip:/i.test(item) || normalize(item).startsWith(key)))) missing.push(`step ${i}: "${step.slice(0, 60)}"`);
  });
  if (!items.length) reasons.push('no todo list');
  else if (missing.length) reasons.push(`todo list does not hold the steps in order: ${missing.join('; ')}`);
  // The second task starts after the first result event: runClaude sends each prompt as one user turn on
  // stdin and stream-json writes one result per turn (evals/results/exec-2026-10-16/finish-pr-at-head.events.jsonl:
  // two prompts, a result at line 6 and at line 114).
  if (kind === 'multi-turn') {
    const turn = events.findIndex((e) => e?.type === 'result');
    const second = turn < 0 ? [] : toolUses(events.slice(turn + 1)).filter((u) => !TODO_TOOLS.has(u.name));
    if (!second.some(hit)) reasons.push('the second task did not read the route again');
  }
  return { pass: reasons.length === 0, reasons, items, hops };
}
