// tests/skills/commit.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, assertHeadings, h2s, steps, DEFER, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/commit/SKILL.md';
const REF = 'skills/commit/references/ledger-tasks.md';

test('commit frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'commit',
    description: "Commit named files with a message that follows the project's convention, after the checks pass.",
    'disable-model-invocation': 'true',
    'argument-hint': '[files...]',
    'allowed-tools': 'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)',
  });
});

test('commit sections, steps and red flags', () => {
  const { body, raw } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 8);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['git -C <toplevel> add -- <files>', 'never `-A` or `.`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', 'git -C <toplevel> commit -F <dir>/commit-msg', 'as its own call, with the literal path',
    'git -C <toplevel> diff --staged --stat', 'one commit per complete task, in ledger order', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap', 'HEAD^{tree}', 'On a detached HEAD, stop:', 'On a protected branch, stop and ask',
    '72 characters or fewer', 'never a retry with a looser message', '${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md',
    'follow `references/ledger-tasks.md`', 'each staging that task\'s exact paths', 'steps 2 to 6',
    'the worktree the caller names', 'git -C <toplevel> symbolic-ref -q --short HEAD` (exit 1: detached)', 'If it fails, stop and report.', 'Never switch branches.',
    'leave out and name any `never_commit` path', 'a mismatch means it is not what was proven: say so.',
    'those before the last are not proven alone, and the report says so',
    'kern-dir` exits 2', '`wt-snap` fails', 'G5 denies or asks and the user declines', '`git add` or `git commit` fails', 'never `--no-verify`',
    'No kern guard allows `git add`: under autopilot it runs unprompted only where the user\'s permission settings allow it, else its prompt is a stop.',
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'parked: <question>; default: <choice>; why: <one line>', 'never through AskUserQuestion',
    'no files, no commit; a failed toplevel, protected branch or detached HEAD, no commit', 'a protected branch or a detached HEAD never commits']);
  assert.ok(!raw.includes('temp file'), 'the message file lives under WORK/tmp, which G5 accepts, not in a temp file');
  assert.ok(!raw.includes('$('), 'no command substitution in a prescribed command');
  // 5,328 since M2b Task 17 (raised from 5,200): the Unreleased changelog line, coverage AD24.
  assertMaxBytes(SKILL, 5328);
});

test('commit ledger-tasks reference', () => {
  assertHeadings(REF, ['# Ledger tasks', '## Which ledger', '## A task\'s files', '## Overlap', '## Already committed']);
  assertContains(REF, ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers`', '`Worktree:` line names `<toplevel>`', 'Several do: ask (default: commit nothing from ledgers).',
    'reviews/task-<N>-<tree7>.diff', '`tree=` of its `Task <N>: complete` line', '`M<TAB>path`, `D<TAB>path`, `R100<TAB>old<TAB>new`', 'stage both paths of a rename',
    'git -C <toplevel> diff --name-only --no-renames <start tree> <complete tree>', '(a `dir/` entry covers what is under it)', 'failing that, ask (default: leave the task uncommitted).',
    'Tasks that share a path cannot be split', "Never stage a file that holds another task's hunks under one task's name.", 'offer one commit naming each, or ask (default: that commit)',
    '`Task <N>: start` line and no complete line contributes the paths in `<ledger dir>/briefs/task-<N>.files`', 'is not committed by path: ask (default: leave it uncommitted).',
    'Autopilot commits each task as it closes', 'the started-task check applies in both', 'reported as already committed, not as a failure']);
  assertMaxBytes(REF, 2000);
});

test('commit: kern\'s commit.attribution governs trailers over Claude Code\'s reminder, and an attribution or convention deny is retried once', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  assert.match(s[5], /`commit\.attribution` governs trailers: with `none` \(the default\), write no Co-Authored-By or other attribution trailer, even when Claude Code's attribution reminder asks for one\.$/);
  assertContains(SKILL, ['A G5 deny naming only attribution or `commit.convention` is no stop: fix it, the subject matching the regex G5 names, and rerun the same `git commit -F` once; a second deny, or one naming another check, stops.',
    'Under autopilot any other G5 deny is a denial, never a retry with a looser message',
    '| A failed check stops; only an attribution or convention deny is retried. |']);
  assert.ok(!body.includes('Add attribution only as `commit.attribution` says.'), 'the old sentence named no precedence over the reminder');
  assert.ok(!body.includes('naming only the attribution trailer'), 'the footer is attribution too, and G5 names it');
});

test('commit resolves commit.convention as G5 does, with kern-get then kern-detect, and states the regex (audit D11)', () => {
  const { body } = readDoc(SKILL);
  assert.match(steps(body)[5], /^5\. Message: match the subject to `commit\.convention`, G5's regex, from `kern-get`, else `kern-detect` \(before the tab; both exit 3: none\), and state it; take the ticket id /);
  assert.ok(!body.includes('infer it from'), 'an inferred convention is not the regex G5 checks');
});

test('commit reads the branch with symbolic-ref, where exit 1 means a detached HEAD', () => {
  assert.ok(!readDoc(SKILL).raw.includes('--abbrev-ref'), 'no rev-parse --abbrev-ref');
});

test('a project with an Unreleased changelog section gets the change\'s line in the same commit, proposed, never unasked (coverage AD24)', () => {
  // M2b Task 17 review I2b: addy git-workflow-and-versioning :311 writes the entry in the change that makes it, not
  // reconstructed at release time; finish-branch's release turns that Unreleased section into the version's entry.
  const s = steps(readDoc(SKILL).body);
  const line = 'A changelog with an Unreleased section gets this change\'s line there, in the same commit, proposed with the files, never unasked.';
  assert.ok(s[3].includes(`list the rest, unstaged. ${line}`), s[3]);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [line]);
});
