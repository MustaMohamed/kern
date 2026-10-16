const fs=require('fs');
let s=fs.readFileSync('tests/exec-eval.test.mjs','utf8');
function rep(a,b){ if(!s.includes(a)) throw new Error('missing '+a.slice(0,60)); s=s.split(a).join(b); }
rep(`import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';`,`import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';`);
rep(`import { ISOLATION, PERMISSIONS, ClaudeRunError, runClaude } from '../scripts/lib/claude-run.mjs';`,`import { ISOLATION, PERMISSIONS, ClaudeRunError, childEnv, runClaude, runProblem } from '../scripts/lib/claude-run.mjs';`);
rep(`const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js' });`,
`const DECOYS = 'M README.md\\n?? notes.txt';
const oneCommit = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'src/sum.js', 'status --porcelain': DECOYS });
const ORIGIN_PR = 'file:///w/app.origin/pull/7';`);
rep(`say('PR https://example.invalid/pr/7 is already open at this head.')`,'say(`PR ${ORIGIN_PR} is already open at this head.`)');
rep(`test('gitCalls drops -C`,`test('commit: a relative .kern/tmp message path is accepted', () => {
  assert.equal(GRADERS['commit-work-file']({ events: [bash('git -C /w/app commit -F .kern/tmp/commit-msg')], git: oneCommit, branch: 'feat/sum' }).pass, true);
});

test('commit: commit -a, add -u and add * fail, by command and by outcome (the decoys are committed)', () => {
  const swept = git({ 'rev-list --count main..feat/sum': '1', 'diff --name-only main feat/sum': 'README.md\\nsrc/sum.js', 'status --porcelain': '?? notes.txt' });
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

test('gitCalls drops -C`);
rep(`const attempt = (env, extra = {}) => () => runClaude({ cwd: tmpdir(), prompts: ['hi'], model: 'm', env, ...extra });`,
`const work = () => mkdtempSync(join(tmpdir(), 'wk-'));
const attempt = (env, extra = {}) => () => runClaude({ cwd: work(), prompts: ['hi'], model: 'm', env, ...extra });`);
rep(`assert.throws(() => runClaude({ cwd: tmpdir(), prompts: ['hi'], env: {} }), /needs a model/);`,`assert.throws(() => runClaude({ cwd: work(), prompts: ['hi'], env: {} }), /needs a model/);`);
rep(`assert.ok(r.argv.includes('--max-budget-usd') && !r.argv.includes('--max-turns'));`,
`assert.deepEqual(r.argv.slice(r.argv.indexOf('--max-turns'), r.argv.indexOf('--max-turns') + 4), ['--max-turns', '12', '--max-budget-usd', '3']);
  assert.ok(attempt(fakeClaude('exit 0'), { maxTurns: 30, maxBudgetUsd: 5 })().argv.join(' ').includes('--max-turns 30 --max-budget-usd 5'));`);
s+=`
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
  assert.match(runProblem(run('echo \\'{"type":"assistant","message":{"content":[]}}\\'; exit 0')), /no result event/);
  assert.match(runProblem(run('echo \\'{"type":"result","subtype":"error_max_turns","is_error":false}\\'; exit 0')), /error_max_turns/);
  assert.match(runProblem(run('echo \\'{"type":"result","subtype":"success","is_error":true,"result":"x"}\\'; exit 0')), /is_error/);
  assert.match(runProblem(run('echo \\'{"type":"result","subtype":"success"}\\'; exit 2')), /exited 2/);
  assert.equal(runProblem(run('echo \\'{"type":"result","subtype":"success","is_error":false,"result":"x"}\\'; exit 0')), '');
});
`;
rep(`  const gh = (...a) => spawnSync(stub, a, { encoding: 'utf8', env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log, KERN_EXEC_PR: 'none' } });`,
`  const repo = mkdtempSync(join(tmpdir(), 'ghr-'));
  spawnSync('git', ['-C', repo, 'init', '-q']);
  spawnSync('git', ['-C', repo, 'remote', 'add', 'origin', \`\${repo}.origin\`]);
  const gh = (...a) => spawnSync(stub, a, { encoding: 'utf8', cwd: repo, env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log, KERN_EXEC_PR: 'none' } });`);
rep(`assert.equal(gh('pr', 'create', '--draft').stdout, 'https://example.invalid/pr/8\\n');`,`assert.equal(gh('pr', 'create', '--draft').stdout, \`file://\${repo}.origin/pull/8\\n\`, 'a PR URL carries the origin path');
  assert.equal(gh('pr', 'view', '7').stdout, \`{"number":7,"state":"OPEN","url":"file://\${repo}.origin/pull/7"}\\n\`);
  const bare = mkdtempSync(join(tmpdir(), 'nr-'));
  const noOrigin = spawnSync(stub, ['pr', 'create'], { encoding: 'utf8', cwd: bare, env: { PATH: '/usr/bin:/bin', KERN_EXEC_LOG: log } });
  assert.equal(noOrigin.status, 1, 'no origin, no invented URL');`);
rep(`.length, 4);`,`.length, 6);`);
fs.writeFileSync('tests/exec-eval.test.mjs',s);
