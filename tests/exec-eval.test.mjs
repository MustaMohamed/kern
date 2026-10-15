// tests/exec-eval.test.mjs: the exec-eval graders on recorded runs, the runner's failure handling and the
// dry run. No model call: the runner tests put a stand-in `claude` first on PATH.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { GRADERS, gitCalls, ghCalls, shellSegments, stubMissed } from '../scripts/lib/exec-grade.mjs';
import { ISOLATION, PERMISSIONS, ClaudeRunError, childEnv, runClaude, runProblem, runSummary } from '../scripts/lib/claude-run.mjs';
import { UsageError, exitCode, parseArgs, runEval } from '../scripts/lib/exec-run.mjs';

const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const bash = (command) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command } }] } });
const git = (answers) => (...a) => answers[a.join(' ')] ?? '';
const DECOYS = 'M README.md\n?? notes.txt';
const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js', 'status --porcelain': DECOYS });
const ORIGIN_PR = 'file:///w/app.origin/pull/7';

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

test('finish-branch: every gh pr create must carry --draft and --title; the split needs a proposal', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc' });
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --title t --base main', 'pr create --title t --base main'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['gh pr create did not carry --draft and --title']);
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: [], git: g, branch: 'feat/sum' }).pass, false, 'no create at all');
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const verdict = (text) => GRADERS['finish-split-nine-files']({ events: [say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  assert.equal(verdict('Nine files is over scope_threshold 4. I propose a split into two PRs.'), true);
  assert.equal(verdict('I will not split this; going ahead.'), false);
  assert.equal(verdict('Nine files, nothing else to say.'), false);
});

test('gitCalls drops -C and -c, reads past && and ;, and ignores other commands', () => {
  assert.deepEqual(gitCalls(['cd /w && git -C /w -c core.x=1 push -u origin feat/sum; echo git push', 'ls git push']), [{ sub: 'push', args: ['-u', 'origin', 'feat/sum'] }]);
  assert.deepEqual(shellSegments("git -C '/a b' commit -F m"), [['git', '-C', '/a b', 'commit', '-F', 'm']]);
});

test('finish-branch: the menu comes before any push or PR', () => {
  const menu = say('Pick one: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.');
  assert.equal(GRADERS['finish-menu-first']({ events: [menu], ghLog: [] }).pass, true);
  assert.equal(GRADERS['finish-menu-first']({ events: [bash('git push -u origin feat/sum'), menu], ghLog: [] }).pass, false);
  assert.equal(GRADERS['finish-menu-first']({ events: [bash('git -C /w/app push -u origin feat/sum'), menu], ghLog: [] }).pass, false, 'a -C push counts');
  assert.equal(GRADERS['finish-menu-first']({ events: [bash('cd /w/app && git push --force-with-lease origin feat/sum'), menu], ghLog: [] }).pass, false);
});

test('finish-branch: nine files stop at a split proposal, with a -C push counted too', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const events = [say('Nine files is over scope_threshold 4: I propose a split.')];
  assert.equal(GRADERS['finish-split-nine-files']({ events, ghLog: [], git: none, branch: 'feat/many' }).pass, true);
  const r = GRADERS['finish-split-nine-files']({ events: [bash('git -C /w push -u origin feat/many'), ...events], ghLog: [], git: none, branch: 'feat/many' });
  assert.deepEqual(r.reasons, ['pushed or opened a PR']);
});

test('finish-branch under autopilot: the draft PR carries --draft and --title, and ready never runs', () => {
  const g = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum' });
  assert.equal(GRADERS['finish-autopilot-draft']({ ghLog: ['pr list --head feat/sum --state all --json number,state,headRefOid,url', 'pr create --draft --title fix: sum --base main --body-file /w/.kern/tmp/pr-body.md'], git: g, branch: 'feat/sum' }).pass, true);
  const r = GRADERS['finish-autopilot-draft']({ ghLog: ['pr create --draft --base main --body-file b.md', 'pr ready 8'], git: g, branch: 'feat/sum' });
  assert.deepEqual(r.reasons, ['gh pr create did not carry --draft and --title', 'gh pr ready ran']);
});

test('finish-branch: a PR at this head stops; one at an older head gets the push', () => {
  const none = git({});
  const pushed = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum' });
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
const drive = ({ only = null, outcomes }) => {
  const lines = [], snaps = [], ran = [];
  const cases = [{ id: 'a' }, { id: 'b' }].filter((c) => !only || c.id === only);
  const code = runEval({ cases, only, dryRun: false, describe: (c) => c.id, log: (l) => lines.push(l),
    runCase: (c) => { ran.push(c.id); return result(c.id, outcomes[c.id]); }, writeSnapshot: (r) => snaps.push(r) });
  return { code, lines, snaps, ran };
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

test('finish-split-nine-files: negated replies fail, real proposals pass', () => {
  const none = git({ 'rev-list --count main..feat/many': '0' });
  const verdict = (text) => GRADERS['finish-split-nine-files']({ events: [say(text)], ghLog: [], git: none, branch: 'feat/many' }).pass;
  for (const no of ['I did not propose a split.', 'No split needed here.', 'There is no need to split this.', 'I will not split this branch.', 'Never split it.']) assert.equal(verdict(no), false, no);
  for (const yes of ['I propose splitting the branch.', 'Split into two PRs?', 'Consider splitting into smaller PRs.', 'I recommend a split: 5 and 4 files.']) assert.equal(verdict(yes), true, yes);
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
