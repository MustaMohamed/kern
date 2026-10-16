// tests/exec-eval.test.mjs: the exec-eval graders on recorded runs, the runner's failure handling and the
// dry run. No model call: the runner tests put a stand-in `claude` first on PATH.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { GRADERS, stoppedOnRedProof, gitCalls, ghCalls, shellSegments, stubMissed } from '../scripts/lib/exec-grade.mjs';
import { ISOLATION, PERMISSIONS, ClaudeRunError, childEnv, runClaude, runProblem, runSummary } from '../scripts/lib/claude-run.mjs';
import { UsageError, caseEnv, exitCode, parseArgs, runEval, snapshotBody, userSettingsProblem } from '../scripts/lib/exec-run.mjs';

const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const bash = (command) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command } }] } });
const git = (answers) => (...a) => answers[a.join(' ')] ?? '';
const DECOYS = 'M README.md\n?? notes.txt';
const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js', 'status --porcelain': DECOYS });
const ORIGIN_PR = 'file:///w/app.origin/pull/7';
// ran(prefix, ...commands): Bash calls with their results, in order; a command written as ['cmd', false]
// failed.
const ran = (prefix, ...cmds) => cmds.flatMap((c, i) => {
  const [command, ok] = Array.isArray(c) ? c : [c, true];
  return [
    { type: 'assistant', message: { content: [{ type: 'tool_use', id: `${prefix}${i}`, name: 'Bash', input: { command } }] } },
    { type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: `${prefix}${i}`, is_error: !ok, content: '' }] } },
  ];
});
// GATE: a green proof, then finish-branch step 6's size gate. REVIEWED: steps 4 and 5 (wt-snap, a self-review package).
const GATE = ran('g', 'cd /w/app && npm test', 'git merge-base HEAD origin/main', 'git diff --shortstat 1a2b 3c4d');
const REVIEWED = ran('v', 'bash /k/scripts/wt-snap /w/app', 'bash /k/scripts/wt-diff /w/app 1a2b --out /w/app/.kern/tmp/review/feat-sum');
const MENU = 'Pick one: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.';

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
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --title t --base main', 'pr create --title t --base main'], git: g, branch: 'feat/sum' });
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
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: ['pr list --head feat/sum --state all --json number,state,headRefOid,url', 'pr create --draft --title fix: sum --base main --body-file /w/.kern/tmp/pr-body.md'], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --base main --body-file b.md', 'pr ready 8'], git: g, branch: 'feat/sum' });
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
  const offered = [
    'Self-review verdict is `ready`, but the size gate stops the run, so nothing is committed or pushed yet.',
    '**Size gate** - The diff is 10 files, +10/-1, against `scope_threshold` 4.',
    '**Decision for you:** should I split this?',
    '1. **Split (recommended):** commit and push the `sum.js` fix on its own, and keep `v1` to `v9` out of the PR.',
    '2. **No split:** go on with all 10 files, then pick from the menu (commit, push, or draft PR).',
    "Reply `split` or `no`. If `no`, I'll show the menu.",
  ].join('\n\n');
  assert.equal(grade(offered).pass, true, 'the reply rerun 3 produced');
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
  assert.deepEqual(noGate.reasons, ['the size gate never ran: no git diff --shortstat after a green test command']);
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

test('C2: the push graders need the branch tip on origin, the right commit count and a clean src/sum.js', () => {
  const tip = 'a'.repeat(40), stale = 'b'.repeat(40);
  const state = (remote, count, status = '') => git({ 'ls-remote origin refs/heads/feat/sum': `${remote}\trefs/heads/feat/sum`,
    'rev-parse feat/sum': tip, 'rev-list --count main..feat/sum': count, 'status --porcelain': status });
  const draft = (g) => GRADERS['finish-autopilot-draft']({ events: [], ghLog: ['pr create --draft --title fix: sum --base main --body-file b.md'], git: g, branch: 'feat/sum' });
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
