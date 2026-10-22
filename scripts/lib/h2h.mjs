// Head-to-head evals (design spec 11.1 tier 3): the same task, the same fixture and the same model under
// each arm (kern, the upstream plugins it learned from, and no plugin), graded blind.
// A task lives in evals/h2h/<category>/<task>/: task.json, repo/ (the project the arm sees), heldout/
// (tests copied in only at grading), reference.patch (diagnose: the fix the heldout tests accept) and
// labels.json (review: seeded bugs and decoys).
// Blinding rules from pstack skills/poteto-mode/playbooks/eval.md:5-13 (MIT; nothing the candidate sees names
// an eval; the judge sees sanitized labels and scores all arms in one pass); the no-plugin control from
// caveman evals/README.md:17 (Apache-2.0; ideas only).
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { UsageError, parseArgs } from './args.mjs';
import { digest, pluginCopy, tryRun } from './behave.mjs';
import { dirtyRefusal, statusEntries, treeRecord } from './run-record.mjs';
import { ISOLATION, PERMISSIONS, childEnv, claudeVersion, finalText, runClaude, workspace } from './claude-run.mjs';

export const CATEGORIES = ['plan', 'diagnose', 'review'];

// h2hFlags(ids, armIds): scripts/h2h.mjs's flags for the shared parser (args.mjs), ids being the task ids and
// armIds the arm ids of evals/h2h/arms.json.
export const h2hFlags = (ids, armIds) => ({ '--category': { key: 'category', value: 'a category', choices: CATEGORIES, noun: 'category' },
  '--task': { key: 'task', value: 'a task id', choices: ids, noun: 'task' }, '--arms': { key: 'arms', value: 'arm ids, comma-separated', list: armIds, noun: 'arm' },
  '--runs': { key: 'runs', value: 'count' }, '--model': { key: 'model', value: 'a model id' }, '--grader-model': { key: 'grader', value: 'a model id' },
  '--dry-run': { key: 'dryRun' }, '--allow-dirty': { key: 'allowDirty' } });

// taskWorkspace(t): the project one arm's session starts in: the task's repo as workspace() builds it (git
// history, origin, branch, setup), then the task's patch committed, as a review task's change under review.
// The caller removes dirname(cwd).
export function taskWorkspace(t) {
  const cwd = workspace(join(t.dir, 'repo'), { name: t.project || 'app', origin: !!t.origin, branch: t.branch || '', setup: t.setup || [] });
  const git = (...g) => execFileSync('git', ['-C', cwd, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...g], { stdio: 'ignore' });
  if (t.patch) { git('apply', join(t.dir, t.patch)); git('add', '-A'); git('commit', '-qm', t.patch_message || 'feat: the change under review'); }
  return cwd;
}

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
// area; plan: claims the grader marked unsupported by both the fixture files and the git facts the
// session was shown.
export function falseAlarms(category, e) {
  if (category === 'review') return (e.decoyHits ?? 0) + (e.unmatched ?? 0);
  if (category === 'diagnose') return (e.floorHits ?? 0) + (e.outOfArea ?? 0);
  return e.unsupported ?? 0;
}

// resultRow(task, run, attempt, grade, reply): one arm's row in the snapshot, from its attempt ({ arm, id, e,
// heldout, git }) and its grade. gate reads score and falseAlarms. A review row also keeps the split behind
// falseAlarms, decoys and unmatched as counts, the count of extras the grader set aside, and the grader's raw
// reply for that task-run, so a split can be checked against what the grader wrote: the 2026-10-22 snapshot kept
// only the sum, and the review diagnosis had to infer each split from `why` (Task 16o). The row holds no blind id,
// since keys stay out of snapshots; the arm's entry in the reply is blindIds(arm ids, `<date>:<task>:<run>`)[arm].
// Each label named in matched, decoys or extras counts once, by its kind in the key, whichever list the grader put it
// in (Task 17a, G2): a decoy under matched is a false alarm, an extra under decoys is an extra (Task 16o review, M3),
// and matched holds the bug labels named. A label the key lacks counts by its prefix ("decoy:d1"), else by its
// list. A list that is not one counts nothing; parseGrades voids such a reply before it reaches a row.
export function resultRow(t, run, x, g, reply) {
  const kinds = new Map((t.labels ?? []).map((l) => [l.id, l.kind]));
  const named = { bug: new Set(), decoy: new Set(), extra: new Set() };
  for (const [list, kind] of [['matched', 'bug'], ['decoys', 'decoy'], ['extras', 'extra']]) {
    for (const d of Array.isArray(g[list]) ? g[list] : []) {
      const k = kinds.get(labelId(d)) ?? String(d).match(LABEL_PREFIX)?.[1] ?? kind;
      named[k]?.add(labelId(d));
    }
  }
  const e = { ...x.e, decoyHits: named.decoy.size, unmatched: g.unmatched ?? 0, unsupported: g.unsupported ?? 0 };
  const score = t.category === 'diagnose' && !x.heldout ? 0 : g.score / 10;
  const matched = t.category === 'review' ? [...named.bug] : g.matched ?? [];
  const row = { task: t.id, category: t.category, run, arm: x.arm, score, falseAlarms: falseAlarms(t.category, e), heldout: x.heldout, git: x.git, matched, why: g.why ?? '' };
  if (t.category !== 'review') return row;
  return { ...row, decoys: e.decoyHits, unmatched: e.unmatched, extras: named.extra.size, reply };
}

// labelId(entry): a grader's label entry without its kind prefix, so "extra:x1" and "x1" name the same label.
const LABEL_PREFIX = /^(bug|decoy|extra):/;
const labelId = (d) => String(d).replace(LABEL_PREFIX, '');

// gate(results, tasks): per category, kern passes when its mean score is at least the strongest other arm's,
// and its mean false alarms are at most that arm's. The control arm counts as an arm. tasks are the loaded
// tasks ({ id, category }): a category in which one has no graded run is INCOMPLETE, never PASS or FAIL,
// since its verdict would rest on part of the category (2026-10-22: a plan verdict from 2 of 4 tasks, the
// other two voided by an outage). status is PASS, FAIL or INCOMPLETE; pass is true only for PASS.
export function gate(results, tasks = []) {
  const by = {};
  for (const r of results) ((by[r.category] ??= {})[r.arm] ??= []).push(r);
  const want = {};
  for (const t of tasks) (want[t.category] ??= []).push(t.id);
  const graded = new Set(results.map((r) => r.task));
  const mean = (xs, k) => xs.reduce((s, x) => s + x[k], 0) / xs.length;
  const done = (category, v) => ({ category, status: v.pass ? 'PASS' : 'FAIL', ...v });
  return [...new Set([...Object.keys(by), ...Object.keys(want)])].map((category) => {
    const ids = want[category] ?? [];
    const ungraded = ids.filter((id) => !graded.has(id));
    if (ungraded.length) {
      const n = ids.length - ungraded.length;
      return { category, status: 'INCOMPLETE', pass: false, graded: n, tasks: ids.length, ungraded, reason: `${n} of ${ids.length} tasks graded; no graded run: ${ungraded.join(', ')}` };
    }
    const arms = by[category];
    if (!arms.kern) return done(category, { pass: false, reason: 'no kern runs' });
    const others = Object.entries(arms).filter(([a]) => a !== 'kern').map(([arm, xs]) => ({ arm, score: mean(xs, 'score'), fa: mean(xs, 'falseAlarms') }));
    const best = others.sort((a, b) => b.score - a.score || a.fa - b.fa)[0];
    const kern = { score: mean(arms.kern, 'score'), fa: mean(arms.kern, 'falseAlarms') };
    if (!best) return done(category, { pass: false, reason: 'no other arm ran', kern });
    const pass = kern.score >= best.score && kern.fa <= best.fa;
    return done(category, { pass, kern, best, reason: pass ? '' : `kern ${kern.score.toFixed(2)} score, ${kern.fa.toFixed(2)} false alarms; ${best.arm} ${best.score.toFixed(2)}, ${best.fa.toFixed(2)}` });
  });
}

// touchedTasks(all, run): every loaded task in a category the run touched. The gate gets these, so a
// `--task` rerun of one task cannot print a PASS or FAIL for its whole category (Task 16n review, I2): the
// category's other tasks read as ungraded, and the category as INCOMPLETE.
export const touchedTasks = (all, run) => all.filter((t) => run.some((x) => x.category === t.category));

// verdictLine(v): the line the runner prints for one category, such as `INCOMPLETE plan: 2 of 4 tasks graded; ...`.
export const verdictLine = (v) => `${v.status} ${v.category}${v.reason ? `: ${v.reason}` : ''}`;

// gateExit(verdict): the runner's exit code. 1 when a category failed, else 3 when one is incomplete, else 0.
export const gateExit = (verdict) => (verdict.some((v) => v.status === 'FAIL') ? 1 : verdict.some((v) => v.status === 'INCOMPLETE') ? 3 : 0);

// RECENT: how many recent commits Claude Code's git status context lists (5 in this session's own context).
export const RECENT = 5;

// gitFacts(dir): the parts of Claude Code's git status context a session that starts in dir is shown, read
// with plain git, never from a transcript. That context lists the current branch, the main branch, the git
// user, the status and the recent commits (short SHA and subject); it lists no remote, so none is kept here,
// and the git user (the machine's, the same for every arm) is left out. main is origin/HEAD's branch, else
// main, else master, else the current branch: inferred, since Claude Code's own rule is not read here; every
// fixture gives main. commits counts the whole history, which the context shows only up to RECENT. The runner
// reads them in each arm's workspace before the arm runs; the grader never sees that context, so
// graderPrompt gives it these.
export function gitFacts(dir) {
  const git = (...a) => execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8' }).trim();
  const tryGit = (...a) => { try { return execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch { return null; } };
  const branch = git('branch', '--show-current') || '(detached HEAD)';
  const has = (b) => tryGit('show-ref', '--verify', '--quiet', `refs/heads/${b}`) !== null;
  const originHead = tryGit('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD');
  return {
    branch,
    main: originHead ? originHead.replace(/^origin\//, '') : has('main') ? 'main' : has('master') ? 'master' : branch,
    head: git('rev-parse', '--short', 'HEAD'),
    commits: Number(git('rev-list', '--count', 'HEAD')),
    recent: git('log', '-n', String(RECENT), '--no-decorate', '--format=%h %s').split('\n').filter(Boolean),
  };
}

// factsLine(f): one attempt's gitFacts as the grader reads them. It names no arm: every arm's workspace is the
// same fixture with the same commit subjects, and only the SHAs, from each commit's time, can differ.
export const factsLine = (f) => {
  const count = f.commits > RECENT ? `more than ${RECENT} commits, the ${RECENT} newest first:` : `${f.commits} commit${f.commits === 1 ? '' : 's'}, newest first:`;
  return [`Git facts: branch ${f.branch}; main branch ${f.main}; HEAD ${f.head}; ${count}`, ...f.recent.map((c) => `  ${c}`)].join('\n');
};

// EXTRA_RULE: how the review grader treats a label of kind "extra", a real issue the key accepts beyond the
// seeded bugs. On 2026-10-22 every arm raised CSV escaping in 15 of 15 sessions and was charged a false alarm for
// it; the user chose to list it, the missing exports/ directory and missing tests as extras after that run
// (the user's "kern and key", an exception to the plan's rule that keys are fixed before any run). An extra is
// optional: leaving it out costs nothing, and rubric line 1's "real problem" means a bug label (Task 16o review, I2).
export const EXTRA_RULE = 'A label of kind "extra" is a real issue the key accepts beyond the seeded bugs. A finding that matches an extra counts neither as a match nor as a false alarm: list its id in "extras", never in "matched", "decoys" or "unmatched", and let it neither raise nor lower the score. An attempt that does not raise an extra loses nothing for it, and a rubric line about real problems counts only the bug labels, never an extra.';

// graderPrompt(task, outputs): each output is { id, text, git }, git from gitFacts. Every arm's session was
// shown those facts in Claude Code's git status context (the 2026-10-22 plan gate counted kern's true
// `base: main` as unsupported), so the grader is told them and a claim that matches them is supported (the
// user's "kern and grader", 2026-10-22). The context shows no remote, so a remote claim still needs a command.
export function graderPrompt(task, outputs) {
  return [
    `You grade ${outputs.length} anonymous attempts at the same ${task.category} task. You do not know which tool made which.`,
    'Score each attempt 0 to 10 on the rubric. Judge only what each attempt shows; a claim it does not support with a command and its output earns nothing.',
    "Each attempt's block opens with git facts read from its workspace before it started. Its session's git status showed it the branch, the main branch, HEAD's short SHA and the recent commits with their subjects, so a claim that matches those is supported, though no command printed it. It was not shown the remotes, so a claim about a remote still needs a command and its output. A claim that contradicts any fact is unsupported.",
    ...(task.category === 'review' ? ['For each finding, name the label id it matches: a bug id, "decoy:<id>" for a decoy, "extra:<id>" for an extra, or "none".', EXTRA_RULE] : []),
    ...(task.category === 'plan' ? ['Count the claims about the repo that neither the fixture files nor the git facts its session was shown support.'] : []),
    // P5 review, Important 1: the reply shape was shown only by an example with non-empty values.
    'Give every field for every attempt: [] when no label matches, 0 when there is nothing to count.',
    ...(task.category === 'review' ? ['A finding that matches no label counts in "unmatched"; never list "none" in matched, decoys or extras.'] : []),
    `Reply with JSON only: {"grades":[{"id":"arm-A","score":7,"matched":["b1"],"decoys":["d2"],${task.category === 'review' ? '"extras":["x1"],' : ''}"unmatched":1,"unsupported":0,"why":"..."}]}.`,
    '', 'Task given to each attempt:', task.prompts.join('\n---\n'), '', 'Rubric:', ...task.rubric.map((r, i) => `${i + 1}. ${r}`),
    ...(task.category === 'review' ? ['', 'Labels:', JSON.stringify(task.labels)] : []),
    ...outputs.map((o) => `\n=== ${o.id} ===\n${o.git ? `${factsLine(o.git)}\n` : ''}${o.text}`),
  ].join('\n');
}

// parseGrades(text, ids, task): one grade per blind id, or throws. A malformed reply voids the task-run (h2hMain asks
// once more first), since every gate decision rests on these numbers (Task 17a, G2; addy scripts/run-evals.js:453-502,
// MIT, ideas only):
// - score is a number from 0 to 10;
// - only the fields the task's category reads are checked, and the rest are kept as given, so a field no gate reads
//   never voids a task-run (P5 review, Important 1). A review grade reads matched and decoys, lists of the key's
//   label ids, each bare or with its kind prefix ("decoy:d1"), extras when given (a list of them too), and
//   unmatched, a whole number of at least 0. A plan grade reads unsupported, a whole number of at least 0. A
//   diagnose grade reads only its score: its false alarms are measured, not graded.
// Without task, only the score is checked.
const READS = { review: { lists: ['matched', 'decoys', 'extras'], counts: ['unmatched'] }, plan: { lists: [], counts: ['unsupported'] } };
export function parseGrades(text, ids, task = null) {
  const m = String(text).match(/\{[\s\S]*\}/);
  if (!m) throw new Error('h2h grader: no JSON object in the reply');
  const grades = JSON.parse(m[0]).grades;
  if (!Array.isArray(grades)) throw new Error('h2h grader: the reply has no grades list');
  const g = Object.fromEntries(grades.filter((x) => x && typeof x === 'object').map((x) => [x.id, x]));
  const key = task?.labels ? new Set(task.labels.map((l) => l.id)) : null;
  const reads = READS[task?.category] ?? { lists: [], counts: [] };
  for (const id of ids) {
    const x = g[id];
    if (!x || typeof x.score !== 'number' || !Number.isFinite(x.score) || x.score < 0 || x.score > 10) throw new Error(`h2h grader: no valid score for ${id}`);
    for (const list of reads.lists) {
      // extras is optional: left out, or null, it names no label.
      if (x[list] === undefined || (list === 'extras' && x[list] === null)) { if (list !== 'extras') throw new Error(`h2h grader: ${id} has no ${list} list`); continue; }
      if (!Array.isArray(x[list]) || (key && x[list].some((d) => typeof d !== 'string'))) throw new Error(`h2h grader: ${list} for ${id} is not a list of label ids`);
      const stray = key ? x[list].find((d) => !key.has(labelId(d))) : undefined;
      if (stray !== undefined) throw new Error(`h2h grader: ${list} for ${id} names ${stray}, which is no label in the key`);
    }
    for (const count of reads.counts) {
      if (x[count] === undefined) throw new Error(`h2h grader: ${id} has no ${count} count`);
      if (!Number.isInteger(x[count]) || x[count] < 0) throw new Error(`h2h grader: ${count} for ${id} is not a whole number of at least 0`);
    }
  }
  return g;
}

// finalFiles(cwd, perFile, total): what an arm's session left in its workspace, for the grader (Task 17a, G1): every
// file `git status --porcelain --ignored --untracked-files=all` lists, changed, untracked or ignored, each as
// `--- <path>` then its final text, cut at perFile characters; a file gone, a symlink or a binary file says so in
// place of its text. The block stops before it would pass total characters and ends `[cut: N more files]`, so an
// arm that ran npm install or wrote build output cannot overflow the grader's prompt (P5 review, Minor 4). A plan
// lands in .kern/, which .git/info/exclude ignores, so `git diff` never shows it, and an Edit after the first Write
// changed what the grader must read: the runner once gave it each Write's input.
export function finalFiles(cwd, perFile = 20000, total = 60000) {
  const entries = statusEntries(cwd, ['--ignored', '--untracked-files=all']);
  const blocks = [];
  let size = 0;
  for (const [n, { path }] of entries.entries()) {
    const f = join(cwd, path);
    let st = null;
    let block;
    try { st = lstatSync(f); } catch { st = null; }
    if (!st) block = `--- ${path} (deleted)`;
    else if (!st.isFile()) block = `--- ${path} (${st.isSymbolicLink() ? 'a symlink' : 'not a file'})`;
    else {
      const buf = readFileSync(f);
      const text = buf.toString('utf8');
      block = buf.includes(0) ? `--- ${path} (binary, ${buf.length} bytes)` : `--- ${path}\n${text.length > perFile ? `${text.slice(0, perFile)}\n[cut: ${text.length - perFile} more characters]` : text}`;
    }
    const grown = size + (blocks.length ? 2 : 0) + block.length;
    if (grown > total) { blocks.push(`[cut: ${entries.length - n} more files]`); break; }
    blocks.push(block);
    size = grown;
  }
  return blocks.join('\n\n');
}

const USAGE = 'usage: node scripts/h2h.mjs [--category plan|diagnose|review] [--task <category/id>] [--arms a,b] [--runs N] [--model <m>] [--grader-model <m>] [--allow-dirty] [--dry-run]';

// h2hMain({ root, argv, env, tasks, arms, armIds, run, version, tree, snapshots, results, floorScan, log, error, now }):
// what scripts/h2h.mjs runs, its exit code returned, with the seams a test needs: the tasks, the arms (arms(pick),
// loadArms by default), the run (runClaude, or a stub), the Claude Code version, the tree record, the snapshot and
// results dirs and the floor-scan script (Task 17a). env is the caller's environment.
// - Flags (h2hFlags) are read by the shared parser: any other word is a usage error (2) before anything runs.
// - Every run but a dry run refuses a kern tree with uncommitted changes it would measure, unless --allow-dirty, a
//   --category or --task run too, since those may be the evidence (G11; P5 review, Minor 1). The snapshot records
//   the tree as kern.
// - Each arm's run must load its plugin, and kern's must print the kernel, every other arm's not (G10). A child
//   process's failure in an arm's workspace (git, a setup command), or a floor-scan that exits other than 0 or 1,
//   voids that task-run, not the run (G13, G9); any other error stops the run (P5 review, Minor 3). Heldout tests
//   and floor-scan get childEnv(env), not the caller's whole environment, and floor-scan an empty temp HOME (G9).
// - A plan is graded from the workspace's final files (finalFiles, G1), and the grader's reply is checked against
//   the task's key (parseGrades, G2). A reply that fails to parse or validate is asked for once more, with the
//   error, before the task-run is VOID: a VOID throws away every arm session of it (P5 review, Important 1).
// - key.json beside the transcripts is merged with the day's earlier keys, never replaced (G3). One that is not
//   JSON stops the run before anything runs (P5 review, Minor 5).
// - Snapshots (G3): only a full run with at least one graded task-run writes <snapshots>/h2h-<model>-<date>.json;
//   a filtered run, an all-VOID run or a run a fatal error stops writes snapshot-<model>-<filter>.json beside the
//   transcripts instead, complete false when it stopped. Each records the tasks under cases and the VOID task-runs.
//   After each task-run, the progress so far goes to that file beside the transcripts (complete false) and key.json
//   is merged, so a run a signal kills, which runs no finally, keeps what it graded (P5 review, Minor 6); a full
//   run removes the progress file once the committed snapshot is written.
// Exit: gateExit (0 pass, 1 a category failed, 3 one incomplete), 2 for a usage error or no task matched.
export function h2hMain({ root, argv, env = process.env, tasks: all = null, arms: armsOf = (pick) => loadArms(root, pick), armIds = null, run = runClaude, version = claudeVersion,
  tree = treeRecord, snapshots = join(root, 'evals', 'snapshots'), results: resultsDir = join(root, 'evals', 'results'), floorScan = join(root, 'scripts', 'floor-scan'),
  log = console.log, error = console.error, now = new Date() }) {
  const usage = (msg) => { error(`h2h: ${msg}\n${USAGE}`); return 2; };
  const allTasks = all ?? loadTasks(root);
  const allArms = armIds ?? JSON.parse(readFileSync(join(root, 'evals', 'h2h', 'arms.json'), 'utf8')).map((a) => a.id);
  let o;
  try { o = parseArgs(argv, h2hFlags(allTasks.map((t) => t.id), allArms)); } catch (e) { if (e instanceof UsageError) return usage(e.message); throw e; }
  const MODEL = o.model ?? (env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
  const GRADER = o.grader ?? 'claude-opus-5-5';
  const RUNS = o.runs ?? 3;
  let arms;
  try { arms = armsOf(o.arms ?? null); } catch (e) { error(e.message); return 2; }
  const tasks = allTasks.filter((t) => (!o.category || t.category === o.category) && (!o.task || t.id === o.task));
  if (!tasks.length) { error('h2h: no task matched'); return 2; }
  if (o.dryRun) {
    for (const t of tasks) log(`${t.id}: ${arms.map((a) => a.id).join(', ')} x ${RUNS} runs; ${t.prompts.length} turn(s)`);
    return 0;
  }
  const full = !o.category && !o.task && !o.arms;
  const kern = tree(root);
  if (!o.allowDirty && dirtyRefusal(kern)) return usage(dirtyRefusal(kern));
  let claude;
  try { claude = version(); } catch (e) { error(`h2h: cannot read the claude version (${String(e.message).split('\n')[0]}); nothing ran`); return 1; }
  const date = now.toISOString().slice(0, 10);
  const model = MODEL.replace(/^claude-/, '');
  const rev = (dir) => { try { return execFileSync('git', ['-C', dir, 'rev-parse', 'HEAD'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch { return 'unknown: not a git checkout'; } };
  // Raw runs and key.json go to the results dir (gitignored); the key (blind id to arm) is written only after
  // grading, outside anything the grader reads.
  const raw = join(resultsDir, `h2h-${date}`);
  mkdirSync(raw, { recursive: true });
  const committed = join(snapshots, `h2h-${model}-${date}.json`);
  const filter = full ? 'all' : [o.category, o.task?.replace('/', '--'), o.arms && `arms-${o.arms.join('+')}`].filter(Boolean).join('-');
  const beside = join(raw, `snapshot-${model}-${filter}.json`);
  const keyFile = join(raw, 'key.json');
  // readKey(): the day's keys so far, {} only when there is no key.json yet. It is the one map from the day's blind
  // ids to arms, so one that does not parse throws and is never overwritten (P5 review, Minor 5).
  const readKey = () => {
    let text;
    try { text = readFileSync(keyFile, 'utf8'); } catch (e) { if (e.code === 'ENOENT') return {}; throw e; }
    let k;
    try { k = JSON.parse(text); } catch (e) { throw new Error(`h2h: ${keyFile} is not JSON (${e.message}); move it aside before a run`); }
    if (!k || typeof k !== 'object' || Array.isArray(k)) throw new Error(`h2h: ${keyFile} is not JSON (not an object of seeds); move it aside before a run`);
    return k;
  };
  try { readKey(); } catch (e) { error(e.message); return 2; }
  // Merged, so a filtered rerun keeps the keys of the day's other task-runs (Task 17a, G3).
  const writeKey = () => writeFileSync(keyFile, JSON.stringify({ ...readKey(), ...key }, null, 2) + '\n');
  const results = []; const voided = []; const key = {};
  let verdict = null;
  const save = (file, complete) => {
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, JSON.stringify({ model: MODEL, grader: GRADER, claude, isolation: ISOLATION, permissions: PERMISSIONS, runs: RUNS, kern, complete, cases: tasks.map((t) => t.id),
      arms: arms.map((a) => ({ id: a.id, plugin: a.plugin, commit: a.id === 'kern' ? kern.commit : a.dir ? rev(a.srcDir ?? a.dir) : null })), voided, gate: verdict, results }, null, 2) + '\n');
  };
  // gradeTaskRun(t, attempts): { grades, reply, regrade } from the grader, or { problem }. A reply that does not parse
  // or validate is asked for once more, with the error after the same prompt; regrade keeps that first error. A
  // grader run that failed, or a second reply that fails too, is the problem (P5 review, Important 1).
  const gradeTaskRun = (t, attempts) => {
    const prompt = graderPrompt(t, attempts);
    let first = '';
    for (;;) {
      const text = first ? `${prompt}\n\nA reply to this prompt could not be used: ${first}. Reply again with JSON only, in the shape above, with every field for every attempt.` : prompt;
      const gdir = mkdtempSync(join(tmpdir(), 'g-'));
      let graded;
      try { graded = tryRun({ cwd: gdir, prompts: [text], model: GRADER, maxTurns: 1 }, run); } finally { rmSync(gdir, { recursive: true, force: true }); }
      if (graded.problem) return { problem: `grader: ${graded.problem}` };
      const reply = finalText(graded.run.events);
      try { return { grades: parseGrades(reply, attempts.map((x) => x.id), t), reply, regrade: first }; } catch (err) {
        if (first) return { problem: `${err.message} (asked twice; first: ${first})` };
        first = err.message;
      }
    }
  };
  // taskRun(t, r): task t's run r: each arm's attempt, then one blind grade of them all, its rows in results and its
  // key in key; a task-run that cannot be graded goes to voided with the reason.
  const taskRun = (t, r) => {
    const seed = `${date}:${t.id}:${r}`;
    const ids = blindIds(arms.map((a) => a.id), seed);
    const attempts = [];
    const fail = (reason) => { voided.push({ task: t.id, run: r, reason }); log(`VOID ${t.id} run ${r}: ${reason}`); };
    for (const a of arms) {
      const x = armAttempt({ t, a, id: ids[a.id], r, raw, arms, model: MODEL, run, env, floorScan });
      if (x.problem) return fail(`${a.id}: ${x.problem}`);
      attempts.push(x.attempt);
    }
    attempts.sort((x, y) => x.id.localeCompare(y.id));
    const g = gradeTaskRun(t, attempts);
    if (g.problem) return fail(g.problem);
    key[seed] = ids;
    // A review row keeps the grader's raw reply and its decoy and unmatched counts (resultRow); a row whose grade
    // came from the re-ask says why the first reply was not used.
    for (const x of attempts) results.push({ ...resultRow(t, r, x, g.grades[x.id], g.reply), ...(g.regrade ? { regrade: g.regrade } : {}) });
  };
  // The kern arm runs from a copy of the plugin without evals/, tests/ and the answer keys, so a model in that
  // arm cannot read labels.json or heldout/ under its plugin root. Every other plugin arm runs from a copy too:
  // outside the repo, symlinks resolved, no .git, so a model cannot walk up into the repo's evals/ or answer keys.
  const copies = [];
  let complete = false;
  try {
    for (const a of arms) {
      if (!a.plugin) continue;
      a.srcDir = a.dir;
      a.dir = a.id === 'kern' ? pluginCopy(a.srcDir) : armCopy(a.srcDir, a.id);
      copies.push(a.dir);
    }
    for (const t of tasks) {
      for (let r = 0; r < RUNS; r++) {
        taskRun(t, r);
        // Progress, so a run a signal kills keeps what it graded (P5 review, Minor 6).
        save(beside, false);
        writeKey();
      }
    }
    complete = true;
  } finally {
    for (const c of copies) rmSync(dirname(c), { recursive: true, force: true });
    if (!complete) save(beside, false);
  }
  verdict = gate(results, touchedTasks(allTasks, tasks).map((t) => ({ id: t.id, category: t.category })));
  for (const v of verdict) log(verdictLine(v));
  if (full && results.length) {
    save(committed, true);
    rmSync(beside, { force: true });
    log(`snapshot: ${committed}`);
  } else {
    save(beside, true);
    log(`${full ? 'no task-run was graded: no committed snapshot, and any earlier one stays' : 'a filtered run: no committed snapshot'}; this one is beside the transcripts: ${beside}`);
  }
  return gateExit(verdict);
}

// armAttempt({ t, a, id, r, raw, arms, model, run, env, floorScan }): one arm's attempt at task t, run r: its
// workspace, gitFacts read before it runs, its run (events saved as <task>-<run>-<blind id>.jsonl), then the diff, the
// out-of-area files, for diagnose the floor-scan hits and the heldout tests, and for plan the final files. Returns
// { attempt } or { problem }, the reason the task-run is VOID: a run that may not be graded, a plugin that did not
// load as the arm needs (G10), a floor-scan exit other than 0 or 1 (G9) or a child process's failure (G13); any other
// error is thrown. The workspace goes either way.
function armAttempt({ t, a, id, r, raw, arms, model, run, env, floorScan }) {
  let cwd = null;
  try {
    cwd = taskWorkspace(t);
    const git = (...g) => execFileSync('git', ['-C', cwd, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...g], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    // What Claude Code's git status context shows this session, read before it starts; the grader gets it.
    const facts = gitFacts(cwd);
    const expect = { plugins: a.dir ? [a.dir] : [], kernel: a.id === 'kern' ? 'on' : 'off' };
    const { run: got, problem, events } = tryRun({ cwd, prompts: t.prompts, pluginDirs: a.dir ? [a.dir] : [], model, maxTurns: t.max_turns || 40, expect }, run);
    // A run cut off by the timeout keeps the events it printed.
    const kept = got ? got.events : events;
    if (kept.length) writeFileSync(join(raw, `${t.id.replace('/', '--')}-${r}-${id}.jsonl`), kept.map((x) => JSON.stringify(x)).join('\n'));
    if (problem) return { problem };
    git('add', '-A', '-N');
    const diff = git('diff', 'HEAD');
    const files = git('diff', '--name-only', 'HEAD').split('\n').filter(Boolean);
    const e = { outOfArea: outOfArea(files, t.area || []).length };
    let heldout = null;
    if (t.category === 'diagnose') {
      writeFileSync(join(dirname(cwd), 'change.diff'), diff);
      e.floorHits = 0;
      if (diff) {
        // floor-scan reads $HOME/.claude/kern.yml ratchets, so it gets an empty HOME, not the host's (P5 review, Minor 2).
        const home = mkdtempSync(join(tmpdir(), 'fh-'));
        let scan;
        try { scan = spawnSync('bash', [floorScan, join(dirname(cwd), 'change.diff')], { cwd, encoding: 'utf8', env: childEnv(env, { HOME: home }) }); } finally { rmSync(home, { recursive: true, force: true }); }
        if (scan.status !== 0 && scan.status !== 1) return { problem: `floor-scan exited ${scan.status ?? scan.signal}: ${(scan.stderr || '').trim().split('\n').pop() || 'no stderr'}` };
        e.floorHits = scan.stdout.split('\n').filter(Boolean).length;
      }
      cpSync(join(t.dir, 'heldout'), cwd, { recursive: true });
      heldout = spawnSync('bash', ['-c', t.test], { cwd, encoding: 'utf8', timeout: 120000, env: childEnv(env) }).status === 0;
    }
    // A plan lands in an ignored work directory, so the grader reads the files the run left, not the diff alone.
    const wrote = t.category === 'plan' ? finalFiles(cwd) : '';
    return { attempt: { arm: a.id, id, e, heldout, git: facts, text: redact(`${digest(got.events, 24000, { results: true })}\n\nDiff:\n${diff || '(none)'}${wrote ? `\n\nFiles written:\n${wrote}` : ''}`, arms) } };
  } catch (err) {
    // Only a child process's failure (git, a setup command: an error with a status or stderr) voids the task-run; any
    // other error is a harness fault, which would void every task-run after it, so it stops the run (P5 review, Minor 3).
    if (err.fatal || (err.status === undefined && err.stderr === undefined)) throw err;
    // A git call's own message (its stderr) says more than node's "Command failed" line.
    return { problem: String(err.stderr || err.message).trim().split('\n')[0] };
  } finally {
    if (cwd) rmSync(dirname(cwd), { recursive: true, force: true });
  }
}
