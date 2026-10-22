// tests/helpers/eval-stub.mjs: what the eval runner tests share (Task 17a, P5). guardedEnv() is the
// environment a test gives a runner it spawns: a stand-in claude first on PATH, an empty config dir and a
// throwaway HOME, so a flag the runner fails to refuse can never start a paid run. The event builders make
// the stream-json a stub run returns through a runner's `run` seam.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// guardedEnv(): { PATH, HOME, CLAUDE_CONFIG_DIR, TMPDIR } with a claude that exits 97 and prints nothing. Its three
// temp dirs are removed when the test process exits (P5 review, Minor 8).
const made = [];
process.once('exit', () => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
export function guardedEnv() {
  const [bin, home, config] = ['stub-', 'sh-', 'sc-'].map((p) => mkdtempSync(join(tmpdir(), p)));
  made.push(bin, home, config);
  writeFileSync(join(bin, 'claude'), '#!/bin/sh\nexit 97\n');
  chmodSync(join(bin, 'claude'), 0o755);
  const env = { PATH: `${bin}:/usr/bin:/bin`, HOME: home, CLAUDE_CONFIG_DIR: config, TMPDIR: tmpdir() };
  assert.equal(spawnSync('/bin/sh', ['-c', 'command -v claude'], { env, encoding: 'utf8' }).stdout.trim(), join(bin, 'claude'), 'the stand-in claude is first on PATH');
  return env;
}

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
