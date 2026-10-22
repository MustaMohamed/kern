// Grade a headless Claude Code run for kernel adherence (design spec 11.1 tier 2, coverage gap 10).
// A routed task passes when it reads the route (a Read of <plugin root>/skills/<route>/SKILL.md or a
// Skill call to kern:<route>) with at most one other tool call before it, todo tools and calls that only
// read <plugin root>/kernel/routes.md aside (a kern tree before Task 16d has that file; in a multi-turn
// case, within the first task): the user relaxed the rule on 2026-10-18 from "the route is the first call".
// The first todo list, and whether it holds the route's steps in order, is reported, not graded.
// A bare skill name, or a skill file outside the plugin root, is not kern's route, and a read that stops
// before the route's first step is not a read of it (Task 16p).
// Pass rule adapted from superpowers tests/explicit-skill-requests/run-test.sh:103-118 (MIT).
import { existsSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { LOOP_FLAGS, UsageError, loopProblem, parseArgs } from './args.mjs';
import { caseInputs, changedCases, rangeSources, skillHashes, touchedSkills, treeSource } from './case-inputs.mjs';
import { filesVersion, openRun, readRecord, reuseNote, roundLine, timeStamp, unitKey, unitStore, writeManifest } from './eval-cache.mjs';
import { limiter, ordered, tracker } from './pool.mjs';
import { caseResult, pluginCopy, stage } from './behave.mjs';
import { dirtyRefusal, treeRecord } from './run-record.mjs';
import { ISOLATION, PERMISSIONS, claudeVersion, countProblem, evalConfigProblem, pluginProblem, promptResult, runClaudeAsync, runProblem, toolUses, workspace } from './claude-run.mjs';

// adherenceFlags(ids): scripts/kernel-adherence.mjs's flags for the shared parser (args.mjs), ids being the case
// ids; --transcript, --route and --root are the offline grade of one saved session.
export const adherenceFlags = (ids) => ({ '--case': { key: 'case', value: 'a case id', choices: ids, noun: 'case' }, '--runs': { key: 'runs', value: 'count' },
  '--model': { key: 'model', value: 'a model id' }, '--variant': { key: 'variant', value: 'a variant' }, '--plugin': { key: 'plugin', value: 'a kern tree' },
  '--transcript': { key: 'transcript', value: 'a session file' }, '--route': { key: 'route', value: 'a route' }, '--root': { key: 'root', value: 'a plugin root' },
  '--dry-run': { key: 'dryRun' }, '--allow-dirty': { key: 'allowDirty' }, ...LOOP_FLAGS });

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

const USAGE = 'usage: node scripts/kernel-adherence.mjs [--case <id> | --changed <range>] [--runs N | --quick] [--jobs N] [--no-cache] [--model <m>] [--variant routed] [--plugin <kern tree>] [--allow-dirty] [--dry-run]\n'
  + '       node scripts/kernel-adherence.mjs --resume <results dir> [--jobs N] [--no-cache]\n'
  + '       node scripts/kernel-adherence.mjs --regrade <results dir>\n'
  + '       node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]';
const routeFileOf = (c) => c.route_file || `skills/${c.route}/SKILL.md`;
// kernOff(c): the case's settings turn kern off, so its run must show no kernel (neg-kern-off).
const kernOff = (c) => /^\s*kern:\s*off\s*$/m.test(c.settings ?? '');

// adherenceParts(c): what case c reads, for its input hash and --changed (case-inputs.mjs): its route's skill (none for a
// kernel-file route or a negative case, which read the kern core and every skill's frontmatter), its fixture layers,
// its entry in evals/adherence/cases.json, and the row prompt it takes when it gives none.
export const adherenceParts = (c) => ({ skills: c.route && !c.route_file ? [c.route] : [], paths: c.files.map((f) => `evals/fixtures/${f}/`),
  entries: [{ file: 'evals/adherence/cases.json', pick: (j) => (Array.isArray(j) ? j.find((x) => x.id === c.id) : undefined) },
    ...(c.prompts ? [] : [{ file: `evals/cases/row-${c.route}.json`, pick: (j) => j.evals?.[0]?.prompt }])] });

// ADHERENCE_CODE: the files whose code runs and grades an adherence run; their content is part of every run's cache key.
const ADHERENCE_CODE = ['scripts/lib/adherence.mjs', 'scripts/lib/behave.mjs', 'scripts/lib/claude-run.mjs', 'scripts/lib/claude-drive.mjs'];

// adherenceMain({ root, argv, env, cases, run, version, tree, snapshots, results, cache, log, error, now }): what
// scripts/kernel-adherence.mjs runs, a promise of its exit code, with the seams a test needs: the cases, the run
// (runClaudeAsync, or a stub), the Claude Code version, the tree record (tree(dir)) and the snapshot, results and cache
// dirs (Task 17a; the fast rounds after it).
// - Flags (adherenceFlags, LOOP_FLAGS) are read by the shared parser: any other word, or flags that do not go together
//   (loopProblem), are a usage error (2) before anything runs.
// - --transcript grades one saved session against --route offline, with --root as the plugin root.
// - Runs go to a pool (pool.mjs): --jobs N sessions at once, 6 by default; results, log lines and snapshots keep case
//   order. The first fatal error stops new runs; running ones finish and save, and the error is thrown.
// - A gating run is a full one (no --case, --plugin, --changed or --quick). It refuses a kern tree with uncommitted
//   changes it would measure, unless --allow-dirty; every snapshot records the tree as kern, and with --plugin that
//   tree's as plugin_tree.
// - --quick runs each case once, --changed <range> only the cases whose inputs changed (adherenceParts); each writes to
//   a results dir of its own, <name>-quick-<HHMMSS> or <name>-changed-<HHMMSS>.
// - Each run is a unit cached under its key (the case's inputs, with --plugin's tree for the kern files, the case, the
//   model, the code, the Claude Code version and the run's index); a valid one is reused unless --no-cache. Its record
//   goes beside its transcript, with the route text the run saw; --resume <dir> runs only what that run lacks, and
//   --regrade <dir> grades its transcripts again (regradeAdherence).
// - Each run must load the kern copy, and print the kernel unless the case turns kern off (pluginProblem, G10).
// - A case passes by caseResult (G5): at least two thirds of its valid runs pass, with at most one invalid run.
// - Snapshots: after each case, the progress so far goes to snapshot.json beside the transcripts (complete false).
//   Only a gating run with at least one valid run writes <snapshots>/adherence-<variant>-<model>-<date>.json
//   (complete true, every case id under cases), and then the progress file goes. Any other run, like an all-invalid
//   run or a stopped one, leaves the committed snapshot as it was.
export async function adherenceMain({ root, argv, env = process.env, cases: all = null, run = runClaudeAsync, version = claudeVersion, tree = treeRecord,
  snapshots = join(root, 'evals', 'snapshots'), results: resultsDir = join(root, 'evals', 'results'), cache = join(resultsDir, 'cache', 'adherence'),
  log = console.log, error = console.error, now = new Date() }) {
  const t0 = Date.now();
  const usage = (msg) => { error(`kernel-adherence: ${msg}\n${USAGE}`); return 2; };
  const allCases = all ?? JSON.parse(readFileSync(join(root, 'evals', 'adherence', 'cases.json'), 'utf8'));
  let o;
  try { o = parseArgs(argv, adherenceFlags(allCases.map((c) => c.id))); } catch (e) { if (e instanceof UsageError) return usage(e.message); throw e; }
  const loop = loopProblem(o, { select: { case: '--case' } });
  if (loop) return usage(loop);
  const withRoot = (c) => ({ ...c, prompts: c.prompts ?? [rowPrompt(root, c.route)] });
  if (o.regrade !== undefined) return regradeAdherence({ dir: o.regrade, cases: allCases.map(withRoot), log, usage, now });
  let resumeDir = null;
  let manifest = null;
  if (o.resume !== undefined) {
    try { ({ m: manifest, dir: resumeDir } = openRun(o.resume, 'adherence')); } catch (e) { if (e instanceof UsageError) return usage(e.message); throw e; }
    o = { ...manifest.options, jobs: o.jobs ?? manifest.options.jobs, noCache: !!o.noCache };
  }
  const MODEL = o.model ?? (env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
  const RUNS = o.runs ?? (o.quick ? 1 : 3);
  const JOBS = o.jobs ?? 6;
  const VARIANT = o.variant ?? 'routed';
  const only = o.case ?? null;
  // --plugin grades another kern tree (an older tag's worktree, for one); the cases still come from this repo.
  const PLUGIN = o.plugin ?? root;
  // A run of one case or of another plugin is diagnostic: its snapshot stays beside its transcripts, not in evals/snapshots.
  const partial = !!only || PLUGIN !== root;
  // The F3 A/B's inline-rows arm is now the kernel itself (Task 16d, the user's "Inline rows").
  if (VARIANT === 'inline-rows') return usage('--variant inline-rows is gone: the kernel table holds every route row since Task 16d, so the routed run is that arm');
  if (VARIANT !== 'routed') return usage(`--variant ${VARIANT}: the only variant is routed`);
  if (o.transcript === undefined && (o.route !== undefined || o.root !== undefined)) return usage('--route and --root go with --transcript only');

  if (o.transcript !== undefined) {
    const at = o.root ?? root;
    if (!o.route) return usage('--transcript needs --route <route>');
    const route = o.route;
    const events = readFileSync(o.transcript, 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
    const file = routeFileOf(allCases.find((c) => c.route === route) || { route });
    if (!existsSync(join(at, file))) return usage(`no route file ${file} under ${at}`);
    const text = readFileSync(join(at, file), 'utf8');
    const g = grade(events, { route, routeFile: file, steps: readSteps(text), text, root: at });
    log(`${g.pass ? 'PASS' : 'FAIL'} ${route} (${g.hops} hops, ${g.before} before, todo: ${g.todo}${g.todo ? `, steps: ${g.todoSteps}` : ''})${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
    return g.pass ? 0 : 1;
  }

  let picked;
  if (manifest) {
    const gone = manifest.options.ids.filter((id) => !allCases.some((c) => c.id === id));
    if (gone.length) return usage(`--resume: no case has the id ${gone.join(', ')} now; start a new run`);
    picked = allCases.filter((c) => manifest.options.ids.includes(c.id));
  } else if (o.changed !== undefined) {
    try {
      const { before, after } = rangeSources(root, o.changed);
      picked = changedCases(allCases, adherenceParts, before, after);
    } catch (e) { if (e instanceof UsageError) return usage(e.message); throw e; }
  } else picked = allCases.filter((c) => !only || c.id === only);
  const cases = picked.map(withRoot);
  if (o.dryRun) {
    if (o.changed !== undefined) log(`--changed ${o.changed}: ${cases.length} of ${allCases.length} cases`);
    for (const c of cases) log(`${c.id}: ${c.kind} ${c.route || '-'} on ${c.files.join('+')}: ${c.prompts.map((p) => JSON.stringify(p)).join(' then ')}`);
    if (PLUGIN !== root) log(`plugin: ${PLUGIN}`);
    return 0;
  }
  const refusal = evalConfigProblem(env);
  if (refusal) { error(`kernel-adherence: ${refusal}`); return 2; }
  if (PLUGIN !== root && !existsSync(join(PLUGIN, 'kernel', 'kernel.md'))) return usage(`--plugin ${PLUGIN} holds no kernel/kernel.md`);
  const gating = !partial && !o.quick && o.changed === undefined;
  const kern = tree(root);
  const pluginTree = PLUGIN !== root ? tree(PLUGIN) : null;
  if (gating && !o.allowDirty && dirtyRefusal(kern)) return usage(dirtyRefusal(kern));
  if (!cases.length) { log(`--changed ${o.changed}: no case reads a file that changed; nothing ran`); return 0; }
  let claude;
  try { claude = version(); } catch (e) { error(`kernel-adherence: cannot read the claude version (${String(e.message).split('\n')[0]}); nothing ran`); return 1; }
  const date = manifest?.date ?? now.toISOString().slice(0, 10);
  const name = `adherence-${VARIANT}-${MODEL.replace(/^claude-/, '')}-${date}`;
  const committed = join(snapshots, `${name}.json`);
  const mode = o.quick ? 'quick' : o.changed !== undefined ? 'changed' : null;
  // Each run's events go to the results dir (gitignored), so a failed case can be read, not only its grade.
  const raw = resumeDir ?? join(resultsDir, `${name}${partial ? `-${only || 'all'}-${basename(PLUGIN)}` : ''}${mode ? `-${mode}-${timeStamp(now)}` : ''}`);
  const progress = join(raw, 'snapshot.json');
  const ids = cases.map((c) => c.id);
  writeManifest(raw, { runner: 'adherence', date, started: manifest?.started ?? now.toISOString(), ...(manifest ? { resumed: [...(manifest.resumed ?? []), now.toISOString()] } : {}),
    claude, kern, options: { model: MODEL, runs: RUNS, jobs: JOBS, variant: VARIANT, case: only, ...(o.plugin !== undefined ? { plugin: o.plugin } : {}), quick: !!o.quick,
      ...(o.changed !== undefined ? { changed: o.changed } : {}), allowDirty: !!o.allowDirty, ids } });
  const results = [];
  const save = (file, complete) => {
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, JSON.stringify({ model: MODEL, claude, isolation: ISOLATION, permissions: PERMISSIONS, variant: VARIANT, runs: RUNS, ...(o.quick ? { quick: true } : {}),
      ...(o.changed !== undefined ? { changed: o.changed } : {}), plugin: PLUGIN, kern, ...(pluginTree ? { plugin_tree: pluginTree } : {}), gating: VARIANT === 'routed' && !/haiku/.test(MODEL),
      complete, cases: ids, results }, null, 2) + '\n');
  };
  const pluginRoot = realpathSync(pluginCopy(PLUGIN));
  // runUnit(c, i): run i of case c in a fresh workspace, graded; its record ({ valid, run, session, text }). session and
  // text keep what --regrade needs: the run's exit, its stderr's tail, the plugin root it loaded and the route text.
  const runUnit = async (c, i) => {
    // The route's text, so a read of it counts only when it reaches the route's first step (Task 16p).
    const text = c.route ? readFileSync(join(pluginRoot, routeFileOf(c)), 'utf8') : null;
    const expect = { plugins: [pluginRoot], kernel: kernOff(c) ? 'off' : 'on' };
    const src = stage(root, c.files);
    let cwd = null;
    try {
      cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
      if (c.settings) { mkdirSync(join(cwd, '.claude'), { recursive: true }); writeFileSync(join(cwd, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
      // A turn cap is expected here: routing is graded from the first calls, so a capped run is still graded and
      // its problem recorded. Any other run that did not happen (a timeout, a signal, a non-zero exit, a result
      // count that differs from the prompt count, a run without kern loaded as the case wants) fails the run,
      // with the reason.
      let r = null; let problem = ''; let failure = ''; let events = [];
      try {
        r = await run({ cwd, prompts: c.prompts, pluginDirs: [pluginRoot], model: MODEL, maxTurns: c.kind === 'multi-turn' ? 16 : 8 });
        const loaded = pluginProblem(r.events, expect);
        problem = runProblem(r, c.prompts.length) || loaded; failure = runFailure(r, c.prompts.length) || loaded; events = r.events;
      } catch (e) { if (e.fatal) throw e; problem = failure = e.message; events = e.events ?? []; }
      // A run cut off by the timeout keeps the events it printed.
      if (events.length) writeFileSync(join(raw, `${c.id}-${i}.jsonl`), events.map((x) => JSON.stringify(x)).join('\n') + '\n');
      const g = r && !failure ? gradeCase(c, r.events, text, pluginRoot) : { pass: false, hops: 0, before: 0, todo: null, todoSteps: null, notes: [], reasons: [failure] };
      const detail = { pass: g.pass, hops: g.hops, before: g.before, todo: g.todo, todoSteps: g.todoSteps, notes: g.notes, reasons: g.reasons, problem, exit: r ? r.status : null, invalid: !!failure };
      return { valid: !failure, run: detail, session: r ? { status: r.status, badLines: r.badLines, stderr: r.stderr.slice(-4000), plugin: pluginRoot } : null, text,
        touched: Object.fromEntries(touchedSkills(events, hashes).map((n) => [n, hashes.get(n)])) };
    } finally {
      if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
      if (cwd) rmSync(dirname(cwd), { recursive: true, force: true });
    }
  };
  const src = treeSource(root);
  const kernSrc = PLUGIN === root ? src : treeSource(PLUGIN);
  const hashes = skillHashes(kernSrc);
  const fresh = (rec) => Object.entries(rec.touched ?? {}).every(([n, h]) => hashes.get(n) === h);
  const code = filesVersion(root, ADHERENCE_CODE);
  const inputs = new Map(cases.map((c) => [c.id, caseInputs(src, adherenceParts(c), kernSrc).hash]));
  const limit = limiter(JOBS);
  const store = unitStore({ raw, cache, from: basename(raw), noCache: !!o.noCache, resume: !!manifest, limit });
  const specs = cases.map((c) => Array.from({ length: RUNS }, (_, i) => ({ name: `${c.id}-${i}`, files: [`${c.id}-${i}.jsonl`],
    key: unitKey({ runner: 'adherence', inputs: inputs.get(c.id), case: c, model: MODEL, variant: VARIANT, code, claude, run: i }), fresh, work: () => runUnit(c, i) })));
  if (manifest) {
    const n = specs.flat().filter((s) => store.stale(s.name, s.key, fresh)).length;
    if (n) log(`--resume: ${n} run(s) of that run no longer match its inputs, the runner's code, the Claude Code version or a kern skill they read, and run again`);
  }
  // live: every unit going, so a fatal error waits for the sessions already running to finish and save.
  const live = tracker();
  const units = [];
  let stop = null;
  const fail = (e) => { if (!stop) { stop = e; limit.close(e); } throw e; };
  const emit = ordered(cases.length, (k, recs) => {
    const c = cases[k];
    units.push(...recs);
    const runs = recs.map((x) => ({ ...x.run, ...(x.cached ? { cached: x.cached } : {}) }));
    results.push(caseRecord(c, runs));
    save(progress, false);
    log(`${caseLine(c, results.at(-1))}${reuseNote(recs)}`);
  });
  const jobs = specs.map((runs, k) => Promise.all(runs.map((s) => live.track(store.unit(s)))).then((recs) => emit(k, recs)).catch(fail));
  try {
    await Promise.allSettled(jobs);
    await live.idle();
    if (stop) throw stop;
  } finally { removeTemp(dirname(pluginRoot)); }
  log(roundLine(units, Date.now() - t0, JOBS));
  if (gating && results.some((x) => x.valid > 0)) {
    save(committed, true);
    rmSync(progress, { force: true });
    log(`snapshot: ${committed}`);
  } else {
    save(progress, true);
    log(`${!gating ? `${only ? '--case' : PLUGIN !== root ? '--plugin' : o.quick ? '--quick' : '--changed'} run: no committed snapshot` : 'no run was valid: no committed snapshot, and any earlier one stays'}; this one is beside the transcripts: ${progress}`);
  }
  return results.every((x) => x.pass) ? 0 : 1;
}

// gradeCase(c, events, text, root): grade() for case c's run, on the route text it saw, under the plugin root it loaded.
const gradeCase = (c, events, text, root) => grade(events, { route: c.route, routeFile: c.route_file, steps: text ? readSteps(text) : [], text, root, kind: c.kind, projectSkill: c.project_skill || null });

// caseRecord(c, runs): a case's snapshot row. The pass rule is behave's (Task 17a G5): an invalid run is left out, never
// counted as a failed one.
const caseRecord = (c, runs) => {
  const cr = caseResult(runs.map((x) => ({ invalid: x.invalid, verdict: [{ pass: x.pass }] })));
  return { id: c.id, kind: c.kind, route: c.route, passed: cr.passed, valid: cr.valid, invalid: cr.invalid, runs: runs.length, pass: cr.pass, detail: runs };
};
const caseLine = (c, x) => `${x.pass ? 'PASS' : 'FAIL'} ${c.id}: ${x.passed}/${x.valid}${x.invalid ? ` (${x.invalid} invalid, not graded)` : ''}, todo ${x.detail.filter((d) => d.todo).length}/${x.runs}${x.passed === x.runs ? '' : `: ${x.detail.filter((d) => !d.pass).map((d) => d.reasons.join(', ')).join(' | ')}`}`;

// regradeAdherence({ dir, cases, log, usage, now }): --regrade. Each run that dir's run.json names is graded again from
// its saved transcript and record: runFailure and pluginProblem on its exit and events, then grade() on the route text
// the run saw, with today's code and today's case. No session starts. The result, shaped as a snapshot with
// regraded: { from, at }, goes to <dir>/regrade-<HHMMSS>.json, never evals/snapshots.
async function regradeAdherence({ dir, cases, log, usage, now }) {
  let m;
  try { ({ m, dir } = openRun(dir, 'adherence')); } catch (e) { if (e instanceof UsageError) return usage(e.message); throw e; }
  const byId = new Map(cases.map((c) => [c.id, c]));
  const results = [];
  for (const id of m.options.ids) {
    const c = byId.get(id);
    if (!c) { log(`SKIP ${id}: no case has this id now`); continue; }
    const runs = [];
    for (let i = 0; i < m.options.runs; i++) {
      const rec = readRecord(dir, `${id}-${i}`);
      const invalid = (why) => ({ pass: false, hops: 0, before: 0, todo: null, todoSteps: null, notes: [], reasons: [why], problem: why, exit: rec?.run?.exit ?? null, invalid: true });
      if (!rec) { runs.push(invalid('no record: the run never finished')); continue; }
      if (!rec.session) { runs.push(rec.run); continue; }
      let events;
      try { events = readFileSync(join(dir, `${id}-${i}.jsonl`), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)); } catch (e) { runs.push(invalid(`its transcript cannot be read: ${e.message}`)); continue; }
      const r = { ...rec.session, events };
      const loaded = pluginProblem(events, { plugins: [rec.session.plugin], kernel: kernOff(c) ? 'off' : 'on' });
      const problem = runProblem(r, c.prompts.length) || loaded;
      const failure = runFailure(r, c.prompts.length) || loaded;
      if (failure) { runs.push({ ...invalid(failure), problem }); continue; }
      const g = gradeCase(c, events, rec.text, rec.session.plugin);
      runs.push({ pass: g.pass, hops: g.hops, before: g.before, todo: g.todo, todoSteps: g.todoSteps, notes: g.notes, reasons: g.reasons, problem, exit: rec.session.status, invalid: false });
    }
    results.push(caseRecord(c, runs));
    log(caseLine(c, results.at(-1)));
  }
  const file = join(dir, `regrade-${timeStamp(now)}.json`);
  writeFileSync(file, JSON.stringify({ regraded: { from: dir, at: now.toISOString() }, model: m.options.model, claude: m.claude, variant: m.options.variant, runs: m.options.runs, kern: m.kern,
    complete: true, cases: m.options.ids, results }, null, 2) + '\n');
  log(`regrade: ${file}`);
  return results.every((x) => x.pass) ? 0 : 1;
}
