#!/usr/bin/env node
// Standing cost: input tokens a one-word session pays with kern loaded, minus the same session without it.
// Median of N runs per arm, isolated from user settings. Spends tokens; never runs in CI; ask first.
// Usage: node scripts/standing-cost.mjs [--runs N] [--model <m>] [--dry-run]
// Prints the delta and writes evals/snapshots/standing-cost-<date>.json (committed).
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, childEnv, claudeVersion } from './lib/claude-run.mjs';
import { isMain } from './lib/is-main.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));

// inputTokens(usage): every input token the turn paid for, cached or not.
export const inputTokens = (u) => {
  if (!u || typeof u.input_tokens !== 'number') throw new Error('standing-cost: the result has no usage.input_tokens');
  return u.input_tokens + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
};
export const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

function once(withKern) {
  const cwd = mkdtempSync(join(tmpdir(), 'sc-'));
  const argv = ['-p', 'hello', '--output-format', 'json', '--model', MODEL, '--max-turns', '1', '--max-budget-usd', '1', ...ISOLATION, ...(withKern ? ['--plugin-dir', ROOT] : [])];
  const r = spawnSync('claude', argv, { cwd, encoding: 'utf8', timeout: 180000, env: childEnv(process.env) });
  rmSync(cwd, { recursive: true, force: true });
  if (r.status !== 0) throw new Error(`standing-cost: claude exited ${r.status}: ${r.error?.message ?? r.stderr.trim().split('\n').pop()}`);
  return inputTokens(JSON.parse(r.stdout).usage);
}

if (isMain(import.meta.url)) {
  if (!Number.isInteger(RUNS) || RUNS < 1) { console.error('standing-cost: --runs needs a whole number of at least 1'); process.exit(2); }
  if (args.includes('--dry-run')) { console.log(`claude -p hello x ${RUNS} with --plugin-dir ${ROOT}, x ${RUNS} without; model ${MODEL}`); process.exit(0); }
  const kern = []; const bare = [];
  for (let i = 0; i < RUNS; i++) { kern.push(once(true)); bare.push(once(false)); }
  const delta = median(kern) - median(bare);
  const out = join(ROOT, 'evals', 'snapshots', `standing-cost-${new Date().toISOString().slice(0, 10)}.json`);
  mkdirSync(join(ROOT, 'evals', 'snapshots'), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, kern, bare, delta }, null, 2) + '\n');
  console.log(`standing cost: ${delta} input tokens (median of ${RUNS}; with kern ${median(kern)}, without ${median(bare)})`);
  console.log(`snapshot: ${out}`);
}
