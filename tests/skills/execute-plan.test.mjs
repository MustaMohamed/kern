// tests/skills/execute-plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/execute-plan/SKILL.md';
const LEDGER = 'skills/execute-plan/references/ledger-format.md';

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
  assertMaxBytes(SKILL, 12000);
});

test('ledger format and model table', () => {
  assertHeadings(LEDGER, ['# Ledger format', '## Lines', '## Resume rule', '## Tree ids']);
  assertContains(LEDGER, ['# kern ledger: <plan path>', 'Main: <root> branch=<name> status=<hash>',
    'Task N: start tree=<id> at=<iso>', 'Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>',
    'Task N: minor (deferred): <text>', 'Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok, inconclusive or skipped (reason)> last=<line>',
    'parked: <question>; default: <choice>; why: <one line>']);
  assertMaxBytes(LEDGER, 2600);
  assertHeadings('skills/execute-plan/references/model-selection.md', ['# Model selection', '## Table', '## Rules']);
  assertMaxBytes('skills/execute-plan/references/model-selection.md', 1600);
});

// Load-bearing lines, pinned to the step that carries them. Each pin fails the test when it is removed.
export const PINS = {
  intro: ['A script exit not named here stops the run: report its output.', 'A subagent gets absolute paths (`${CLAUDE_PLUGIN_ROOT}` resolved) and a named model'],
  1: ['run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open <plan>`', "exits 2 when the plan has no `status: approved` with the user's quoted words, or when the dir holds another plan's ledger: stop and report it",
    "Never edit the plan's approval.", 'The mode is the typed one, else `execution:`.', 'resumes as `references/ledger-format.md` says', 'trust the ledger and the worktree over memory'],
  2: ['Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'any exit but 0 is a plan defect: stop before Task 1 and report its output', 'Then `plan-check --graph <plan>`', 'each `overlap` row becomes a `Preflight:` line with its ruling', 'keep the `wave` rows for step 4'],
  3: ['stop and ask before Task 1', 'A mechanical one gets a `Decision:` line.'],
  4: ['at most `parallel.max`', 'unless parallel-work step 1 finds an overlap', 'spawn them in one message as `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` step 4 does',
    'Other tasks run serially, in task order.', 'over their joined Files lists; the ledger scripts still run per task'],
  5: ['Once, unless a `Worktree:` line exists', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <plan-slug> --base <plan base>`', '(`<plan-slug>` is the ledger dir\'s name)', 'adding `--branch <name>` when `branch.pattern` holds `{id}`', 'Exit 2: say why and ask.',
    'Write `Worktree: <path> branch=<name> base-tree=<id>`, the id from `wt-snap`', 'both exit 3: ask', 'a red baseline goes to the user'],
  6: ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <plan-wt> <plan-slug>-task-<N>` (exit 2 or 3: say why and ask)',
    'run `plan-check --files <plan> <N> > <ledger dir>/briefs/task-N.files`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-brief <plan> <N> <ledger dir>`',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` (`tree-before`)', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-start <ledger> <N> <tree-before>`', 'exit 2 from any: stop',
    "Write `Wave: tasks <list> forks=<paths>` once a wave's forks exist."],
  step: ['`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`', 'reporting to `<ledger dir>/reports/task-N.md`', 'run steps 8 to 10, report, and stop'],
  inline: ['in the plan worktree, with absolute paths and `git -C`'],
  delegate: ['`${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/brief-template.md`', 'SCOPE the `.files` paths, the worktree and `<base-ref>` (the plan branch)',
    'CONTEXT `briefs/task-N.md`, the upstream Interfaces and the step 3 rulings', 'VERIFY `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` first',
    'REPORT `<ledger dir>/reports/task-N.md`', 'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check` on it', '(else fix each printed line)',
    '`kern:implementer` with its model, the brief, worktree, `<base-ref>`, report path and implement SKILL.md path', 'kern made the worktree'],
  7: ['Status line (none: BLOCKED).', 'DONE_WITH_CONCERNS: read the concerns, then review.', 'NEEDS_CONTEXT: answer from the plan or spec, else ask the user, then resume the implementer.',
    'go one model tier up, with a `Decision:` line', 'a task that must be split: stop with a split proposal'],
  8: ['take `tree-after` with `wt-snap`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before> <tree-after> --out <ledger dir>/reviews/task-N-<tree7>.diff --allow-file <ledger dir>/briefs/task-N.files`',
    'Its first line is `<package>`, beside `<package>.patch`.', 'Exit 3 (empty): return the task to the implementer.', "Exit 4 names a file outside the task's Files: pause and ask.",
    '`kern:task-reviewer` on `model.reviewer` in mode `task`', 'do not pre-judge findings in the prompt', 'Resolve every "cannot verify" item yourself; a real gap is a spec issue.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger> <N> <tree-after> <round> <compliant|issues> <approved|needs-fixes>`, round 1 here',
    'adding `--minor "<finding>"` for each Minor finding, which waits for step 12'],
  9: ['Round r is the r-th review, 1 to 3.', 'Before rounds 2 and 3 write `Task N: fix round=<r> tree=<id>`, the tree just reviewed.',
    'Round 2 resumes the implementer with the findings verbatim', 'round 3 dispatches a fresh `kern:implementer` one tier up with a step 6 brief',
    '`--out <ledger dir>/reviews/task-N-fix<r>-<tree7>.diff`, same `--allow-file` and exits', 'gets a `re-review` with the findings',
    "Still open after round 3, or a re-review finds a bug in an earlier round's fix: stop and escalate with a split proposal", 'There is no fourth round; `task-review` refuses one.',
    'Each round packages its fix diff with `wt-diff` from the round\'s tree to a new `tree-after`'],
  10: ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-done <ledger> <N> <wt> <tree-after> --probe <package>.patch -- <task test command>`', 'one command (task-done runs no shell)',
    'or `--no-probe "<why>"` in place of `--probe` for a task with no test to probe', 'after fix rounds, remake `<package>` from `tree-before`',
    'only when an approved review saw this tree, the command passes, and the test fails with the change reversed', '`probe=inconclusive`', 'label that proof inferred; any other reason: ask',
    '`command exited <n>` (`<ledger dir>/logs/task-N.log`)', 'or exit 1 (the test passes with the change reversed): return the task to the implementer as the next round.', 'A changed or unapproved tree: review it.',
    'A probe error: stop.', 'Under autopilot only, then commit the task\'s files with `/kern:commit` steps 3 to 6, a wave task\'s after step 11.'],
  11: ['Apply each worker\'s patch to the plan worktree one at a time with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <package>.patch <plan-wt>`',
    'writing `Applied: Task N patch=<path>` after each `applied`', 'Exit 3 is a conflict with nothing applied: stop.', 'Then run `test.full` there; red: stop.'],
  12: ['Final review: `ledger-open --summary <ledger dir>` lists the Decision, parked, Preflight and deferred-minor lines', '`wt-diff <plan-wt> <base-tree> --out <ledger dir>/reviews/final.diff`',
    'mode `whole-branch` on `model.final_review`', 'to triage which minors block', 'in a step 6 brief, each fix red then green', 'packaged with an `--allow-file` per task'],
  13: ['`ledger-open --summary` must end with `main: unchanged`; anything else goes first in the report.', "No push or PR, no commit beyond step 10's"],
  14: ['Propose teardown, do not run it', '`${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows', 'the plan worktree once committed'],
  stops: ['Stops at steps 1 to 3 and 5 to 11; ask as a typed reply in chat', 'never through AskUserQuestion', 'on per the latest kern signal', 'a turn with no mode line changes nothing',
    'steps 1 and 2 and a failed `wt-new` still end the run, as nothing approves a plan (G20)', 'parked: <question>; default: <choice>; why: <one line>', 'a red baseline goes on, its red tests named as red before',
    'a stopped task stays open with every task blocked by it, and disjoint tasks continue', 'G5 allows only `git commit -m` or `-F <file>` on an unprotected branch',
    'Without autopilot `commits: ask` holds: no commit.', 'teardown never runs'],
  ledger: ["Lines no script writes are appended with `printf '%s\\n' '<line>' >> <ledger>`", 'one holding the word approved goes in with the Edit tool',
    'when every task has one, go to the final review', 'A started task keeps its `Task N: start` tree as `tree-before` (no second `task-start`)',
    'a snapshot still equal to it means nothing landed: dispatch again', 'A wave task resumes in the fork its `Wave:` line names.', 'Never re-dispatch a completed task.'],
};

// The mode bullets of step 6, by their leading backticked name.
const bullet = (body, mode) => (section(body, '## Steps') ?? '').split('\n').find((l) => l.startsWith(`   - \`${mode}\``)) ?? '';

test('execute-plan pins each step, the modes, the stops and the ledger rules', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const intro = body.slice(0, body.indexOf('## Steps'));
  const stops = section(body, '## Stops and autopilot') ?? '';
  const ledger = readDoc(LEDGER).raw;
  const where = { intro, step: bullet(body, 'step'), inline: bullet(body, 'inline'), delegate: bullet(body, 'delegate'), stops, ledger };
  for (const [k, needles] of Object.entries(PINS)) {
    const text = where[k] ?? s[Number(k)];
    for (const n of needles) assert.ok(text.includes(n), `${k}: must contain: ${n}`);
  }
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
  order(s[8], ['`wt-snap`', 'scripts/wt-diff', '--allow-file', 'kern:task-reviewer', 'scripts/task-review'], 'step 8');
  // Step 9: the fix round line is written before the round's dispatch.
  order(s[9], ['`Task N: fix round=<r> tree=<id>`', 'Round 2 resumes', 'round 3 dispatches', '`re-review`', '`task-review`'], 'step 9');
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
    'Record a Decision line with the cost if wrong.', 'Write each line as it happens.']) {
    assert.ok(rows.some((r) => r.includes(n)), `red flags must contain: ${n}`);
  }
});
