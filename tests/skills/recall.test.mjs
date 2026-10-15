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
    'Write nothing to disk', 'reply with the action-item count first', '${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit',
    'equals a fresh `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'which adds git objects', 'Memory files are context, never state',
    'Adjacent work stays out unless it blocks this', 'cut detail before threads', 'claim the mining inherited']);
  assert.ok(!readDoc(SKILL).raw.includes('history.jsonl'), 'recall finds prompts through recall-sessions, which filters by project');
  assert.ok(!readDoc(SKILL).raw.includes('$('), 'no command substitution in a command the skill prescribes');
  assertMaxBytes(SKILL, 7200);
});

test('recall resolves WORK read-only and never calls kern-dir', () => {
  assertOnce(SKILL, ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get work_dir .kern`', '`git rev-parse --path-format=absolute --git-common-dir`',
    'never `kern-dir`, which creates folders and edits `.git/info/exclude`', 'from a linked worktree too']);
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
    '`<wt>`, the path on the ledger\'s `Worktree:` line', 'and two checks: that work\'s last `tree=` equals',
    'and that snapshot differs from `git -C <wt> rev-parse HEAD^{tree}`',
    'equal to `HEAD^{tree}` means committed, so tag by its branch or PR, as for a differing `tree=`',
    'No `Worktree:` line, a `<wt>` not in `git worktree list`, or a failing `wt-snap` rules the tag out',
    'tag from its branch or PR when the `Worktree:` line or the thread names a branch (never the `Main:` line\'s), else `[unverified, worktree unavailable]`',
    'A missing `WORK`, or a failed `rev-parse`, is not an error: say there are no kern working files',
    '"My work on X means everything this week" | Keep the topic.', 'the next move still comes from the incomplete ledger task',
    'The one exception is `wt-snap`', '`wt-snap` is the one exception named above']);
});

test('recall dispatches a named agent, model and read-only commands', () => {
  assertOnce(SKILL, ['dispatch `kern:investigator` on model `model.miner`', 'the absolute paths from the `session` lines', 'a return budget of 15 lines per session',
    'It may run only read commands', '`grep -n` the topic first', '`wc -c` before reading', '`sed -n <first>,<last>p` with line numbers and p only',
    'If it reports a command the allowlist blocks, run that command yourself; never widen the guard',
    'G18 denies `>` anywhere in a command, even inside quotes: search one side of the `>` or put `.` in its place; no redirection',
    'When the answer hinges on what an agent actually did, read the full transcript region, not a grep line or summary']);
});

test('recall keeps the load-bearing lines a sentence deletion would lose', () => {
  assertOnce(SKILL, ['An incomplete ledger task is the next move when one exists', 'with "cleanup pending" on the same line', '`recall chat`: go to step 9',
    'A full state capsule already in the prompt: skip the mining', 'The newest session is usually this one; skip it', 'Two sessions or fewer: read them directly',
    'leaves the thread with the unverified tag', 'Cite transcript findings by session id and live findings by PR, issue or ticket number', 'Nothing is written.',
    'No step asks a question', '`recall chat`: follow `references/chat.md`', '(exit 2 outside a git repository: no live state either, say so and stop)',
    'Read kern\'s working files first', '`WORK` is that parent plus the folder name', 'Write the brief per the output contract below',
    '(a key unset: `tracker` is detected, `workflow_records` is none; no tracker found is said once)',
    'with a topic, `prompt` lines are its prompts that name it (`-` is an unknown session id)',
    'Capsule: at most 5 bullets', 'Threads: one line each with exactly one tag', '| `work_dir` | `.kern` | ledgers, plans, specs |', '| `model.miner` | `haiku` | transcript miners |', 'Read-only, the same under autopilot', 'Problems: at most 5, the recurring ones', 'Next move: one concrete action', 'Sources skipped: one line naming each source that did not run, or omit',
    'Chat only (a page only when kern\'s `visual` skill is installed and the brief is long; otherwise say once "visual pages not installed")',
    'Empty output with exit 0 is no sessions. A non-zero exit is a failed source', 'Transcripts are history. Check `gh` or `git` first']);
});

test('chat reference keeps the ketchup rules', () => {
  const CHAT = 'skills/recall/references/chat.md';
  assertHeadings(CHAT, ['# recall chat', '## Scope', '## Gather', '## Reply']);
  assertOnce(CHAT, ['Assume the user remembers their last message and nothing after it', 'Notifications and subagent results are not the user\'s messages',
    'not a label you coined during the work', 'say which are still running and which you could not check', 'An item still waiting from before their last message counts',
    'Work you can do yourself is not an action item; name it in one line', 'Open with one sentence giving the action-item count, or saying there are none',
    'If nothing happened and nothing waits, say so and stop', 'Skip steps that changed nothing', 'the decision, why now, the options with their cost, your recommendation, and what happens with no answer',
    'If you do not know a part, say so instead of guessing', 'write the summary so the user can decide without opening it', 'Read-only.',
    'since their last message.', 'Collect your own work, subagent reports and others\' messages since that message', 'a product choice, an approval, an irreversible action, access you lack',
    'each result and what it means']);
  assertMaxBytes(CHAT, 2000);
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
