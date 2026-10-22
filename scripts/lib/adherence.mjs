// Grade a headless Claude Code run for kernel adherence (design spec 11.1 tier 2, coverage gap 10).
// A routed task passes when it reads the route (a Read of <plugin root>/skills/<route>/SKILL.md or a
// Skill call to kern:<route>) with at most one other tool call before it, todo tools and calls that only
// read <plugin root>/kernel/routes.md aside (a kern tree before Task 16d has that file; in a multi-turn
// case, within the first task): the user relaxed the rule on 2026-10-18 from "the route is the first call".
// The first todo list, and whether it holds the route's steps in order, is reported, not graded.
// A bare skill name, or a skill file outside the plugin root, is not kern's route, and a read that stops
// before the route's first step is not a read of it (Task 16p).
// Pass rule adapted from superpowers tests/explicit-skill-requests/run-test.sh:103-118 (MIT).
import { readFileSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { countProblem, promptResult, runProblem, toolUses } from './claude-run.mjs';

// rowPrompt(root, route): a positive case's prompt is its row's first routing eval, so the two cannot drift.
export const rowPrompt = (root, route) => JSON.parse(readFileSync(join(root, 'evals', 'cases', `row-${route}.json`), 'utf8')).evals[0].prompt;

// runFailure(run, prompts): why a run counts as not having happened, or '' when it may be graded. prompts is
// the number of prompts sent. A run capped by --max-turns is still graded (routing shows in the first
// calls), so its problem is not a failure; any other problem (a non-zero exit, no events, an error result)
// is, and so is a result count that differs from prompts, capped or not: a task that never ran as its own
// turn cannot be graded. runProblem reports the cap as an error_max_turns result, but a non-zero exit comes
// first in its message, so the cap is read from the result event itself.
export function runFailure(run, prompts) {
  const problem = runProblem(run, prompts);
  const count = countProblem(run, prompts);
  const results = run.events.filter((e) => e?.type === 'result');
  // Every result must be a cap or a clean success (a two-prompt run has two), and at least one a cap.
  const cap = (e) => e.subtype === 'error_max_turns';
  const capped = run.badLines === 0 && results.length > 0 && results.some(cap) && results.every((e) => cap(e) || (e.subtype === 'success' && e.is_error !== true));
  if (capped) return count;
  const bad = results.find((e) => !cap(e) && (e.subtype !== 'success' || e.is_error === true));
  return problem && !count && bad && run.status === 0 && run.badLines === 0 ? `the run ended with ${bad.subtype ?? 'a result with no subtype'}${bad.is_error === true ? ' (is_error)' : ''}` : problem;
}

// removeTemp(dir): rmSync that refuses a path outside the OS temp dir, so a wrong root can never delete a repo or its parent.
export function removeTemp(dir) {
  const base = realpathSync(tmpdir());
  if (!realpathSync(dir).startsWith(base + sep)) throw new Error(`refusing to remove ${dir}: not under ${base}`);
  rmSync(dir, { recursive: true, force: true });
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

// stepLine(skillText): the 1-based line of the first numbered line under `## Steps`, or null when the file has
// no `## Steps` heading or no numbered line before the next `## ` heading.
export function stepLine(skillText) {
  const lines = skillText.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim() === '## Steps');
  if (start < 0) return null;
  for (let i = start + 1; i < lines.length && !/^## /.test(lines[i]); i++) if (/^\d+\.\s+/.test(lines[i])) return i + 1;
  return null;
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
const SEGMENTS = /&&|\|\||;|\||\n/;
// readerWords(seg): the words after the command name, unquoted, when the segment prints a file; else null.
// A segment that writes the file, follows it or runs it as a program is not a read the model sees: an
// output redirect (stderr ones aside), sed -i, tail -f, awk -f.
const readerWords = (seg) => {
  const s = seg.replace(/\d?>&\d|2>\s*\/dev\/null/g, '');
  const words = s.trim().split(/\s+/);
  if (!READERS.test(words[0] || '') || s.includes('>') || words.some((w) => /^-(?:i|f|F)|^--(?:in-place|follow)/.test(w))) return null;
  return words.slice(1).map((w) => w.replace(/^['"]|['"]$/g, ''));
};
const bashReads = (u) => (u.name === 'Bash' && typeof u.input.command === 'string'
  ? u.input.command.split(SEGMENTS).flatMap((seg) => (readerWords(seg) ?? []).filter((w) => w.startsWith('/')))
  : []);
const readsOf = (u) => (u.name === 'Read' && typeof u.input.file_path === 'string' ? [u.input.file_path] : bashReads(u)).map(canon);
const readOf = (u, path) => readsOf(u).includes(canon(path));
// routeCall: u reads the route's file (skills/<route>/SKILL.md, or routeFile for a kernel-file route such
// as kernel/context.md) under the plugin root, or calls the Skill tool with kern:<route>.
export const routeCall = (u, route, root, routeFile = `skills/${route}/SKILL.md`) => readOf(u, `${root}/${routeFile}`) || (u.name === 'Skill' && u.input.skill === `kern:${route}`);
export const routesCall = (u, root) => readOf(u, `${root}/kernel/routes.md`);
// Line spans (Task 16p): [from, to], 1-based and inclusive, to Infinity for a read to the end of the file.
// lineSpan(cmd, words, len): the span a head, tail or sed stage prints of its input, len lines long, from its
// own words; a form it cannot measure (head -c, a sed script with a pattern, any other reader) prints it all.
const WHOLE = [1, Infinity];
const lineSpan = (cmd, words, len) => {
  if (cmd === 'head' || cmd === 'tail') {
    let n = '10';
    for (let i = 0; i < words.length; i++) {
      const w = words[i];
      if (w === '-n' || w === '--lines') n = words[++i] ?? '';
      else if (/^-n./.test(w)) n = w.slice(2);
      else if (w.startsWith('--lines=')) n = w.slice(8);
      else if (/^-\d+$/.test(w) || (cmd === 'tail' && /^\+\d+$/.test(w))) n = w.replace(/^-/, '');
      else if (w.startsWith('-')) return WHOLE;
    }
    if (!/^\+?\d+$/.test(n)) return WHOLE;
    if (cmd === 'head') return n.startsWith('+') ? WHOLE : [1, Number(n)];
    return n.startsWith('+') ? [Math.max(1, Number(n)), Infinity] : [Math.max(1, len - Number(n) + 1), Infinity];
  }
  if (cmd !== 'sed') return WHOLE;
  const quiet = words.includes('-n');
  const script = words.find((w, i) => !w.startsWith('-') && (i === 0 || words[i - 1] !== '-f'));
  const p = quiet && script?.match(/^(\d+)(?:,(\d+|\$))?p$/);
  if (p) return [Number(p[1]), p[2] === undefined ? Number(p[1]) : p[2] === '$' ? Infinity : Number(p[2])];
  const q = !quiet && script?.match(/^(\d+)q$/);
  return q ? [1, Number(q[1])] : WHOLE;
};
// readSpans(u, path, len): the spans of path, a file len lines long, that u shows the model. A Read covers
// lines offset to offset+limit-1, offset 0 or none being line 1 (a Read with offset 9 prints from line 9:
// evals/results/exec-2026-10-21-run1/finish-pr-older-head.events.jsonl). In Bash, each pipeline's reading
// stage that names path gives the span its own words print, cut by each head, tail or sed stage after it.
const PIPELINES = /&&|\|\||;|\n/;
const readSpans = (u, path, len) => {
  const want = canon(path);
  if (u.name === 'Read') {
    if (typeof u.input.file_path !== 'string' || canon(u.input.file_path) !== want) return [];
    const from = Math.max(1, Number(u.input.offset) || 1);
    return [[from, u.input.limit === undefined ? Infinity : from + Number(u.input.limit) - 1]];
  }
  if (u.name !== 'Bash' || typeof u.input.command !== 'string') return [];
  return u.input.command.split(PIPELINES).flatMap((pipeline) => {
    const stages = pipeline.split('|').map((seg) => ({ seg, words: readerWords(seg) }));
    const at = stages.findIndex(({ words }) => words?.some((w) => w.startsWith('/') && canon(w) === want));
    if (at < 0) return [];
    let [from, to] = lineSpan(stages[at].seg.trim().split(/\s+/)[0], stages[at].words, len);
    for (const { seg, words } of stages.slice(at + 1)) {
      if (!words) continue;
      const [a, b] = lineSpan(seg.trim().split(/\s+/)[0], words, Math.min(to, len) - from + 1);
      [from, to] = [from + a - 1, Math.min(to, from + b - 1)];
    }
    return [[from, to]];
  });
};
// stepsRead(u, path, text): null when u reads path to the first step of text (stepLine) or text places no
// step, else the spans it read, which all miss that step.
const stepsRead = (u, path, text) => {
  const at = text ? stepLine(text) : null;
  if (at === null || u.name === 'Skill') return null;
  const len = text.split(/\r?\n/).length - (text.endsWith('\n') ? 1 : 0);
  const spans = readSpans(u, path, len);
  return spans.some(([from, to]) => from <= at && at <= to) ? null : { spans, at };
};
const spanText = ([from, to]) => `lines ${from} to ${to === Infinity ? 'the end' : to}`;
// routesOnly: u reads routes.md and nothing else, so it is free before the route: a Read of it, or a Bash
// call each of whose parts prints a file and names no file but routes.md (a filter after a pipe, such as
// head -40, names none). A flag, a count (40, 1,80p) or a script with a comma or brace and no slash is not
// a file; any other word is, a glob, a brace list, a $ word or a relative name included.
const fileWord = (w) => w !== '' && !w.startsWith('-') && !/^\d+(?:,\d+)?[a-z]?$/.test(w) && !(/[,{}]/.test(w) && !w.includes('/'));
const routesOnly = (u, root) => routesCall(u, root) && (u.name !== 'Bash' || u.input.command.split(SEGMENTS).every((seg) => {
  if (!seg.trim()) return true;
  const words = readerWords(seg);
  return words !== null && words.filter(fileWord).every((w) => w.startsWith('/') && canon(w) === canon(`${root}/kernel/routes.md`));
}));
// bashWords(u): every word a reading Bash segment names, relative ones included.
const bashWords = (u) => (u.name === 'Bash' && typeof u.input.command === 'string' ? u.input.command.split(SEGMENTS).flatMap((seg) => readerWords(seg) ?? []) : []);
const anyKernRoute = (u, root) => readsOf(u).some((f) => f.startsWith(`${canon(join(root, 'skills'))}/`) && f.endsWith('/SKILL.md')) ||
  routesCall(u, root) || readOf(u, `${root}/kernel/context.md`) || (u.name === 'Skill' && /^kern:/.test(String(u.input.skill || '')));

function todoItems(uses) {
  const firstEdit = uses.findIndex((u) => EDITS.has(u.name));
  const todo = uses.find((u) => u.name === 'TodoWrite');
  if (todo) return (todo.input.todos ?? []).map((t) => t.content ?? '');
  return uses.filter((u, i) => u.name === 'TaskCreate' && (firstEdit === -1 || i < firstEdit)).map((u) => u.input.subject ?? '');
}

const callText = (u) => `${u.name} ${u.input.file_path || u.input.command || u.input.skill || u.input.pattern || ''}`.trim();

// grade(events, { route, routeFile, steps, text, root, kind, projectSkill }):
// { pass, reasons, items, hops, before, todo, todoSteps, notes }. text is the route file's text: given, a
// Read or Bash read of the route counts only when it shows the route's first step (stepsRead); without it,
// any read of the file counts. A Skill call to kern:<route> always counts. Once the route is read, hops is
// 1, or 2 when routes.md was read before it, and before counts the other calls before it (0 or 1 in a pass).
// todo says whether a todo list was opened, todoSteps whether it holds the route's steps in order, and
// notes say what it lacks; none of the three gates. kind: positive (default), negative (no kern route at
// all; with projectSkill, that project skill is used instead, and only the job's own kern route counts as
// a hit) or multi-turn (positive, and the route is read again for the second task).
export function grade(events, { route, routeFile, steps = [], text = null, root, kind = 'positive', projectSkill = null }) {
  const uses = toolUses(events);
  const work = uses.filter((u) => !TODO_TOOLS.has(u.name));
  const reasons = [];
  const items = todoItems(uses);
  if (kind === 'negative') {
    const hit = work.find((u) => (projectSkill ? routeCall(u, projectSkill, root) : anyKernRoute(u, root)));
    if (hit) reasons.push(`a kern route was read: ${hit.name} ${hit.input.file_path || hit.input.skill || hit.input.command}`);
    if (projectSkill && !work.some((u) => (u.name === 'Skill' && u.input.skill === projectSkill) ||
      [...readsOf(u), ...bashWords(u)].some((f) => f === `.claude/skills/${projectSkill}/SKILL.md` || f.endsWith(`/.claude/skills/${projectSkill}/SKILL.md`)))) {
      reasons.push(`the project skill ${projectSkill} was not used`);
    }
    return { pass: reasons.length === 0, reasons, items, hops: 0, before: 0, todo: items.length > 0, todoSteps: null, notes: [] };
  }
  let hops = 0;
  let before = 0;
  // With the route file's text, a read of the route counts only when it reaches the first step (Task 16p).
  const file = routeFile || `skills/${route}/SKILL.md`;
  const shortOf = (u) => (routeCall(u, route, root, routeFile) ? stepsRead(u, `${root}/${file}`, text) : null);
  const hit = (u) => routeCall(u, route, root, routeFile) && !shortOf(u);
  const shortText = (uses) => {
    const s = uses.map(shortOf).find(Boolean);
    return s && `read ${file} only as ${s.spans.map(spanText).join(' and ')}, which miss its first step at line ${s.at}`;
  };
  // The second task starts after the first prompt's result: runClaude sends each prompt as one user turn on
  // stdin, the second only after the first turn's result, and stream-json writes one result per turn
  // (evals/results/exec-2026-10-16/finish-pr-at-head.events.jsonl: two prompts, a result at line 6 and at
  // line 114). A background task's turn also ends in a result, which is not a prompt's (promptResult).
  // runFailure does not let a run with fewer prompt results than prompts reach this grade. A multi-turn
  // case finds the route in the first task.
  const turn = events.findIndex(promptResult);
  const first = kind === 'multi-turn' && turn >= 0 ? toolUses(events.slice(0, turn)).filter((u) => !TODO_TOOLS.has(u.name)) : work;
  const at = first.findIndex(hit);
  const early = at < 0 ? [] : first.slice(0, at).filter((u) => !routesOnly(u, root));
  if (at < 0) reasons.push(`${shortText(first) || `never read ${file} under the plugin root, nor called kern:${route}`}${kind === 'multi-turn' ? ', in the first task' : ''}`);
  else {
    hops = early.length < at ? 2 : 1;
    before = early.length;
    if (early.length > 1) reasons.push(`two tool calls came before the route: ${callText(early[0])}, then ${callText(early[1])}`);
  }
  const missing = [];
  steps.forEach((step, i) => {
    const item = items[i];
    const key = normalize(step).slice(0, 24);
    if (!(item !== undefined && (/^\s*skip:/i.test(item) || normalize(item).startsWith(key)))) missing.push(`step ${i}: "${step.slice(0, 60)}"`);
  });
  const notes = [];
  if (!items.length) notes.push('no todo list');
  else if (missing.length) notes.push(`todo list does not hold the steps in order: ${missing.join('; ')}`);
  if (kind === 'multi-turn') {
    const second = turn < 0 ? [] : toolUses(events.slice(turn + 1)).filter((u) => !TODO_TOOLS.has(u.name));
    if (!second.some(hit)) reasons.push(`the second task did not read the route again${shortText(second) ? `: it ${shortText(second)}` : ''}`);
  }
  return { pass: reasons.length === 0, reasons, items, hops, before, todo: items.length > 0, todoSteps: items.length > 0 && missing.length === 0, notes };
}
