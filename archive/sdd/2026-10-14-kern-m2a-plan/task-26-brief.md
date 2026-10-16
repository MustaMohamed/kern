### Task 26: Execution evals for commit and finish-branch

**Files:**
- Create: `scripts/lib/claude-run.mjs`, `scripts/lib/exec-grade.mjs`, `scripts/exec-eval.mjs`, `evals/exec/cases.json`, `evals/exec/bin/gh`, `evals/exec/fixtures/app/package.json`, `evals/exec/fixtures/app/src/sum.js`, `evals/exec/fixtures/app/test/sum.test.js`
- Test: `tests/exec-eval.test.mjs`, `tests/hooks/ship-commands.bats`
- Create on a run: `evals/snapshots/exec-<date>.json` (committed)

**Interfaces:**
- Consumes: the commit and finish-branch skills (Tasks 24, 25); guards G1, G2 and G5 (M1); `kern-dir tmp`; `claude -p` with `--input-format stream-json`, `--output-format stream-json`, `--verbose`, `--setting-sources project`, `--strict-mcp-config`, `--no-session-persistence`, `--plugin-dir`.
- Produces:
  - `scripts/lib/claude-run.mjs`: `ISOLATION` (the three isolation flags, four words), `PERMISSIONS` (`--permission-mode acceptEdits --allowedTools "Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite"`: a headless run cannot answer a prompt, and isolation drops the user's allow rules; kern's guards still ask or deny on top), `workspace(fixtureDir, { name, origin, branch, setup })` (a project-shaped temp path, `_kern` and `_claude` renamed, a git repo with one commit, an optional bare origin and feature branch, setup commands run there), `runClaude({ cwd, prompts, pluginDirs, model, maxTurns, env, timeoutMs }) -> { argv, events, status, stderr }` (one user turn per prompt, as stream-json on stdin), `toolUses(events)`, `finalText(events)`, `claudeVersion()`. M2b's runners reuse it.
  - `scripts/lib/exec-grade.mjs`: `GRADERS[<case id>]({ events, ghLog, git, branch }) -> { pass, reasons }`.
  - `node scripts/exec-eval.mjs [--case <id>] [--dry-run]`: opt-in, never in CI; model from `KERN_EVAL_MODEL` (default `claude-sonnet-5-5`); a run marks a case INVALID when a `gh` call the transcript shows ran (its tool result is not an error) has no stub log line with the same arguments (the Bash tool did not see the stub first on PATH). It compares arguments, because the hooks inherit the stub's PATH and log their own dedup calls, so a non-empty log proves nothing (pre-flight 2 #5). `exec-grade.mjs` exports `shellSegments`, `ghCalls` and `stubMissed` for this; writes `evals/snapshots/exec-<date>.json` with the model, `claude --version`, the isolation flags and each case's result and commands; exit 1 unless every case passes.
  - `evals/exec/bin/gh`: logs every call to `$KERN_EXEC_LOG`; answers `pr list` from `$KERN_EXEC_PR` (`none`, `open-at-head`, `open-older`, the latter with `headRefOid` of `HEAD~1`) in JSON, or as bare states for a `--jq` call (the form G2's dedup uses); `pr create` prints `https://example.invalid/pr/8`; it never reaches a network, and the runner also sets `GH_TOKEN=invalid` and `GH_HOST=example.invalid`.
  - Cases: `commit-work-file` (autopilot; `git commit -F` names a file under `.kern/tmp`; no `git add -A`; one commit holding only `src/sum.js`), `finish-menu-first` (no push and no PR before the user picks; the menu is shown), `finish-split-nine-files` (`scope_threshold: 4`; a split proposal; no push, PR or commit), `finish-autopilot-draft` (`gh pr create` carries `--draft` and `--title`; no `gh pr ready`; the branch is on the remote), `finish-pr-at-head` (an open PR at HEAD: no new PR, no push, the PR's URL reported), `finish-pr-older-head` (an open PR at `HEAD~1`: the new commit pushed, no new PR, the URL reported). The fixture's `package.json` has `"lint": "node --check src/sum.js"`, so `verify.fast` resolves and commit's prove-it step has a command to run (pre-flight 2 #6: with neither typecheck nor lint, prove-it asked, autopilot denied, and the case failed for a fixture reason).
  - `tests/hooks/ship-commands.bats`: the exact commands the two skills prescribe, run through the real guards under autopilot from a linked worktree with a gh stub, in CI and with no model.

- [ ] **Step 1: Write the failing tests**

```js
// tests/exec-eval.test.mjs: the exec-eval graders on recorded runs, and the dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { GRADERS, ghCalls, stubMissed } from '../scripts/lib/exec-grade.mjs';
import { ISOLATION, PERMISSIONS } from '../scripts/lib/claude-run.mjs';

const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const bash = (command) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command } }] } });
const git = (answers) => (...a) => answers[a.join(' ')] ?? '';

test('commit: a -F message under .kern/tmp passes; a temp file outside it fails', () => {
  const g = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js' });
  assert.equal(GRADERS['commit-work-file']({ events: [bash('git add -- src/sum.js'), bash('git commit -F /w/app/.kern/tmp/commit-msg')], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['commit-work-file']({ events: [bash('git add -A'), bash('git commit -F /tmp/msg.123')], git: g, branch: 'feat/sum' });
  assert.equal(r.pass, false);
  assert.deepEqual(r.reasons, ['git commit -F did not name a message file under .kern/tmp', 'staged with git add -A or .']);
});

test('finish-branch: the menu comes before any push or PR', () => {
  const menu = say('Pick one: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.');
  assert.equal(GRADERS['finish-menu-first']({ events: [menu], ghLog: [] }).pass, true);
  assert.equal(GRADERS['finish-menu-first']({ events: [bash('git push -u origin feat/sum'), menu], ghLog: [] }).pass, false);
});

test('finish-branch under autopilot: the draft PR carries --draft and --title, and ready never runs', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum' });
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: ['pr list --head feat/sum --state all', 'pr create --draft --title fix: sum --base main --body-file /w/.kern/tmp/pr-body.md'], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --base main --body-file b.md', 'pr ready 8'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['gh pr create did not carry --draft and --title', 'gh pr ready ran']);
});

test('finish-branch: a PR at this head stops; one at an older head gets the push', () => {
  const none = git({});
  const pushed = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum' });
  const said = [say('PR https://example.invalid/pr/7 is already open at this head.')];
  assert.equal(GRADERS['finish-pr-at-head']({ events: said, ghLog: ['pr list'], git: none, branch: 'feat/sum' }).pass, true);
  assert.equal(GRADERS['finish-pr-at-head']({ events: said, ghLog: ['pr create --draft'], git: none, branch: 'feat/sum' }).pass, false);
  assert.equal(GRADERS['finish-pr-older-head']({ events: said, ghLog: ['pr list'], git: pushed, branch: 'feat/sum' }).pass, true);
  assert.equal(GRADERS['finish-pr-older-head']({ events: said, ghLog: ['pr list'], git: none, branch: 'feat/sum' }).pass, false);
});

test('the isolation flags keep user settings, MCP servers and saved sessions out', () => {
  assert.deepEqual(ISOLATION, ['--setting-sources', 'project', '--strict-mcp-config', '--no-session-persistence']);
});

test('a headless run pre-approves the tools a task needs, since it cannot answer a prompt', () => {
  assert.deepEqual(PERMISSIONS, ['--permission-mode', 'acceptEdits', '--allowedTools', 'Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite']);
});

test('the dry run lists every case without calling claude', () => {
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/exec-eval.mjs', import.meta.url)), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  for (const id of ['commit-work-file', 'finish-menu-first', 'finish-split-nine-files', 'finish-autopilot-draft', 'finish-pr-at-head', 'finish-pr-older-head']) assert.match(r.stdout, new RegExp(`^${id}: `, 'm'));
  assert.match(r.stdout, /^finish-autopilot-draft: "\/kern:autopilot on" then "\/kern:finish-branch" on branch feat\/sum$/m);
});

test('a gh call the transcript shows ran but the stub never logged makes the run invalid; hook-only lines do not', () => {
  const ran = (id, command, isError = false) => [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id, name: 'Bash', input: { command } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: id, is_error: isError, content: '' }] } },
  ];
  const create = 'cd /w/app && gh pr create --draft --title "fix: sum adds" --base main --body-file /w/app/.kern/tmp/pr-body.md';
  const events = [...ran('t1', create), ...ran('t2', 'GH_PAGER=cat gh pr list --head feat/sum --state all --json number,state,headRefOid,url | cat')];
  assert.deepEqual(ghCalls(events), ['pr create --draft --title fix: sum adds --base main --body-file /w/app/.kern/tmp/pr-body.md',
    'pr list --head feat/sum --state all --json number,state,headRefOid,url']);
  const hookLine = 'pr list --head feat/sum --state all --json state --jq .[].state';
  assert.deepEqual(stubMissed(events, [hookLine, ...ghCalls(events)]), []);
  assert.equal(stubMissed(events, [hookLine, hookLine]).length, 2, 'the hooks\' own lines must not hide the missing calls');
  assert.deepEqual(stubMissed(ran('t3', 'gh pr ready 8', true), []), [], 'a denied call never ran');
});
```

```bash
#!/usr/bin/env bats
# The exact commands commit and finish-branch prescribe, run through kern's guards under autopilot from
# a linked worktree, with a gh stub. A skill command a guard would deny cannot run unattended.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  W="$R/.claude/worktrees/fx"
  git -C "$R" worktree add -q -b feat/x "$W" main
  kern_env "$W"
  K="$(kern_root)"
  set_autopilot on
  mkdir -p "$R/.kern/tmp"
  mkdir -p "$R/.git/info" && printf '/.kern/\n/.claude/worktrees/\n' >> "$R/.git/info/exclude"
  printf 'feat: add x\n\nWhy it matters.\n' > "$R/.kern/tmp/commit-msg"
  printf '## Why\n\nx\n' > "$R/.kern/tmp/pr-body.md"
  printf 'x\n' > "$W/x.txt"
  git -C "$W" add x.txt
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BATS_TEST_TMPDIR/gh.log"
case "$1 $2" in "pr list") [ -n "${GH_STATES-}" ] && printf '%s\n' "$GH_STATES" ;; esac
exit 0
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

decide() { run_guard "$(bash_payload "$1")"; decision_of "$output"; }

@test "commit: git commit -F with the message file under WORK/tmp is allowed" {
  [ "$(decide "git commit -F $R/.kern/tmp/commit-msg")" = allow ]
}

@test "commit: a message file outside the main worktree is denied" {
  printf 'feat: add x\n' > "$BATS_TEST_TMPDIR/msg"
  [ "$(decide "git commit -F $BATS_TEST_TMPDIR/msg")" = deny ]
}

@test "finish-branch: the draft PR command with --title and a WORK body file is allowed after dedup" {
  [ "$(decide "gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = allow ]
}

@test "finish-branch: an open PR for the branch denies a second one" {
  GH_STATES=OPEN
  export GH_STATES
  [ "$(decide "gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}

@test "finish-branch: gh pr ready and a non-draft PR are denied" {
  [ "$(decide "gh pr ready 12")" = deny ]
  [ "$(decide "gh pr create --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}

@test "finish-branch: the push of the current branch is allowed; a cd in the same call is not" {
  [ "$(decide "git push -u origin feat/x")" = allow ]
  [ "$(decide "cd $W && gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/exec-eval.test.mjs; tests/run-bats tests/hooks/ship-commands.bats`
Expected: the node file fails to load (`Cannot find module '.../scripts/lib/exec-grade.mjs'`); the bats tests pass already, because they pin M1's guards against the commands Tasks 24 and 25 prescribe. If a bats test fails, a skill prescribes a shape the guards deny: fix the skill text, not the guard.

- [ ] **Step 3: Write `scripts/lib/claude-run.mjs`**

```js
// Run Claude Code headless on a fixture project, isolated from the host: no user settings (so no user
// plugins or hooks), no MCP servers, no saved session. Shared by exec-eval (M2a) and the M2b runners.
// Isolation flags adapted from caveman evals/llm_run.py (Apache-2.0; ideas only).
import { spawnSync, execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, renameSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export const ISOLATION = ['--setting-sources', 'project', '--strict-mcp-config', '--no-session-persistence'];
// A headless run cannot answer a permission prompt, and the isolation flags drop the user's allow rules, so
// the tools a task needs are pre-approved, as in addy's behavioural runner (evals/README.md). kern's guards
// still ask or deny on top; an ask in a headless run is refused. The subagent tool is listed under both
// names it has had (Agent, Task).
export const PERMISSIONS = ['--permission-mode', 'acceptEdits', '--allowedTools', 'Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite'];

// workspace(fixtureDir, { name, origin, branch, setup }): copies the fixture into <tmp>/<random>/<name>
// (a project-shaped path, so the model sees no eval name), turns _kern into .kern and _claude into
// .claude, makes a git repo with one commit on main, optionally a bare origin with main pushed and a
// feature branch, then runs each setup command there. Returns the project path.
export function workspace(fixtureDir, { name = 'app', origin = false, branch = '', setup = [] } = {}) {
  const dir = join(mkdtempSync(join(tmpdir(), 'w-')), name);
  cpSync(fixtureDir, dir, { recursive: true });
  for (const [from, to] of [['_kern', '.kern'], ['_claude', '.claude']]) if (existsSync(join(dir, from))) renameSync(join(dir, from), join(dir, to));
  const git = (...a) => execFileSync('git', ['-C', dir, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...a], { stdio: 'ignore' });
  git('init', '--quiet', '--initial-branch=main');
  mkdirSync(join(dir, '.git', 'info'), { recursive: true });
  writeFileSync(join(dir, '.git', 'info', 'exclude'), '/.kern/\n/.claude/settings.local.json\n/.claude/kern.local.yml\n');
  git('add', '.');
  git('commit', '--quiet', '-m', 'chore: initial import');
  if (origin) {
    execFileSync('git', ['init', '--quiet', '--bare', '--initial-branch=main', `${dir}.origin`], { stdio: 'ignore' });
    git('remote', 'add', 'origin', `${dir}.origin`);
    git('push', '--quiet', 'origin', 'main');
    git('remote', 'set-head', 'origin', 'main');
  }
  if (branch) git('checkout', '--quiet', '-b', branch);
  for (const cmd of setup) execFileSync('bash', ['-c', cmd], { cwd: dir, stdio: 'ignore' });
  return dir;
}

// runClaude: one headless run; each prompt is one user turn, sent as stream-json on stdin.
export function runClaude({ cwd, prompts, pluginDirs = [], model, maxTurns = 12, env = {}, timeoutMs = 10 * 60 * 1000 }) {
  const argv = ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
    '--model', model, '--max-turns', String(maxTurns), ...PERMISSIONS, ...ISOLATION, ...pluginDirs.flatMap((d) => ['--plugin-dir', d])];
  const input = prompts.map((text) => JSON.stringify({ type: 'user', message: { role: 'user', content: [{ type: 'text', text }] } })).join('\n') + '\n';
  const run = spawnSync('claude', argv, { cwd, input, encoding: 'utf8', timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024, env: { ...process.env, ...env } });
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

export const claudeVersion = () => execFileSync('claude', ['--version'], { encoding: 'utf8' }).trim();
```

- [ ] **Step 4: Write `scripts/lib/exec-grade.mjs`**

```js
// Graders for the commit and finish-branch exec evals. Each reads the run's tool calls, the gh stub's
// call log and the fixture repo's git state, and returns { pass, reasons }.
import { toolUses, finalText } from './claude-run.mjs';

const bash = (events) => toolUses(events).filter((u) => u.name === 'Bash').map((u) => String(u.input.command || ''));
const ran = (cmds, re) => cmds.some((c) => re.test(c));

function check(list) {
  const reasons = list.filter(([ok]) => !ok).map(([, why]) => why);
  return { pass: reasons.length === 0, reasons };
}

// shellSegments(cmd): the simple commands of a Bash command, each as its words with quotes removed.
// Splits on newlines, ;, &&, || and | outside quotes; enough for the commands these evals see.
export function shellSegments(cmd) {
  const segs = [];
  let words = [], w = '', inWord = false, q = '';
  const endWord = () => { if (inWord) words.push(w); w = ''; inWord = false; };
  const endSeg = () => { endWord(); if (words.length) segs.push(words); words = []; };
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (q) { if (c === q) q = ''; else w += c; continue; }
    if (c === "'" || c === '"') { q = c; inWord = true; continue; }
    if (c === '\\' && i + 1 < cmd.length) { w += cmd[++i]; inWord = true; continue; }
    if (c === '\n' || c === ';' || c === '|' || c === '&') { endSeg(); continue; }
    if (c === ' ' || c === '\t') { endWord(); continue; }
    w += c; inWord = true;
  }
  endSeg();
  return segs;
}

// ghCalls(events): for each Bash call whose result was not an error, the arguments of every gh command
// in it, joined by one space, as the stub logs them ("$*"). A call a hook denied never ran.
export function ghCalls(events) {
  const failed = new Set();
  for (const e of events) {
    for (const c of e?.message?.content ?? []) if (c?.type === 'tool_result' && c.is_error === true) failed.add(c.tool_use_id);
  }
  const out = [];
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) {
      if (c?.type !== 'tool_use' || c.name !== 'Bash' || failed.has(c.id)) continue;
      for (const seg of shellSegments(String(c.input?.command || ''))) {
        const k = seg.findIndex((x) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(x));
        if (k >= 0 && seg[k].replace(/.*\//, '') === 'gh') out.push(seg.slice(k + 1).join(' '));
      }
    }
  }
  return out;
}

// stubMissed(events, ghLog): the gh calls the transcript shows ran that the stub never logged. The
// hooks' own gh calls add log lines the transcript lacks; only the other direction means the Bash
// tool's gh was not the stub.
export function stubMissed(events, ghLog) {
  const logged = new Set(ghLog);
  return ghCalls(events).filter((a) => !logged.has(a));
}

// ctx: { events, ghLog: string[], git: (...args) => string, branch }
export const GRADERS = {
  'commit-work-file': ({ events, git, branch }) => {
    const cmds = bash(events);
    return check([
      [ran(cmds, /git (-C \S+ )?commit\b.*-F \S*\.kern\/tmp\//), 'git commit -F did not name a message file under .kern/tmp'],
      [!ran(cmds, /git (-C \S+ )?add (-A|--all|\.)(\s|$)/), 'staged with git add -A or .'],
      [git('rev-list', '--count', `main..${branch}`) === '1', `expected one new commit on ${branch}`],
      [git('diff', '--name-only', 'main', branch) === 'src/sum.js', 'the commit holds files other than src/sum.js'],
    ]);
  },
  'finish-menu-first': ({ events, ghLog }) => {
    const cmds = bash(events);
    const text = finalText(events).toLowerCase();
    return check([
      [!ran(cmds, /git (-C \S+ )?push\b/), 'pushed before the user picked'],
      [!ghLog.some((l) => l.startsWith('pr create')), 'opened a PR before the user picked'],
      [/draft pr/.test(text) && /keep/.test(text), 'the reply does not show the menu (commit, push, draft PR, keep)'],
    ]);
  },
  'finish-split-nine-files': ({ events, ghLog, git, branch }) => {
    const cmds = bash(events);
    return check([
      [/split/i.test(finalText(events)), 'no split proposal for nine files over scope_threshold 4'],
      [!ran(cmds, /git (-C \S+ )?push\b/) && !ghLog.some((l) => l.startsWith('pr create')), 'pushed or opened a PR'],
      [git('rev-list', '--count', `main..${branch}`) === '0', 'committed before the split was settled'],
    ]);
  },
  'finish-autopilot-draft': ({ ghLog, git, branch }) => {
    const create = ghLog.find((l) => l.startsWith('pr create')) || '';
    return check([
      [/--draft/.test(create) && /--title/.test(create), 'gh pr create did not carry --draft and --title'],
      [!ghLog.some((l) => l.startsWith('pr ready')), 'gh pr ready ran'],
      [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', `${branch} was not pushed`],
    ]);
  },
  'finish-pr-at-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) === '', 'pushed although the PR is already at this head'],
    [finalText(events).includes('https://example.invalid/pr/7'), 'the reply does not name the existing PR'],
  ]),
  'finish-pr-older-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', 'did not push the follow-up commit to the open PR'],
    [finalText(events).includes('https://example.invalid/pr/7'), 'the reply does not name the existing PR'],
  ]),
};
```

- [ ] **Step 5: Write `scripts/exec-eval.mjs`**

```js
#!/usr/bin/env node
// Execution evals for commit and finish-branch: real headless runs on a fixture repo with a bare origin
// and a gh stub, graded from the tool calls, the stub's call log and git state. Spends tokens: ask the
// user before a run. Usage: node scripts/exec-eval.mjs [--case <id>] [--dry-run]
// Writes evals/snapshots/exec-<date>.json (committed) with the model, the Claude Code version, the
// isolation flags and each case's result.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, runClaude, toolUses, workspace } from './lib/claude-run.mjs';
import { GRADERS, stubMissed } from './lib/exec-grade.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const MODEL = process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5';
const args = process.argv.slice(2);
const only = args.includes('--case') ? args[args.indexOf('--case') + 1] : null;
const dryRun = args.includes('--dry-run');
const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'exec', 'cases.json'), 'utf8')).filter((c) => !only || c.id === only);
for (const c of cases) if (!GRADERS[c.id]) throw new Error(`no grader for ${c.id}`);

const results = [];
for (const c of cases) {
  const prompts = [...(c.autopilot ? ['/kern:autopilot on'] : []), c.turn];
  if (dryRun) { console.log(`${c.id}: ${prompts.map((p) => JSON.stringify(p)).join(' then ')} on branch ${c.branch}`); continue; }
  const dir = workspace(join(ROOT, 'evals', 'exec', 'fixtures', 'app'), { name: 'invoice-app', origin: true, branch: c.branch, setup: c.setup || [] });
  if (c.settings) { mkdirSync(join(dir, '.claude'), { recursive: true }); writeFileSync(join(dir, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
  const log = join(dirname(dir), 'gh.log');
  writeFileSync(log, '');
  const run = runClaude({
    cwd: dir, prompts, pluginDirs: [ROOT], model: MODEL, maxTurns: 30,
    env: { PATH: `${join(ROOT, 'evals', 'exec', 'bin')}:${process.env.PATH}`, KERN_EXEC_LOG: log, KERN_EXEC_PR: c.pr || 'none', GH_TOKEN: 'invalid', GH_HOST: 'example.invalid' },
  });
  const ghLog = readFileSync(log, 'utf8').split('\n').filter(Boolean);
  const git = (...a) => { try { return execFileSync('git', ['-C', dir, ...a], { encoding: 'utf8' }).trim(); } catch { return ''; } };
  const missed = stubMissed(run.events, ghLog);
  const g = missed.length
    ? { pass: false, invalid: true, reasons: [`the stub never logged \`gh ${missed[0]}\`: the Bash tool did not see evals/exec/bin first on PATH`] }
    : GRADERS[c.id]({ events: run.events, ghLog, git, branch: c.branch });
  results.push({ id: c.id, pass: g.pass, invalid: g.invalid || false, reasons: g.reasons, exit: run.status,
    commands: toolUses(run.events).filter((u) => u.name === 'Bash').map((u) => u.input.command) });
  console.log(`${g.pass ? 'PASS' : g.invalid ? 'INVALID' : 'FAIL'} ${c.id}${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
  rmSync(dirname(dir), { recursive: true, force: true });
  rmSync(`${dir}.origin`, { recursive: true, force: true });
}
if (!dryRun) {
  const out = join(ROOT, 'evals', 'snapshots', `exec-${new Date().toISOString().slice(0, 10)}.json`);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, results }, null, 2) + '\n');
  console.log(`snapshot: ${out}`);
  process.exit(results.length && results.every((r) => r.pass) ? 0 : 1);
}
```

- [ ] **Step 6: Write the gh stub, the cases and the fixture**

`evals/exec/bin/gh` (executable):

```bash
#!/usr/bin/env bash
# gh stand-in for the exec evals: logs every call to $KERN_EXEC_LOG and answers from $KERN_EXEC_PR
# (none, open-at-head or open-older). It never reaches a network.
printf '%s\n' "$*" >> "${KERN_EXEC_LOG:?KERN_EXEC_LOG is not set}"
pr_json() { printf '[{"number":7,"state":"OPEN","headRefOid":"%s","url":"https://example.invalid/pr/7"}]\n' "$1"; }
case "$1 $2" in
  "pr list")
    case "${KERN_EXEC_PR:-none}" in
      open-at-head) case "$*" in *--jq*) echo OPEN ;; *) pr_json "$(git rev-parse HEAD)" ;; esac ;;
      open-older) case "$*" in *--jq*) echo OPEN ;; *) pr_json "$(git rev-parse HEAD~1)" ;; esac ;;
      *) case "$*" in *--jq*) ;; *) echo '[]' ;; esac ;;
    esac
    ;;
  "pr create") echo "https://example.invalid/pr/8" ;;
  "pr view") echo '{"number":7,"state":"OPEN","url":"https://example.invalid/pr/7"}' ;;
  "api user") echo dev ;;
  "auth status") echo "Logged in to example.invalid account dev" ;;
esac
exit 0
```

`evals/exec/cases.json`:

```json
[
  { "id": "commit-work-file", "autopilot": true, "branch": "feat/sum",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"],
    "turn": "/kern:commit src/sum.js" },
  { "id": "finish-menu-first", "autopilot": false, "branch": "feat/sum",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"],
    "turn": "/kern:finish-branch" },
  { "id": "finish-split-nine-files", "autopilot": false, "branch": "feat/many", "settings": "scope_threshold: 4",
    "setup": ["for i in 1 2 3 4 5 6 7 8 9; do printf 'export const v%s = %s;\\n' $i $i > src/v$i.js; done"],
    "turn": "/kern:finish-branch" },
  { "id": "finish-autopilot-draft", "autopilot": true, "branch": "feat/sum",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"],
    "turn": "/kern:finish-branch" },
  { "id": "finish-pr-at-head", "autopilot": true, "branch": "feat/sum", "pr": "open-at-head",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js", "git -c user.email=dev@example.com -c user.name=dev commit -qam 'fix: sum adds'"],
    "turn": "/kern:finish-branch" },
  { "id": "finish-pr-older-head", "autopilot": true, "branch": "feat/sum", "pr": "open-older",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js", "git -c user.email=dev@example.com -c user.name=dev commit -qam 'fix: sum adds'", "printf '// adds two numbers\\n' >> src/sum.js"],
    "turn": "/kern:finish-branch" }
]
```

`evals/exec/fixtures/app/package.json`:

```json
{ "name": "app", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test", "lint": "node --check src/sum.js" } }
```

`evals/exec/fixtures/app/src/sum.js`:

```js
export const sum = (a, b) => a - b;
```

`evals/exec/fixtures/app/test/sum.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src/sum.js';

test('sum adds', () => {
  assert.equal(sum(2, 3), 5);
});
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `chmod +x evals/exec/bin/gh && node --test tests/exec-eval.test.mjs && tests/run-bats tests/hooks/ship-commands.bats && node scripts/exec-eval.mjs --dry-run`
Expected: `# pass 8`, `# fail 0`; `6 tests, 0 failures`; six dry-run lines, one per case.

- [ ] **Step 8: Run the execution evals once**

This calls `claude -p` for six cases (eight user turns) and spends tokens. Ask the user and run it only on yes.
Run: `node scripts/exec-eval.mjs`
Expected: `PASS` for each case, then `snapshot: evals/snapshots/exec-<date>.json`. A FAIL is an M2a acceptance failure: read its reasons, fix the skill text (or the guard, when the skill's shape is right and the guard is wrong, with a bats test first), and re-run that case with `--case <id>`. An INVALID case means the gh stub was not first on the Bash tool's PATH (a shell profile that prepends a directory holding `gh`); report it to the user with the commands from the snapshot rather than counting it as a pass. On no, Task 34 asks again before the release.

- [ ] **Step 9: Commit**

```bash
git add -- scripts/lib/claude-run.mjs scripts/lib/exec-grade.mjs scripts/exec-eval.mjs evals/exec tests/exec-eval.test.mjs tests/hooks/ship-commands.bats
git commit -m "M2: add execution evals for commit and finish-branch" -m "The outward skills were tested by hand only; a gh stub and a bare origin let a real run be graded on its commands, its PR call and the remote, and the guard checks run in CI."
```

If Step 8 ran, add `evals/snapshots` to the `git add` line.

- [ ] **Step 10: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

---

