#!/usr/bin/env node
// The M2b side-by-side pilot (docs/pilot.md).
// Usage: node scripts/pilot.mjs metrics <session.jsonl> [--root <arm repo>]
//        node scripts/pilot.mjs review --task <id> --base <sha> --kern-repo <dir> --kern-session <jsonl>
//          --current-repo <dir> --current-session <jsonl> [--plugin <dir>]... [--model <m>] [--dry-run]
//        node scripts/pilot.mjs decide
// --tasks <file>, --results <file> and --out <dir> replace evals/pilot/tasks.json, evals/pilot/results.json
// and evals/results/pilot-<date>/ (tests use them).
// review spends tokens (one blind grader call); ask the user first. It writes the bundle and the key to
// evals/results/pilot-<date>/ (gitignored), the key only after grading, and the scores and metrics to
// evals/pilot/results.json (committed). decide reads that file, with the user's confirmed counts.
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, claudeVersion, finalText, runClaude } from './lib/claude-run.mjs';
import { blindIds } from './lib/h2h.mjs';
import { RULE, TELLS, attempt, decide, diffAgainst, hide, mergeRow, metrics, parseReview, readSession, reviewPrompt } from './lib/pilot.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const [cmd, ...args] = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const all = (name) => args.flatMap((a, i) => (a === name ? [args[i + 1]] : []));
const KNOWN = ['--task', '--base', '--kern-repo', '--kern-session', '--current-repo', '--current-session', '--plugin', '--model', '--dry-run', '--replace', '--tasks', '--results', '--out', '--root'];
const badFlag = args.find((a) => a.startsWith('--') && !KNOWN.includes(a));
if (badFlag) { console.error(`pilot: unknown flag ${badFlag}; known: ${KNOWN.join(' ')}`); process.exit(2); }
const real = (p) => { try { return realpathSync(p); } catch { return resolve(p); } };
const inside = (dir, p) => [[resolve(dir), resolve(p)], [real(dir), real(p)]].some(([d, q]) => q === d || q.startsWith(d + sep));
const RESULTS = opt('--results', join(ROOT, 'evals', 'pilot', 'results.json'));
const readJson = (p, dflt) => { try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return dflt; } };

if (cmd === 'metrics') {
  if (!args[0]) { console.error('pilot: metrics needs a session file'); process.exit(2); }
  console.log(JSON.stringify(metrics(readSession(args[0]), { root: opt('--root', null) }), null, 2));
} else if (cmd === 'review') {
  const id = opt('--task');
  const tasksFile = opt('--tasks', join(ROOT, 'evals', 'pilot', 'tasks.json'));
  const task = readJson(tasksFile, []).find((t) => t.id === id);
  if (!task) { console.error(`pilot: no task ${id} in ${tasksFile}`); process.exit(2); }
  const base = opt('--base');
  const arms = ['kern', 'current'].map((a) => ({ id: a, repo: opt(`--${a}-repo`), session: opt(`--${a}-session`) }));
  if (!base || arms.some((a) => !a.repo || !a.session)) { console.error('pilot: review needs --base, --kern-repo, --kern-session, --current-repo and --current-session'); process.exit(2); }
  const date = new Date().toISOString().slice(0, 10);
  const ids = blindIds(arms.map((a) => a.id), `${date}:pilot:${id}`);
  const dirs = [...arms.map((a) => a.repo), ...all('--plugin')];
  const outputs = arms.map((a) => {
    const entries = readSession(a.session);
    const stray = [entries.find((e) => typeof e?.cwd === 'string')].find((e) => e && !inside(a.repo, e.cwd));
    if (stray) { console.error(`pilot: ${a.id} session ${a.session} started in ${stray.cwd}, outside its repo ${a.repo}; sessions and repos are swapped or mixed`); process.exit(2); }
    return { arm: a.id, id: ids[a.id], m: metrics(entries, { root: a.repo }), text: hide(attempt(entries, diffAgainst(a.repo, base)), dirs) };
  }).sort((x, y) => x.id.localeCompare(y.id));
  const prompt = reviewPrompt(task, outputs);
  const left = prompt.match(TELLS);
  if (left) { console.error(`pilot: the bundle still names an arm ("${left[0]}"); redaction failed`); process.exit(1); }
  const raw = opt('--out', join(ROOT, 'evals', 'results', `pilot-${date}`));
  mkdirSync(raw, { recursive: true });
  writeFileSync(join(raw, `${id}.prompt.txt`), prompt);
  if (args.includes('--dry-run')) {
    for (const o of outputs) console.log(`${o.id}: ${o.text.length} chars; ${o.m.stops} stops, ${o.m.tokens.total} tokens, ${o.m.wallSeconds} s, ${o.m.slipCandidates.length} slip candidate(s)`);
    console.log(`bundle: ${join(raw, `${id}.prompt.txt`)} (no model called)`);
    process.exit(0);
  }
  if (resolve(process.env.CLAUDE_CONFIG_DIR || '') !== join(homedir(), '.claude-kern-eval')) {
    console.error('pilot: a paid review runs only under CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval (the personal account); set CLAUDE_CONFIG_DIR and run it again');
    process.exit(2);
  }
  try { mergeRow(readJson(RESULTS, []), { task: id }, args.includes('--replace')); } catch (e) { console.error(e.message); process.exit(2); }
  const model = opt('--model', 'claude-opus-5-5');
  const gdir = mkdtempSync(join(tmpdir(), 'g-'));
  const run = runClaude({ cwd: gdir, prompts: [prompt], model, maxTurns: 1 });
  rmSync(gdir, { recursive: true, force: true });
  let review;
  try { review = parseReview(finalText(run.events), outputs.map((o) => o.id)); } catch (e) { console.error(`pilot: VOID ${id}: ${e.message}`); process.exit(1); }
  writeFileSync(join(raw, `${id}.key.json`), `${JSON.stringify(ids, null, 2)}\n`);
  const byArm = Object.fromEntries(outputs.map((o) => [o.arm, { score: review.grades[o.id].score, why: review.grades[o.id].why ?? '', stops: o.m.stops,
    tokens: o.m.tokens.total, wallSeconds: o.m.wallSeconds, guards: o.m.guards, slipCandidates: o.m.slipCandidates }]));
  const prefer = review.prefer === 'tie' ? 'tie' : outputs.find((o) => o.id === review.prefer).arm;
  const results = mergeRow(readJson(RESULTS, []), { task: id, base, date, grader: model, claude: claudeVersion(), isolation: ISOLATION, prefer, ...byArm }, args.includes('--replace'));
  mkdirSync(dirname(RESULTS), { recursive: true });
  writeFileSync(RESULTS, `${JSON.stringify(results, null, 2)}\n`);
  console.log(`${id}: kern ${byArm.kern.score}, current ${byArm.current.score}; the grader keeps ${prefer}. Confirm kern's slips and needless guard calls in ${RESULTS}.`);
} else if (cmd === 'decide') {
  const rows = readJson(RESULTS, []);
  if (!rows.length) { console.error(`pilot: no results in ${RESULTS}`); process.exit(2); }
  let v;
  try { v = decide(rows, RULE, readJson(opt('--tasks', join(ROOT, 'evals', 'pilot', 'tasks.json')), []).map((t) => t.id)); } catch (e) { console.error(e.message); process.exit(2); }
  console.log(`pilot: ${v.pass ? 'PASS' : 'FAIL'}; cost ${v.cost} (median tokens kern/current ${v.tokenRatio.toFixed(2)}, wall time ${v.wallRatio.toFixed(2)}); ${rows.map((r, i) => `${r.task} ${v.outcome[i]}`).join(', ')}`);
  for (const r of v.reasons) console.log(`  ${r}`);
  process.exit(v.pass ? 0 : 1);
} else {
  console.error('usage: node scripts/pilot.mjs metrics <session.jsonl> [--root <dir>] | review --task <id> --base <sha> ... | decide');
  process.exit(2);
}
