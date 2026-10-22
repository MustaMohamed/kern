// tests/bench/eval-speed.mjs: times the eval runners against sleepy-claude.mjs, a stand-in claude that sleeps 1 to 20 s
// a session, so a pool's speed-up can be measured with no model call. Each runner runs from a sandbox copy of the repo
// (its results and cache go there, never into this repo's evals/), on a PATH whose only claude is the stand-in, with a
// throwaway CLAUDE_CONFIG_DIR and HOME. Not a test: node --test does not pick it up.
// Usage: node tests/bench/eval-speed.mjs [--jobs 1,6] [--runners exec-eval,behave,kernel-adherence,h2h] [--scale S] [--extra]
// --extra also times, at the last --jobs, a --quick round and a rerun served from the cache. Prints one line per round
// and a JSON summary at the end.
import { spawnSync } from 'node:child_process';
import { chmodSync, cpSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = fileURLToPath(new URL('../..', import.meta.url)).replace(/\/$/, '');
const arg = (name, dflt) => { const i = process.argv.indexOf(name); return i < 0 ? dflt : process.argv[i + 1]; };
const JOBS = arg('--jobs', '1,6').split(',').map(Number);
const RUNNERS = arg('--runners', 'exec-eval,behave,kernel-adherence,h2h').split(',');
const SCALE = arg('--scale', '1');
const EXTRA = process.argv.includes('--extra');

const scratch = mkdtempSync(join(tmpdir(), 'bench-'));
const sandbox = join(scratch, 'kern');
for (const d of ['scripts', 'hooks', 'kernel', 'skills', 'agents', 'modes', '.claude-plugin', 'README.md', 'LICENSE', 'NOTICE']) cpSync(join(REPO, d), join(sandbox, d), { recursive: true });
cpSync(join(REPO, 'evals'), join(sandbox, 'evals'), { recursive: true, filter: (src) => !/^evals\/(results|snapshots)(\/|$)/.test(src.slice(REPO.length + 1)) });
const bin = join(scratch, 'bin');
cpSync(join(REPO, 'tests', 'bench', 'sleepy-claude.mjs'), join(scratch, 'sleepy-claude.mjs'));
spawnSync('mkdir', ['-p', bin]);
// The scale is set in the wrapper: runClaude passes the stand-in only the variables on its allowlist (childEnv).
writeFileSync(join(bin, 'claude'), `#!/bin/sh\nSLEEPY_SCALE='${SCALE}' exec '${process.execPath}' '${join(scratch, 'sleepy-claude.mjs')}' "$@"\n`);
chmodSync(join(bin, 'claude'), 0o755);
const env = { PATH: `${bin}:/usr/bin:/bin`, HOME: mkdtempSync(join(scratch, 'home-')), CLAUDE_CONFIG_DIR: mkdtempSync(join(scratch, 'config-')), TMPDIR: tmpdir() };
const found = spawnSync('/bin/sh', ['-c', 'command -v claude'], { env, encoding: 'utf8' }).stdout.trim();
if (found !== join(bin, 'claude')) throw new Error(`the stand-in is not the claude on PATH: ${found}`);

const ARGS = { 'exec-eval': [], behave: [], 'kernel-adherence': [], h2h: ['--arms', 'kern,control'] };
const rows = [];
const round = (runner, extra, label) => {
  const t0 = Date.now();
  const r = spawnSync(process.execPath, [join(sandbox, 'scripts', `${runner}.mjs`), ...ARGS[runner], '--allow-dirty', ...extra], { env, encoding: 'utf8', timeout: 4 * 60 * 60 * 1000, maxBuffer: 64 * 1024 * 1024 });
  const seconds = Math.round((Date.now() - t0) / 100) / 10;
  const line = r.stdout.match(/^round: .*$/m)?.[0] ?? `(no round line; exit ${r.status}: ${(r.stderr || '').trim().split('\n').slice(0, 8).join(' / ')})`;
  rows.push({ runner, label, seconds, line });
  console.log(`${runner} ${label}: ${seconds} s; ${line}`);
};
try {
  for (const runner of RUNNERS) {
    for (const j of JOBS) round(runner, ['--jobs', String(j), '--no-cache'], `--jobs ${j}`);
    if (EXTRA) {
      const j = String(JOBS.at(-1));
      round(runner, ['--quick', '--jobs', j, '--no-cache'], `--quick --jobs ${j}`);
      round(runner, ['--jobs', j], `cached rerun --jobs ${j}`);
    }
  }
} finally { rmSync(scratch, { recursive: true, force: true }); }
console.log(JSON.stringify(rows, null, 2));
