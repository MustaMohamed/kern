// Run Claude Code headless on a fixture project, isolated from the host: no user settings (so no user
// plugins or hooks), no MCP servers, no saved session. Shared by exec-eval (M2a) and the M2b runners.
import { spawnSync, execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ISOLATION = ['--setting-sources', 'project', '--strict-mcp-config', '--no-session-persistence'];
// A headless run cannot answer a permission prompt, and the isolation flags drop the user's allow rules, so
// the tools a task needs are pre-approved. kern's guards still ask or deny on top; an ask in a headless run is refused. The subagent tool is listed under both
// names it has had (Agent, Task).
export const PERMISSIONS = ['--permission-mode', 'acceptEdits', '--allowedTools', 'Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite'];

const SETUP_TIMEOUT_MS = 60 * 1000;

// The only parent variables a run inherits, by exact name: the shell basics and the auth and config
// Claude Code reads. No ANTHROPIC_* or CLAUDE_* prefix: the calling session's own plumbing
// (CLAUDE_CODE_MESSAGING_TOKEN, SESSION_ID, ...) must not reach a model that has unrestricted Bash. Every
// other credential in the caller's shell (GITHUB_TOKEN, AWS_*, ...) stays out too.
export const INHERITED_NAMES = new Set(['PATH', 'HOME', 'USER', 'LOGNAME', 'SHELL', 'TMPDIR', 'LANG', 'TERM',
  'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL',
  'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CONFIG_DIR']);
const INHERITED_PREFIXES = ['LC_', 'KERN_EXEC_'];
const inherited = (k) => INHERITED_NAMES.has(k) || INHERITED_PREFIXES.some((p) => k.startsWith(p));

// The default login is never used for evals (P15: a standing-cost run used it on 2026-10-22). Every real
// claude spawn needs CLAUDE_CONFIG_DIR, the eval account's config dir; a test's stand-in claude takes a temp one.
export const NO_EVAL_CONFIG = "set CLAUDE_CONFIG_DIR to the eval account's config dir; the default login is never used for evals";
// evalConfigProblem(env): NO_EVAL_CONFIG when env sets no CLAUDE_CONFIG_DIR, or an empty or blank one; else ''.
export const evalConfigProblem = (env) => (String(env?.CLAUDE_CONFIG_DIR ?? '').trim() ? '' : NO_EVAL_CONFIG);

// childEnv(parent, extra): the inherited variables of parent, then extra on top.
export function childEnv(parent, extra = {}) {
  const env = {};
  for (const [k, v] of Object.entries(parent)) if (inherited(k) && v !== undefined) env[k] = v;
  return { ...env, ...extra };
}

// A child that could not run, or was cut off, is never a result. fatal: every later run would fail the
// same way (no claude binary, not executable), so the caller stops instead of grading the rest.
export class ClaudeRunError extends Error {
  constructor(message, fatal = false) {
    super(message);
    this.name = 'ClaudeRunError';
    this.fatal = fatal;
  }
}

// workspace(fixtureDir, { name, origin, branch, setup }): copies the fixture into <tmp>/<random>/<name>
// (a project-shaped path, so the model sees no eval name), turns _kern into .kern and _claude into
// .claude, makes a git repo with one commit on main, optionally a bare origin with main pushed and a
// feature branch, then runs each setup command there. The fixture's _setup folder holds files only the
// setup commands read (a script, the file versions of later history): it is not copied into the
// project, and each setup command gets its path as $SETUP_FILES. Returns the project path. A failing git
// or setup command throws.
export function workspace(fixtureDir, { name = 'app', origin = false, branch = '', setup = [] } = {}) {
  const dir = join(mkdtempSync(join(tmpdir(), 'w-')), name);
  const setupFiles = join(fixtureDir, '_setup');
  cpSync(fixtureDir, dir, { recursive: true, filter: (src) => src !== setupFiles });
  for (const [from, to] of [['_kern', '.kern'], ['_claude', '.claude']]) if (existsSync(join(dir, from))) renameSync(join(dir, from), join(dir, to));
  const run = (cmd, argv, opts = {}) => execFileSync(cmd, argv, { stdio: 'ignore', timeout: SETUP_TIMEOUT_MS, ...opts });
  const git = (...a) => run('git', ['-C', dir, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...a]);
  git('init', '--quiet', '--initial-branch=main');
  mkdirSync(join(dir, '.git', 'info'), { recursive: true });
  writeFileSync(join(dir, '.git', 'info', 'exclude'), '/.kern/\n/.claude/settings.local.json\n/.claude/kern.local.yml\n');
  git('add', '.');
  git('commit', '--quiet', '-m', 'chore: initial import');
  if (origin) {
    run('git', ['init', '--quiet', '--bare', '--initial-branch=main', `${dir}.origin`]);
    git('remote', 'add', 'origin', `${dir}.origin`);
    git('push', '--quiet', 'origin', 'main');
    git('remote', 'set-head', 'origin', 'main');
  }
  if (branch) git('checkout', '--quiet', '-b', branch);
  for (const cmd of setup) run('bash', ['-c', cmd], { cwd: dir, env: { ...process.env, SETUP_FILES: setupFiles } });
  return dir;
}

// parseEvents(stdout): the stream-json events of a run's stdout, and how many lines were not JSON.
const parseEvents = (stdout) => {
  const events = [];
  let badLines = 0;
  for (const l of (stdout || '').split('\n').filter(Boolean)) {
    try { events.push(JSON.parse(l)); } catch { badLines += 1; }
  }
  return { events, badLines };
};

// The driver that runs claude for runClaude, one turn per prompt (claude-drive.mjs).
const DRIVER = fileURLToPath(new URL('./claude-drive.mjs', import.meta.url));

// promptResult(e): e is the result event of a turn a prompt started. Since Claude Code 2.1.304 an Agent
// call that omits run_in_background runs in the background, and its notification starts a turn of its own
// whose result carries origin { kind: 'task-notification', producer: 'session-task', runId }, the run_id
// of a system/task_notification event (task-16-diagnosis-2 Y1: 174 results with no origin over 174
// prompts on 2026-10-20, and 14 with that origin). Such a turn is not a prompt's.
export const promptResult = (e) => e?.type === 'result' && e.origin?.kind !== 'task-notification';

// NO_BACKGROUND: what runClaude adds to the environment of a run of more than one prompt, so a subagent
// runs in the foreground and each prompt stays one turn. Claude Code 2.1.304 reads it as a boolean
// ("1", "true", "yes" or "on"); with it set, the Agent tool offers no run_in_background and launches
// nothing in the background, and background shells are off too (read from the binary, Task 16h). A
// run of one prompt keeps background agents, as a user's session has them: stdin closes after the
// prompt's result, and Claude Code waits for a running subagent, holding its turns' results until it is
// done (workflow-execute-plan-ledger-0, 2026-10-20: four notification turns after stdin closed).
export const NO_BACKGROUND = { CLAUDE_CODE_DISABLE_BACKGROUND_TASKS: '1' };

// runClaude: one headless run; each prompt is one user turn, sent as stream-json on stdin, prompt k+1 only
// after the run's k-th prompt result (promptResult; claude-drive.mjs, run synchronously here). A run of more
// than one prompt gets NO_BACKGROUND on top of env. Throws ClaudeRunError when
// cwd is not under the OS temp dir (the run has unrestricted Bash), claude is missing, not executable
// (126, 127), killed by the timeout or a signal. The child sees childEnv(), not the caller's whole
// environment. A non-zero exit is returned in status; use runProblem() to decide whether the run may be
// graded. Capped by turns (--max-turns, which `claude --help` does not list but the CLI reference
// documents) and by dollars (--max-budget-usd). On the timeout claude's process group gets SIGTERM, then
// SIGKILL after killGraceMs. More than maxBuffer bytes on stdout or stderr cuts the run off the same way.
export function runClaude({ cwd, prompts, pluginDirs = [], model, maxTurns = 12, maxBudgetUsd = 3, env = {}, timeoutMs = 10 * 60 * 1000,
  killGraceMs = 5000, maxBuffer = 64 * 1024 * 1024 }) {
  if (!model) throw new ClaudeRunError('runClaude needs a model', true);
  const childEnvironment = childEnv(process.env, { ...env, ...(prompts.length > 1 ? NO_BACKGROUND : {}) });
  if (evalConfigProblem(childEnvironment)) throw new ClaudeRunError(NO_EVAL_CONFIG, true);
  const root = realpathSync(tmpdir());
  let real;
  try { real = realpathSync(cwd); } catch (e) { throw new ClaudeRunError(`cwd ${cwd} is not usable: ${e.message}`, true); }
  if (!real.startsWith(root + sep)) throw new ClaudeRunError(`refusing to run in ${real}: not under ${root}`, true);
  const argv = ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
    '--model', model, '--max-turns', String(maxTurns), '--max-budget-usd', String(maxBudgetUsd), ...PERMISSIONS, ...ISOLATION, ...pluginDirs.flatMap((d) => ['--plugin-dir', d])];
  // fd 3 carries the driver's one-line report of how claude ended.
  const run = spawnSync(process.execPath, [DRIVER, ...argv], { cwd, input: JSON.stringify({ prompts, graceMs: killGraceMs }), stdio: ['pipe', 'pipe', 'pipe', 'pipe'],
    encoding: 'utf8', timeout: timeoutMs, maxBuffer, env: childEnvironment });
  // A run the timeout cut off is no result, but the events it printed go with the error, so a runner can save
  // them and a reader see how far it got (Task 16h review, M6).
  if (run.error?.code === 'ETIMEDOUT') {
    const { events } = parseEvents(run.stdout);
    throw Object.assign(new ClaudeRunError(`claude timed out after ${timeoutMs} ms; the ${events.length} events it printed are kept`), { events });
  }
  // ENOBUFS: spawnSync stopped the driver, which stopped claude, before either could report. Only this run
  // printed that much, so it is not fatal.
  if (run.error?.code === 'ENOBUFS') throw new ClaudeRunError(`claude printed more than ${maxBuffer} bytes to stdout or stderr, so the run was cut off`);
  let end = null;
  try { end = JSON.parse(run.output?.[3] || 'null'); } catch { end = null; }
  if (end?.error?.code === 'ENOENT') throw new ClaudeRunError('claude is not on PATH', true);
  if (end?.error) throw new ClaudeRunError(`claude could not run: ${end.error.message}`, true);
  // No report: the driver itself failed, so every later run would too. An EPIPE from claude exiting
  // before it read a prompt is not this: the driver takes it and reports claude's own status or signal.
  if (!end) throw new ClaudeRunError(`the claude driver failed: ${run.error?.message || `exit ${run.status ?? run.signal}`}: ${(run.stderr || '').trim().split('\n').pop() || 'no stderr'}`, true);
  if (end.status === 126 || end.status === 127) throw new ClaudeRunError(`claude exited ${end.status}: ${(run.stderr || '').trim()}`, true);
  if (end.status === null) throw new ClaudeRunError(`claude was killed by ${end.signal}`);
  const { events, badLines } = parseEvents(run.stdout);
  // A usage or rate limit: Claude Code answers by itself (model "<synthetic>") and no model ran. Every
  // later run would get the same reply, so the caller stops instead of grading it as a failed case.
  const limit = events.find((e) => e?.type === 'assistant' && e.message?.model === '<synthetic>' &&
    /\blimit\b/i.test((e.message.content ?? []).map((c) => c?.text ?? '').join(' ')));
  if (limit) throw new ClaudeRunError(`claude stopped at a usage limit: ${limit.message.content.map((c) => c?.text ?? '').join(' ').trim()}`, true);
  return { argv, events, badLines, status: end.status, stderr: run.stderr || '' };
}

// countProblem(run, prompts): why the run's turns do not match the prompts sent, or '' when they do: each
// prompt is one turn, and stream-json prints one result event per turn. Only a prompt's result counts
// (promptResult); a background task's turns are not prompts. In a run of more than one prompt, a task
// started in the background is a problem too: its turns can come between two prompts' turns, or join a
// queued prompt (task-16-diagnosis-2 section 3, recall-3-2), and NO_BACKGROUND should have kept it in the
// foreground.
export function countProblem(run, prompts) {
  if (!Number.isInteger(prompts) || prompts < 1) throw new TypeError(`countProblem needs the number of prompts sent, got ${prompts}`);
  const n = run.events.filter(promptResult).length;
  const notes = run.events.filter((e) => e?.type === 'result').length - n;
  if (n !== prompts) {
    return `${prompts} prompt${prompts === 1 ? '' : 's'} but ${n} result event${n === 1 ? '' : 's'}${notes ? ` from a prompt (and ${notes} from a background task)` : ''}: each prompt must run as its own turn`;
  }
  if (prompts > 1 && run.events.some((e) => e?.type === 'system' && e.subtype === 'task_started' && e.is_backgrounded === true)) {
    return `a background task started in a run of ${prompts} prompts, so its turns can cross a prompt boundary (${Object.keys(NO_BACKGROUND)[0]} did not hold)`;
  }
  return '';
}

// runProblem(run, prompts): why a run may not be graded, or '' when it may: a non-zero exit, a line that
// is not JSON, no events, no result event, a turn count that differs from the prompts sent (countProblem),
// or a result that is not a success (a turn or budget stop, an error), a background task's turn included.
// A run that ended early reads as an invalid run, never as a failed or passed case.
export function runProblem(run, prompts) {
  const count = countProblem(run, prompts);
  if (run.status !== 0) return `claude exited ${run.status}: ${run.stderr.trim().split('\n').pop() || 'no stderr'}`;
  if (run.badLines > 0) return `${run.badLines} line(s) of stdout were not JSON`;
  if (run.events.length === 0) return 'claude printed no events';
  const results = run.events.filter((e) => e?.type === 'result');
  if (results.length === 0) return 'no result event: the run was cut off';
  if (count) return count;
  const bad = results.find((e) => e.subtype !== 'success' || e.is_error === true);
  return bad ? `${promptResult(bad) ? 'the run' : "a background task's turn"} ended with ${bad.subtype ?? 'a result with no subtype'}${bad.is_error === true ? ' (is_error)' : ''}` : '';
}

// pluginProblem(events, { plugins, kernel }): why a run did not test what it was given, or '' (Task 17a, G10).
// plugins are the --plugin-dir paths: each must be listed by path in every system/init event, and a run with no
// init event is a problem. A SessionStart hook whose response is not a success (or exits non-zero) is a problem.
// kernel 'on': a SessionStart response opens with kern's header ("# kern"), the kernel kern injects; 'off': no
// response holds it, as for a case that turns kern off or an arm without kern; null or left out: not checked.
// /var and /private/var name one folder on macOS, and Claude Code lists either.
const bare = (p) => String(p).replace(/^\/private(?=\/)/, '');
const KERN_HEADER = /^# kern\b/m;
export function pluginProblem(events, { plugins = [], kernel = null } = {}) {
  const inits = events.filter((e) => e?.type === 'system' && e.subtype === 'init');
  if (!inits.length) return 'no system/init event, so the plugins the run loaded are unknown';
  for (const e of inits) {
    const loaded = (e.plugins ?? []).map((p) => bare(p?.path ?? ''));
    const missing = plugins.find((d) => !loaded.includes(bare(d)));
    if (missing) return `the plugin at ${missing} is not in the run's init.plugins (loaded: ${(e.plugins ?? []).map((p) => p?.name).join(', ') || 'none'})`;
  }
  const starts = events.filter((e) => e?.type === 'system' && e.subtype === 'hook_response' && e.hook_event === 'SessionStart');
  const failed = starts.find((e) => e.outcome !== 'success' || (e.exit_code ?? 0) !== 0);
  if (failed) return `a SessionStart hook failed: outcome ${failed.outcome ?? 'none'}, exit ${failed.exit_code ?? 'none'}`;
  const header = starts.some((e) => KERN_HEADER.test(String(e.output ?? e.stdout ?? '')));
  if (kernel === 'on' && !header) return 'kern\'s SessionStart printed no kernel (no "# kern" header)';
  if (kernel === 'off' && header) return 'kern was meant to be off, but its SessionStart printed the kernel';
  return '';
}

// toolUses(events): every tool call in order, { name, input }.
export function toolUses(events) {
  const out = [];
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) if (c?.type === 'tool_use') out.push({ name: c.name, input: c.input ?? {} });
  }
  return out;
}

// finalText(events): the last assistant text, or the result event's text.
export function finalText(events) {
  const result = [...events].reverse().find((e) => e?.type === 'result' && typeof e.result === 'string');
  if (result) return result.result;
  for (const e of [...events].reverse()) {
    if (e?.type !== 'assistant') continue;
    const t = (e.message?.content ?? []).filter((c) => c?.type === 'text').map((c) => c.text).join('\n');
    if (t) return t;
  }
  return '';
}

// runSummary(events): what a snapshot keeps to explain a stop: the last 4000 characters of the final
// reply, the number of assistant turns, and the last result event's subtype (null when there is none).
export function runSummary(events) {
  const results = events.filter((e) => e?.type === 'result');
  return {
    final: finalText(events).slice(-4000),
    turns: events.filter((e) => e?.type === 'assistant').length,
    subtype: results.length ? (results[results.length - 1].subtype ?? null) : null,
  };
}

// claudeVersion(env): `claude --version` under env; it refuses as runClaude does when env sets no CLAUDE_CONFIG_DIR.
export const claudeVersion = (env = process.env) => {
  if (evalConfigProblem(env)) throw new ClaudeRunError(NO_EVAL_CONFIG, true);
  return execFileSync('claude', ['--version'], { encoding: 'utf8', timeout: SETUP_TIMEOUT_MS, env }).trim();
};
