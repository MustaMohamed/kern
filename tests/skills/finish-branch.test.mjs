// tests/skills/finish-branch.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/finish-branch/SKILL.md';
const OPS = 'skills/finish-branch/references/branch-ops.md';
const PUSH = 'skills/finish-branch/references/push-and-pr.md';
const DISC = 'skills/finish-branch/references/discard.md';
const BODY = 'skills/finish-branch/references/pr-body.md';

// Each pin occurs exactly once in its file, so removing it fails the test. Pins are whole clauses,
// so a swapped condition or outcome inside one fails too.
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
    'allowed-tools': 'Bash(git rev-parse *), Bash(git symbolic-ref -q --short HEAD), Bash(gh pr list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)',
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
    '`Worktree:` path', 'ls -t <dir>/*/ledger.md', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers`', 'Run `cd <wt>` as its own call', 'git rev-parse --path-format=absolute --git-dir --git-common-dir',
    '`git symbolic-ref -q --short HEAD` prints the branch; exit 1 means detached:',
    'git switch -c <name>', 'in the main checkout, stop: kern never switches its branch', 'A protected branch: stop',
    'git remote get-url origin', 'git fetch origin <base>', '"base not refreshed"', 'git rev-list --left-right --count <baseref>...HEAD',
    'behind above 0 is stale: offer a rebase per `references/branch-ops.md`.',
    '${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'Red, or `wt-snap` failing: stop.',
    '${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md', 'skip: no-comments ships in M3', '`fix first`, `split` or no verdict: stop', '`rebase first`: handle it as step 3\'s stale base', '`ready`: go on.',
    'git diff --shortstat <merge-base> <tree>', 'untracked files count', 'insertions plus deletions above `pr.max_lines`', 'propose a split; stop on yes, go on on no.',
    '1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is', 'Leave out 2 and 3 with no remote or `push.policy: deny`, and 3 with `pr.policy: deny`',
    'typed word `discard`, per `references/discard.md`',
    'nothing to commit', 'steps 2 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'its stops stop this skill', 'its proof is its own, apart from step 4\'s',
    'offer a rebase step 3 put off', 'Option 1 ends with the short SHA.',
    'Dedup, before any push or PR: `references/push-and-pr.md`, section Dedup', '`references/branch-ops.md`, section Proven tree, then `references/push-and-pr.md`, section Push',
    'Draft PR, for option 3: `references/push-and-pr.md`, section PR', 'the worktree stays',
    'never through AskUserQuestion', 'A G1 or G2 prompt is the confirmation; a declined prompt or a denial stops',
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'every kern ask is a denial', 'nothing is rebased or discarded, no teardown runs but the stale-check removal in `references/branch-ops.md`',
    'the menu resolves to option 3, or the highest option step 7 left: commit, then the dedup check, then the push and PR',
    'parked: <question>; default: <choice>; why: <one line>', 'a stale base or `rebase first`: no rebase; go on', 'A failed fetch: the last fetched ref.',
    'The size gate: go on', 'Dedup: per its section.', 'Stray untracked files can park the finish at commit\'s "no files, no commit" default.',
    '`fix first`, `split` and a failed or unrunnable proven-tree check included',
    '"Tests passed earlier this session"', 'Only a PR at this head stops.', 'Only the typed word `discard` deletes work.',
    'The remote moved, unless this run rebased. Investigate; never a plain force.']);
  assertNoSubstitution(SKILL);
  assertMaxBytes(SKILL, 6400);
});

test('branch-ops reference: rebase and the proven-tree check', () => {
  assertHeadings(OPS, ['# Branch operations', '## Rebase', '## Proven tree']);
  assertOnce(OPS, ['Under autopilot only the check runs, without its teardown; its removal of an earlier run\'s check path is not a teardown.',
    'If `git rev-parse --verify --quiet origin/<branch>` prints a SHA, the branch is published', 'warn that a rebase rewrites published commits and needs the lease push in `push-and-pr.md`',
    'offer it only if `git log --format=%ae <baseref>..HEAD origin/<branch>` prints only `git config user.email`; else G1 denies that push, so go on stale.',
    'Run `git rebase <baseref>` only on yes; on no, go on.', 'git refuses a rebase over uncommitted changes: offer it again after step 8\'s commit; refused again, go on.',
    'A rebase stopped by a conflict: run `git rebase --abort`, report the conflicting paths, and stop.',
    'After a rebase in step 3 or 5, rerun from step 4; after one in step 8, the check below proves the new tree.',
    '`git rev-parse HEAD^{tree}` must equal the tree from finish-branch step 4; commit\'s own proof is separate.',
    'If not, run `git rev-parse HEAD`, then', 'wt-new <slug>-check-<sha7> --detach --base <HEAD sha>', '`<sha7>`: the SHA\'s first 7 characters',
    'Exit 2 with `path exists` means an earlier run left that check: run plain `git worktree remove <path>`, under autopilot too, then wt-new again.',
    'Any other non-zero exit, or a refused remove: report its output and ask; no push.',
    'then `cd <wt>`', 'Red: no push.', 'If wt-new said `worktree.setup` is unset, a red may be the environment: check that before blaming the commit',
    'Then propose plain `git worktree remove <check>`, never `--force`, and run it on yes; a refusal keeps it, reported.']);
  assertNoSubstitution(OPS);
  assertMaxBytes(OPS, 2400);
});

test('discard reference', () => {
  assertHeadings(DISC, ['# Discard']);
  assertOnce(DISC, ['Only on the typed word `discard`, never under autopilot.', 'In the main checkout, discard stops',
    '`git worktree remove --force` never runs here', 'the first needing a `wt-apply`',
    'status --porcelain -uall --ignored', 'a remove deletes ignored files too', 'git log --oneline <baseref>..HEAD',
    'Run `git worktree remove <wt>`, then `git branch -D <branch>` (G1 asks), then `git worktree prune`', 'A refused remove stops; the worktree and branch stay.',
    'print `git worktree remove --force <wt>` and `git branch -D <branch>` for the user to type with the `!` prefix', 'remote branches and PRs stay']);
  assertNoSubstitution(DISC);
  assertMaxBytes(DISC, 2400);
});

test('push-and-pr reference: dedup, push, PR', () => {
  assertHeadings(PUSH, ['# Push and PR', '## Dedup', '## Push', '## PR']);
  assertOnce(PUSH, ['no `cd`, wrapper or expansion',
    'gh pr list --head <branch> --state all --json number,state,headRefOid,url', 'whatever `pr.dedup` says',
    'A PR counts only if its URL is this repo\'s (`git remote get-url origin`); check before reporting it.',
    'whose `headRefOid` is `git rev-parse HEAD`, in any state: report its URL and stop', 'An open PR at an older head: push, report its URL, and open no new PR.',
    'Only merged or closed PRs: push, then ask before a new PR', 'Autopilot parks with no PR', 'gh missing, logged out or failing: report its output; push, but open no PR.',
    'git push -u origin <branch>', 'Under `push.policy: ask` G1 asks', 'under `auto` or autopilot it allows this shape', '`deny` denies every push',
    'After this run\'s rebase of a published branch, push with `git push --force-with-lease origin <branch>` instead, as its own call',
    'G1 asks when every commit past the base is the user\'s, else denies', 'Autopilot never rebases, so never lease-pushes.',
    'never `--no-verify`', 'A plain push rejected right after this run\'s rebase is that rebase: it rewrote published commits, so use the lease push.',
    'Any other rejection means the remote moved', 'git log --oneline HEAD..origin/<branch>', 'Never a plain force.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', '(exit 2: stop)', 'else `references/pr-body.md`',
    "gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md",
    'no terminal can prompt for one', "write each `'` in it as `'\\''`",
    'A subject with a backtick, or a `$` before `(`, is reworded for the title without them',
    '`pr.policy` meets G2 as `push.policy` meets G1', 'only this draft shape, for a branch with no PR', '`gh pr ready` is never run',
    'say the branch is pushed and stop', 'never retry another shape']);
  assertNoSubstitution(PUSH);
  assertMaxBytes(PUSH, 2400);
});

test('PR body template', () => {
  assertHeadings(BODY, ['# PR body', '## Why', '## What changed', '## Scope', '## Tradeoffs', '## Merge danger', '## Verification']);
  assertContains(BODY, ['drop a section with nothing to say', 'about 40 lines', 'smallest useful view', 'Screenshots first']);
  assertMaxBytes(BODY, 2000);
});

test('finish-branch reads the branch with symbolic-ref, where exit 1 means a detached HEAD', () => {
  assert.ok(!readDoc(SKILL).raw.includes('--abbrev-ref'), 'no rev-parse --abbrev-ref');
});

test('finish-branch: the size command runs every time, since its line count is what pr.max_lines reads', () => {
  const s = steps(readDoc(SKILL).body);
  assert.match(s[6], /^6\. Size gate: `git merge-base HEAD <baseref>`, then `git diff --shortstat <merge-base> <tree>` \(step 4's tree, so untracked files count\)\. Always run it, even after self-review listed the files: `pr\.max_lines` reads its line count\. /);
});

test('the PR body follows commit.attribution (coverage gap 54)', () => {
  assertContains(BODY, ["With `commit.attribution: none`, the default, the body carries no attribution footer such as \"Generated with Claude Code\" and no Co-Authored-By line, even when Claude Code's attribution reminder asks for one."]);
  assertContains('kernel/settings.md', ["Governs commit trailers and a PR body's attribution footer | pre-tool-use G5, commit, finish-branch, autopilot |"]);
});
