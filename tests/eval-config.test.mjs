// tests/eval-config.test.mjs
// Every real claude spawn the eval runners make refuses unless CLAUDE_CONFIG_DIR names a config dir: the
// default login is never used for evals (P15, after a standing-cost run on the default login, 2026-10-22).
// Each test leaves CLAUDE_CONFIG_DIR unset or empty, puts a stand-in claude that logs its calls first on a
// PATH that holds no real claude, and checks that the stand-in never ran.
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, runClaude } from '../scripts/lib/claude-run.mjs';

const NO_EVAL_CONFIG = "set CLAUDE_CONFIG_DIR to the eval account's config dir; the default login is never used for evals";
const REPO = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const made = [];
after(() => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
const scratch = (prefix) => {
  const d = mkdtempSync(join(tmpdir(), prefix));
  made.push(d);
  return d;
};

// standIn(): a claude that logs each call's arguments and exits 0, first on a PATH with only system dirs
// after it, and an empty HOME; no CLAUDE_CONFIG_DIR.
function standIn() {
  const dir = scratch('ec-');
  writeFileSync(join(dir, 'claude'), `#!/bin/sh\nprintf '%s\\n' "$*" >> '${dir}/calls'\n[ "$1" = --version ] && echo '9.9.9 (stand-in)'\nexit 0\n`);
  chmodSync(join(dir, 'claude'), 0o755);
  const env = { PATH: `${dir}:/usr/bin:/bin`, HOME: scratch('eh-'), TMPDIR: tmpdir() };
  assert.equal(spawnSync('/bin/sh', ['-c', 'command -v claude'], { env, encoding: 'utf8' }).stdout.trim(), join(dir, 'claude'), 'the stand-in is first on PATH');
  return { env, calls: () => (existsSync(join(dir, 'calls')) ? readFileSync(join(dir, 'calls'), 'utf8') : '') };
}

// A copy of the repo to run the runners from, so a runner that got past the check writes only into the copy.
let SANDBOX;
const sandbox = () => {
  if (SANDBOX) return SANDBOX;
  SANDBOX = join(scratch('es-'), 'kern');
  const out = new Set(['.git', '.upstream', 'node_modules', 'tests', 'docs', '.superpowers']);
  cpSync(REPO, SANDBOX, { recursive: true, filter: (src) => !out.has(src.slice(REPO.length + 1).split('/')[0]) && !/^evals\/(results|snapshots)\/./.test(src.slice(REPO.length + 1)) });
  return SANDBOX;
};

test('runClaude refuses a run with no CLAUDE_CONFIG_DIR, or an empty one, and never starts claude', () => {
  const s = standIn();
  for (const env of [{ ...s.env, CLAUDE_CONFIG_DIR: '' }, { ...s.env, CLAUDE_CONFIG_DIR: '  ' }]) {
    const saved = process.env.CLAUDE_CONFIG_DIR;
    delete process.env.CLAUDE_CONFIG_DIR;
    try {
      assert.throws(() => runClaude({ cwd: scratch('ew-'), prompts: ['hi'], model: 'm', env }),
        (e) => e instanceof ClaudeRunError && e.fatal && e.message === NO_EVAL_CONFIG);
    } finally {
      if (saved !== undefined) process.env.CLAUDE_CONFIG_DIR = saved;
    }
  }
  assert.equal(s.calls(), '');
});

test('the claude driver exits 2 with no CLAUDE_CONFIG_DIR and reports why, and never starts claude', () => {
  const s = standIn();
  const r = spawnSync(process.execPath, [join(REPO, 'scripts', 'lib', 'claude-drive.mjs'), '-p'], {
    input: JSON.stringify({ prompts: ['hi'], graceMs: 100 }), env: s.env, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe', 'pipe'] });
  assert.equal(r.status, 2, r.stderr);
  assert.match(r.stderr, new RegExp(NO_EVAL_CONFIG.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.equal(JSON.parse(r.output[3]).error.message, NO_EVAL_CONFIG);
  assert.equal(s.calls(), '');
});

test('claudeVersion refuses with no CLAUDE_CONFIG_DIR and never starts claude', () => {
  const s = standIn();
  const url = new URL('../scripts/lib/claude-run.mjs', import.meta.url).href;
  const r = spawnSync(process.execPath, ['--input-type=module', '-e',
    `import { claudeVersion } from ${JSON.stringify(url)}; try { console.log(claudeVersion()); } catch (e) { console.error(e.message); process.exit(3); }`], { env: s.env, encoding: 'utf8' });
  assert.equal(r.status, 3, r.stdout);
  assert.equal(r.stderr.trim(), NO_EVAL_CONFIG);
  assert.equal(s.calls(), '');
});

// One non-dry run of each runner that spawns claude, as narrow as its flags allow.
const RUNNERS = [
  ['exec-eval', ['--case', 'finish-menu-first', '--allow-dirty']],
  ['behave', ['--case', 'recall-1', '--runs', '1', '--allow-dirty']],
  ['h2h', ['--task', 'plan/rename-small', '--arms', 'kern,control', '--runs', '1', '--allow-dirty']],
  ['kernel-adherence', ['--case', 'row-define', '--runs', '1', '--allow-dirty']],
  ['standing-cost', ['--runs', '1']],
];
for (const [name, args] of RUNNERS) {
  test(`${name} exits 2 before any claude call when CLAUDE_CONFIG_DIR is unset or empty`, () => {
    const s = standIn();
    for (const env of [s.env, { ...s.env, CLAUDE_CONFIG_DIR: '' }]) {
      const r = spawnSync(process.execPath, [join(sandbox(), 'scripts', `${name}.mjs`), ...args], { env, encoding: 'utf8', timeout: 120000 });
      assert.equal(r.status, 2, `${r.stdout}${r.stderr}`);
      assert.equal(r.stderr, `${name}: ${NO_EVAL_CONFIG}\n`);
      assert.equal(r.stdout, '');
    }
    assert.equal(s.calls(), '');
  });
}
