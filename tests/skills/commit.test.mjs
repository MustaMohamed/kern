// tests/skills/commit.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, assertHeadings, h2s, steps, section, DEFER, assertMaxBytes, assertContains } from '../helpers/md.mjs';

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
    "Under autopilot `git add -- <paths>` runs unprompted, and G16 gives a project's own hook file that resolves outside kern's hooks folder no vote; kern's own hook code and any hook entry file (`pre-tool-use`, `prompt-submit`, `session-start`, `subagent-start`) still ask, and that ask is a stop.",
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'parked: <question>; default: <choice>; why: <one line>', 'never through AskUserQuestion',
    'no files, no commit; a failed toplevel, protected branch or detached HEAD, no commit', 'a protected branch or a detached HEAD never commits']);
  assert.ok(!raw.includes('temp file'), 'the message file lives under WORK/tmp, which G5 accepts, not in a temp file');
  assert.ok(!raw.includes('$('), 'no command substitution in a prescribed command');
  // 5,328 since M2b Task 17 (raised from 5,200): the Unreleased changelog line, coverage AD24.
  // 5,370 since M3 part 1 Task 6: the pointer line to the run rules, after lossless cuts.
  // 5,660 since its Task 8 and that task's fix rounds 1 and 3: the no-PR end's proof rule, the line that a stop waits, both
  // scoped to autopilot, and step 3's `--untracked-files=all`, after a shorter `git add` sentence.
  // 5,680 since its Task 14: step 4 takes the proven tree before the proof, and files the proof wrote are not proven, after a cut there.
  // 5,744 since its final review's fix (I1): prove-it's named skip is no step 4 stop.
  // 5,831 since that fix's second round: G16's deny of a project's own hook file is a stop.
  // 5,984 since M3 part 2 Task 1: G16 gives a project's own hook file outside kern's hooks folder no vote, and kern's
  // hook code or an entry file still asks, a stop.
  // 6,062 since M3 part 2 project 1's final review fix (I2): run.md's stops on a defect the ticket demands and on a change it
  // does not name are no-PR ends, so a red proof there is no step 4 stop.
  // 6,072 since its paid round 1 (the user's "Take the fix (Recommended)", 2026-11-04): the no-PR end's message body names
  // the red check as `fail`, which go-required-check-stop's bodyNamesCheck reads beside the check's name.
  assertMaxBytes(SKILL, 6072);
  // The size sentence quotes the user in full (round 2's fix review, Minor 3).
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['SKILL.md at most 6,072 bytes (6,062 until M3 part 2 project 1\'s paid round 1, the user\'s "Take the fix (Recommended)" of 2026-11-04: ']);
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

test('under autopilot a commit stop waits for a typed reply, and only a judgment call with a default parks', () => {
  // M3 part 1 Task 8, from Task 6's review: this route said each stop parks, and run.md says a stop waits.
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  assert.ok(auto.includes('never a retry with a looser message; a judgment call parks as `parked: <question>; default: <choice>; why: <one line>` committing nothing on that path'), auto);
  assert.ok(auto.includes('Ledger-task defaults: the reference. Any other stop waits for a typed reply, with the data and a recommendation.'), auto);
  assert.ok(!auto.includes('each stop parks'), auto);
  // Task 12's vote allows it, so a prompt no one answers no longer stops a run here.
  assert.ok(!auto.includes('No kern guard allows `git add`'), auto);
  // Task 7 review: finish-branch's end path commits, pushes, reports each red or unrun check as `fail` and opens no PR,
  // so a red proof there is no stop. The body says so; on every other path step 4 still stops. Task 8 review, M2: both
  // rules open under autopilot, so a typed /kern:commit never reads as commit-past-red. M3 part 2 project 1's final review, I2:
  // run.md's demanded-defect and unnamed-change stops commit and push too, and a red test is what the unnamed change forces.
  // Its paid round 1 (the user's "Take the fix (Recommended)", 2026-11-04): go-required-check-stop's body said the check
  // "could not run" with no `fail`, and run.md asks `fail` of the report only, so the body names the red check as `fail` too.
  assert.ok(auto.includes("Under autopilot, on a run's no-PR end (finish-branch's third fix round still `fix first`, a required check that cannot run, execute-plan's task still open at step 13, run.md's stop on a defect the ticket demands or on a change it does not name), a red or unrunnable step 4 proof is no stop, and the message body names the red check as `fail`. Elsewhere step 4 stops, but for prove-it's named skip of a `verify.fast` with nothing resolved."), auto);
  assert.ok(auto.includes('Stops: steps 1 to 4,'), auto);
  // A failed `git add` or `git commit` still reports what it printed.
  assert.ok(auto.includes('`git add` or `git commit` fails: report its output; never `--no-verify`, never another command shape.'), auto);
});

test('step 3 lists a new directory as files, so `git add -- <files>` keeps G5\'s allow', () => {
  // M3 part 1 Task 12 review: plain porcelain collapses an untracked directory to `?? src/new/`, the natural
  // `git add -- src/new/` gets no G5 allow, and the prompt it raises is no longer a stop here.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[3].startsWith('3. Files: read `git -C <toplevel> status --porcelain --untracked-files=all`;'), s[3]);
  // Task 8 fix round 4: plain porcelain shows `?? src/`, so a task's new file under it can read as clean, and an
  // uncommitted file gets reported as already committed.
  assertContains(REF, ['A complete task whose paths are clean in `git -C <toplevel> status --porcelain --untracked-files=all` is reported as already committed']);
});

test('the proven tree is taken before the proof, and files the proof wrote are not proven (audit D14)', () => {
  // A snapshot after the proof counted what the proof wrote, so step 7's check saw no difference.
  const s4 = steps(readDoc(SKILL).body)[4];
  assert.ok(s4.startsWith('4. Before the first commit, record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <toplevel>`, then follow `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md` once (`verify.fast` and the focused tests); files the proof wrote are not proven.'), s4);
  assert.ok(!s4.includes('Record the proven tree'), s4);
});
