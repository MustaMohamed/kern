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
  assertMaxBytes(SKILL, 7241);
});

// Audit E4: WORK is kern-root's main root plus work_dir, as kern-dir and autopilot find it. The parent of
// --git-common-dir is not the checkout in a submodule or a separate-git-dir checkout.
test('recall resolves WORK read-only and never calls kern-dir', () => {
  assertOnce(SKILL, ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get work_dir .kern`',
    'it is line 1 of `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root`, a `/`, then the text before the tab in `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get',
    'never `kern-dir`, which creates folders and edits `.git/info/exclude`']);
  assert.ok(!readDoc(SKILL).raw.includes('scripts/kern-dir'), 'recall never calls kern-dir');
  assert.ok(!readDoc(SKILL).raw.includes('git-common-dir'), 'WORK does not come from the git common dir');
});

// Audit E2 and E14: the running session is the one recall-sessions marks, not the newest; the tracker key
// names its commands.
test('recall skips the session marked current and names how tracker is found', () => {
  assertOnce(SKILL, ['Skip the `current` session: it is this one',
    '(`tracker` from `kern-get tracker`, else `kern-detect tracker`; `workflow_records` unset is none; no tracker found is said once)']);
  assertOnce(REF, ['Skip the `current` session: recall-sessions marks the one whose id is `CLAUDE_CODE_SESSION_ID`',
    'the running session (in a subagent, its parent)', 'With no `current` line, skip none; a transcript holding only this request is this one.']);
  for (const rel of [SKILL, REF]) assert.ok(!/usually (this one|the running session)/.test(readDoc(rel).raw), `${rel}: the newest session is not taken for the running one`);
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
    'A missing `WORK`, or a failed `kern-root`, is not an error: say there are no kern working files',
    '"My work on X means everything this week" | Keep the topic.', 'the next move still comes from the incomplete ledger task',
    'The one exception is `wt-snap`', '`wt-snap` is the one exception named above']);
});

test('recall dispatches a named agent, model and read-only commands', () => {
  assertOnce(SKILL, ['dispatch `kern:investigator` on model `model.miner`', 'the absolute paths from the `session` lines', 'a return budget of 15 lines per session',
    'It may run only read commands', '`grep -n` the topic first', '`wc -c` before reading', '`sed -n <first>,<last>p` with line numbers and p only',
    'If it reports a command the allowlist blocks, run that command yourself; never widen the guard',
    'G18 denies `>` anywhere in a command, even quoted: search one side of it or put `.` in its place',
    'When the answer hinges on what an agent actually did, read the full transcript region, not a grep line or summary']);
});

test('recall keeps the load-bearing lines a sentence deletion would lose', () => {
  assertOnce(SKILL, ['An incomplete ledger task is the next move when one exists', 'with "cleanup pending" on the same line', '`recall chat`: go to step 9',
    'A full state capsule already in the prompt: skip the mining', 'Two sessions or fewer: read them directly',
    'leaves the thread with the unverified tag', 'Cite transcript findings by session id and live findings by PR, issue or ticket number', 'Nothing is written.',
    'No step asks a question', '`recall chat`: follow `references/chat.md`', '(exit 2 outside a git repository: no live state either, say so and stop)',
    'Read kern\'s working files first', 'Write the brief per the output contract below',
    'with a topic, `prompt` lines are its prompts that name it (`-` is an unknown session id)',
    'Capsule: at most 5 bullets','| `work_dir` | `.kern` | ledgers, plans, specs |', '| `model.miner` | `haiku` | transcript miners |', 'Read-only, the same under autopilot', 'Problems: at most 5, the recurring ones', 'Next move: one concrete action', 'Sources skipped: one line naming each source that did not run, or omit',
    'Chat only (a page only when kern\'s `visual` skill is installed and the brief is long; otherwise say once "visual pages not installed")',
    'Empty output with exit 0 is no sessions. A non-zero exit is a failed source', 'Transcripts are history. Check `gh` or `git` first']);
});

// Task 16p item 2 (task-16-diagnosis-5, recall-1): on 2026-10-21 and 2026-10-22, 5 of 6 recall-1 runs had a kern
// miss: Threads lines with no tag (Sources-skipped and Problems material filed under Threads), and in one run no
// scope said before mining. Each duty now has a fixed form at its decision point.
test('recall says its Scope line right after the read, and every Threads line starts with its tag', () => {
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[2].startsWith('2. Right after reading this file, before any other tool call, say `Scope: <window>, <topic>, <workspace>.`: the window'), s[2]);
  assertOnce(SKILL, ['- Threads: one line per thread, starting with its one listed tag, as `- [tag] <thread>`:',
    'A line without a tag goes under Problems or Sources skipped.']);
  const { body } = readDoc(SKILL);
  const contract = body.slice(body.indexOf('## Output contract'), body.indexOf('## Inputs'));
  assert.ok(contract.indexOf('- Threads:') < contract.indexOf('- Problems:'), 'Threads still come before Problems');
});

// M2b bfix R (bfix-lane-2, recall-1): since Task 16p, of 12 recall-1 and recall-2 runs, 2 put a test result or a
// report's claim untagged under Threads, and 1 (b1 recall-2-1) used `[unverified, no PR]`, a tag off the list; a
// prose note on a tag (b1 recall-1-0) sat there too. So the tag is "listed", and the scripted thread-tags check
// reads the list from the Threads line: every backticked span on it that starts with `[` is one tag, each once,
// in this order.
const TAGS = ['[merged #N]', '[open PR #N]', '[in flight <branch>]', '[verified, uncommitted]', '[reverted #N]',
  '[blocked, <why>]', '[parked]', '[planned, not started]', '[unverified, <source> unavailable]'];
test('recall keeps one tag list a script can read, and names what is not a thread', () => {
  const lines = readDoc(SKILL).body.split('\n').filter((l) => l.startsWith('- Threads:'));
  assert.equal(lines.length, 1, 'one Threads line');
  assert.deepEqual([...lines[0].matchAll(/`(\[[^`]*\])`/g)].map((m) => m[1]), TAGS);
  assertOnce(SKILL, ['A test result, a report\'s claim or a note on a tag is not a thread. A line without a tag goes under Problems or Sources skipped.']);
});

// M2b bfix R follow-up (bfix-lane-2, recall-1 fix 3; task-16-confirming-diagnosis section 6 item 4): 4 of 9
// recall-1 runs since Task 16p tagged Task 3's work `[verified, uncommitted]`, though its last `tree=` differs
// from the fresh wt-snap, and the behaviour check now fails that. The condition sits beside the tag, unbackticked
// so the tag list keeps one backticked span per tag.
test('recall gives [verified, uncommitted] its condition on the Threads line', () => {
  assertOnce(SKILL, ['`[verified, uncommitted]` (only if the last tree= equals a fresh wt-snap), `[reverted #N]`']);
});

// M2b bfix R (bfix-lane-2, recall-4): since 2026-10-22, 4 of 9 recall-4 runs ran recall-sessions, most to check
// that the named session exists, before pointing to `claude --resume`. Step 1 makes no tool call, so no Read,
// Glob or Grep either, and a Red flags row answers that thought.
test('recall points one named session to claude --resume and makes no tool call', () => {
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].startsWith('1. Route. One named prior session: point to `claude --resume` and stop, making no tool call. A full state capsule'), s[1]);
  assertOnce(SKILL, ['| "I\'ll check the session exists first" | Step 1 makes no tool call. |']);
});

test('chat reference keeps the ketchup rules', () => {
  const CHAT = 'skills/recall/references/chat.md';
  assertHeadings(CHAT, ['# recall chat', '## Scope', '## Gather', '## Reply']);
  assertOnce(CHAT, ['Assume the user remembers their last message and nothing after it', 'Notifications and subagent results are not the user\'s messages',
    'not a label you coined during the work', 'say which are still running and which you could not check', 'An item still waiting from before their last message counts',
    'Work you can do yourself is not an action item; name it in one line', 'Open with one sentence giving the action-item count, or saying there are none',
    'If nothing happened and nothing waits, say so and stop', 'Skip steps that changed nothing',
    'If you do not know a part, say so instead of guessing', 'write the summary so the user can decide without opening it', 'Read-only.',
    'Keep the reply under 150 words', 'Say what changed for the user, not how you did it', 'Check each number you will show against the output it comes from',
    'Never invent an action item to fill the reply', 'Never mark done what still waits on the user', 'An irreversible step the user did not ask for gets one line',
    'the options side by side with what each gains and costs',
    'since their last message.', 'Collect your own work, subagent reports and others\' messages since that message', 'a product choice, an approval, an irreversible action, access you lack',
    'each result and what it means']);
  assertMaxBytes(CHAT, 2000);
});

test('transcripts reference', () => {
  assertHeadings(REF, ['# Where the records are', '## Transcripts', '## Prompt index', '## Working files', '## Live state']);
  assertContains(REF, ['recall-sessions']);
  // Audit E1: Claude Code slugs UTF-16 code units, not bytes, and cuts a long slug.
  assertOnce(REF, ['every UTF-16 code unit outside A-Z, a-z and 0-9 turned into `-`', 'a slug over 200 characters is cut to 200 and gets `-<hash>`']);
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
