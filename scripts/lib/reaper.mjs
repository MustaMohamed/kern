// A guard that removes a runner's temp folders when the runner ends, however it ends: a signal's default
// action (SIGINT, SIGTERM, SIGHUP), SIGKILL, or an error past every finally. A runner blocked in spawnSync
// runs no signal handler, so it cannot clean up by itself (Task 16h review, M2: a Ctrl-C left exec's
// plugin copy and the current workspace in the temp dir).
// reaper() starts the guard and returns { add(path), drop(path) }. The guard is a detached node process
// (its own process group, so a terminal's Ctrl-C does not reach it) whose stdin is a pipe from the runner.
// When the pipe closes, which it does when the runner ends, the guard removes every folder still added,
// under the OS temp dir only, then its own state, and exits. The list is a state file written whole on
// each change, so the guard reads it once, at the end.
// As the guard: node reaper.mjs <state file>.
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const SELF = fileURLToPath(import.meta.url);

export function reaper() {
  const state = join(mkdtempSync(join(tmpdir(), 'r-')), 'paths.json');
  const paths = new Set();
  const save = () => {
    writeFileSync(`${state}.new`, JSON.stringify([...paths]));
    renameSync(`${state}.new`, state);
  };
  save();
  const guard = spawn(process.execPath, [SELF, state], { stdio: ['pipe', 'ignore', 'ignore'], detached: true });
  guard.stdin.on('error', () => {});
  guard.stdin.unref();
  guard.unref();
  return { add: (p) => { paths.add(p); save(); }, drop: (p) => { paths.delete(p); save(); } };
}

// watch(state): the guard's side. Removes the listed folders once stdin closes.
function watch(state) {
  const base = realpathSync(tmpdir());
  const inTemp = (p) => { try { return realpathSync(p).startsWith(base + sep); } catch { return false; } };
  let done = false;
  const end = () => {
    if (done) return;
    done = true;
    let list = [];
    try { list = JSON.parse(readFileSync(state, 'utf8')); } catch { list = []; }
    for (const p of list) if (inTemp(p)) rmSync(realpathSync(p), { recursive: true, force: true });
    if (inTemp(dirname(state))) rmSync(dirname(state), { recursive: true, force: true });
    process.exit(0);
  };
  for (const e of ['end', 'close', 'error']) process.stdin.on(e, end);
  process.stdin.resume();
}

if (process.argv[1] === SELF) watch(process.argv[2]);
