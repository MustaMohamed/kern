// tests/exec-eval.test.mjs: the exec-eval graders on recorded runs, the runner's failure handling and the
// dry run. No model call: the runner tests put a stand-in `claude` first on PATH.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { GRADERS, gitCalls, ghCalls, shellSegments, stubMissed } from '../scripts/lib/exec-grade.mjs';
import { ISOLATION, PERMISSIONS, ClaudeRunError, runClaude } from '../scripts/lib/claude-run.mjs';

const say = (text) => ({ type: 'assistant', message: { content: [{ type: 'text', text }] } });
const bash = (command) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command } }] } });
const git = (answers) => (...a) => answers[a.join(' ')] ?? '';
const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js' });

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
function fakeClaude(body) {
  const dir = mkdtempSync(join(tmpdir(), 'fc-'));
  writeFileSync(join(dir, 'claude'), `#!/bin/sh\n${body}\n`);
  chmodSync(join(dir, 'claude'), 0o755);
  return { PATH: `${dir}:/usr/bin:/bin` };
}
const attempt = (env, extra = {}) => () => runClaude({ cwd: tmpdir(), prompts: ['hi'], model: 'm', env, ...extra });

test('runClaude: a missing binary, exit 126 or 127, a timeout and a signal all throw; none is a result', () => {
  assert.throws(attempt({ PATH: '/nonexistent' }), (e) => e instanceof ClaudeRunError && e.fatal && /not on PATH/.test(e.message));
  for (const code of [126, 127]) assert.throws(attempt(fakeClaude(`echo boom >&2; exit ${code}`)), (e) => e.fatal && e.message.includes(`exited ${code}`) && e.message.includes('boom'));
  assert.throws(attempt(fakeClaude('sleep 5'), { timeoutMs: 200 }), (e) => e instanceof ClaudeRunError && !e.fatal && /timed out/.test(e.message));
  assert.throws(attempt(fakeClaude('kill -9 $$')), (e) => e instanceof ClaudeRunError && /killed by SIGKILL/.test(e.message));
  assert.throws(() => runClaude({ cwd: tmpdir(), prompts: ['hi'], env: {} }), /needs a model/);
});

test('runClaude: a non-zero exit is returned for the caller to fail on, with stdin as stream-json turns and the budget cap', () => {
  const r = attempt(fakeClaude('cat > "$0.in"; echo "$@" > "$0.argv"; echo \'{"type":"result","result":"x"}\'; exit 3'))();
  assert.equal(r.status, 3);
  assert.deepEqual(r.events, [{ type: 'result', result: 'x' }]);
  assert.ok(r.argv.includes('--max-budget-usd') && !r.argv.includes('--max-turns'));
});

test('the gh stub logs every call, answers pr list from the case, and fails on a call it does not know', () => {
  const stub = fileURLToPath(new URL('../evals/exec/bin/gh', import.meta.url));
  const log = join(mkdtempSync(join(tmpdir(), 'gh-')), 'gh.log');
  const gh = (...a) => spawnSync(stub, a, { encoding: 'utf8', env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log, KERN_EXEC_PR: 'none' } });
  assert.equal(gh('pr', 'list', '--json', 'state').stdout, '[]\n');
  assert.equal(gh('pr', 'list', '--state', 'all', '--json', 'state', '--jq', '.[].state').stdout, '');
  assert.equal(gh('pr', 'create', '--draft').stdout, 'https://example.invalid/pr/8\n');
  const odd = gh('repo', 'delete', 'x');
  assert.equal(odd.status, 1);
  assert.match(odd.stderr, /unhandled call: repo delete x/);
  assert.equal(readFileSync(log, 'utf8').split('\n').filter(Boolean).length, 4);
  assert.notEqual(spawnSync(stub, ['pr', 'list'], { env: { PATH: '/usr/bin:/bin' } }).status, 0, 'no log path, no run');
});
