// tests/claude-run-async.test.mjs: runClaudeAsync, the non-blocking runClaude the session pool runs, against
// the stand-in claudes runClaude's own tests use (tests/exec-eval.test.mjs). It keeps runClaude's rules: the
// same argv, guards, end report and errors. No model call: a stand-in claude is first on PATH.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ClaudeRunError, runClaude, runClaudeAsync, runProblem } from '../scripts/lib/claude-run.mjs';
import { NO_AUTH, fakeClaude, guardedEnv, standInCalls, turnClaude } from './helpers/eval-stub.mjs';

const work = () => mkdtempSync(join(tmpdir(), 'wk-'));
const attempt = (env, extra = {}) => runClaudeAsync({ cwd: work(), prompts: ['hi'], model: 'm', env, ...extra });
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch { return false; } };
const until = async (ok, ms = 3000) => { for (const t0 = Date.now(); !ok() && Date.now() - t0 < ms;) await new Promise((r) => setTimeout(r, 50)); return ok(); };

test('runClaudeAsync: a missing binary, exit 126 or 127, a timeout and a signal all reject; none is a result', async () => {
  await assert.rejects(attempt({ PATH: '/nonexistent', CLAUDE_CONFIG_DIR: '/nonexistent-config', ...NO_AUTH }), (e) => e instanceof ClaudeRunError && e.fatal && /not on PATH/.test(e.message));
  for (const code of [126, 127]) await assert.rejects(attempt(fakeClaude(`echo boom >&2; exit ${code}`)), (e) => e.fatal && e.message.includes(`exited ${code}`) && e.message.includes('boom'));
  await assert.rejects(attempt(fakeClaude('sleep 5'), { timeoutMs: 200 }), (e) => e instanceof ClaudeRunError && !e.fatal && /timed out/.test(e.message));
  await assert.rejects(attempt(fakeClaude('kill -9 $$')), (e) => e instanceof ClaudeRunError && /killed by SIGKILL/.test(e.message));
  await assert.rejects(runClaudeAsync({ cwd: work(), prompts: ['hi'], env: {} }), /needs a model/);
});

test('runClaudeAsync refuses the default login and a workspace outside the temp dir before it starts claude', async () => {
  const env = guardedEnv({ config: false, log: true });
  const saved = process.env.CLAUDE_CONFIG_DIR;
  delete process.env.CLAUDE_CONFIG_DIR;
  try {
    await assert.rejects(runClaudeAsync({ cwd: work(), prompts: ['hi'], model: 'm', env }), (e) => e.fatal && /CLAUDE_CONFIG_DIR/.test(e.message));
  } finally { if (saved !== undefined) process.env.CLAUDE_CONFIG_DIR = saved; }
  assert.equal(standInCalls(env), '', 'the stand-in never ran');
  await assert.rejects(runClaudeAsync({ cwd: process.cwd(), prompts: ['hi'], model: 'm', env: fakeClaude('exit 0') }), (e) => e.fatal && /not under/.test(e.message));
  await assert.rejects(runClaudeAsync({ cwd: join(tmpdir(), 'no-such-dir-x'), prompts: ['hi'], model: 'm', env: fakeClaude('exit 0') }), (e) => e.fatal && /not usable/.test(e.message));
});

test('runClaudeAsync: a timeout stops claude and its process group, and keeps the events it printed', async () => {
  const cwd = work();
  const stub = `echo $$ > claude.pid; echo '{"type":"system","subtype":"init","session_id":"s1"}'; trap 'echo term > stopped.txt; kill $!; exit 143' TERM; sleep 30 & echo $! > sleep.pid; read -r _; wait $!`;
  let err = null;
  await assert.rejects(runClaudeAsync({ cwd, prompts: ['hi'], model: 'm', timeoutMs: 800, killGraceMs: 300, env: fakeClaude(stub, { drain: false }) }), (e) => { err = e; return !e.fatal && /timed out/.test(e.message); });
  assert.deepEqual(err.events.map((e) => e.type), ['system']);
  await until(() => existsSync(join(cwd, 'sleep.pid')) && existsSync(join(cwd, 'stopped.txt')));
  const pids = ['claude.pid', 'sleep.pid'].map((f) => Number(readFileSync(join(cwd, f), 'utf8')));
  assert.equal(readFileSync(join(cwd, 'stopped.txt'), 'utf8'), 'term\n', 'claude got SIGTERM');
  assert.ok(await until(() => pids.every((p) => !alive(p))), 'claude and its sleep are gone');
});

test('runClaudeAsync: output over the buffer limit is a run cut off, said as such', async () => {
  const stub = `head -c 4096 /dev/zero | tr '\\0' x; echo; echo '{"type":"result","subtype":"success","result":"x"}'`;
  await assert.rejects(attempt(fakeClaude(stub), { maxBuffer: 1024 }), (e) => !e.fatal && /^claude printed more than 1024 bytes to stdout or stderr/.test(e.message));
  assert.equal((await attempt(fakeClaude(stub))).badLines, 1, 'under the default 64 MB it is returned');
});

test('runClaudeAsync returns what runClaude returns: argv, events, the exit status and stderr', async () => {
  const body = 'IFS= read -r line; printf "%s\\n" "$line" > in.txt; echo \'{"type":"result","subtype":"success","result":"x"}\'; echo warn >&2; exit 3';
  const [a, b] = [work(), work()];
  const sync = runClaude({ cwd: a, prompts: ['hi'], model: 'm', maxTurns: 30, env: fakeClaude(body, { drain: false }) });
  const got = await runClaudeAsync({ cwd: b, prompts: ['hi'], model: 'm', maxTurns: 30, env: fakeClaude(body, { drain: false }) });
  assert.deepEqual(got, sync);
  assert.deepEqual([got.status, got.stderr], [3, 'warn\n']);
  assert.equal(readFileSync(join(b, 'in.txt'), 'utf8'), readFileSync(join(a, 'in.txt'), 'utf8'));
});

test('runClaudeAsync: a usage-limit reply stops the runner; a child that exits unread is its own result', async () => {
  const limit = JSON.stringify({ type: 'assistant', message: { model: '<synthetic>', content: [{ type: 'text', text: 'You have hit your weekly limit' }] } });
  await assert.rejects(attempt(fakeClaude(`echo '${limit}'; echo '{"type":"result","subtype":"success","is_error":true}'`)), (e) => e.fatal && /weekly limit/.test(e.message));
  const big = 'x'.repeat(1024 * 1024);
  const r = await runClaudeAsync({ cwd: work(), prompts: [big], model: 'm', env: fakeClaude('exit 0', { drain: false }) });
  assert.match(runProblem(r, 1), /printed no events/);
});

test('runClaudeAsync sends prompt k+1 only after result k, then closes stdin', async () => {
  const stub = turnClaude();
  const r = await runClaudeAsync({ cwd: work(), prompts: ['one', 'two', 'three'], model: 'm', env: stub.env, timeoutMs: 20000 });
  assert.deepEqual(stub.log(), ['read 1', 'read 2', 'read 3', 'eof']);
  assert.equal(runProblem(r, 3), '');
});

test('runClaudeAsync runs sessions side by side: four 1-second claudes take about one second, not four', async () => {
  const env = fakeClaude('sleep 1; echo \'{"type":"result","subtype":"success","is_error":false,"result":"x"}\'');
  const t0 = Date.now();
  const runs = await Promise.all([0, 1, 2, 3].map(() => attempt(env)));
  const took = Date.now() - t0;
  assert.ok(runs.every((r) => r.status === 0 && runProblem(r, 1) === ''));
  assert.ok(took < 3000, `four parallel 1 s runs took ${took} ms`);
  const sub = work();
  mkdirSync(join(sub, 'sub'));
  assert.equal((await runClaudeAsync({ cwd: join(sub, 'sub'), prompts: ['hi'], model: 'm', env })).status, 0);
});
