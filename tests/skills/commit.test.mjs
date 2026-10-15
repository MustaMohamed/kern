// tests/skills/commit.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/commit/SKILL.md';

test('commit frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'commit',
    description: "Commit named files with a message that follows the project's convention, after the checks pass.",
    'disable-model-invocation': 'true',
    'argument-hint': '[files...]',
    'allowed-tools': 'Bash(git -C * status *), Bash(git -C * diff *), Bash(git -C * log *), Bash(git -C * rev-parse *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)',
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
    // gap 1: the task's file list
    'reviews/task-<N>-<tree7>.diff', '`tree=` of its `Task <N>: complete` line', 'git -C <toplevel> diff --name-only <start tree> <complete tree>',
    // gap 2: overlap
    '`Worktree:` line names `<toplevel>`', 'Autopilot commits each task as it closes', 'share a path', 'Never stage a file that holds another task\'s hunks under one task\'s name',
    // gap 3: where the commit runs
    'the worktree the caller names', 'git -C <toplevel> rev-parse --abbrev-ref HEAD',
    // exits
    'kern-dir` exits 2', '`wt-snap` fails', 'G5 denies or asks', '`git add` or `git commit` fails', 'never `--no-verify`',
    // autopilot
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'parked: <question>; default: <choice>; why: <one line>', 'never through AskUserQuestion',
    'a protected branch or a detached HEAD never commits']);
  assert.ok(!raw.includes('temp file'), 'the message file lives under WORK/tmp, which G5 accepts, not in a temp file');
  assert.ok(!raw.includes('$('), 'no command substitution in a prescribed command');
  assertMaxBytes(SKILL, 5200);
});
