// tests/skills/recall.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/recall/SKILL.md';
const REF = 'skills/recall/references/transcripts.md';

// Every pinned line must occur exactly once, so removing it fails the test and no second copy hides the removal.
function assertOnce(rel, needles) {
  const { raw } = readDoc(rel);
  for (const n of needles) assert.equal(raw.split(n).length - 1, 1, `${rel} must contain exactly once: ${n}`);
}

test('recall frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'recall',
    description: 'Use when starting or resuming work and state must be rebuilt first: "where did I leave off", "catch me up on X", "what remains", "I got lost in these PRs", a session after days away, or "recall chat" for this thread since my last message. Not for one named session.',
  });
});

test('recall sections, steps and the source lines it keeps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Output contract', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 10);
  assert.equal(s[0], DEFER);
  assertOnce(SKILL, ['claude --resume', 'never turn "all" into "recent"', 'WORK/ledgers', 'gh pr list --head <branch> --state all', '[planned, not started]',
    'Write nothing to disk', 'action-item count first', '${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit',
    'equals a fresh `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'which adds git objects', 'Memory files are context, never state',
    'Adjacent work stays out unless it blocks this', 'cut detail before threads', 'notifications and subagent results are not the user\'s messages',
    'work you can do yourself is not an action item', 'claim the mining inherited']);
  assert.ok(!readDoc(SKILL).raw.includes('history.jsonl'), 'recall finds prompts through recall-sessions, which filters by project');
  assert.ok(!readDoc(SKILL).raw.includes('$('), 'no command substitution in a command the skill prescribes');
  assertMaxBytes(SKILL, 7200);
});

test('recall resolves WORK read-only and never calls kern-dir', () => {
  assertOnce(SKILL, ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get work_dir .kern`', '`git rev-parse --path-format=absolute --git-common-dir`',
    'never `kern-dir`, which creates folders and edits `.git/info/exclude`', 'from a linked worktree too',
    'A missing `WORK` is not an error: say there are no kern working files']);
  assert.ok(!readDoc(SKILL).raw.includes('scripts/kern-dir'), 'recall never calls kern-dir');
});

test('recall gives every script exit an action', () => {
  assertOnce(SKILL, ['adding `--topic <topic>` only when a topic was named (an empty topic is a usage error)',
    'Exit 1 (a record could not be read) or 2 never means there were no sessions', 'name transcripts in Sources skipped, tag nothing from transcripts, and go on with live state',
    'a non-zero exit, or a worktree in the `unknown` bucket, goes in Sources skipped with its evidence, never as clean',
    'A source that did not run (tracker tools absent or erroring, `gh` missing, `gh auth status` failing) goes in Sources skipped',
    'a null result from a source that ran is a finding']);
});

test('recall pins the unverified tag and the verified-uncommitted rules', () => {
  assertOnce(SKILL, ['`[unverified, <source> unavailable]`', 'a transcript alone never earns a stronger tag',
    '`<wt>`, the path on the ledger\'s `Worktree:` line', 'A `<wt>` that is not in `git worktree list`, or a `wt-snap` that fails, rules the tag out',
    'use `[unverified, worktree unavailable]` and say the worktree is gone', 'A differing tree means the work moved: tag by its PR or branch',
    'The one exception is `wt-snap`', '`wt-snap` is the one exception named above']);
});

test('recall dispatches a named agent, model and read-only commands', () => {
  assertOnce(SKILL, ['dispatch `kern:investigator` on model `model.miner`', 'the absolute paths from the `session` lines', 'a return budget of 15 lines per session',
    'It may run only read commands', '`grep -n` the topic first', '`wc -c` before reading', '`sed -n <first>,<last>p` with line numbers and p only',
    'If it reports a command the allowlist blocks, run that command yourself; never widen the guard']);
});

test('transcripts reference', () => {
  assertHeadings(REF, ['# Where the records are', '## Transcripts', '## Prompt index', '## Working files', '## Live state']);
  assertContains(REF, ['recall-sessions']);
  assertMaxBytes(REF, 2200);
});

test('the C11 acceptance checks are behavioural cases', () => {
  const c = JSON.parse(readFileSync(join(ROOT, 'evals', 'cases', 'recall.json'), 'utf8'));
  assert.equal(c.evals.length, 5);
  const text = JSON.stringify(c.evals);
  for (const needle of ['next move', 'action-item count', 'claude --resume', 'recall mean in machine learning']) assert.ok(text.includes(needle), needle);
});

test('the recall ledger fixture exists and leaves Task 3 incomplete', () => {
  const ledger = readFileSync(join(ROOT, 'evals', 'fixtures', 'recall-ledger', '_kern', 'ledgers', 'export', 'ledger.md'), 'utf8');
  assert.match(ledger, /^Task 2: complete /m);
  assert.match(ledger, /^Task 3: start /m);
  assert.doesNotMatch(ledger, /^Task 3: complete /m);
});
