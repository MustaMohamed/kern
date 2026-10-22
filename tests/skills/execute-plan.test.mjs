// tests/skills/execute-plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/execute-plan/SKILL.md';
const LEDGER = 'skills/execute-plan/references/ledger-format.md';
const RESUME = 'skills/execute-plan/references/resume.md';

test('execute-plan frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'execute-plan',
    description: 'Run an approved plan task by task in step, inline or delegate mode, with a resumable ledger and two-verdict review.',
    'disable-model-invocation': 'true',
    'argument-hint': '[plan path] [step|inline|delegate]',
  });
});

test('execute-plan sections, steps, scripts and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 15);
  assert.equal(s[0], DEFER);
  for (const script of ['ledger-open', 'plan-check', 'wt-new', 'wt-fork', 'wt-snap', 'wt-diff', 'wt-apply', 'task-start', 'task-brief', 'brief-check', 'task-review', 'task-done']) {
    assertContains(SKILL, [`\${CLAUDE_PLUGIN_ROOT}/scripts/${script}`]);
  }
  assertContains(SKILL, ['kern:implementer', 'kern:task-reviewer', 'Pass no `isolation` parameter', 'Never re-dispatch unchanged', 'split proposal',
    'plan-check --graph', 'plan-check --files', '--allow-file', 'Exit 4', '--minor', '--probe <package>.patch', 'return the task to the implementer',
    'Batch small tasks', 'closed in its fork through steps 6 to 10', 'ledger-open --summary', 'One fix subagent gets the complete findings list',
    'main: unchanged', 'run them only on yes', '`<ledger>` below is `<ledger dir>/ledger.md`', 'briefs/task-N.brief.md', 'dispatch only on `brief-check: ok`',
    '--no-probe']);
  assertMaxBytes(SKILL, 12400);
});

test('ledger format and model table', () => {
  assertHeadings(LEDGER, ['# Ledger format', '## Lines', '## Resume rule', '## Tree ids']);
  assertContains(LEDGER, ['# kern ledger: <plan path>', 'Main: <root> branch=<name> status=<hash>',
    'Task N: start tree=<id> at=<iso>', 'Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>',
    'Task N: minor (deferred): <text>', 'Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok or skipped (reason)> last=<line>',
    'parked: <question>; default: <choice>; why: <one line>']);
  assertMaxBytes(LEDGER, 2600);
  assertHeadings('skills/execute-plan/references/model-selection.md', ['# Model selection', '## Table', '## Rules']);
  assertMaxBytes('skills/execute-plan/references/model-selection.md', 1600);
  assertHeadings(RESUME, ['# Resume', '## Where to continue', '## Fix loop memory']);
  assertMaxBytes(RESUME, 2500);
});

// Load-bearing lines, pinned to the step that carries them. Each pin fails the test when it is removed.
export const PINS = {
  intro: ['An unnamed script exit stops the run: report its output.', 'Subagents get absolute paths (`${CLAUDE_PLUGIN_ROOT}` resolved) and a named model and effort',
    'Only the scripts write `Task N: start`, review, minor and `Task N: complete` lines.'],
  1: ['run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open <plan>`', "exits 2 when the plan has no `status: approved` with the user's quoted words, or when the dir holds another plan's ledger: stop and report it",
    "Never edit the plan's approval.", 'The mode is the typed one, else `execution:`.',
    'Line formats and how to append them: `references/ledger-format.md`.',
    'If the ledger already held lines past `Main:`, or after compaction, read `references/resume.md` and continue where it says.'],
  2: ['Steps 2 and 3 run on every invocation, fresh or resumed,', 'add a `Preflight:`, `Decision:` or `parked:` line only when the ledger lacks that exact line.',
    'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'any exit but 0 is a plan defect: stop before any task and report its output', 'Then `plan-check --graph <plan>`',
    'each `overlap` row becomes a `Preflight:` line with its ruling', "this run's `wave` rows feed step 4"],
  3: ['one todo per task', 'A spec or scope conflict the graph does not show: stop and ask; record the answer, or a mechanical call, as a `Decision:` line.'],
  4: ['at most `parallel.max`', 'unless parallel-work step 1 finds an overlap', 'spawn them in one message as `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` step 4 does',
    'Others run serially, in task order.', 'Batch small tasks of one shape (the same one-line edit across files) into one dispatch and one review over their joined Files lists'],
  5: ['Once, make the plan worktree', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <plan-slug> --plan <plan>`', "(`<plan-slug>`: the ledger dir's name)",
    'adding `--branch <name>` when `branch.pattern` holds `{id}`', 'Exit 2: say why and ask.', 'both exit 3: ask', 'a red baseline goes to the user',
    'Then write `Worktree: <path> branch=<name> base-tree=<id>`, the id from `wt-snap`.'],
  6: ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <plan-wt> <plan-slug>-task-<N>` (exit 2 or 3: say why and ask)',
    'run `plan-check --files <plan> <N> > <ledger dir>/briefs/task-N.files`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-brief <plan> <N> <ledger dir>`',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` (`tree-before`)', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-start <ledger> <N> <tree-before>`', 'exit 2 from any: stop',
    "Write `Wave: tasks <list> forks=<paths>` once a wave's forks exist."],
  step: ['`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`', 'reporting to `<ledger dir>/reports/task-N.md`', 'run steps 8 to 10, report, and stop'],
  inline: ['in the plan worktree, with absolute paths and `git -C`'],
  delegate: ['`${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/brief-template.md`', 'SCOPE the `.files` paths, the worktree and `<base-ref>` (the plan branch)',
    'CONTEXT `briefs/task-N.md`, the upstream Interfaces and the step 3 rulings', 'VERIFY `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` first',
    'REPORT `<ledger dir>/reports/task-N.md`, each round opening with its `Status:` line', 'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check` on it', '(else fix each printed line)',
    '`kern:implementer` with its model and effort, the brief, worktree, `<base-ref>`, report path and implement SKILL.md path', 'kern made the worktree'],
  7: ['Status line (none: BLOCKED).', 'DONE_WITH_CONCERNS: read the concerns, then review.', 'NEEDS_CONTEXT: answer from the plan or spec, else ask the user, then resume the implementer.',
    'go one model tier up (a `Decision:` line)', 'a task that must be split: stop with a split proposal'],
  8: ['take `tree-after` with `wt-snap`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before> <tree-after> --out <ledger dir>/reviews/task-N-<tree7>.diff --allow-file <ledger dir>/briefs/task-N.files`',
    'Its first line is `<package>`, beside `<package>.patch`.', 'Exit 3 (empty): return the task to the implementer.', "Exit 4 names a file outside the task's Files: pause and ask",
    'on a yes append it to `briefs/task-N.files` with a `Decision:` line, on a no return the task to the implementer',
    '`kern:task-reviewer` on `model.reviewer` in mode `task`', 'do not pre-judge findings in the prompt',
    "Save its return as `<ledger dir>/reviews/task-N-r<r>.txt`, r = 1 + the task's review lines.", 'Resolve every "cannot verify" item yourself; a real gap is a spec issue.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger> <N> <tree-after> <r> <compliant|issues> <approved|needs-fixes>`',
    'adding `--minor "<finding>"` for each Minor finding, which waits for step 12'],
  9: ['Before rounds 2 and 3 write `Task N: fix round=<r> tree=<id>`, the tree just reviewed.', "Round 2 resumes the implementer with the previous round's `.txt`",
    "(SendMessage to its agent id, or `references/resume.md`'s fallback; inline and step: fix it yourself)",
    'round 3 dispatches a fresh `kern:implementer` one tier up with a step 6 brief, the report and that file',
    "Each round packages its fix diff with `wt-diff` from the round's tree to a new `tree-after`", '`--out <ledger dir>/reviews/task-N-fix<r>-<tree7>.diff`, same `--allow-file` and exits',
    'gets a `re-review` with that file, dispatched, saved and recorded as step 8 does',
    "Still open after round 3, or a re-review finds a bug in an earlier round's fix: stop and escalate with a split proposal", 'there is no fourth round.'],
  10: ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-done <ledger> <N> <wt> <tree-after> --probe <package>.patch -- <task test command>`',
    'or `--no-probe "<why>"` in place of `--probe` for a task with no test to probe', 'One command, no shell: a compound `Run:` goes in a `kern-dir tmp` script, passed as `-- bash <path>`.',
    'After fix rounds, remake `<package>` from `tree-before`.',
    'only when an approved review saw this tree, the command passes, and the test fails with the change reversed (`probe=ok`) or `--no-probe` gave a reason.',
    'A refusal writes nothing and says why.', '`command exited <n>` or exit 1 (the test passes with the change reversed): return the task to the implementer as the next round',
    '(after round 3: the split proposal)', '`command exited 126` or `127`: stop.',
    'Exit 3, an inconclusive probe: rerun with `--no-probe "probe inconclusive: <reason>"` only for a new module or export, or a patch of test files only; else stop and ask.',
    'Exit 2: a changed or unapproved tree, review it; a probe error, stop.', "Under autopilot only, then commit the task's files with `/kern:commit` steps 2 to 6 (a wave task: after step 11)."],
  11: ["Apply each worker's patch to the plan worktree one at a time with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <package>.patch <plan-wt>`",
    'writing `Applied: Task N patch=<path>` after each `applied`', 'Exit 3 is a conflict with nothing applied: stop.', 'Then `test.full` there; red: stop.'],
  12: ["`ledger-open --summary <ledger dir>` lists the ledger's rulings and minors, then the main checkout's state", '`wt-diff <plan-wt> <base-tree> --out <ledger dir>/reviews/final.diff`',
    "(the `Worktree:` line's base tree)", 'mode `whole-branch` on `model.final_review`', 'to triage which minors block', 'Re-grade findings by effect.',
    'One fix subagent gets the complete findings list (`kern:implementer`, a step 6 brief), each fix red then green',
    "one `re-review` on `model.final_review` of its diff from `final.diff`'s second line, packaged with an `--allow-file` per task", 'Residual findings go to the user in step 13.'],
  13: ['`ledger-open --summary` must end with `main: unchanged`; anything else goes first in the report.', "No push or PR, no commit beyond step 10's"],
  14: ['Propose teardown, do not run it', '`${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows', 'the plan worktree once committed'],
  stops: ['Ask at each stop as a typed reply in chat, never through AskUserQuestion.', 'on per the latest kern signal', 'a turn with no mode line changes nothing',
    'When on, steps 1 and 2 and a failed `wt-new` still end the run.', 'parked: <question>; default: <choice>; why: <one line>', 'a red baseline goes on, naming red-before tests',
    'a stopped task stays open with every task blocked by it, and disjoint tasks continue', 'One commit per closed task when its checks pass, through `/kern:commit`',
    'G5 allows only `git commit -m` or `-F <file>` on an unprotected branch', 'Without autopilot `commits: ask` holds: no commit.', 'teardown never runs'],
  ledger: ['Only the scripts write `Task N: start`, review, minor and `Task N: complete` lines; never write or edit one by hand.',
    "A batch of tasks shares one brief, package and review, and the scripts still write each task's lines.",
    "The other lines are appended with `printf '%s\\n' '<line>' >> <ledger>`", 'one holding the word approved goes in with the Edit tool',
    "Limit: no guard yet stops an Edit or Write that forges a script's line; that guard is deferred to M3.",
    'A task is done only when its `Task N: complete` line exists. Where a run resumes is in `resume.md`.',
    "| any step | a ruling: the user's answer to a stop, or a mechanical call made without the user |"],
  resume: ['Read this when the ledger already holds lines past `Main:`, and after compaction.', 'Trust the ledger and the worktrees over memory.',
    'Steps 2 and 3 run again on every invocation and add only the lines the ledger lacks', 'plan-check and its `wave` rows come from this run',
    'a step 3 conflict with no `Decision:` line is asked again (under autopilot, parked once)', 'r is 1 plus its review lines.', 'The first case that holds, in this order:', '1. No `Worktree:` line: step 5.',
    '2. A task on a `Wave:` line has its `Task N: complete` line but no `Applied: Task N patch=<path>` line: step 11 for it, before the final review or any later task.',
    'A task a `parked:` line holds stays out, with every task blocked by it.', '3. The first task in task order with no `Task N: complete` line, by its last line, `minor (deferred)` lines skipped:',
    '- none: step 6.', 'keep that tree as `tree-before`, with no second `task-start`', 'A snapshot still equal to it means nothing landed: dispatch again.',
    "A changed snapshot waits until the implementer has stopped, its report holding that round's `Status:` line: DONE or DONE_WITH_CONCERNS goes to step 8 as round r, any other status (or none) to step 7",
    'until then wait for it or resume it (step and inline: finish the change first)', 'a review that did not approve: write `Task N: fix round=<r> tree=<id>` with the reviewed tree and continue step 9',
    'an r of 4 is past the cap, so stop with a split proposal', '`Task N: fix round=<r> tree=<id>`: resume that round', 'a fresh snapshot that differs from its tree is',
    "the round's `tree-after` once the implementer has stopped, and its `Status:` line routes it as above.",
    '- an approving review: step 10.', '4. Every task complete and applied: step 12.', "A wave task resumes in the fork its `Wave:` line names.", 'Never re-dispatch a completed task.',
    "Round r's findings are the reviewer's return saved as `<ledger dir>/reviews/task-N-r<r>.txt`. The next round gets that file.",
    'is replaced by a fresh `kern:implementer` with the brief, the report and that file: the report file is the memory.'],
};

// The mode bullets of step 6, by their leading backticked name.
const bullet = (body, mode) => (section(body, '## Steps') ?? '').split('\n').find((l) => l.startsWith(`   - \`${mode}\``)) ?? '';

test('execute-plan pins each step, the modes, the stops and the ledger rules', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const intro = body.slice(0, body.indexOf('## Steps'));
  const stops = section(body, '## Stops and autopilot') ?? '';
  const ledger = readDoc(LEDGER).raw;
  const resume = readDoc(RESUME).raw;
  const where = { intro, step: bullet(body, 'step'), inline: bullet(body, 'inline'), delegate: bullet(body, 'delegate'), stops, ledger, resume };
  for (const [k, needles] of Object.entries(PINS)) {
    const text = where[k] ?? s[Number(k)];
    for (const n of needles) assert.ok(text.includes(n), `${k}: must contain: ${n}`);
  }
});

test('execute-plan runs its task and final reviews in the foreground', () => {
  // Claude Code 2.1.304 runs an Agent call that omits run_in_background in the background, and the notification
  // starts a turn no prompt asked for: in the three workflow-execute-plan-ledger runs of 2026-10-20 four such
  // results came after the last turn's text (task-16-diagnosis-2, Y1). task-done waits on the review's verdict.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[8].includes('Dispatch `kern:task-reviewer` on `model.reviewer` in mode `task` (`run_in_background: false`) with `briefs/task-N.md`'), s[8]);
  assert.ok(s[9].includes('gets a `re-review` with that file, dispatched, saved and recorded as step 8 does'), s[9]);
  assert.ok(s[12].includes('dispatch `kern:task-reviewer` in mode `whole-branch` on `model.final_review` (`run_in_background: false`) with the package'), s[12]);
  assert.ok(s[12].includes('packaged with an `--allow-file` per task, dispatched as the whole-branch review is.'), s[12]);
  // Step 6 names no run_in_background: a wave's implementers spawn as parallel-work step 4 does, in the background,
  // and its serial delegate implementer, which step 7 waits on, runs in the foreground by model-selection.md's rule
  // (Task 16i review, M4).
  assert.ok(!s[6].includes('run_in_background'), s[6]);
});

test('only the user\'s word skips the final review; task-done refuses a task no review approved', () => {
  // The user's "Only by my word" (2026-10-22, Task 16n): a gating review is skipped only when the user says so. The
  // kernel's Routing line states it for every route; task-done already refuses a tree no approved review saw.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[12].startsWith("12. Final review (only the user's word skips it): `ledger-open --summary <ledger dir>`"), s[12]);
  assert.ok(s[10].includes('only when an approved review saw this tree'), s[10]);
});

test('an Agent call the next step waits on runs in the foreground, by the file every Agent call follows', () => {
  // Task 16i review, M4: self-review's lanes, recall's miners, plan's and diagnose's investigators and execute-plan's
  // serial and fix implementers gate their next step and name no run_in_background, so on Claude Code 2.1.304 they
  // ran in the background. One rule in the file the kernel's Context line names covers each of them.
  assertContains('skills/execute-plan/references/model-selection.md', ["- Pass `run_in_background: false` when your next step waits on the agent's return; only parallel-work's workers and define's explorers run in the background."]);
  assertContains('kernel/kernel.md', ['Agent calls pass their role\'s model and effort: {KERN}/execute-plan/references/model-selection.md.']);
});

test('execute-plan reruns its plan checks on every invocation and writes only missing lines', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const resume = readDoc(RESUME).raw;
  // Fix round 2: a once-only step 2 or 3 skipped plan-check, the wave rows and an unanswered step 3 stop on resume.
  for (const n of [2, 3]) assert.ok(!/\bOnce\b/i.test(s[n]), `step ${n} must run on every invocation, not once`);
  for (const bad of ['ran already', 'rebuild only the todo list']) assert.ok(!resume.includes(bad), `resume.md must not say: ${bad}`);
});

test('execute-plan orders each gate after what it needs', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const order = (text, names, where) => {
    let at = -1;
    for (const n of names) {
      const i = text.indexOf(n, at + 1);
      assert.ok(i > at, `${where}: "${n}" must come after the previous gate`);
      at = i;
    }
  };
  // Step 6: the fork exists before its Files list, the brief, the snapshot and task-start.
  order(s[6], ['scripts/wt-fork', 'plan-check --files', 'scripts/task-brief', 'scripts/wt-snap', 'scripts/task-start'], 'step 6');
  // The wrapped brief is written, then checked, then dispatched.
  order(bullet(body, 'delegate'), ['briefs/task-N.brief.md', 'scripts/brief-check', 'dispatch only on `brief-check: ok`', '`kern:implementer`'], 'delegate');
  // Step 8: snapshot, package with the allow list, review, then record.
  order(s[8], ['`wt-snap`', 'scripts/wt-diff', '--allow-file', 'kern:task-reviewer', 'reviews/task-N-r<r>.txt', 'scripts/task-review'], 'step 8');
  // Step 5: the base tree is taken after the baseline run, so test output is not in the final package.
  order(s[5], ['scripts/wt-new', 'baseline `test.full`', '`Worktree: <path>'], 'step 5');
  // Step 9: the fix round line is written before the round's dispatch.
  order(s[9], ['`Task N: fix round=<r> tree=<id>`', 'Round 2 resumes', 'round 3 dispatches', '`re-review`', 'saved and recorded'], 'step 9');
  // Step 10: task-done, then the autopilot commit; step 11: applied, then the Applied line.
  order(s[10], ['scripts/task-done', 'Under autopilot only, then commit'], 'step 10');
  order(s[11], ['scripts/wt-apply', '`Applied: Task N patch=<path>` after each `applied`', '`test.full`'], 'step 11');
  // Step 12: the summary list exists before the final review that triages it.
  order(s[12], ['ledger-open --summary', 'reviews/final.diff', 'whole-branch', 'One fix subagent', 're-review'], 'step 12');
});

test('execute-plan red flags tell the reader what to do', () => {
  const { body } = readDoc(SKILL);
  const rows = (section(body, '## Red flags') ?? '').split('\n').filter((l) => /^\| "/.test(l));
  assert.equal(rows.length, 6);
  for (const n of ['Fix them or reach round 3 and escalate.', 'Resume the implementer, then re-review.', 'Stop with a split proposal.', 'Re-review every fix.',
    'Argue it in the re-review. At the cap, the split proposal names it.', 'Write each line as it happens.']) {
    assert.ok(rows.some((r) => r.includes(n)), `red flags must contain: ${n}`);
  }
});

test('every dispatch passes a model and an effort', () => {
  const MS = 'skills/execute-plan/references/model-selection.md';
  assertContains(MS, ['| Role | Setting | Default | Effort | Up a tier when |', 'Name the model and pass `effort` in every Agent call', 'keep lookups and transcript mining at `low`', '`model.<role>.effort`']);
  assertContains('kernel/kernel.md', ["Agent calls pass their role's model and effort: {KERN}/execute-plan/references/model-selection.md."]);
  for (const role of ['implementer', 'reviewer', 'final_review', 'investigator', 'miner']) assertContains('kernel/settings.md', [`| \`model.${role}.effort\` |`]);
  assertContains('skills/execute-plan/SKILL.md', ['Under autopilot, end the report with a catch-up per `${CLAUDE_PLUGIN_ROOT}/skills/recall/references/chat.md`.']);
});
