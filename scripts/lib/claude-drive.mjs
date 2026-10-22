// The child side of runClaude (claude-run.mjs), which runs it under spawnSync: one headless claude run, one
// turn per prompt. Each prompt goes to claude's stdin as one stream-json user turn, prompt k+1 only after
// claude has printed the run's k-th prompt result (promptResult: a background task's turn does not count,
// task-16-diagnosis-2 section 3), and stdin closes after the last prompt's result, so claude exits once its
// background work is done. Writing every prompt at once let Claude Code 2.1.304 read them all and run them as one turn
// (task-16-diagnosis X3). claude's stdout and stderr pass through unchanged. How claude ended goes to fd 3
// as one JSON line: { status, signal } once it exits, or { error: { code, message } } when it could not
// start. A claude that exits before its last result ends the drive with what it printed; one that never
// prints a result runs until runClaude's timeout sends this process SIGTERM. Then, as on SIGINT or SIGHUP,
// the driver sends SIGTERM to claude's process group (claude leads its own, so the tools it started stop
// too), waits up to graceMs for claude to close, sends the group SIGKILL and exits.
// Usage (runClaude only): node claude-drive.mjs <claude arguments...>, with { prompts, graceMs } as JSON on
// stdin.
import { spawn } from 'node:child_process';
import { readFileSync, writeSync } from 'node:fs';
import { StringDecoder } from 'node:string_decoder';
import { evalConfigProblem, promptResult } from './claude-run.mjs';

// The default login is never used for evals: when evalConfigProblem refuses this environment, claude is not
// started, and fd 3 says why.
const refusal = evalConfigProblem(process.env);
if (refusal) {
  try { writeSync(3, `${JSON.stringify({ error: { code: 'NO_EVAL_CONFIG', message: refusal } })}\n`); } catch { /* no runner to tell */ }
  process.stderr.write(`claude-drive: ${refusal}\n`);
  process.exit(2);
}
const { prompts, graceMs } = JSON.parse(readFileSync(0, 'utf8'));
const turn = (text) => `${JSON.stringify({ type: 'user', message: { role: 'user', content: [{ type: 'text', text }] } })}\n`;

// detached: claude leads a new process group, so one signal reaches it and every process it started. A
// terminal's Ctrl-C then reaches only the runner and this driver, which pass it on (stop).
const child = spawn('claude', process.argv.slice(2), { stdio: ['pipe', 'pipe', 'pipe'], detached: true });
let reported = false;
const report = (end) => {
  if (reported) return;
  reported = true;
  // fd 3 is closed once the runner is gone, and then there is no one left to tell.
  try { writeSync(3, `${JSON.stringify(end)}\n`); } catch { /* the runner is gone */ }
};
let exited = false;
// A spawn failure (no claude on PATH, not executable) has no pid; any later error comes with 'close'.
child.on('error', (e) => { if (child.pid === undefined) report({ error: { code: e.code ?? null, message: e.message } }); });
child.on('close', (status, signal) => { exited = true; report({ status, signal }); });

// group(sig): signal claude's process group; a group already gone is not an error.
const group = (sig) => {
  if (child.pid === undefined) return;
  try { process.kill(-child.pid, sig); } catch { /* gone */ }
};
let stopping = false;
const stop = (code) => {
  if (stopping) return;
  stopping = true;
  const end = () => { group('SIGKILL'); process.exit(code); };
  if (exited) end();
  group('SIGTERM');
  const timer = setTimeout(end, graceMs);
  child.once('close', () => { clearTimeout(timer); end(); });
};
process.on('SIGTERM', () => stop(143));
process.on('SIGINT', () => stop(130));
process.on('SIGHUP', () => stop(129));
// The runner can end without signalling this driver: a signal sent to its pid alone, or SIGKILL. claude
// leads its own group, so it would run on with no one to read it. The driver checks every 250 ms that its
// parent is still the runner, and treats a write to the runner's closed stdout (EPIPE) the same way; either
// stops claude as a signal does (Task 16h review, M2).
const runner = process.ppid;
setInterval(() => { if (process.ppid !== runner) stop(129); }, 250).unref();
process.stdout.on('error', () => stop(129));

// EPIPE: claude exited before it read a prompt. That is its own result, which 'close' reports.
child.stdin.on('error', () => {});
let sent = 0;
let inputClosed = false;
const next = () => {
  if (inputClosed) return;
  if (sent < prompts.length) child.stdin.write(turn(prompts[sent++]));
  else { inputClosed = true; child.stdin.end(); }
};

const decoder = new StringDecoder('utf8');
let buf = '';
let results = 0;
child.stdout.on('data', (chunk) => {
  process.stdout.write(chunk);
  buf += decoder.write(chunk);
  for (let i = buf.indexOf('\n'); i >= 0; i = buf.indexOf('\n')) {
    const line = buf.slice(0, i);
    buf = buf.slice(i + 1);
    let event;
    try { event = JSON.parse(line); } catch { continue; }
    if (promptResult(event) && ++results >= sent) next();
  }
});
child.stderr.on('data', (chunk) => process.stderr.write(chunk));
if (child.pid !== undefined) next();
