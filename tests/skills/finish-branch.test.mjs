// tests/skills/finish-branch.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/finish-branch/SKILL.md';
const OPS = 'skills/finish-branch/references/branch-ops.md';
const PUSH = 'skills/finish-branch/references/push-and-pr.md';
const BODY = 'skills/finish-branch/references/pr-body.md';

// Each pin occurs exactly once in its file, so removing it fails the test.
function assertOnce(rel, needles) {
  assertContains(rel, needles);
  const { raw } = readDoc(rel);
  for (const n of needles) assert.equal(raw.split(n).length - 1, 1, `${rel}: pin occurs more than once: ${n}`);
}

function assertNoSubstitution(rel) {
  assert.ok(!readDoc(rel).raw.includes('$('), `${rel}: no command substitution in a prescribed command`);
}

test('finish-branch frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'finish-branch',
    description: 'Finish a branch: verify, self-review, check base and size, then offer commit, push, draft PR or keep.',
    'disable-model-invocation': 'true',
    'allowed-tools': 'Bash(git status *), Bash(git rev-list *), Bash(git rev-parse *), Bash(gh pr list *)',
  });
});

test('finish-branch sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 12);
  assert.equal(s[0], DEFER);
  assert.equal(s[1], '1. Consent: the user typed `/kern:finish-branch` or asked to push or open a PR in this session, or autopilot is on. Otherwise stop.');
  assertOnce(SKILL, ['A failure no step handles stops the run: report its output.',
    '`Worktree:` line', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers`', 'Run `cd <wt>` as its own call', 'git rev-parse --path-format=absolute --git-dir --git-common-dir',
    'git switch -c <name>', 'in the main checkout, stop: kern never switches its branch', 'A protected branch: stop',
    'git remote get-url origin', 'git fetch origin <base>', '"base not refreshed"', 'git rev-list --left-right --count <baseref>...HEAD', 'offer a rebase per `references/branch-ops.md`',
    '${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'Red, or `wt-snap` failing: stop.',
    '${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md', 'skip: no-comments ships in M3', '`fix first`, `split` or no verdict: stop', '`rebase first`: handle it as step 3\'s stale base',
    'git diff --shortstat <merge-base> <tree>', 'untracked files count', 'insertions plus deletions above `pr.max_lines`', 'propose a split',
    '1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is', 'Leave out 2 and 3 with no remote or `push.policy: deny`, and 3 with `pr.policy: deny`',
    'typed word `discard`, per `references/branch-ops.md`',
    'nothing to commit', 'steps 2 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'its stops stop this skill', 'offer a rebase step 3 put off',
    'Dedup, before any push or PR: `references/push-and-pr.md`, section Dedup', '`references/branch-ops.md`, section Proven tree, then `references/push-and-pr.md`, section Push',
    'Draft PR, for option 3: `references/push-and-pr.md`, section PR', 'the worktree stays',
    'never through AskUserQuestion', 'A G1 or G2 prompt is the confirmation; a declined prompt or a denial stops',
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'every kern ask is a denial', 'nothing is rebased or discarded, no teardown runs', 'the menu resolves to option 3 after the dedup check',
    'parked: <question>; default: <choice>; why: <one line>', 'a stale base or `rebase first`: no rebase; go on', 'A failed fetch: the last fetched ref.',
    'The size gate: go on', 'Dedup: per its section.', '`fix first`, `split` and a failed or unrunnable proven-tree check included',
    '"Tests passed earlier this session"', 'Only a PR at this head stops.', 'Only the typed word `discard` deletes work.', 'never force it']);
  assertNoSubstitution(SKILL);
  assertMaxBytes(SKILL, 6000);
});

test('branch-ops reference: rebase, proven-tree check, discard', () => {
  assertHeadings(OPS, ['# Branch operations', '## Rebase', '## Proven tree', '## Discard']);
  assertOnce(OPS, ['Under autopilot only the proven-tree check runs, without its teardown.', '`git worktree remove --force` never runs here', 'the first needing a `wt-apply`',
    'run it only on yes; on no, go on', 'git refuses a rebase over uncommitted changes', 'if refused again, go on', 'git rebase --abort', 'run again from step 4',
    '`git rev-parse HEAD^{tree}` must equal the tree from step 4', 'wt-new <slug>-check --detach --base <HEAD sha>', 'non-zero exit: report its output and ask; no push',
    'then `cd <wt>`', 'Red: no push', '`git worktree remove <check>`, run on yes',
    'In the main checkout, discard stops', 'status --porcelain -uall --ignored', 'a remove deletes ignored files too', 'git log --oneline <baseref>..HEAD',
    '`git worktree remove <wt>`', 'git branch -D <branch>', 'git worktree prune', 'A refused remove stops', 'remote branches and PRs stay']);
  assertNoSubstitution(OPS);
  assertMaxBytes(OPS, 2000);
});

test('push-and-pr reference: dedup, push, PR', () => {
  assertHeadings(PUSH, ['# Push and PR', '## Dedup', '## Push', '## PR']);
  assertOnce(PUSH, ['no `cd`, wrapper or expansion',
    'gh pr list --head <branch> --state all --json number,state,headRefOid,url', 'whatever `pr.dedup` says',
    'whose `headRefOid` is `git rev-parse HEAD`, in any state: report its URL and stop', 'open no new PR',
    'Only merged or closed PRs: push, then ask before a new PR', 'Autopilot parks with no PR', 'gh missing, logged out or failing', 'push, but open no PR',
    'git push -u origin <branch>', 'Under `push.policy: ask` G1 asks', 'under `auto` or autopilot it allows this shape', '`deny` denies every push',
    'never `--no-verify`', 'git log --oneline HEAD..origin/<branch>', 'never force.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', '(exit 2: stop)', 'else `references/pr-body.md`',
    "gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md",
    'no terminal can prompt for one', "write each `'` in it as `'\\''`", 'no backtick and no `$` before `(`',
    '`pr.policy` meets G2 as `push.policy` meets G1', 'only this draft shape, for a branch with no PR', '`gh pr ready` is never run',
    'say the branch is pushed', 'never retry another shape']);
  assertNoSubstitution(PUSH);
  assertMaxBytes(PUSH, 2000);
});

test('PR body template', () => {
  assertHeadings(BODY, ['# PR body', '## Why', '## What changed', '## Scope', '## Tradeoffs', '## Merge danger', '## Verification']);
  assertContains(BODY, ['drop a section with nothing to say', 'about 40 lines', 'smallest useful view', 'Screenshots first']);
  assertMaxBytes(BODY, 2000);
});
