// Run Claude Code headless on a fixture project, isolated from the host: no user settings (so no user
// plugins or hooks), no MCP servers, no saved session. Shared by exec-eval (M2a) and the M2b runners.
import { spawnSync, execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';

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
// feature branch, then runs each setup command there. Returns the project path. A failing git or setup
// command throws.
export function workspace(fixtureDir, { name = 'app', origin = false, branch = '', setup = [] } = {}) {
  const dir = join(mkdtempSync(join(tmpdir(), 'w-')), name);
  cpSync(fixtureDir, dir, { recursive: true });
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
  for (const cmd of setup) run('bash', ['-c', cmd], { cwd: dir });
  return dir;
}

// runClaude: one headless run; each prompt is one user turn, sent as stream-json on stdin. Throws
// ClaudeRunError when cwd is not under the OS temp dir (the run has unrestricted Bash), claude is
// missing, not executable (126, 127), killed by the timeout or a signal. The child sees childEnv(), not
// the caller's whole environment. A non-zero exit is returned in status; use runProblem() to decide
// whether the run may be graded. Capped by turns (--max-turns, which `claude --help` does not list but
// the CLI reference documents) and by dollars (--max-budget-usd).
export function runClaude({ cwd, prompts, pluginDirs = [], model, maxTurns = 12, maxBudgetUsd = 3, env = {}, timeoutMs = 10 * 60 * 1000 }) {
  if (!model) throw new ClaudeRunError('runClaude needs a model', true);
  const root = realpathSync(tmpdir());
  let real;
  try { real = realpathSync(cwd); } catch (e) { throw new ClaudeRunError(`cwd ${cwd} is not usable: ${e.message}`, true); }
  if (!real.startsWith(root + sep)) throw new ClaudeRunError(`refusing to run in ${real}: not under ${root}`, true);
  const argv = ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
    '--model', model, '--max-turns', String(maxTurns), '--max-budget-usd', String(maxBudgetUsd), ...PERMISSIONS, ...ISOLATION, ...pluginDirs.flatMap((d) => ['--plugin-dir', d])];
  const input = prompts.map((text) => JSON.stringify({ type: 'user', message: { role: 'user', content: [{ type: 'text', text }] } })).join('\n') + '\n';
  const run = spawnSync('claude', argv, { cwd, input, encoding: 'utf8', timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, env: childEnv(process.env, env) });
  if (run.error?.code === 'ENOENT') throw new ClaudeRunError('claude is not on PATH', true);
  if (run.error?.code === 'ETIMEDOUT') throw new ClaudeRunError(`claude timed out after ${timeoutMs} ms`);
  if (run.error) throw new ClaudeRunError(`claude could not run: ${run.error.message}`, true);
  if (run.status === 126 || run.status === 127) throw new ClaudeRunError(`claude exited ${run.status}: ${(run.stderr || '').trim()}`, true);
  if (run.status === null) throw new ClaudeRunError(`claude was killed by ${run.signal}`);
  const events = [];
  let badLines = 0;
  for (const l of (run.stdout || '').split('\n').filter(Boolean)) {
    try { events.push(JSON.parse(l)); } catch { badLines += 1; }
  }
  return { argv, events, badLines, status: run.status, stderr: run.stderr || '' };
}

// runProblem(run): why a run may not be graded, or '' when it may: a non-zero exit, a line that is not
// JSON, no events, or no result event, or a result that is not a success (a turn or budget stop, an
// error). A run that ended early reads as an invalid run, never as a failed or passed case.
export function runProblem(run) {
  if (run.status !== 0) return `claude exited ${run.status}: ${run.stderr.trim().split('\n').pop() || 'no stderr'}`;
  if (run.badLines > 0) return `${run.badLines} line(s) of stdout were not JSON`;
  if (run.events.length === 0) return 'claude printed no events';
  const results = run.events.filter((e) => e?.type === 'result');
  if (results.length === 0) return 'no result event: the run was cut off';
  const bad = results.find((e) => e.subtype !== 'success' || e.is_error === true);
  return bad ? `the run ended with ${bad.subtype ?? 'a result with no subtype'}${bad.is_error === true ? ' (is_error)' : ''}` : '';
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

export const claudeVersion = () => execFileSync('claude', ['--version'], { encoding: 'utf8', timeout: SETUP_TIMEOUT_MS }).trim();
