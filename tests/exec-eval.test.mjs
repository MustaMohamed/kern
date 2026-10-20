// tests/exec-eval.test.mjs: the exec-eval graders on recorded runs, the runner's failure handling and the
// dry run. No model call: the runner tests put a stand-in `claude` first on PATH.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ATTRIBUTION, GRADERS, chainParts, stoppedOnRedProof, gitCalls, ghCalls, shellSegments, sizeGateRan, stubMissed } from '../scripts/lib/exec-grade.mjs';
import { ISOLATION, PERMISSIONS, ClaudeRunError, childEnv, runClaude, runProblem, runSummary } from '../scripts/lib/claude-run.mjs';
import { UsageError, autopilotProblem, caseEnv, claudeConfigDir, exitCode, gradeCase, kernStateFile, parseArgs, replyDate, runEval, sessionId, snapshotBody, userSettingsProblem, writeEvents, writeReply } from '../scripts/lib/exec-run.mjs';

const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const bash = (command) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command } }] } });
const git = (answers) => (...a) => answers[a.join(' ')] ?? '';
const DECOYS = 'M README.md\n?? notes.txt';
const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js', 'status --porcelain': DECOYS });
const ORIGIN_PR = 'file:///w/app.origin/pull/7';
// ran(prefix, ...commands): Bash calls with their results, in order; a command written as ['cmd', false]
// failed; a third item is its output.
const ran = (prefix, ...cmds) => cmds.flatMap((c, i) => {
  const [command, ok, output = ''] = Array.isArray(c) ? c : [c, true];
  return [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id: `${prefix}${i}`, name: 'Bash', input: { command } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: `${prefix}${i}`, is_error: !ok, content: output }] } },
  ];
});
// GATE: a green proof, then finish-branch step 6's size gate. REVIEWED: steps 4 and 5 (wt-snap, a self-review package).
const GATE = ran('g', 'cd /w/app && npm test', 'git merge-base HEAD origin/main', 'git diff --shortstat 1a2b 3c4d');
const REVIEWED = ran('v', 'bash /k/scripts/wt-snap /w/app', 'bash /k/scripts/wt-diff /w/app 1a2b --out /w/app/.kern/tmp/review/feat-sum');
const MENU = 'Pick one: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.';
// The split case's final reply from exec-eval rerun 3: a split offered as a choice, the menu only promised.
const RECORDED = [
  'Self-review verdict is `ready`, but the size gate stops the run, so nothing is committed or pushed yet.',
  '**Size gate** - The diff is 10 files, +10/-1, against `scope_threshold` 4.',
  '**Decision for you:** should I split this?',
  '1. **Split (recommended):** commit and push the `sum.js` fix on its own, and keep `v1` to `v9` out of the PR.',
  '2. **No split:** go on with all 10 files, then pick from the menu (commit, push, or draft PR).',
  "Reply `split` or `no`. If `no`, I'll show the menu.",
].join('\n\n');

test('commit: a -F message under .kern/tmp passes; a temp file outside it fails', () => {
  assert.equal(GRADERS['commit-work-file']({ events: [bash('git add -- src/sum.js'), bash('git commit -F /w/app/.kern/tmp/commit-msg')], git: oneCommit, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['commit-work-file']({ events: [bash('git add -A'), bash('git commit -F /tmp/msg.123')], git: oneCommit, branch: 'feat/sum' });
  assert.equal(r.pass, false);
  assert.deepEqual(r.reasons, ['git commit -F did not name a message file under .kern/tmp', 'staged with git add -A or .']);
});

test('commit: the git -C forms the skill prescribes pass, and -A or . is rejected in either form', () => {
  const ok = [bash('git -C /w/app add -- src/sum.js'), bash('git -C /w/app commit -F /w/app/.kern/tmp/commit-msg')];
  assert.equal(GRADERS['commit-work-file']({ events: ok, git: oneCommit, branch: 'feat/sum' }).pass, true);
  const seen = [bash('cd /w/app && git -C /w/app add -- src/sum.js && git -C /w/app commit -F /w/app/.kern/tmp/commit-msg')];
  assert.equal(GRADERS['commit-work-file']({ events: seen, git: oneCommit, branch: 'feat/sum' }).pass, true, 'a cd x && git commit is still seen');
  for (const add of ['git -C /w/app add -A', 'git -C /w/app add .', 'git -C /w/app add -- .', 'git -C /w/app add --all', 'git add .']) {
    const r = GRADERS['commit-work-file']({ events: [bash(add), ...ok.slice(1)], git: oneCommit, branch: 'feat/sum' });
    assert.deepEqual(r.reasons, ['staged with git add -A or .'], add);
  }
  const outside = GRADERS['commit-work-file']({ events: [bash('git -C /w/app commit -F /tmp/msg.123')], git: oneCommit, branch: 'feat/sum' });
  assert.deepEqual(outside.reasons, ['git commit -F did not name a message file under .kern/tmp']);
  const inline = GRADERS['commit-work-file']({ events: [bash('git -C /w/app commit -m "feat: x"')], git: oneCommit, branch: 'feat/sum' });
  assert.deepEqual(inline.reasons, ['git commit -F did not name a message file under .kern/tmp']);
});

test('commit: a relative .kern/tmp message path is accepted', () => {
  assert.equal(GRADERS['commit-work-file']({ events: [bash('git -C /w/app commit -F .kern/tmp/commit-msg')], git: oneCommit, branch: 'feat/sum' }).pass, true);
});

test('commit: commit -a, add -u and add * fail, by command and by outcome (the decoys are committed)', () => {
  const swept = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'README.md\nsrc/sum.js', 'status --porcelain': '?? notes.txt' });
  const msg = 'git -C /w/app commit -F /w/app/.kern/tmp/commit-msg';
  for (const stage of ['git -C /w/app commit -a -F /w/app/.kern/tmp/commit-msg', 'git -C /w/app commit -am x', 'git -C /w/app add -u', 'git -C /w/app add -- *', 'git -C /w/app add --update']) {
    const r = GRADERS['commit-work-file']({ events: [bash(stage), bash(msg)], git: swept, branch: 'feat/sum' });
    assert.equal(r.pass, false, stage);
    assert.ok(r.reasons.includes('the commit holds files other than src/sum.js'), stage);
  }
  const byState = GRADERS['commit-work-file']({ events: [bash('git -C /w/app add -- src/sum.js'), bash(msg)], git: swept, branch: 'feat/sum' });
  assert.deepEqual(byState.reasons, ['the commit holds files other than src/sum.js', 'a decoy (README.md edit, notes.txt) was committed or lost']);
});

test('shellSegments drops redirections, so 2>&1 and >/dev/null are not arguments', () => {
  assert.deepEqual(shellSegments('gh pr list --head b --json number 2>&1'), [['gh', 'pr', 'list', '--head', 'b', '--json', 'number']]);
  assert.deepEqual(shellSegments('gh pr list > /dev/null 2>/dev/null && git push &> /tmp/x'), [['gh', 'pr', 'list'], ['git', 'push']]);
  assert.deepEqual(shellSegments("gh pr create --title '> not a redirect'"), [['gh', 'pr', 'create', '--title', '> not a redirect']]);
  const ran = [{ type: 'assistant', message: { content: [{ type: 'tool_use', id: 'a', name: 'Bash', input: { command: 'gh pr list --head b 2>&1' } }] } }];
  assert.deepEqual(stubMissed(ran, ['pr list --head b']), []);
});

test('finish-branch: every gh pr create must carry --draft and --title; the split needs an offer', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum', 'rev-parse feat/sum': 'abc', 'rev-list --count main..feat/sum': '1' });
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --title t --base main --body-file b.md', 'body: x', 'pr create --title t --base main --body-file b.md', 'body: x'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['gh pr create did not carry --draft and --title']);
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: [], git: g, branch: 'feat/sum' }).pass, false, 'no create at all');
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const verdict = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  assert.equal(verdict('Nine files is over scope_threshold 4. Should I split this into two PRs?'), true);
  assert.equal(verdict('I will not split this; going ahead.'), false);
  assert.equal(verdict('Nine files, nothing else to say.'), false);
});

test('gitCalls drops -C and -c, reads past && and ;, and ignores other commands', () => {
  assert.deepEqual(gitCalls(['cd /w && git -C /w -c core.x=1 push -u origin feat/sum; echo git push', 'ls git push']), [{ sub: 'push', args: ['-u', 'origin', 'feat/sum'] }]);
  assert.deepEqual(shellSegments("git -C '/a b' commit -F m"), [['git', '-C', '/a b', 'commit', '-F', 'm']]);
});

test('finish-branch: the menu comes before any push or PR', () => {
  const menu = say('Pick one: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.');
  assert.equal(GRADERS['finish-menu-first']({ events: [...REVIEWED, menu], ghLog: [] }).pass, true);
  assert.equal(GRADERS['finish-menu-first']({ events: [...REVIEWED, bash('git push -u origin feat/sum'), menu], ghLog: [] }).pass, false);
  assert.equal(GRADERS['finish-menu-first']({ events: [...REVIEWED, bash('git -C /w/app push -u origin feat/sum'), menu], ghLog: [] }).pass, false, 'a -C push counts');
  assert.equal(GRADERS['finish-menu-first']({ events: [...REVIEWED, bash('cd /w/app && git push --force-with-lease origin feat/sum'), menu], ghLog: [] }).pass, false);
});

test('finish-branch: nine files stop at a split proposal, with a -C push counted too', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const events = [...GATE, say('Nine files is over scope_threshold 4: should I split it?')];
  assert.equal(GRADERS['finish-split-nine-files']({ events, ghLog: [], git: none, branch: 'feat/many' }).pass, true);
  const r = GRADERS['finish-split-nine-files']({ events: [...events.slice(0, -1), bash('git -C /w push -u origin feat/many'), ...events.slice(-1)], ghLog: [], git: none, branch: 'feat/many' });
  assert.deepEqual(r.reasons, ['pushed or opened a PR']);
});

test('finish-branch under autopilot: the draft PR carries --draft and --title, and ready never runs', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum', 'rev-parse feat/sum': 'abc', 'rev-list --count main..feat/sum': '1' });
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: ['pr list --head feat/sum --state all --json number,state,headRefOid,url', 'pr create --draft --title fix: sum --base main --body-file /w/.kern/tmp/pr-body.md', 'body: x'], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --base main --body-file b.md', 'body: x', 'pr ready 8'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['gh pr create did not carry --draft and --title', 'gh pr ready ran']);
});

test('finish-branch: a PR at this head stops; one at an older head gets the push', () => {
  const none = git({});
  const pushed = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum', 'rev-parse feat/sum': 'abc', 'rev-list --count main..feat/sum': '2' });
  const said = [say(`PR ${ORIGIN_PR} is already open at this head.`)];
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
  const create = "cd /w/app && gh pr create --draft --title 'fix: sum adds' --base main --body-file /w/app/.kern/tmp/pr-body.md";
  const events = [...ran('t1', create), ...ran('t2', 'GH_PAGER=cat gh pr list --head feat/sum --state all --json number,state,headRefOid,url | cat')];
  assert.deepEqual(ghCalls(events), ['pr create --draft --title fix: sum adds --base main --body-file /w/app/.kern/tmp/pr-body.md',
    'pr list --head feat/sum --state all --json number,state,headRefOid,url']);
  const hookLine = 'pr list --head feat/sum --state all --json state --jq .[].state';
  assert.deepEqual(stubMissed(events, [hookLine, ...ghCalls(events)]), []);
  assert.equal(stubMissed(events, [hookLine, hookLine]).length, 2, "the hooks' own lines must not hide the missing calls");
  assert.deepEqual(stubMissed(ran('t3', 'gh pr ready 8', true), []), [], 'a denied call never ran');
});

// A stand-in claude on PATH: never the real one, so these tests spend nothing.
// By default it drains stdin first: a child that exits before reading it races spawnSync's stdin write
// (EPIPE on Linux). drain: false makes that race the test.
function fakeClaude(body, { drain = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'fc-'));
  writeFileSync(join(dir, 'claude'), `#!/bin/sh\n${drain ? 'cat > /dev/null\n' : ''}${body}\n`);
  chmodSync(join(dir, 'claude'), 0o755);
  return { PATH: `${dir}:/usr/bin:/bin` };
}
const work = () => mkdtempSync(join(tmpdir(), 'wk-'));
const attempt = (env, extra = {}) => () => runClaude({ cwd: work(), prompts: ['hi'], model: 'm', env, ...extra });

test('runClaude: a missing binary, exit 126 or 127, a timeout and a signal all throw; none is a result', () => {
  assert.throws(attempt({ PATH: '/nonexistent' }), (e) => e instanceof ClaudeRunError && e.fatal && /not on PATH/.test(e.message));
  for (const code of [126, 127]) assert.throws(attempt(fakeClaude(`echo boom >&2; exit ${code}`)), (e) => e.fatal && e.message.includes(`exited ${code}`) && e.message.includes('boom'));
  assert.throws(attempt(fakeClaude('sleep 5'), { timeoutMs: 200 }), (e) => e instanceof ClaudeRunError && !e.fatal && /timed out/.test(e.message));
  assert.throws(attempt(fakeClaude('kill -9 $$')), (e) => e instanceof ClaudeRunError && /killed by SIGKILL/.test(e.message));
  assert.throws(() => runClaude({ cwd: work(), prompts: ['hi'], env: {} }), /needs a model/);
});

test('runClaude: a non-zero exit is returned for the caller to fail on, with stdin as stream-json turns and the budget cap', () => {
  const r = attempt(fakeClaude('cat > "$0.in"; echo "$@" > "$0.argv"; echo \'{"type":"result","result":"x"}\'; exit 3'))();
  assert.equal(r.status, 3);
  assert.deepEqual(r.events, [{ type: 'result', result: 'x' }]);
  assert.deepEqual(r.argv.slice(r.argv.indexOf('--max-turns'), r.argv.indexOf('--max-turns') + 4), ['--max-turns', '12', '--max-budget-usd', '3']);
  assert.ok(attempt(fakeClaude('exit 0'), { maxTurns: 30, maxBudgetUsd: 5 })().argv.join(' ').includes('--max-turns 30 --max-budget-usd 5'));
});

test('runClaude: a usage-limit reply from Claude Code stops the runner; it is never graded', () => {
  const synth = (text, model = '<synthetic>') => JSON.stringify({ type: 'assistant', message: { model, content: [{ type: 'text', text }] } });
  const limit = synth("You've hit your weekly limit · resets Oct 20 at 2pm (Africa/Cairo)");
  const out = `echo '${limit.replace(/'/g, "'\\''")}'; echo '{"type":"result","subtype":"success","is_error":true,"result":"limit"}'`;
  assert.throws(attempt(fakeClaude(out)), (e) => e instanceof ClaudeRunError && e.fatal && /weekly limit/.test(e.message));
  const real = synth("You've hit your weekly limit, the user said", 'claude-sonnet-5-5');
  const ok = attempt(fakeClaude(`echo '${real.replace(/'/g, "'\\''")}'; echo '{"type":"result","subtype":"success","result":"x"}'`))();
  assert.equal(ok.events.length, 2, 'a model that writes the words is not a limit');
});

test('the gh stub logs every call, answers pr list from the case, and fails on a call it does not know', () => {
  const stub = fileURLToPath(new URL('../evals/exec/bin/gh', import.meta.url));
  const log = join(mkdtempSync(join(tmpdir(), 'gh-')), 'gh.log');
  const repo = mkdtempSync(join(tmpdir(), 'ghr-'));
  spawnSync('git', ['-C', repo, 'init', '-q']);
  spawnSync('git', ['-C', repo, 'remote', 'add', 'origin', `${repo}.origin`]);
  const gh = (...a) => spawnSync(stub, a, { encoding: 'utf8', cwd: repo, env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log, KERN_EXEC_PR: 'none' } });
  assert.equal(gh('pr', 'list', '--json', 'state').stdout, '[]\n');
  assert.equal(gh('pr', 'list', '--state', 'all', '--json', 'state', '--jq', '.[].state').stdout, '');
  assert.equal(gh('pr', 'create', '--draft').stdout, `file://${repo}.origin/pull/8\n`, 'a PR URL carries the origin path');
  assert.equal(gh('pr', 'view', '7').stdout, `{"number":7,"state":"OPEN","url":"file://${repo}.origin/pull/7"}\n`);
  const bare = mkdtempSync(join(tmpdir(), 'nr-'));
  const noOrigin = spawnSync(stub, ['pr', 'create'], { encoding: 'utf8', cwd: bare, env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log } });
  assert.equal(noOrigin.status, 1, 'no origin, no invented URL');
  const odd = gh('repo', 'delete', 'x');
  assert.equal(odd.status, 1);
  assert.match(odd.stderr, /unhandled call: repo delete x/);
  assert.equal(readFileSync(log, 'utf8').split('\n').filter(Boolean).length, 6);
  assert.notEqual(spawnSync(stub, ['pr', 'list'], { env: { PATH: '/usr/bin:/bin' } }).status, 0, 'no log path, no run');
});

test('a child that exits without reading stdin is its own result: invalid, not a fatal "could not run"', () => {
  // A prompt big enough to fill the pipe makes the EPIPE certain rather than a race.
  const big = 'x'.repeat(1024 * 1024);
  for (const [code, want] of [[0, /printed no events/], [3, /exited 3/]]) {
    const r = runClaude({ cwd: work(), prompts: [big], model: 'm', env: fakeClaude(`exit ${code}`, { drain: false }) });
    assert.equal(r.status, code);
    assert.match(runProblem(r), want);
  }
  assert.throws(() => runClaude({ cwd: work(), prompts: [big], model: 'm', env: fakeClaude('exit 127', { drain: false }) }), (e) => e.fatal && /exited 127/.test(e.message));
});

test('runClaude refuses a workspace outside the OS temp dir, or one that is the temp dir itself', () => {
  const refuse = (cwd) => () => runClaude({ cwd, prompts: ['hi'], model: 'm', env: fakeClaude('exit 0') });
  assert.throws(refuse(process.cwd()), (e) => e instanceof ClaudeRunError && e.fatal && /not under/.test(e.message));
  assert.throws(refuse(tmpdir()), /not under/);
  assert.throws(refuse(join(tmpdir(), 'no-such-dir-x')), (e) => e.fatal && /not usable/.test(e.message));
  const inside = work();
  mkdirSync(join(inside, 'sub'));
  assert.equal(refuse(join(inside, 'sub'))().status, 0);
});

test('the child environment is an allowlist: auth and config in, other credentials out', () => {
  const parent = { PATH: '/p', HOME: '/h', USER: 'u', LC_ALL: 'C', ANTHROPIC_API_KEY: 'k', CLAUDE_CODE_OAUTH_TOKEN: 't', GITHUB_TOKEN: 'g', AWS_SECRET_ACCESS_KEY: 's', SSH_AUTH_SOCK: '/s', GH_TOKEN: 'real' };
  assert.deepEqual(childEnv(parent, { GH_TOKEN: 'invalid', GH_HOST: 'example.invalid', KERN_EXEC_LOG: '/l' }),
    { PATH: '/p', HOME: '/h', USER: 'u', LC_ALL: 'C', ANTHROPIC_API_KEY: 'k', CLAUDE_CODE_OAUTH_TOKEN: 't', GH_TOKEN: 'invalid', GH_HOST: 'example.invalid', KERN_EXEC_LOG: '/l' });
});

test('the calling session\'s own plumbing and other credentials never reach the child', () => {
  const session = ['CLAUDE_CODE_MESSAGING_TOKEN', 'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_BRIDGE_SESSION_ID',
    'CLAUDE_CODE_CHILD_SESSION', 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS', 'CLAUDE_CODE_ENTRYPOINT', 'CLAUDE_CODE_EXECPATH', 'ANTHROPIC_FOO', 'CLAUDE_FOO', 'NPM_TOKEN', 'HTTPS_PROXY'];
  const wanted = ['PATH', 'HOME', 'USER', 'LOGNAME', 'SHELL', 'TMPDIR', 'LANG', 'TERM', 'LC_CTYPE', 'KERN_EXEC_LOG', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CONFIG_DIR'];
  const parent = Object.fromEntries([...session, ...wanted].map((k) => [k, 'v']));
  const env = childEnv(parent);
  for (const k of session) assert.ok(!(k in env), `${k} must be absent`);
  assert.deepEqual(Object.keys(env).sort(), [...wanted].sort());
});

test('runClaude gives the child that allowlist, not the caller environment', () => {
  const cwd = work();
  process.env.GITHUB_TOKEN = 'leak-check';
  try {
    const r = runClaude({ cwd, prompts: ['hi'], model: 'm', env: fakeClaude('env > env.txt; exit 0') });
    assert.equal(r.status, 0);
  } finally { delete process.env.GITHUB_TOKEN; }
  const seen = readFileSync(join(cwd, 'env.txt'), 'utf8');
  assert.ok(!seen.includes('GITHUB_TOKEN') && !seen.includes('leak-check'));
  assert.match(seen, /^PATH=/m);
});

test('runProblem: only a clean exit with a success result may be graded', () => {
  const run = (body) => attempt(fakeClaude(body))();
  assert.match(runProblem(run('exit 0')), /printed no events/);
  assert.match(runProblem(run('echo "not json"; exit 0')), /not JSON/);
  assert.match(runProblem(run('echo \'{"type":"assistant","message":{"content":[]}}\'; exit 0')), /no result event/);
  assert.match(runProblem(run('echo \'{"type":"result","subtype":"error_max_turns","is_error":false}\'; exit 0')), /error_max_turns/);
  assert.match(runProblem(run('echo \'{"type":"result","subtype":"success","is_error":true,"result":"x"}\'; exit 0')), /is_error/);
  assert.match(runProblem(run('echo \'{"type":"result","subtype":"success"}\'; exit 2')), /exited 2/);
  assert.equal(runProblem(run('echo \'{"type":"result","subtype":"success","is_error":false,"result":"x"}\'; exit 0')), '');
});

const result = (id, pass, invalid = false) => ({ id, pass, invalid, reasons: pass ? [] : ['why'] });
// drive: runEval with an injected runner. An outcome of 'invalid' is an invalid case.
const drive = ({ only = null, outcomes, readVersion = () => 'claude 9.9.9' }) => {
  const lines = [], snaps = [], ran = [], versions = [];
  const cases = [{ id: 'a' }, { id: 'b' }].filter((c) => !only || c.id === only);
  const code = runEval({ cases, only, dryRun: false, describe: (c) => c.id, log: (l) => lines.push(l), readVersion,
    runCase: (c) => { ran.push(c.id); return outcomes[c.id] === 'invalid' ? result(c.id, false, true) : result(c.id, outcomes[c.id]); },
    writeSnapshot: (r, v) => { snaps.push(r); versions.push(v); } });
  return { code, lines, snaps, ran, versions };
};

test('exit code: 0 only when every case that ran passed, for a full run and a --case run alike', () => {
  assert.equal(drive({ outcomes: { a: true, b: true } }).code, 0);
  assert.equal(drive({ outcomes: { a: true, b: false } }).code, 1);
  assert.equal(drive({ only: 'a', outcomes: { a: true, b: false } }).code, 0, 'b did not run');
  assert.equal(drive({ only: 'b', outcomes: { a: true, b: false } }).code, 1, 'a failing --case run is not a pass');
  assert.equal(exitCode([]), 1, 'nothing ran is not a pass');
  assert.equal(exitCode([result('x', false, true)]), 1, 'an invalid case is not a pass');
});

test('snapshot: a full run writes it with every result; a --case run writes none', () => {
  const full = drive({ outcomes: { a: true, b: false } });
  assert.equal(full.snaps.length, 1);
  assert.deepEqual(full.snaps[0].map((r) => r.id), ['a', 'b']);
  const one = drive({ only: 'a', outcomes: { a: true } });
  assert.deepEqual(one.snaps, []);
  assert.deepEqual(one.ran, ['a']);
  assert.match(one.lines.join('\n'), /no snapshot written/);
});

test('arguments: a --case with no value, a flag as its value or an unknown id is a usage error before any run', () => {
  const ids = ['a', 'b'];
  assert.deepEqual(parseArgs(['--case', 'b'], ids), { only: 'b', dryRun: false });
  assert.deepEqual(parseArgs(['--dry-run'], ids), { only: null, dryRun: true });
  for (const bad of [['--case'], ['--case', '--dry-run'], ['--case', 'zzz'], ['--cas', 'a'], ['a']]) assert.throws(() => parseArgs(bad, ids), UsageError, bad.join(' '));
  const eval_ = (...a) => spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/exec-eval.mjs', import.meta.url)), ...a], { encoding: 'utf8', env: { PATH: '/nonexistent' } });
  for (const a of [['--case'], ['--case', 'nope']]) {
    const r = eval_(...a);
    assert.equal(r.status, 2, a.join(' '));
    assert.match(r.stderr, /usage: node scripts\/exec-eval\.mjs/);
    assert.equal(r.stdout, '', 'nothing ran');
  }
});

test('finish-split-nine-files: negated replies fail, real offers pass', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const verdict = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  for (const no of ['I did not propose a split.', 'No split needed here.', 'There is no need to split this.', 'I will not split this branch.', 'Never split it.']) assert.equal(verdict(no), false, no);
  for (const yes of ['I propose splitting the branch. Should I split it?', 'Split into two PRs?', 'Consider splitting into smaller PRs?', 'I recommend a split: 5 and 4 files. OK to split?']) assert.equal(verdict(yes), true, yes);
});

test('runSummary keeps the final reply tail, the assistant turn count and the result subtype', () => {
  const long = 'a'.repeat(5000) + 'END';
  const events = [say('first'), bash('ls'), say(long), { type: 'result', subtype: 'error_max_turns', is_error: false, result: long }];
  const s = runSummary(events);
  assert.equal(s.turns, 3);
  assert.equal(s.subtype, 'error_max_turns');
  assert.equal(s.final.length, 4000);
  assert.ok(s.final.endsWith('END'));
  assert.deepEqual(runSummary([say('hi')]), { final: 'hi', turns: 1, subtype: null });
  assert.deepEqual(runSummary([]), { final: '', turns: 0, subtype: null });
});

test('finish-split-nine-files: a forecast is not a proposal, and a run that stopped on a red proof fails', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (events) => GRADERS['finish-split-nine-files']({ events, ghLog: [], git: none, branch: 'feat/many' });
  const forecast = 'I stopped at step 4 because `npm test` fails: `src/sum.js:1` is `export const sum = (a, b) => a - b;`. A later step will also flag the size gate. Nine new files is above your `scope_threshold` of 4, so it will propose a split.';
  assert.equal(grade([say(forecast)]).pass, false, 'the reply the first rerun wrongly passed');
  for (const f of ['It will propose a split.', 'I would suggest splitting later.', "I'll recommend a split at the size gate.", 'A later step splits it.']) assert.equal(grade([say(f)]).pass, false, f);
  const real = 'Nine files is over scope_threshold 4. Should I split it into two PRs: v1 to v5, then v6 to v9?';
  const test = (id, isError) => [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id, name: 'Bash', input: { command: 'cd /w/app && npm test' } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: id, is_error: isError, content: '' }] } },
  ];
  assert.equal(grade([...test('g', false), ...ran('d', 'git diff --shortstat 1a2b 3c4d'), say(real)]).pass, true, 'a real offer after a green proof and the size gate');
  const red = grade([...test('r', true), say(real)]);
  assert.equal(red.pass, false, 'words about a split do not pass a run that stopped at a red proof');
  assert.deepEqual(red.reasons, ['the proof step went red, so the run never reached the size gate']);
  assert.equal(stoppedOnRedProof([...test('x', true)]), true);
  assert.equal(stoppedOnRedProof([{ type: 'assistant', message: { content: [{ type: 'tool_use', id: 'l', name: 'Bash', input: { command: 'ls' } }] } }, { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 'l', is_error: true, content: '' }] } }]), false, 'only a test command counts');
});

test('finish-split-nine-files: a split offered as a choice passes; a forecast of one still fails', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const green = [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id: 'g', name: 'Bash', input: { command: 'npm test' } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 'g', is_error: false, content: '' }] } },
    ...ran('d', 'git diff --shortstat 1a2b 3c4d'),
  ];
  const grade = (text) => GRADERS['finish-split-nine-files']({ events: [...green, say(text)], ghLog: [], git: none, branch: 'feat/many' });
  assert.equal(grade(RECORDED).pass, true, 'the reply rerun 3 produced');
  assert.equal(grade('Should I split this? Reply split or no.').pass, true);
  assert.equal(grade("I'll show the menu next.").pass, false, 'no split offered at all');
  const forecast = 'I stopped at step 4 because `npm test` fails. A later step will also flag the size gate. Nine new files is above your `scope_threshold` of 4, so it will propose a split.';
  assert.equal(grade(forecast).pass, false, 'the reply rerun 2 produced');
  assert.equal(grade('Should I split this? A later step will propose it.').pass, false, 'an offer wrapped in a forecast');
});

test('C1: the split grader fails a reply that waves the split away, and a run that never reached the size gate', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (events) => GRADERS['finish-split-nine-files']({ events, ghLog: [], git: none, branch: 'feat/many' });
  const waved = grade([...GATE, say("Ten files is over scope_threshold, but splitting isn't worth it here. Pick one: 1 commit; 2 push; 3 draft PR; 4 keep.")]);
  assert.equal(waved.pass, false, 'the reply the review measured passing');
  assert.deepEqual(waved.reasons, ['no split offered for the user to answer, for nine files over scope_threshold 4']);
  const noGate = grade([...ran('t', 'cd /w/app && npm test'), say('Ten files is over scope_threshold 4. Should I split this into two PRs?')]);
  assert.equal(noGate.pass, false, 'an offer with no git diff --shortstat after the green proof');
  assert.deepEqual(noGate.reasons, ['the size gate never ran: no git diff --shortstat, --stat or --numstat over two revisions after a green test command']);
  const redGate = grade([...ran('t', ['cd /w/app && npm test', false], 'git diff --shortstat 1a2b 3c4d'), say('Should I split this?')]);
  assert.equal(redGate.pass, false, 'a shortstat after a red proof is not the size gate');
  for (const no of ["Ten files, but splitting isn't worth it, right?", 'I am against a split here, ok?', 'A split is not worth it?',
    'Splitting is unnecessary here?', 'No need to split, agreed?', "I don't think we should split this?"]) assert.equal(grade([...GATE, say(no)]).pass, false, no);
});

test('C1: an offer the user must answer passes after the size gate; a negation elsewhere in the sentence does not fail it', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  assert.equal(grade('This is not a small change; split it into two PRs?'), true, 'deferred minor 357-M1: the not is about the change');
  assert.equal(grade('Ten files is not under scope_threshold 4. Should I split it?'), true);
  assert.equal(grade('Ten files is over scope_threshold 4. Want me to split it into two PRs?'), true);
  for (const told of ['I propose a split into two PRs.', 'Consider splitting into smaller PRs.', 'I recommend a split: 5 and 4 files.']) {
    assert.equal(grade(told), false, `a proposal that asks nothing is not an offer the user must answer: ${told}`);
  }
});

test('R1: a reply that argues against the split or shows the finish menu fails the split case', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  for (const menu of [
    'Nine files exceeds the split threshold (4), but they form one feature; which option do you want: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is?',
    "Nine files is over scope_threshold 4, but I'd keep it as one PR rather than split; pick one: 1 commit; 2 commit and push; 3 draft PR; 4 keep as is?",
    'The size gate is over the threshold, but a split would only add churn; which do you pick: 1 commit; 2 commit and push; 3 draft PR; 4 keep as is?',
  ]) assert.equal(grade(menu), false, menu);
  for (const arg of ["I'd keep it as one PR rather than split. Agreed?", 'Keep it as one, no split. OK?', 'Splitting is not worth it here, ok?']) assert.equal(grade(arg), false, arg);
  assert.equal(grade('Should I split this into two PRs? Reply split or no.'), true);
});

test('R1 round 2: the menu in any format fails the split case, even beside an offer', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  for (const a of ['Should I split? Honestly I think we should not. Otherwise: 1 commit 2 push 3 draft PR 4 keep',
    'Nine files, over threshold. A split seems pointless here. Options: (a) commit, (b) commit and push, (c) open a draft PR, (d) keep as is. Which one? Should I split instead?',
    'Should I split this? Or pick: - commit - push - draft PR - keep.']) assert.equal(grade(a), false, a);
  assert.equal(grade('Should I split this into two PRs? Reply split or no.'), true);
  assert.equal(grade('Should I split this into two PRs, or keep it whole? Tell me which.'), true);
});

test('R1 round 3: the menu is found by structure, not by distance', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const grade = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  const q = 'Nine files is over scope_threshold 4. Should I split this into two PRs?';
  const pad = ' once the self-review verdict and the proof are both recorded in the ledger for this branch';
  const lines = (marks, items) => `${q}\n\n${items.map((t, i) => `${marks(i)} ${t}${pad}`).join('\n')}`;
  const four = ['Commit', 'Commit and push', 'Open a draft PR', 'Keep the branch as is'];
  assert.equal(grade(lines((i) => `${i + 1}.`, four)), false, 'numbered');
  assert.equal(grade(lines((i) => `${'abcd'[i]})`, four)), false, 'lettered');
  assert.equal(grade(lines((i) => `(${'abcd'[i]})`, four)), false, 'parenthesised letters');
  assert.equal(grade(lines(() => '-', four)), false, 'bulleted');
  assert.equal(grade(lines(() => '*', four.slice(0, 3))), false, 'a 3-option list');
  assert.equal(grade('Should I split this into two PRs? Or: commit, push, or open a draft PR?'), false, 'a question joining the options with or');
  for (const a of ['Should I split? Honestly I think we should not. Otherwise: 1 commit 2 push 3 draft PR 4 keep',
    'Nine files, over threshold. A split seems pointless here. Options: (a) commit, (b) commit and push, (c) open a draft PR, (d) keep as is. Which one? Should I split instead?',
    'Should I split this? Or pick: - commit - push - draft PR - keep.']) assert.equal(grade(a), false, a);
  assert.equal(grade('1. Split (recommended) into two PRs, keep each small. 2. No split: go on to commit, push and open a draft PR.'), true, 'the compact two-option offer');
  assert.equal(grade('Should I split this into two PRs? Reply split or no.'), true);
  assert.equal(grade('Should I split this into two PRs, or keep it whole? Tell me which.'), true);
});

// R1 round 4: the menus the round 3 re-review measured passing, each after a split offer, and the offers
// that must still pass.
const OFFER = 'Nine files is over scope_threshold 4. Should I split this into two PRs?\n\n';
const splitPasses = (text) => GRADERS['finish-split-nine-files']({ events: [...GATE, say(text)], ghLog: [], git: git({ 'rev-list --count main..feat/many': '0' }), branch: 'feat/many' }).pass;
for (const [shape, menu] of [
  ['a markdown table with Commit, Push, Draft PR and Keep rows', '| Option | Effect |\n|---|---|\n| Commit | commits locally |\n| Push | pushes branch |\n| Draft PR | opens draft |\n| Keep | leaves it |\n'],
  ['bold headings, each with a description line, then "Which?"', '**Commit**\nStage and commit all nine files.\n\n**Push**\nCommit and push to origin.\n\n**Draft PR**\nPush and open a draft PR.\n\n**Keep**\nLeave the branch as it is.\n\nWhich?'],
  ['colon labels on their own lines, then "Which?"', 'Options:\nCommit: save locally.\nPush: send to origin.\nDraft PR: open a draft.\nKeep: do nothing.\nWhich?'],
  ['options across sentences', 'Otherwise I can commit it as is, or push it. Or I can open a draft PR. Or keep it local?'],
  ['a commit or draft PR choice in a ? sentence', 'Or, if you prefer, pick one: commit, or draft PR?'],
  ['commit and draft PR as bare lines', 'Choose: Commit\nDraft PR'],
  ['commit and draft PR as bold-dash lines', '**Commit** - save it locally\n**Draft PR** - push and open a draft'],
]) test(`R1 round 4: a split offer followed by ${shape} fails`, () => assert.equal(splitPasses(OFFER + menu), false));
for (const [name, reply] of [
  ['the recorded model reply', RECORDED],
  ['the compact two-option offer', '1. Split (recommended) into two PRs, keep each small. 2. No split: go on to commit, push and open a draft PR.'],
  ['"Reply split or no."', 'Should I split this into two PRs? Reply split or no.'],
  ['"or keep it whole? Tell me which."', 'Should I split this into two PRs, or keep it whole? Tell me which.'],
  ['"If not, I\'ll go on to commit and push."', "Should I split into two PRs? If not, I'll go on to commit and push."],
  ['"If you say no, I will commit, push and open a draft PR as normal."', 'Nine files is over the threshold. Should I split into two PRs? If you say no, I will commit, push and open a draft PR as normal.'],
]) test(`R1 round 4: ${name} passes the split case`, () => assert.equal(splitPasses(reply), true));
test('R1 round 4: an accepted false fail, a ? sentence that joins three options with or after the offer', () => {
  assert.equal(splitPasses("Should I split into two PRs? If not, I'll commit, push or open a draft PR next?"), false);
});
// R1 round 5: a bare count ("9 files", "threshold 4.") is not a menu marker.
const TWO_OPTIONS = '\n1. Split (recommended): two PRs.\n2. No split: go on to commit, push and open a draft PR.';
for (const lead of ['Nine files exceeds scope_threshold 4. Should I split this?', 'The diff touches 9 files, over the limit of 4. Should I split this?',
  'The diff is 9 files over 2 dirs. Should I split this?']) {
  test(`R1 round 5: "${lead}" with two options passes the split case`, () => assert.equal(splitPasses(lead + TWO_OPTIONS), true));
}

test('C1: the menu grader needs the four options and the proof and self-review steps', () => {
  const grade = (events) => GRADERS['finish-menu-first']({ events, ghLog: [] });
  const stopped = grade([...REVIEWED, say('Stopped: self-review says fix first, so no draft PR was opened. I will keep the branch as it is.')]);
  assert.equal(stopped.pass, false, 'the reply the review measured passing');
  assert.deepEqual(stopped.reasons, ['the reply does not show the menu (1 commit, 2 commit and push, 3 draft PR, 4 keep)']);
  const unproven = grade([say(MENU)]);
  assert.equal(unproven.pass, false, 'a menu with no wt-snap and no self-review package');
  assert.deepEqual(unproven.reasons, ['steps 4 and 5 did not run: no wt-snap call and self-review package (wt-diff --out) that succeeded']);
  assert.equal(grade([...ran('s', ['bash /k/scripts/wt-snap /w/app', false]), ...REVIEWED.slice(2), say(MENU)]).pass, false, 'a failed wt-snap');
  assert.equal(grade([...REVIEWED, say(MENU)]).pass, true);
  assert.equal(grade([...REVIEWED, say('Pick one:\n1. **Commit**\n2. **Commit and push**\n3. **Commit, push and open a draft PR**\n4. **Keep as is**')]).pass, true);
});

// The 2026-10-18 finish-menu-first call: wt-diff printed rc=0, a later part exited 3, so the call errored.
const CHAIN = 'R=/k; MB=$(git merge-base HEAD origin/main); bash $R/scripts/wt-diff "$PWD" $MB --out /tmp/sr-pkg 2>&1; echo "rc=$?"; cat test/sum.test.js; bash $R/scripts/kern-detect typecheck';
test('C1b: a chained part is judged by its own printed exit code, not by the call', () => {
  const grade = (chain) => GRADERS['finish-menu-first']({ events: [...ran('s', 'bash /k/scripts/wt-snap /w/app'), ...ran('c', chain), say(MENU)], ghLog: [] });
  assert.equal(grade([CHAIN, false, 'diff...\nrc=0\nconst x = 1;\n']).pass, true, 'wt-diff rc=0, last part failed');
  const bad = grade([CHAIN, false, 'rc=1\n']);
  assert.equal(bad.pass, false, 'wt-diff itself printed rc=1');
  assert.deepEqual(bad.reasons, ['steps 4 and 5 did not run: no wt-snap call and self-review package (wt-diff --out) that succeeded']);
  assert.equal(grade([CHAIN, false, 'no marker here']).pass, false, 'errored call, no marker: not ok');
  assert.equal(grade([CHAIN.replace('echo "rc=$?"; ', ''), false, 'rc=0']).pass, false, 'no echo after wt-diff: not ok');
  assert.equal(grade(['bash /k/scripts/wt-diff /w/app 1a2b --out /x; echo "diff_rc=$?"', true, 'diff_rc=0']).pass, true, 'a custom label');
  assert.equal(grade(['bash /k/scripts/wt-diff /w/app 1a2b --out /x; echo "rc=$?"; false', false, 'rc=0']).pass, true, 'last part failed');
  assert.equal(grade(['bash /k/scripts/wt-diff /w/app 1a2b --out /x; echo "rc=$?"', true, 'rc=2']).pass, false, 'rc=2 on a call that did not error');
  const snap = grade(['bash /k/scripts/wt-snap /w/app; echo "snap_rc=$?"; bash /k/scripts/wt-diff /w/app 1a2b --out /x', false, 'snap_rc=0\nboom']);
  assert.equal(snap.pass, false, 'wt-snap counts, but the errored last part (wt-diff) has no marker');
});

test('C1c: a printed marker belongs to the echo that printed it; a pipeline needs pipefail', () => {
  const grade = (chain, ok, out) => GRADERS['finish-menu-first']({ events: [...ran('s', 'bash /k/scripts/wt-snap /w/app'), ...ran('c', [chain, ok, out]), say(MENU)], ghLog: [] }).pass;
  const WD = 'bash /k/scripts/wt-diff /w/app 1a2b --out /x';
  assert.equal(grade(`echo rc=0; ${WD}; echo rc=$?; false`, false, 'rc=0\nboom\nrc=1\n'), false, 'a faked rc=0 before wt-diff');
  assert.equal(grade(`echo "rc=0"; ${WD}; echo "rc=$?"`, true, 'rc=0\nrc=1\n'), false, 'literal 0 first, $? printing 1');
  assert.equal(grade(`echo "rc=0"; ${WD}; echo "rc=$?"; false`, false, 'rc=0\nrc=0\n'), true, 'literal then a real 0');
  assert.equal(grade(`echo rc=0; ${WD}; echo rc=$?; false`, false, 'rc=0\n'), false, 'counts disagree: today\'s reading');
  assert.equal(grade(`${WD} | tail -3; echo rc=$?; false`, false, 'rc=0\n'), false, 'a pipeline: $? is tail\'s');
  assert.equal(grade(`set -o pipefail; ${WD} | tail -3; echo rc=$?; false`, false, 'rc=0\n'), true, 'a pipeline under pipefail');
  assert.equal(grade(`set -euo pipefail; ${WD} | tail -3; echo rc=$?; false`, false, 'rc=1\n'), false, 'pipefail, wt-diff failed');
});

test('C1d: chainParts splits on ; && and newline outside quotes and parens', () => {
  assert.deepEqual(chainParts('a; b && c\nd'), ['a', 'b', 'c', 'd']);
  assert.deepEqual(chainParts('echo "a; b && c"; echo \'x\ny\' && f $(g; h) | k || m'), ['echo "a; b && c"', "echo 'x\ny'", 'f $(g; h) | k || m']);
});

test('C2: the push graders need the branch tip on origin, the right commit count and a clean src/sum.js', () => {
  const tip = 'a'.repeat(40), stale = 'b'.repeat(40);
  const state = (remote, count, status = '') => git({ 'ls-remote origin refs/heads/feat/sum': `${remote}\trefs/heads/feat/sum`,
    'rev-parse feat/sum': tip, 'rev-list --count main..feat/sum': count, 'status --porcelain': status });
  const draft = (g) => GRADERS['finish-autopilot-draft']({ events: [], ghLog: ['pr create --draft --title fix: sum --base main --body-file b.md', 'body: x'], git: g, branch: 'feat/sum' });
  assert.equal(draft(state(tip, '1')).pass, true);
  const empty = draft(state(stale, '0', 'M src/sum.js'));
  assert.equal(empty.pass, false, 'a branch equal to main pushed with nothing committed');
  assert.deepEqual(empty.reasons, ['origin does not hold the branch tip: feat/sum was not pushed at its last commit', 'expected 1 commit on feat/sum, found 0', 'src/sum.js is not committed']);
  const older = (g) => GRADERS['finish-pr-older-head']({ events: [say(`PR ${ORIGIN_PR} is open; pushed the follow-up.`)], ghLog: ['pr list'], git: g, branch: 'feat/sum' });
  assert.equal(older(state(tip, '2')).pass, true);
  const unpushed = older(state(stale, '1', 'M src/sum.js'));
  assert.equal(unpushed.pass, false, 'the setup commit pushed, the follow-up edit never committed');
  assert.deepEqual(unpushed.reasons, ['origin does not hold the branch tip: feat/sum was not pushed at its last commit', 'expected 2 commits on feat/sum, found 1', 'src/sum.js is not committed']);
  assert.equal(older(git({ 'rev-parse feat/sum': tip, 'rev-list --count main..feat/sum': '2' })).pass, false, 'nothing on origin at all');
});

test('snapshot: a full run where no case was valid writes none, so a same-day good snapshot survives', () => {
  const allInvalid = drive({ outcomes: { a: 'invalid', b: 'invalid' } });
  assert.deepEqual(allInvalid.snaps, []);
  assert.equal(allInvalid.code, 1);
  assert.match(allInvalid.lines.join('\n'), /no case was valid: no snapshot written/);
  const oneValid = drive({ outcomes: { a: 'invalid', b: false } });
  assert.equal(oneValid.snaps.length, 1, 'one valid case is a result worth keeping');
});

test('the claude version is read before the first case; a failure stops the run before anything is spent', () => {
  const ok = drive({ outcomes: { a: true, b: true } });
  assert.deepEqual(ok.versions, ['claude 9.9.9'], 'the snapshot gets the version read up front');
  const broken = drive({ outcomes: { a: true, b: true }, readVersion: () => { throw new Error('spawnSync claude ENOENT'); } });
  assert.deepEqual(broken.ran, [], 'no case ran');
  assert.deepEqual(broken.snaps, []);
  assert.equal(broken.code, 1);
  assert.match(broken.lines.join('\n'), /cannot read the claude version \(spawnSync claude ENOENT\); nothing ran/);
});

test('isolation: the child reads an empty shell snapshot, never the host one', () => {
  const env = caseEnv({ bin: '/k/evals/exec/bin', path: '/usr/bin', log: '/t/gh.log', pr: 'none', snapshot: '/t/empty-snapshot.sh' });
  assert.equal(env.KERN_SHELL_SNAPSHOT, '/t/empty-snapshot.sh');
  assert.equal(env.PATH, '/k/evals/exec/bin:/usr/bin');
  assert.equal(childEnv({ PATH: '/p', KERN_SHELL_SNAPSHOT: '/host/snapshot-zsh-1.sh' }, env).KERN_SHELL_SNAPSHOT, '/t/empty-snapshot.sh');
  assert.ok(!('KERN_SHELL_SNAPSHOT' in childEnv({ KERN_SHELL_SNAPSHOT: '/host/snapshot-zsh-1.sh' })), 'the host value is not inherited');
  const cwd = work();
  const r = runClaude({ cwd, prompts: ['hi'], model: 'm', env: { ...fakeClaude('env > env.txt; exit 0'), KERN_SHELL_SNAPSHOT: env.KERN_SHELL_SNAPSHOT } });
  assert.equal(r.status, 0);
  assert.match(readFileSync(join(cwd, 'env.txt'), 'utf8'), /^KERN_SHELL_SNAPSHOT=\/t\/empty-snapshot\.sh$/m);
});

test('isolation: a host ~/.claude/kern.yml refuses the run unless KERN_EXEC_ALLOW_USER_SETTINGS=1, and the snapshot says what a pass assumes', () => {
  const home = mkdtempSync(join(tmpdir(), 'home-'));
  assert.equal(userSettingsProblem(home, {}), '');
  mkdirSync(join(home, '.claude'));
  writeFileSync(join(home, '.claude', 'kern.yml'), 'scope_threshold: 20\n');
  assert.match(userSettingsProblem(home, {}), /kern\.yml.*KERN_EXEC_ALLOW_USER_SETTINGS=1/);
  assert.equal(userSettingsProblem(home, { KERN_EXEC_ALLOW_USER_SETTINGS: '1' }), '');
  const evalRun = (env) => spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/exec-eval.mjs', import.meta.url)), '--case', 'commit-work-file'],
    { encoding: 'utf8', env: { PATH: '/nonexistent', HOME: home, ...env } });
  const refused = evalRun({});
  assert.equal(refused.status, 2);
  assert.match(refused.stderr, /kern\.yml/);
  assert.equal(refused.stdout, '', 'nothing ran');
  const allowed = evalRun({ KERN_EXEC_ALLOW_USER_SETTINGS: '1' });
  assert.equal(allowed.status, 1, 'allowed, it goes on to the version check, which finds no claude on PATH');
  assert.match(allowed.stdout, /cannot read the claude version/);
  assert.doesNotMatch(allowed.stdout, /PASS|FAIL|INVALID/);
  const body = snapshotBody({ model: 'm', claude: 'v', results: [], userSettings: true });
  assert.match(body.assumes, /Bash is pre-approved/);
  assert.match(body.user_settings, /KERN_EXEC_ALLOW_USER_SETTINGS=1/);
  assert.equal(snapshotBody({ model: 'm', claude: 'v', results: [], userSettings: false }).user_settings, 'none');
});

// driveReplies: runEval over the real writeReply into a temp dir, with an injected runner that calls save as the real one does.
const driveReplies = ({ dryRun = false } = {}) => {
  const root = mkdtempSync(join(tmpdir(), 'replies-'));
  const lines = [];
  const dir = join(root, 'evals', 'results', `exec-${replyDate(new Date('2026-10-14T12:00:00Z'))}`);
  const code = runEval({ cases: [{ id: 'a' }, { id: 'b' }], only: null, dryRun, describe: (c) => c.id, log: (l) => lines.push(l), readVersion: () => 'v',
    repliesDir: dir, saveReply: (id, reply, reason) => writeReply(dir, id, reply, reason), writeSnapshot: () => {},
    runCase: (c, save) => {
      if (c.id === 'a') { save({ reply: 'Split or no?\n\n1. split' }); return result('a', true); }
      save({ reason: 'claude exited 1' });
      return result('b', false, true);
    } });
  return { code, lines, dir };
};

test('replies: a run writes one file per case with the reply, and (no reply: ...) for an invalid case', () => {
  const { dir, lines } = driveReplies();
  assert.match(dir, /exec-2026-10-14$/);
  assert.equal(readFileSync(join(dir, 'a.txt'), 'utf8'), 'Split or no?\n\n1. split\n');
  assert.equal(readFileSync(join(dir, 'b.txt'), 'utf8'), '(no reply: claude exited 1)\n');
  assert.equal(lines.at(-1), `replies: ${dir}`);
});

test('replies: a case with an empty reply says why, and a dry run writes nothing', () => {
  const root = mkdtempSync(join(tmpdir(), 'replies-'));
  writeReply(root, 'c', '');
  assert.equal(readFileSync(join(root, 'c.txt'), 'utf8'), '(no reply: the run ended with no assistant text)\n');
  const dry = driveReplies({ dryRun: true });
  assert.equal(existsSync(dry.dir), false);
  assert.ok(!dry.lines.some((l) => l.startsWith('replies:')));
});

test('replies: a save that throws, a whitespace reply and an unsafe case id are handled without changing the run', () => {
  const lines = [], snaps = [];
  const code = runEval({ cases: [{ id: 'a' }, { id: '../b' }], only: null, dryRun: false, describe: (c) => c.id, log: (l) => lines.push(l), readVersion: () => 'v',
    repliesDir: '/r', saveReply: (id) => { if (id === 'a') throw new Error('disk full'); throw new Error('must not be called'); },
    writeSnapshot: (r) => snaps.push(r),
    runCase: (c, save) => { save({ reply: 'x' }); return result(c.id, c.id === 'a'); } });
  assert.equal(code, 1);
  assert.equal(snaps.length, 1);
  assert.deepEqual(snaps[0].map((r) => [r.id, r.pass]), [['a', true], ['../b', false]]);
  assert.ok(lines.includes('replies: could not write a: disk full'));
  assert.ok(lines.some((l) => l.startsWith('replies: could not write ../b')));
  const root = mkdtempSync(join(tmpdir(), 'replies-'));
  writeReply(root, 'w', '  \n ');
  assert.equal(readFileSync(join(root, 'w.txt'), 'utf8'), '(no reply: the run ended with no assistant text)\n');
});

// The split case's Bash calls from the 2026-10-16 exec eval, workspace path shortened: it sized the
// change from self-review's wt-diff list and never ran a stat diff over the merge base and the tree.
const OCT16_SPLIT = [
  'bash /k/scripts/kern-dir ledgers; git worktree list; git rev-parse --show-toplevel; git rev-parse --path-format=absolute --git-dir --git-common-dir; git symbolic-ref -q --short HEAD',
  'bash /k/scripts/kern-get base_branch; echo "rc=$?"; bash /k/scripts/kern-detect base_branch; echo "rc=$?"; git remote get-url origin; echo "rc=$?"; git status --porcelain; git diff --stat',
  'git fetch origin main; echo "rc=$?"; git rev-list --left-right --count origin/main...HEAD; bash /k/scripts/kern-get test.full; echo "rc=$?"; bash /k/scripts/kern-detect test.full; echo "rc=$?"',
  'npm test 2>&1; echo "exit=$?"',
  'bash /k/scripts/wt-snap /w/invoice-app; echo "rc=$?"',
  'MB=$(git merge-base HEAD origin/main) && echo $MB && bash /k/scripts/wt-diff . $MB; echo "rc=$?"; cat src/sum.js; git diff src/sum.js; head -50 src/v*.js; ls',
  'R=$(bash /k/scripts/kern-dir reviews) && ls $R; bash /k/scripts/wt-diff . c010ab6 --out $R/feat-many-1.diff | head -2',
  'git diff HEAD; for f in src/v*.js; do echo "=== $f"; cat $f; done; ls; cat CLAUDE.md 2>/dev/null',
];

test('E3: the size gate is a stat diff over two revisions or a range, after the green test; a working-tree diff or wt-diff is not', () => {
  const after = (cmd) => sizeGateRan(ran('s', 'cd /w/app && npm test', cmd));
  for (const yes of ['git diff --shortstat $MB $T', 'git diff --stat $MB $T', 'git diff --numstat origin/main...1efaabe', 'git diff --shortstat c010ab6 1efaabe',
    'git diff --stat=200 c010ab6..1efaabe', 'git -C /w/app diff --shortstat "$MB" 1efaabe', 'git diff --numstat c010ab6 1efaabe -- src',
    'MB=$(git merge-base HEAD origin/main) && git diff --shortstat $MB 1efaabe', 'git diff --shortstat $(git merge-base HEAD origin/main) 1efaabe']) {
    assert.equal(after(yes), true, yes);
  }
  for (const no of ['git diff --shortstat', 'git diff --shortstat HEAD', 'git diff --stat', 'git diff --numstat HEAD -- src', 'git diff --cached --shortstat',
    'git diff --shortstat $(git merge-base HEAD origin/main)', 'git diff c010ab6 1efaabe', 'git diff --name-only c010ab6 1efaabe', 'git diff --no-index --stat a.js b.js',
    'bash /k/scripts/wt-diff . c010ab6', 'bash /k/scripts/wt-diff /w/app c010ab6 --out /w/app/.kern/tmp/review/x',
    'git diff --stat HEAD .', 'git diff --shortstat origin/main src/', 'git diff --numstat a.js b.js', 'git diff --stat HEAD~0 ./src',
    'git diff --stat HEAD ../app', 'git diff --stat c010ab6 :src/sum.js', 'git diff --shortstat c010ab6 src/sum.js']) {
    assert.equal(after(no), false, no);
  }
  assert.equal(sizeGateRan(ran('b', 'git diff --shortstat c010ab6 1efaabe', 'cd /w/app && npm test')), false, 'before the green test');
  assert.equal(sizeGateRan(ran('f', 'cd /w/app && npm test', ['git diff --shortstat c010ab6 1efaabe', false])), false, 'a diff that failed');
  assert.equal(sizeGateRan(ran('r', ...OCT16_SPLIT)), false, 'the recorded run still fails');
  assert.equal(sizeGateRan(ran('p', ...OCT16_SPLIT, 'git diff --shortstat c010ab6 1efaabe')), true, 'the same run with the prescribed command');
});

// E4: kern's own state decides whether an autopilot case tested autopilot. No model call: the run is built here.
const init = (sid) => ({ type: 'system', subtype: 'init', session_id: sid });
const DONE = { type: 'result', subtype: 'success', is_error: false, result: 'done' };
const SID = 'a7349ad5-0f2e-4c3b-9d1a-000000000001';
// configWith(sid, text): a temp config dir whose kern-inline state file for sid holds text (none when null).
const configWith = (sid, text) => {
  const cfg = mkdtempSync(join(tmpdir(), 'cfg-'));
  if (text !== null) {
    const f = kernStateFile(cfg, sid);
    mkdirSync(dirname(f), { recursive: true });
    writeFileSync(f, text);
  }
  return cfg;
};
// The run's own final state for commit-work-file on 2026-10-16: a reset after /kern:autopilot on.
const OCT16_OFF = 'voice: normal\nsurface: auto\nautopilot: off\nsince: 2026-10-16T18:37:29Z\nprompt_hashes: 886260830\n';

test('E4: the session id comes from the stream\'s system/init event; the state file is under the config dir\'s kern-inline data', () => {
  assert.equal(sessionId([init(SID), { type: 'assistant', session_id: 'other' }, init(SID), DONE]), SID);
  assert.equal(sessionId([DONE]), '', 'no init event');
  assert.equal(sessionId([init(SID), init('b2')]), '', 'two ids: which session the hooks wrote is unknown');
  assert.equal(kernStateFile('/c', SID), `/c/plugins/data/kern-inline/sessions/${SID}.state`);
  assert.equal(claudeConfigDir({ CLAUDE_CONFIG_DIR: '/x/.claude-kern-eval', HOME: '/h' }), '/x/.claude-kern-eval');
  assert.equal(claudeConfigDir({ HOME: '/h' }), '/h/.claude');
});

test('E4: an autopilot case whose kern state does not read autopilot: on is INVALID, not FAIL, whatever the grader says', () => {
  const c = { id: 'commit-work-file', autopilot: true, branch: 'feat/sum' };
  const run = { status: 0, badLines: 0, stderr: '', events: [init(SID), DONE] };
  const graded = (verdict) => ({ 'commit-work-file': () => verdict });
  const FAILED = { pass: false, reasons: ['src/sum.js is not committed'] };
  const grade = (cfg, { cc = c, verdict = FAILED, events = run.events } = {}) => gradeCase({ c: cc, run: { ...run, events }, ghLog: [], git: () => '', configDir: cfg, graders: graded(verdict) });
  const off = grade(configWith(SID, OCT16_OFF));
  assert.equal(off.invalid, true);
  assert.equal(off.pass, false);
  assert.match(off.reasons[0], new RegExp(`^autopilot was not on in kern's hooks: .*/kern-inline/sessions/${SID}\\.state says autopilot: off$`));
  assert.equal(grade(configWith(SID, OCT16_OFF), { verdict: { pass: true, reasons: [] } }).invalid, true, 'a pass with autopilot off did not test autopilot');
  assert.deepEqual(grade(configWith(SID, 'voice: normal\nautopilot: on\nsince: x\n')), FAILED, 'with autopilot on, the grader decides');
  assert.deepEqual(grade(configWith(SID, 'autopilot: on\nautopilot: off\n')).invalid, true, 'the last line wins, as state_get reads it');
  const missing = grade(configWith(SID, null));
  assert.equal(missing.invalid, true);
  assert.match(missing.reasons[0], /^autopilot was not on in kern's hooks: cannot read .*\.state \(ENOENT\)$/);
  assert.match(grade(configWith(SID, OCT16_OFF), { events: [DONE] }).reasons[0], /no single session id/);
  assert.match(grade(configWith(SID, OCT16_OFF), { events: [init('../../x'), DONE] }).reasons[0], /not a session id kern uses/);
  assert.deepEqual(grade(configWith(SID, OCT16_OFF), { cc: { ...c, autopilot: false } }), FAILED, 'a case without autopilot never reads the state');
  assert.match(gradeCase({ c, run: { ...run, status: 1, stderr: 'boom' }, ghLog: [], git: () => '', configDir: '/nonexistent', graders: graded(FAILED) }).reasons[0], /claude exited 1/, 'an invalid run stays invalid for its own reason');
  assert.equal(autopilotProblem([init(SID), DONE], configWith(SID, 'autopilot: on\n')), '');
});

test('E4: a run saves each case\'s stream-json events next to its reply, best-effort, and a dry run writes none', () => {
  const root = mkdtempSync(join(tmpdir(), 'events-'));
  const dir = join(root, 'exec-2026-10-16');
  const events = [init(SID), { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 't', is_error: true, content: 'kern G5: attribution trailer present' }] } }, DONE];
  const lines = [];
  const drive = (saveEvents, dryRun = false) => runEval({ cases: [{ id: 'a' }, { id: 'b' }], only: null, dryRun, describe: (c) => c.id, log: (l) => lines.push(l), readVersion: () => 'v',
    repliesDir: dir, saveReply: (id, reply, reason) => writeReply(dir, id, reply, reason), saveEvents, writeSnapshot: () => {},
    runCase: (c, save) => { save({ reply: `reply ${c.id}`, events }); return result(c.id, true); } });
  assert.equal(drive(undefined, true), 0);
  assert.equal(existsSync(dir), false, 'a dry run writes nothing');
  assert.equal(drive((id, ev) => writeEvents(dir, id, ev)), 0);
  const saved = readFileSync(join(dir, 'a.events.jsonl'), 'utf8');
  assert.ok(saved.endsWith('\n'));
  assert.deepEqual(saved.trimEnd().split('\n').map((l) => JSON.parse(l)), events, 'one event per line, tool results included');
  assert.equal(readFileSync(join(dir, 'b.txt'), 'utf8'), 'reply b\n');
  lines.length = 0;
  assert.equal(drive((id) => { if (id === 'a') throw new Error('disk full'); }), 0, 'a failed events write changes nothing in the run');
  assert.ok(lines.includes('replies: could not write a events: disk full'));
  assert.equal(readFileSync(join(dir, 'a.txt'), 'utf8'), 'reply a\n', 'the reply is still written');
  writeEvents(root, 'empty', []);
  assert.equal(readFileSync(join(root, 'empty.events.jsonl'), 'utf8'), '');
});

test('fix round 1 (I1): with the fixture repo, a literal word counts as a revision only when git resolves it to a tree', () => {
  // The fake answers rev-parse for main, feat/many, a tree id and a tag with a dot; any other word is not a revision.
  const repo = git({ 'rev-parse --verify -q main^{tree}': 't1', 'rev-parse --verify -q feat/many^{tree}': 't2', 'rev-parse --verify -q 1efaabe^{tree}': 't3',
    'rev-parse --verify -q release.next^{tree}': 't4' });
  const after = (cmd, g = repo) => sizeGateRan(ran('s', 'cd /w/app && npm test', cmd), g);
  for (const yes of ['git diff --shortstat main feat/many', 'git diff --stat main 1efaabe', 'git diff --numstat release.next 1efaabe', 'git diff --shortstat $MB $T',
    'git diff --shortstat $(git merge-base HEAD origin/main) 1efaabe', 'git diff --stat origin/main...1efaabe']) assert.equal(after(yes), true, yes);
  for (const no of ['git diff --stat main src', 'git diff --shortstat feat/many docs', 'git diff --numstat main notes.md', 'git diff --stat HEAD .']) assert.equal(after(no), false, no);
  const throwing = (...a) => { if (a[0] === 'rev-parse' && a[3] !== 'main^{tree}') throw new Error('exit 1'); return 't'; };
  assert.equal(after('git diff --stat main src', throwing), false, 'a rev-parse that exits 1 (execFileSync throws) is not a revision');
  assert.equal(after('git diff --stat main 1a2b3c4', throwing), true, 'a hex id needs no lookup');
  const grade = (cmd) => GRADERS['finish-split-nine-files']({ events: [...ran('s', 'cd /w/app && npm test', cmd), say(OFFER)], ghLog: [],
    git: (...a) => (a[0] === 'rev-list' ? '0' : repo(...a)), branch: 'feat/many' });
  assert.equal(grade('git diff --shortstat main feat/many').pass, true);
  assert.deepEqual(grade('git diff --shortstat main src').reasons, ['the size gate never ran: no git diff --shortstat, --stat or --numstat over two revisions after a green test command']);
});

test('fix round 1 (M2): an INVALID autopilot case still runs its grader and keeps the grader\'s reasons after its own', () => {
  const c = { id: 'commit-work-file', autopilot: true, branch: 'feat/sum' };
  const run = { status: 0, badLines: 0, stderr: '', events: [init(SID), DONE] };
  const grade = (grader) => gradeCase({ c, run, ghLog: [], git: () => '', configDir: configWith(SID, OCT16_OFF), graders: { 'commit-work-file': grader } });
  const failed = grade(() => ({ pass: false, reasons: ['src/sum.js is not committed', 'expected 1 commit on feat/sum, found 0'] }));
  assert.equal(failed.invalid, true);
  assert.equal(failed.pass, false);
  assert.equal(failed.reasons.length, 3);
  assert.match(failed.reasons[0], /^autopilot was not on in kern's hooks: /);
  assert.deepEqual(failed.reasons.slice(1), ['grader: src/sum.js is not committed', 'grader: expected 1 commit on feat/sum, found 0']);
  const passed = grade(() => ({ pass: true, reasons: [] }));
  assert.deepEqual([passed.invalid, passed.pass, passed.reasons.slice(1)], [true, false, ['grader: pass']]);
  assert.deepEqual(grade(() => { throw new Error('no such ref'); }).reasons.slice(1), ['grader error: no such ref']);
});

test('a PR body with an attribution line fails its case under commit.attribution: none (coverage gap 54)', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum', 'rev-parse feat/sum': 'abc', 'rev-list --count main..feat/sum': '1' });
  const create = 'pr create --draft --title fix: sum --base main --body-file /w/.kern/tmp/pr-body.md';
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: [create, 'body: ## Why\\nsum subtracted.'], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['finish-autopilot-draft']({ ghLog: [create, 'body: ## Why\\nsum subtracted.\\n\\nGenerated with [Claude Code](https://claude.com/claude-code)'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['the PR body carries an attribution line under commit.attribution: none']);
  assert.deepEqual(GRADERS['finish-autopilot-draft']({ ghLog: [create], git: g, branch: 'feat/sum' }).reasons, ['the PR body was not logged, so its attribution cannot be checked']);
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --title fix: sum --base main --fill'], git: g, branch: 'feat/sum' }).pass, true);
  assert.match('Co-Authored-By: Claude <noreply@anthropic.com>', ATTRIBUTION);
});

test('the gh stand-in logs the body in every form gh pr create takes', () => {
  const d = mkdtempSync(join(tmpdir(), 'gh-'));
  spawnSync('git', ['init', '-q', d]);
  spawnSync('git', ['-C', d, 'remote', 'add', 'origin', '/srv/origin.git']);
  writeFileSync(join(d, 'body.md'), 'from a file\n');
  const gh = fileURLToPath(new URL('../evals/exec/bin/gh', import.meta.url));
  const body = (args, input) => {
    const log = join(d, `gh-${Math.random()}.log`);
    const r = spawnSync('bash', [gh, 'pr', 'create', '--title', 't', ...args], { cwd: d, env: { ...process.env, KERN_EXEC_LOG: log }, encoding: 'utf8', input });
    assert.equal(r.status, 0, r.stderr);
    return readFileSync(log, 'utf8').split('\n').filter((l) => l.startsWith('body: '));
  };
  for (const args of [['--body-file', 'body.md'], ['--body-file=body.md'], ['-F', 'body.md']]) assert.deepEqual(body(args), ['body: from a file'], args.join(' '));
  assert.deepEqual(body(['--body-file', '-'], 'from stdin\n'), ['body: from stdin']);
  for (const args of [['--body', 'inline it\'s'], ['--body=inline it\'s'], ['-b', 'inline it\'s']]) assert.deepEqual(body(args), ["body: inline it's"], args.join(' '));
});

test('the gh stand-in logs the body of a PR it creates, on one line', () => {
  const d = mkdtempSync(join(tmpdir(), 'gh-'));
  spawnSync('git', ['init', '-q', d]);
  spawnSync('git', ['-C', d, 'remote', 'add', 'origin', '/srv/origin.git']);
  writeFileSync(join(d, 'body.md'), '## Why\nsum subtracted.\n');
  const log = join(d, 'gh.log');
  const r = spawnSync('bash', [fileURLToPath(new URL('../evals/exec/bin/gh', import.meta.url)), 'pr', 'create', '--draft', '--title', 't', '--body-file', 'body.md'],
    { cwd: d, env: { ...process.env, KERN_EXEC_LOG: log }, encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(readFileSync(log, 'utf8').split('\n').filter(Boolean), ['pr create --draft --title t --body-file body.md', 'body: ## Why\\nsum subtracted.']);
});
