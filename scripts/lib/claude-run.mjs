// Run Claude Code headless on a fixture project, isolated from the host: no user settings (so no user
// plugins or hooks), no MCP servers, no saved session. Shared by exec-eval (M2a) and the M2b runners.
import { spawnSync, execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, renameSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export const ISOLATION = ['--setting-sources', 'project', '--strict-mcp-config', '--no-session-persistence'];
// A headless run cannot answer a permission prompt, and the isolation flags drop the user's allow rules, so
// the tools a task needs are pre-approved. kern's guards still ask or deny on top; an ask in a headless run is refused. The subagent tool is listed under both
// names it has had (Agent, Task).
export const PERMISSIONS = ['--permission-mode', 'acceptEdits', '--allowedTools', 'Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite'];

const SETUP_TIMEOUT_MS = 60 * 1000;

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
// ClaudeRunError when claude is missing, not executable (126, 127), killed by the timeout or a signal.
// A non-zero exit is returned in status for the caller to fail on; it is never a pass.
// The run is capped by dollars (--max-budget-usd): this Claude Code lists no turn cap in `claude --help`.
export function runClaude({ cwd, prompts, pluginDirs = [], model, maxBudgetUsd = 3, env = {}, timeoutMs = 10 * 60 * 1000 }) {
  if (!model) throw new ClaudeRunError('runClaude needs a model', true);
  const argv = ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
    '--model', model, '--max-budget-usd', String(maxBudgetUsd), ...PERMISSIONS, ...ISOLATION, ...pluginDirs.flatMap((d) => ['--plugin-dir', d])];
  const input = prompts.map((text) => JSON.stringify({ type: 'user', message: { role: 'user', content: [{ type: 'text', text }] } })).join('\n') + '\n';
  const run = spawnSync('claude', argv, { cwd, input, encoding: 'utf8', timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, env: { ...process.env, ...env } });
  if (run.error?.code === 'ENOENT') throw new ClaudeRunError('claude is not on PATH', true);
  if (run.error?.code === 'ETIMEDOUT') throw new ClaudeRunError(`claude timed out after ${timeoutMs} ms`);
  if (run.error) throw new ClaudeRunError(`claude could not run: ${run.error.message}`, true);
  if (run.status === 126 || run.status === 127) throw new ClaudeRunError(`claude exited ${run.status}: ${(run.stderr || '').trim()}`, true);
  if (run.status === null) throw new ClaudeRunError(`claude was killed by ${run.signal}`);
  const events = (run.stdout || '').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
  return { argv, events, status: run.status, stderr: run.stderr || '' };
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
