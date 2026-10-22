// tests/eval-config.test.mjs
// Every real claude spawn the eval runners make refuses unless CLAUDE_CONFIG_DIR names a config dir that is not
// the default one, and no auth variable in the environment would log claude in past it: the default login is
// never used for evals (P15, after a standing-cost run on the default login, 2026-10-22). Each test puts a
// stand-in claude that logs its calls first on a PATH that holds no real claude (guardedEnv), and checks that
// the stand-in never ran.
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, realpathSync, rmSync } from 'node:fs';
import { tmpdir, userInfo } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ClaudeRunError, evalConfigProblem, runClaude } from '../scripts/lib/claude-run.mjs';
import { guardedEnv, standInCalls } from './helpers/eval-stub.mjs';

const NO_EVAL_CONFIG = "set CLAUDE_CONFIG_DIR to the eval account's config dir, $HOME/.claude-kern-eval; the default login (~/.claude) is never used for evals";
const authRefusal = (name) => `${name} is set, so claude would log in with it whatever CLAUDE_CONFIG_DIR says; unset it, or set KERN_EVAL_ENV_AUTH=1 to run on it`;
const AUTH = ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN'];
const DUMMY = 'dummy-secret-value-0451';
const REPO = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const made = [];
after(() => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
const scratch = (prefix) => {
  const d = mkdtempSync(join(tmpdir(), prefix));
  made.push(d);
  return d;
};

// refusals(env): each environment a real run must refuse, with the refusal it must give: no config dir, an
// empty one, each form of the default ~/.claude, and each auth variable beside a good config dir.
function refusals(env) {
  const h = env.HOME;
  const good = { ...env, CLAUDE_CONFIG_DIR: join(h, '.claude-kern-eval') };
  return [
    [env, NO_EVAL_CONFIG],
    [{ ...env, CLAUDE_CONFIG_DIR: '' }, NO_EVAL_CONFIG],
    [{ ...env, CLAUDE_CONFIG_DIR: join(h, '.claude') }, NO_EVAL_CONFIG],
    [{ ...env, CLAUDE_CONFIG_DIR: `${h}/.claude/` }, NO_EVAL_CONFIG],
    [{ ...env, CLAUDE_CONFIG_DIR: '~/.claude' }, NO_EVAL_CONFIG],
    ...AUTH.map((k) => [{ ...good, [k]: DUMMY }, authRefusal(k)]),
  ];
}

// A copy of what the runners read, so a runner that got past the check writes only into the copy.
let SANDBOX;
const sandbox = () => {
  if (SANDBOX) return SANDBOX;
  SANDBOX = join(scratch('es-'), 'kern');
  for (const d of ['scripts', 'hooks', 'kernel', 'skills', 'agents', 'modes', '.claude-plugin']) cpSync(join(REPO, d), join(SANDBOX, d), { recursive: true });
  cpSync(join(REPO, 'evals'), join(SANDBOX, 'evals'), { recursive: true, filter: (src) => !/^evals\/(results|snapshots)(\/|$)/.test(src.slice(REPO.length + 1)) });
  return SANDBOX;
};

test('evalConfigProblem refuses no config dir, a blank one, every form of the default ~/.claude, and an auth variable without the opt-in', () => {
  const h = scratch('eh-');
  const no = [
    {}, { CLAUDE_CONFIG_DIR: '' }, { CLAUDE_CONFIG_DIR: '  ' },
    ...[join(h, '.claude'), `${h}/.claude/`, `${h}/./.claude`, '~/.claude', '~/.claude/', join(realpathSync(h), '.claude'), join(userInfo().homedir, '.claude')]
      .map((d) => ({ HOME: h, CLAUDE_CONFIG_DIR: d })),
  ];
  for (const env of no) assert.equal(evalConfigProblem(env), NO_EVAL_CONFIG, JSON.stringify(env));
  const good = { HOME: h, CLAUDE_CONFIG_DIR: join(h, '.claude-kern-eval') };
  for (const env of [good, { ...good, CLAUDE_CONFIG_DIR: join(h, '.claude', 'other') }, { ...good, ANTHROPIC_API_KEY: '' }]) assert.equal(evalConfigProblem(env), '', JSON.stringify(env));
  for (const k of AUTH) {
    const why = evalConfigProblem({ ...good, [k]: DUMMY });
    assert.equal(why, authRefusal(k));
    assert.ok(!why.includes(DUMMY), 'the refusal names the variable, never its value');
    assert.equal(evalConfigProblem({ ...good, [k]: DUMMY, KERN_EVAL_ENV_AUTH: 'yes' }), authRefusal(k), 'only KERN_EVAL_ENV_AUTH=1 opts in');
    assert.equal(evalConfigProblem({ ...good, [k]: DUMMY, KERN_EVAL_ENV_AUTH: '1' }), '');
  }
});

test('runClaude refuses every such environment, the variable unset included, and never starts claude', () => {
  const env = guardedEnv({ config: false, log: true });
  const saved = Object.fromEntries(['CLAUDE_CONFIG_DIR', ...AUTH].map((k) => [k, process.env[k]]));
  for (const k of Object.keys(saved)) delete process.env[k];
  try {
    for (const [e, why] of refusals(env)) {
      assert.throws(() => runClaude({ cwd: scratch('ew-'), prompts: ['hi'], model: 'm', env: e }),
        (err) => err instanceof ClaudeRunError && err.fatal && err.message === why, JSON.stringify(e));
    }
  } finally {
    for (const [k, v] of Object.entries(saved)) if (v !== undefined) process.env[k] = v;
  }
  assert.equal(standInCalls(env), '');
});

test('the claude driver exits 2 on every such environment and reports why, and never starts claude', () => {
  const env = guardedEnv({ config: false, log: true });
  for (const [e, why] of refusals(env)) {
    const r = spawnSync(process.execPath, [join(REPO, 'scripts', 'lib', 'claude-drive.mjs'), '-p'], {
      input: JSON.stringify({ prompts: ['hi'], graceMs: 100 }), env: e, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe', 'pipe'] });
    assert.equal(r.status, 2, r.stderr);
    assert.equal(r.stderr, `claude-drive: ${why}\n`);
    assert.equal(JSON.parse(r.output[3]).error.message, why);
    assert.ok(!r.stderr.includes(DUMMY));
  }
  assert.equal(standInCalls(env), '');
});

test('claudeVersion refuses every such environment and never starts claude', () => {
  const env = guardedEnv({ config: false, log: true });
  const url = new URL('../scripts/lib/claude-run.mjs', import.meta.url).href;
  for (const [e, why] of refusals(env)) {
    const r = spawnSync(process.execPath, ['--input-type=module', '-e',
      `import { claudeVersion } from ${JSON.stringify(url)}; try { console.log(claudeVersion()); } catch (e) { console.error(e.message); process.exit(3); }`], { env: e, encoding: 'utf8' });
    assert.equal(r.status, 3, r.stdout);
    assert.equal(r.stderr.trim(), why);
  }
  assert.equal(standInCalls(env), '');
});

// standing-cost's once() spawns claude itself; its own check is the backstop behind main's.
test('standing-cost once() refuses every such environment and never starts claude', async () => {
  const { once } = await import('../scripts/standing-cost.mjs');
  const env = guardedEnv({ config: false, log: true });
  for (const [e, why] of refusals(env)) assert.throws(() => once(true, e), (err) => err.message === `standing-cost: ${why}`, JSON.stringify(e));
  assert.equal(standInCalls(env), '');
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
  test(`${name} exits 2 before any claude call on every such environment`, () => {
    const env = guardedEnv({ config: false, log: true });
    for (const [e, why] of refusals(env)) {
      const r = spawnSync(process.execPath, [join(sandbox(), 'scripts', `${name}.mjs`), ...args], { env: e, encoding: 'utf8', timeout: 120000 });
      assert.equal(r.status, 2, `${r.stdout}${r.stderr}`);
      assert.equal(r.stderr, `${name}: ${why}\n`);
      assert.equal(r.stdout, '');
    }
    assert.equal(standInCalls(env), '');
  });
}
