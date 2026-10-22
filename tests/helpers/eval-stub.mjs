// tests/helpers/eval-stub.mjs: what the eval runner tests share (Task 17a, P5). guardedEnv() is the
// environment a test gives a runner it spawns: a stand-in claude first on PATH, an empty config dir and a
// throwaway HOME, so a flag the runner fails to refuse can never start a paid run. The event builders make
// the stream-json a stub run returns through a runner's `run` seam.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// guardedEnv({ config, log }): { PATH, HOME, CLAUDE_CONFIG_DIR, TMPDIR } with a claude that exits 97 and prints
// nothing. config: false leaves CLAUDE_CONFIG_DIR out, for a test of the refusal without it. log: true makes the
// stand-in append each call's arguments to a file that standInCalls(env) reads. Its temp dirs are removed when
// the test process exits (P5 review, Minor 8).
const made = [];
process.once('exit', () => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
export function guardedEnv({ config = true, log = false } = {}) {
  const [bin, home, dir] = ['stub-', 'sh-', 'sc-'].map((p) => mkdtempSync(join(tmpdir(), p)));
  made.push(bin, home, dir);
  writeFileSync(join(bin, 'claude'), `#!/bin/sh\n${log ? `printf '%s\\n' "$*" >> '${join(bin, 'calls')}'\n` : ''}exit 97\n`);
  chmodSync(join(bin, 'claude'), 0o755);
  const env = { PATH: `${bin}:/usr/bin:/bin`, HOME: home, ...(config ? { CLAUDE_CONFIG_DIR: dir } : {}), TMPDIR: tmpdir() };
  assert.equal(spawnSync('/bin/sh', ['-c', 'command -v claude'], { env, encoding: 'utf8' }).stdout.trim(), join(bin, 'claude'), 'the stand-in claude is first on PATH');
  return env;
}
// standInCalls(env): the calls a guardedEnv({ log: true }) stand-in logged, one argument line each; '' when none.
export const standInCalls = (env) => {
  const f = join(env.PATH.split(':')[0], 'calls');
  return existsSync(f) ? readFileSync(f, 'utf8') : '';
};

// init(dirs): a system/init event that lists each plugin dir, as Claude Code lists a --plugin-dir.
export const init = (dirs = []) => ({ type: 'system', subtype: 'init', session_id: 's1',
  plugins: [...dirs.map((d) => ({ name: d.split('/').pop(), path: d, source: `${d.split('/').pop()}@inline` })), { name: 'cc-plugin-telemetry', path: 'builtin' }] });
// sessionStart(output, outcome): one SessionStart hook's response.
export const sessionStart = (output = '', outcome = 'success') => ({ type: 'system', subtype: 'hook_response', hook_name: 'SessionStart:startup', hook_event: 'SessionStart',
  output, stdout: output, stderr: '', exit_code: outcome === 'success' ? 0 : 1, outcome });
export const KERNEL = '# kern 0.4.0\nIn kern files read by path, ...';
// use(name, input, id): an assistant tool call; done(id, isError): its result.
export const use = (name, input, id = `t${Math.random().toString(36).slice(2, 8)}`) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', id, name, input }] } });
export const done = (id, isError = false, content = '') => ({ type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: id, is_error: isError, content }] } });
export const result = (text = 'done') => ({ type: 'result', subtype: 'success', is_error: false, result: text });
// ran(events): a run runClaude could have returned: exit 0, every line JSON.
export const ran = (events, status = 0) => ({ argv: [], events, badLines: 0, status, stderr: status ? 'failed' : '' });
// started(dirs, kernel): the events a session opens with: kern's SessionStart (the kernel, or nothing) and init.
export const started = (dirs, kernel = KERNEL) => [sessionStart(kernel), init(dirs)];

// A stand-in claude on PATH: never the real one, so these tests spend nothing. It comes with a
// CLAUDE_CONFIG_DIR, which runClaude needs before it starts any claude, and blanks the auth variables
// runClaude passes on, so one in the caller's shell neither refuses the run nor reaches the stand-in (P15).
export const NO_AUTH = { ANTHROPIC_API_KEY: '', ANTHROPIC_AUTH_TOKEN: '', CLAUDE_CODE_OAUTH_TOKEN: '' };
// By default it reads the one prompt first: a child that exits before reading it races the driver's stdin
// write (EPIPE). drain: false makes that race the test. It reads one line, not to the end: stdin closes
// only after the last prompt's result, so a child that waits for the end before answering never answers.
export function fakeClaude(body, { drain = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'fc-'));
  writeFileSync(join(dir, 'claude'), `#!/bin/sh\n${drain ? 'read -r _\n' : ''}${body}\n`);
  chmodSync(join(dir, 'claude'), 0o755);
  return { PATH: `${dir}:/usr/bin:/bin`, CLAUDE_CONFIG_DIR: join(dir, 'config'), ...NO_AUTH };
}

// A stand-in claude that runs one turn per stdin line, as stream-json input does. It holds each turn
// open for 0.3 s, and logs `early <k+1>` when prompt k+1 has reached it before it printed result k. It
// logs `eof` when stdin closes. `stop` is JavaScript run when a turn opens, to make the child die or
// exit early; n is the turn number.
export function turnClaude(stop = '') {
  const dir = mkdtempSync(join(tmpdir(), 'tc-'));
  writeFileSync(join(dir, 'claude'), `#!${process.execPath}
const fs = require('fs');
const log = (s) => fs.appendFileSync(__filename + '.log', s + '\\n');
const out = (o) => fs.writeSync(1, JSON.stringify(o) + '\\n');
let buf = '', n = 0, open = false;
const queue = [];
const next = () => {
  if (open || !queue.length) return;
  open = true; n += 1; queue.shift(); log('read ' + n);
  ${stop}
  setTimeout(() => {
    if (queue.length) log('early ' + (n + 1));
    out({ type: 'assistant', message: { content: [{ type: 'text', text: 'turn ' + n }] } });
    out({ type: 'result', subtype: 'success', is_error: false, result: 'turn ' + n });
    open = false; next();
  }, 300);
};
process.stdin.on('data', (d) => {
  buf += d;
  for (let i; (i = buf.indexOf('\\n')) >= 0; buf = buf.slice(i + 1)) queue.push(buf.slice(0, i));
  next();
});
process.stdin.on('end', () => log('eof'));
`);
  chmodSync(join(dir, 'claude'), 0o755);
  return { env: { PATH: `${dir}:/usr/bin:/bin`, CLAUDE_CONFIG_DIR: join(dir, 'config'), ...NO_AUTH }, log: () => readFileSync(join(dir, 'claude.log'), 'utf8').split('\n').filter(Boolean) };
}


// gitSandbox(repo): a git repo, one commit, holding what a runner reads of the kern repo at repo: the plugin files,
// the eval runners and evals/fixtures and evals/h2h/arms.json, so --changed has a range to read. The caller removes
// dirname(root).
export function gitSandbox(repo) {
  const root = join(mkdtempSync(join(tmpdir(), 'gs-')), 'kern');
  for (const d of ['scripts', 'hooks', 'kernel', 'skills', 'agents', 'modes', '.claude-plugin', 'evals/fixtures', 'evals/h2h/arms.json']) cpSync(join(repo, d), join(root, d), { recursive: true });
  const git = (...a) => spawnSync('git', ['-C', root, '-c', 'user.email=t@example.com', '-c', 'user.name=t', ...a], { encoding: 'utf8' });
  git('init', '-q', '-b', 'main'); git('add', '-A'); git('commit', '-qm', 'base');
  return root;
}
