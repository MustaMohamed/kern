// tests/skills/execute-plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/execute-plan/SKILL.md';
const LEDGER = 'skills/execute-plan/references/ledger-format.md';
const RESUME = 'skills/execute-plan/references/resume.md';
const MS = 'skills/execute-plan/references/model-selection.md';

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
  assert.ok(s[6].includes('A verification task, one whose Files modify nothing and whose steps gather evidence, follows `references/verification.md` in every mode.'), s[6]);
  assert.equal(s.length, 15);
  assert.equal(s[0], DEFER);
  for (const script of ['ledger-open', 'plan-check', 'wt-new', 'wt-fork', 'wt-snap', 'wt-diff', 'wt-apply', 'task-start', 'task-brief', 'brief-check', 'task-review', 'task-done']) {
    assertContains(SKILL, [`\${CLAUDE_PLUGIN_ROOT}/scripts/${script}`]);
  }
  assertContains(SKILL, ['kern:implementer', 'kern:task-reviewer', 'Pass no `isolation` parameter', 'Never re-dispatch unchanged', 'split proposal',
    'plan-check --graph', 'plan-check --files', '--allow-file', 'Exit 4', '--minor', '--probe <package>.patch', 'return the task to the implementer',
    'Batch small tasks', 'closes in its forks (steps 6 to 10)', 'ledger-open --summary', 'One fix subagent gets the complete findings list',
    'main: unchanged', 'run them only on yes', '`<ledger>` below is `<ledger dir>/ledger.md`', 'briefs/task-N.brief.md', 'dispatch only on `brief-check: ok`',
    '--no-probe']);
  // 13,550 since pilot fix plan 2's Task 1 (raised from 12,599): step 10 sizes the plan worktree after each closed task
  // and asks at the first breach; MA-254 round 2 had the count at 22:40 and asked at 00:24, with the user gone.
  // 13,850 since its Task 3: steps 6 and 8 send a verification task to references/verification.md, and step 8 saves a review
  // with the Write tool.
  // 13,900 since group A fix round 1: step 10 records the user's size answer quoted, which finish-branch step 6 reads,
  // names the `git diff -w --shortstat` count and scopes "never `git add`" to the count; step 8 merges exit 3 and its exception.
  // 14,150 since the final review of pilot fix plan 2: step 10's size `Decision:` line carries `lines: <n> (<measure>)`
  // and the `-w` count (so finish-branch step 6 reads them), anchors the ask in the ledger, and writes the line from the
  // Size line's one-PR word when that was already over the limit; step 9 points a verification task's fix round to its two-round cap.
  // 15,200 since M3 part 1 Task 8 and its fix rounds 1 to 3: steps 5, 8 and 10 keep a run going, the section separates a
  // stop from a judgment call and says how a go and an open task end, and a refused path counts as a review, after word cuts.
  // 15,700 since M3 part 1's Task 15: step 1 names ledger-open's working-file refusal, step 10 task-done's timeout and a refused
  // `--no-probe`, step 11 the one-run rule, step 12 the saved return, after the dead parameter's words and `size-check`'s path went.
  // 16,150 since its fix rounds 1 and 2: step 10's timeout rule and task-start line, step 11's saved log, step 12's worktree, spec
  // and rules and its saved return's first line, after word trims.
  // 16,371 since M3 part 2 project 1's Task 9: under a go, a baseline `test.full` with nothing resolved builds by the closest
  // check and opens no PR, after step 4's "each in its fork" went.
  // 16,525 since its Task 17 (2026-10-22 Opus audit section 5, rows L476 and L492): step 9 sends a fix report that lacks its
  // covering tests, command or output back once before the re-review, and rounds 2 and 3 get the standing orders and
  // resume.md's parked-finding pointers, after the intro's restated tree names went.
  assertMaxBytes(SKILL, 16525);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ["SKILL.md at most 16,525 bytes (16,371 until M3 part 2 project 1's Task 17:", 'rows L476 and L492; 16,150 until']);
  assertHeadings('skills/execute-plan/references/verification.md', ['# Verification tasks', '## Brief', '## Review', '## Close']);
  // 1,350 since the final review of pilot fix plan 2: round 2's review is `evidence` too, on the new report, not re-review.
  assertMaxBytes('skills/execute-plan/references/verification.md', 1350);
  assertContains('skills/execute-plan/references/verification.md', ['Its Files modify nothing.', 'a value with no stored output proves nothing',
    'mode `evidence`', 'At most two rounds, the review and one fix round', "Round 2's review is `evidence` too, on the new report, not `re-review`.",
    'A state still unproven after round 2: stop and ask, naming each one; never start a third round.',
    '--no-probe "verification task: no code"', '`wt-diff` exits 3 by design: say so in the review prompt and go on.']);
  assertContains(SKILL, ["| `pr.max_lines`, `pr.size_command` | 300 lines; none | step 10's size |"]);
});

test('ledger format and model table', () => {
  assertHeadings(LEDGER, ['# Ledger format', '## Lines', '## Resume rule', '## Tree ids']);
  assertContains(LEDGER, ['# kern ledger: <plan path>', '| `Plan: <hash>` | `ledger-open` |', 'Main: <root> branch=<name> head=<sha> status=<hash>',
    'Task N: start tree=<id> at=<iso>', 'Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>',
    'Task N: minor (deferred): <text>', 'Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok or skipped (reason)> last=<line>',
    'parked: <question>; default: <choice>; why: <one line>', 'a `task-review ... approved` call included: append it in a call of its own.']);
  // 2,750 since pilot fix plan 2's Task 9 (raised from 2,600): append in a call of its own beside a task-review approved call.
  assertMaxBytes(LEDGER, 2750);
  assertHeadings('skills/execute-plan/references/model-selection.md', ['# Model selection', '## Table', '## Rules']);
  assertMaxBytes('skills/execute-plan/references/model-selection.md', 1600);
  assertHeadings(RESUME, ['# Resume', '## Where to continue', '## Fix loop memory']);
  // 2,700 since M3 part 1's Task 14 and its fix rounds 1 and 2 (raised from 2,500): case 1 names the adopt and what it reuses,
  // and a snapshot equal to `tree-before` waits for a worker this session dispatched, then snapshots again.
  // 2,735 since its Task 15: a resumed fix round names step 9, and step 8 only for a refused round, after a word cut.
  // 2,953 since its final review's fix (M10): case 1 names the way out of a refused adopt.
  // 3,523 since M3 part 2 project 1's Task 17 (audit section 5, rows L476 and L492): a worker that returns after its task
  // was recorded reconciles against the ledger, every resume re-pastes the standing orders, and each fix round gets a
  // pointer to the parked findings on its paths. Every other line here is pinned, so nothing was cut.
  assertMaxBytes(RESUME, 3523);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ["`resume.md` 3,523 (2,953 until M3 part 2 project 1's Task 17:", 'rows L476 and L492']);
});

test('resume names the way out of a refused adopt', () => {
  // M3 part 1 final review, M10: wt-new says why and step 5 says ask, and no text named the recovery.
  assertContains(RESUME, ['A refused adopt names what the worktree holds: the user saves that work elsewhere and removes the worktree and its branch, then step 5 runs again. A setup that rewrites a tracked file refuses every adopt until it stops.']);
});

// Load-bearing lines, pinned to the step that carries them. Each pin fails the test when it is removed.
export const PINS = {
  intro: ['An unnamed script exit stops the run: report its output.', 'Subagents get absolute paths (`${CLAUDE_PLUGIN_ROOT}` resolved) and a named model and effort',
    'Only the scripts write `Task N: start`, review, minor and `Task N: complete` lines.'],
  1: ['run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open <plan>`', "exits 2 when the plan has no `status: approved` with the user's quoted words, when it or its spec sits under `WORK/ledgers`, `WORK/reviews` or `WORK/tmp`, or when the dir holds another plan's ledger: stop and report it",
    "Never edit the plan's approval.", 'The mode is the typed one, else `execution:`.',
    'Line formats and how to append them: `references/ledger-format.md`.',
    'If the ledger already held lines past `Main:`, or after compaction, read `references/resume.md` and continue where it says.'],
  2: ['Steps 2 and 3 run on every invocation, fresh or resumed,', 'add a `Preflight:`, `Decision:` or `parked:` line only when the ledger lacks that exact line.',
    'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'any exit but 0 is a plan defect: stop before any task and report its output', 'Then `plan-check --graph <plan>`',
    'each `overlap` row becomes a `Preflight:` line with its ruling', "this run's `wave` rows feed step 4"],
  3: ['one todo per task', 'A spec or scope conflict the graph does not show: stop and ask; record the answer, or a mechanical call, as a `Decision:` line.'],
  4: ['at most `parallel.max`', 'unless parallel-work step 1 finds an overlap', 'spawn them in one message as `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` step 4 does',
    'Others run serially, in task order.', 'Batch small tasks of one shape (the same one-line edit across files) into one dispatch and one review over their joined Files lists'],
  5: ['Once, make the plan worktree', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <plan-slug> --plan <plan> --adopt`', "(`<plan-slug>`: the ledger dir's name)",
    "adding `--branch <name>` when `branch.pattern` holds `{id}` (the plan's `issue:`, with quotes and a leading `#` removed).", 'Exit 2: say why and ask.', 'both exit 3: ask', 'a red baseline goes to the user',
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
    'Its first line is `<package>`, beside `<package>.patch`.', "Exit 3 (empty): return the task to the implementer, unless it is a verification task, whose diff is empty by design: review it as `references/verification.md` says.", "Exit 4 names a file outside the task's Files: pause and ask",
    'on a yes append it to `briefs/task-N.files` with a `Decision:` line, on a no return the task to the implementer',
    "Under autopilot, try each path against a `generated_artifacts` command: move the path to `kern-dir tmp`'s `task-N/<path>`, rerun the command in `<wt>` and see it return. That is a yes: retake `tree-after` and rerun `wt-diff`.",
    "Any other path is a no: move it back, save them as `reviews/task-N-r<r>.txt`, opening `Refused paths, no review saw this tree`, record `task-review <ledger> <N> <tree-after> <r> issues needs-fixes` and go to step 9, whose round packages from `tree-before` and reviews in mode `task` (a verification task: `evidence`): no review saw this tree.",
    '`kern:task-reviewer` on `model.reviewer` in mode `task`', 'do not pre-judge findings in the prompt',
    "Save its return as `<ledger dir>/reviews/task-N-r<r>.txt`, r = 1 + the task's review lines.", 'Resolve every "cannot verify" item yourself and rule on each "Declined to judge" line',
    'A real gap is a spec issue; add it to that `.txt` as a finding.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger> <N> <tree-after> <r> <compliant|issues> <approved|needs-fixes>`',
    'adding `--minor "<finding>"` for each Minor finding, which waits for step 12',
    'Use the Write tool: G20 may deny a shell write of text that holds approved.'],
  9: ['a verification task: `references/verification.md` (its two-round cap)',
    'Before rounds 2 and 3 write `Task N: fix round=<r> tree=<id>`, the tree just reviewed.', "Round 2 resumes the implementer with the previous round's `.txt`",
    "(SendMessage to its agent id, or `references/resume.md`'s fallback; inline and step: fix it yourself)",
    'round 3 dispatches a fresh `kern:implementer` one tier up with a step 6 brief, the report and that file',
    "Each round packages its fix diff with `wt-diff` from the round's tree to a new `tree-after`", '`--out <ledger dir>/reviews/task-N-fix<r>-<tree7>.diff`, same `--allow-file` and exits',
    'gets a `re-review` with that file, dispatched, saved and recorded as step 8 does',
    "Still open after round 3, or a re-review finds a bug in an earlier round's fix: stop and escalate with a split proposal", 'there is no fourth round.'],
  10: ['`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-done <ledger> <N> <wt> <tree-after> --probe <package>.patch -- <task test command>`',
    'or `--no-probe "<why>"` in place of `--probe` for a task with no test to probe (docs or config paths, an empty diff).', 'One command, no shell: a compound `Run:` goes in a `kern-dir tmp` script, passed as `-- bash <path>`.',
    'After fix rounds, remake `<package>` from `tree-before`.',
    'only when an approved review saw this tree, the command passes, and the test fails with the change reversed (`probe=ok`) or `--no-probe` gave a reason.',
    'A refusal writes nothing and says why.', '`command exited <n>` or exit 1 (the test passes with the change reversed): return the task to the implementer as the next round',
    '(after round 3: the split proposal)', '`command exited 126` or `127`: stop.',
    'Exit 3, an inconclusive probe: rerun with `--no-probe "probe inconclusive: <reason>"` only for a new module or export, or a patch of test files only; else stop and ask.',
    'Under autopilot, exit 3 with no allowed `--no-probe` reason is a required check that cannot run.',
    'Exit 2: a changed or unapproved tree, review it; a refused `--no-probe` (a path outside docs and config, no could-not-judge record): rerun with `--probe`; no start line: run `task-start` with `tree-before`, then rerun; a probe error, stop.',
    "`task-done`'s Bash timeout is the tool's default or five times the test's time plus setup, whichever is longer, capped at the tool's 10 minutes. Longer, or cut off once: the Bash tool's background mode, never `&`; wait for its notification, then read its exit and the ledger.",
    "Under autopilot only, then commit the task's files with `/kern:commit` steps 2 to 6 (a wave task: after step 11).",
    "Then task-done's `size:` lines size the plan worktree (a wave: after step 11, `size-check <ledger>`)",
    'so untracked files count; never `git add` to count, not even `-N`.',
    'At `size: over`, or a `pr.size_command` count over `pr.max_lines` with no `size: decided`', "and the plan's Size line not already over that limit: stop before the next task and ask the `size: ask:` line's question word for word",
    '(a `pr.size_command` count: that question with its count)',
    'when the Size line was already over it, take its one-PR word with no ask',
    'Either way record the word, quoted, with `lines: <n> (<measure>)` and the `-w` count, in a `Decision:` line whose what opens with size; `split` ends the run.'],
  11: ["apply each closed worker's patch to the plan worktree one at a time with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <package>.patch <plan-wt> --tree <complete line's tree>`",
    'writing `Applied: Task N patch=<path>` after each `applied`', 'Exit 3 is a conflict with nothing applied: stop.', 'Then take `<id>` with `wt-snap` and run `test.full` there, saving its output as `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/references/evidence.md` says; red: stop.',
    'A `test.full` that passed on tree `<id>` in this run stands for that tree; a step that would rerun it on that tree cites the run. Runs on other trees stay.'],
  12: ["`ledger-open --summary <ledger dir>` lists the ledger's rulings and minors, then the main checkout's state", '`wt-diff <plan-wt> <base-tree> --out <ledger dir>/reviews/final.diff`',
    "(the `Worktree:` line's base tree)", 'mode `whole-branch` on `model.final_review`', 'to triage which minors block', 'Re-grade findings by effect.',
    'Save its return as `<ledger dir>/reviews/final.txt` with the Write tool, opening `Spec given: <absolute path or none> tree=<id>`, `<id>` from `wt-diff`\'s second output line.',
    'One fix subagent gets the complete findings list, real gaps included (`kern:implementer`, a step 6 brief), each fix red then green',
    "one `re-review` on `model.final_review` of its diff from `wt-diff`'s second output line, packaged with an `--allow-file` per task", 'Residual findings go to the user in step 13.'],
  13: ['`ledger-open --summary` must end with `main: unchanged`; anything else goes first in the report.', "No push or PR, no commit beyond step 10's (autopilot: below)"],
  14: ['Propose teardown, do not run it', '`${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows', 'the plan worktree once committed'],
  stops: ['Ask at each stop as a typed reply in chat, never through AskUserQuestion.', 'on per the latest kern signal', 'a turn with no mode line changes nothing',
    'When on, steps 1 and 2 and a failed `wt-new` still end the run.', 'A later judgment call parks as `parked: <question>; default: <choice>; why: <one line>` in the ledger and takes its default (', 'a red baseline goes on, naming red-before tests',
    'Any other stop waits for a typed reply, with the data and a recommendation: a stopped task stays open with every task blocked by it, and disjoint tasks continue',
    'Without autopilot `commits: ask` holds: no commit.',
    'Push and a draft PR only through finish-branch, which a go runs after step 13.', "A task still open at step 13 means push, report, and no PR: `/kern:commit` steps 2 to 6 on the dirty paths in that task's `briefs/task-N.files`, under commit's no-PR end rule, then finish-branch's end path, skipping steps 4 to 8 (a wave task: report its fork); teardown never runs.",
    "the size stop takes one PR, why: a split is the user's scope call and a draft can be closed"],
  ledger: ['Only the scripts write `Task N: start`, review, minor and `Task N: complete` lines; never write or edit one by hand.',
    "A batch of tasks shares one brief, package and review, and the scripts still write each task's lines.",
    "The other lines are appended with `printf '%s\\n' '<line>' >> <ledger>`",
    "Limit: no guard yet stops an Edit or Write that forges a script's line; that guard is deferred to M3.",
    'A task is done only when its `Task N: complete` line exists. Where a run resumes is in `resume.md`.',
    "| any step | a ruling: the user's answer to a stop, a mechanical call made without the user, or a \"Declined to judge\" ruling |"],
  resume: ['Read this when the ledger already holds lines past `Main:`, and after compaction.', 'Trust the ledger and the worktrees over memory.',
    'Steps 2 and 3 run again on every invocation and add only the lines the ledger lacks', 'plan-check and its `wave` rows come from this run',
    'a step 3 conflict with no `Decision:` line is asked again (under autopilot, parked once)', 'r is 1 plus its review lines.', 'The first case that holds, in this order:', '1. No `Worktree:` line: step 5. Its `wt-new --adopt` reuses a clean worktree a stopped step 5 left and finishes its setup; on a free path an adopt makes a worktree.',
    '2. A task on a `Wave:` line has its `Task N: complete` line but no `Applied: Task N patch=<path>` line: step 11 for it, before the final review or any later task.',
    'A task a `parked:` line holds stays out, with every task blocked by it.', '3. The first task in task order with no `Task N: complete` line, by its last line, `minor (deferred)` lines skipped:',
    '- none: step 6.', 'keep that tree as `tree-before`, with no second `task-start`', 'A snapshot still equal to it: a worker this session dispatched may still run, so wait for its notification and snapshot again.', 'Still equal, or no such worker (a new session has none): dispatch again.',
    "A changed snapshot waits until the implementer has stopped, its report holding that round's `Status:` line: DONE or DONE_WITH_CONCERNS goes to step 8 as round r, any other status (or none) to step 7",
    'until then wait for it or resume it (step and inline: finish the change first)', 'a review that did not approve: write `Task N: fix round=<r> tree=<id>` with the reviewed tree and continue step 9',
    'an r of 4 is past the cap, so stop with a split proposal', '`Task N: fix round=<r> tree=<id>`: resume that round', 'a fresh snapshot that differs from its tree is',
    "the round's `tree-after`, and its `Status:` line sends DONE or DONE_WITH_CONCERNS to step 9's fix diff (a `Refused paths` file: step 8), else to step 7.",
    '- an approving review: step 10.', '4. Every task complete and applied: step 12.', "A wave task resumes in the fork its `Wave:` line names.", 'Never re-dispatch a completed task.',
    "Round r's findings are the reviewer's return saved as `<ledger dir>/reviews/task-N-r<r>.txt`, with any real gap step 8 appended. The next round gets that file.",
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

test('execute-plan keeps one review flow, with the dead Agent parameter gone from the four files that held it', () => {
  // M3 part 1 Task 15. The Agent tool takes no run_in_background, so reviews come back as notification turns whatever
  // the text says (design, Cost and speed: "Remove the dead `run_in_background` text and keep one review flow").
  // Parallel-work step 4 and the skills spec's copy of it went in the final review's fix (M8).
  for (const f of [SKILL, MS, 'skills/plan/SKILL.md', 'skills/define/SKILL.md', 'skills/parallel-work/SKILL.md']) assert.ok(!readDoc(f).raw.includes('run_in_background'), f);
  assert.ok(!readDoc('docs/specs/2026-10-12-kern-m1-m2-skills.md').raw.includes('in one message with `run_in_background: true`'));
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[8].includes('Dispatch `kern:task-reviewer` on `model.reviewer` in mode `task` with `briefs/task-N.md`'), s[8]);
  assert.ok(s[9].includes('gets a `re-review` with that file, dispatched, saved and recorded as step 8 does'), s[9]);
  assert.ok(s[12].includes('dispatch `kern:task-reviewer` in mode `whole-branch` on `model.final_review` with the package'), s[12]);
  assert.ok(s[12].includes('packaged with an `--allow-file` per task, dispatched as the whole-branch review is.'), s[12]);
});

test('the final review is the same proof as self-review\'s spec lane, so one can stand for the other', () => {
  // M3 part 1 Task 15 fix round 1, I1: this review never saw acceptance text, `States:`, `Handles:` or Not doing lines, and got no
  // `review.rules`, while self-review's lane skipped on its word. It now takes what the lane takes and asks what the lane asks.
  const s = steps(readDoc(SKILL).body);
  // Fix round 2, I1: with no worktree path, the reviewer's one allowed read hit the main checkout and base code.
  assert.ok(s[12].includes("with the package, `<plan-wt>`, the plan, that list, the plan's `spec:` file, if any, and the `review.rules` files, to triage which minors block."), s[12]);
  const lane = steps(readDoc('skills/self-review/SKILL.md').body)[4];
  assert.ok(lane.includes('the `review.rules` files'), lane);
  // Fix round 2, C1: both dispatch mode `whole-branch` with a spec, so the ask lives once, in that mode. These two files load on every run.
  for (const t of [s[12], lane]) {
    assert.ok(t.includes('`whole-branch`'), t);
    assert.ok(!t.includes('what is missing, partial, unasked or wrong'), t);
  }
  const mode = readDoc('agents/task-reviewer.md').body.split('\n').find((l) => l.startsWith('- `whole-branch`:')) ?? '';
  assert.ok(mode.includes('Given a spec, also ask what is missing, partial, unasked or wrong, quoting spec lines.'), mode);
});

test('execute-plan rules on each "Declined to judge" line and reports it in step 13', () => {
  // Task 17 lanes 3 and 5: kern:task-reviewer writes a "Declined to judge" list in task and whole-branch mode
  // (agents/task-reviewer.md), but no execute-plan step read it, so a behaviour the reviewer set aside was dropped
  // silently. superpowers' executor rules on each line and ledgers it (executing-plans/SKILL.md:260-264;
  // requesting-code-review/code-reviewer.md:43-48). Each ruling is a Decision: line, so ledger-open --summary lists
  // it for the final review and step 13 after compaction, whose "report decisions" carries it. A real gap is a spec
  // issue, so step 9's fix loop takes it at any grade.
  const s = steps(readDoc(SKILL).body);
  // Fix round 1, Important 1: the rule names re-reviews, so step 9's and step 12's re-reviews rule on their lines too.
  const rule = 'Resolve every "cannot verify" item yourself and rule on each "Declined to judge" line of every review and re-review in a `Decision:` line: settled by spec or plan, the user\'s call at finish, or a real gap.';
  assert.ok(s[8].includes(rule), s[8]);
  // Fix round 1, Important 2: a real gap reaches the fix round as a finding, in the .txt that rounds 2 and 3 and a
  // resume read (resume.md's Fix loop memory), and in step 12's findings list.
  const gap = 'A real gap is a spec issue; add it to that `.txt` as a finding.';
  // The ruling comes after the return is saved and before the verdicts are recorded, as a gap changes the spec verdict.
  const at = ['reviews/task-N-r<r>.txt', rule, gap, 'scripts/task-review'].map((n) => s[8].indexOf(n));
  assert.ok(at.every((i, k) => i >= 0 && (k === 0 || i > at[k - 1])), s[8]);
  assert.ok(s[9].includes('dispatched, saved and recorded as step 8 does'), s[9]);
  assert.ok(s[12].includes('One fix subagent gets the complete findings list, real gaps included'), s[12]);
  assertContains(RESUME, ["Round r's findings are the reviewer's return saved as `<ledger dir>/reviews/task-N-r<r>.txt`, with any real gap step 8 appended. The next round gets that file."]);
  assert.ok(s[13].startsWith('13. Finish: report decisions with the cost if wrong, parked items'), s[13]);
  // Fix round 1, Minor 2: the ledger format names this use of a Decision: line.
  assertContains(LEDGER, ["| `Decision: <what>; why: <one line>; cost if wrong: <one line>` | any step | a ruling: the user's answer to a stop, a mechanical call made without the user, or a \"Declined to judge\" ruling |"]);
});

test('the task test command names no worktree path and has no cd, in step 10 and in the implementer agent', () => {
  // Audit C-I2, its text half (Task 17a P7): task-done runs the command in the worktree, and probe runs it again
  // in a fork with the change reversed. A command or script that cds to the worktree's absolute path ran the
  // reversed test in the unreversed worktree; probe now exits 3 for it (P4). agents/implementer.md said "start
  // shell commands with `cd <WT> &&`", and plans often wrote `Run:` that way (lane C, I2).
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[10].includes('passed as `-- bash <path>`. Neither may `cd` or name the worktree\'s absolute path: task-done runs them there and in the fork.'), s[10]);
  const rule = readDoc('agents/implementer.md').body.split('\n').find((l) => l.startsWith('1. Work only in WT.')) ?? '';
  assert.ok(rule.includes('so start shell commands with `cd <WT> &&`; the test command you report has no `cd` and names WT\'s files by relative path, as the controller runs it in WT and in a fork.'), rule);
});

test('only the user\'s word skips the final review; task-done refuses a task no review approved', () => {
  // The user's "Only by my word" (2026-10-22, Task 16n): a gating review is skipped only when the user says so. The
  // kernel's Routing line states it for every route; task-done already refuses a tree no approved review saw.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[12].startsWith("12. Final review (only the user's word skips it): `ledger-open --summary <ledger dir>`"), s[12]);
  assert.ok(s[10].includes('only when an approved review saw this tree'), s[10]);
});

test('a step that needs an agent\'s return waits for it, by the file every Agent call follows', () => {
  // Task 16i review, M4: self-review's lanes, recall's miners, plan's and diagnose's investigators and execute-plan's
  // serial and fix implementers gate their next step. M3 part 1 Task 15: subagents report by notification, so this
  // one rule, in the file the kernel's Context line names, holds plan step 12's ask behind its review, and the rest.
  assertContains(MS, ["- When your next step needs an agent's return, wait for it."]);
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
  assertContains(MS, ['| Role | Setting | Default | Effort | Up a tier when |', 'Name the model and pass `effort` in every Agent call', 'keep lookups and transcript mining at `low`', '`model.<role>.effort`']);
  assertContains('kernel/kernel.md', ["Agent calls pass their role's model and effort: {KERN}/execute-plan/references/model-selection.md."]);
  for (const role of ['implementer', 'reviewer', 'final_review', 'investigator', 'miner']) assertContains('kernel/settings.md', [`| \`model.${role}.effort\` |`]);
  assertContains('skills/execute-plan/SKILL.md', ['Under autopilot, end the report with a catch-up per `${CLAUDE_PLUGIN_ROOT}/skills/recall/references/chat.md`.']);
});

test('under autopilot a stop waits, a judgment call parks, and a generated file or a dead probe does not end a task unseen', () => {
  // M3 part 1 Task 8. The pilot's run stops came from step 8's exit 4 on generated files and from step 10's exit 3.
  // Task 6's review: this route said a later stop parks, and run.md says a stop waits for a typed reply.
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const auto = section(body, '## Stops and autopilot');
  assert.ok(!auto.includes('A later stop parks'), auto);
  assert.ok(auto.indexOf('A later judgment call parks') < auto.indexOf('Any other stop waits'), auto);
  // The autopilot rule follows the plain one in each step, so without autopilot exit 4 still asks and exit 3 still stops.
  assert.ok(s[8].indexOf('pause and ask') < s[8].indexOf('Under autopilot, try each path'), s[8]);
  assert.ok(s[10].indexOf('else stop and ask.') < s[10].indexOf('Under autopilot, exit 3'), s[10]);
  assertContains('skills/autopilot/references/run.md', ['| A required check that cannot run |', 'commits, pushes its branch, stops with the report, naming the check as `fail`, and opens no PR.']);
  assertContains('skills/finish-branch/SKILL.md', ["a required check that cannot run, or run.md's stop on a defect the ticket demands or on a change it does not name: the run commits its work, pushes its branch"]);
  // Step 13's own "No push or PR" holds without autopilot; the section says what a go does.
  assert.ok(s[13].includes("No push or PR, no commit beyond step 10's (autopilot: below); offer `/kern:commit` and `/kern:finish-branch`."), s[13]);
  // Task 7 review: finish-branch's end path commits past a red proof, and an open task's end follows the same rule.
  assertContains('skills/commit/SKILL.md', ["execute-plan's task still open at step 13, run.md's stop on a defect the ticket demands or on a change it does not name), a red or unrunnable step 4 proof is no stop"]);
  // Step 10 commits each closed task, so the section does not say it again.
  assert.ok(s[10].includes("Under autopilot only, then commit the task's files with `/kern:commit` steps 2 to 6"), s[10]);
});

test('under a go, a baseline test.full with nothing resolved builds on by the closest check and opens no PR', () => {
  // M3 part 2 project 1 Task 9. Step 5's "both exit 3: ask" stopped a go before any code, while implement's route builds
  // by the closest check (design, "execute-plan stops with no `test.full` under a go"). The section carves the case out
  // for a go only: a person's run still asks at step 5, and steps 1 and 2 and a failed `wt-new` still end a go.
  const rule = 'Under a go, a baseline `test.full` with nothing resolved (`kern-get` and `kern-detect` both exit 3) is a required check that cannot run: build by the closest check, commit, push the branch, name `test.full` as `fail`, stop and open no PR.';
  const { body } = readDoc(SKILL);
  const auto = section(body, '## Stops and autopilot') ?? '';
  for (const n of ['Under a go, a baseline `test.full` with nothing resolved', 'the closest check', 'name `test.full` as `fail`', 'open no PR', rule]) assert.ok(auto.includes(n), n);
  assert.ok(auto.indexOf('When on, steps 1 and 2 and a failed `wt-new` still end the run.') < auto.indexOf(rule), auto);
  assert.ok(steps(body)[5].includes('(`kern-get`, else `kern-detect`; both exit 3: ask)'), steps(body)[5]);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [`under a go, ${rule.slice('Under a go, '.length, -1)}, while a person's run asks at step 5`]);
});

test('step 10 names task-done\'s refusals of --no-probe, so none is an unnamed exit', () => {
  // M3 part 1 Task 15. The step text and the script's refusals stay in step.
  assertContains('scripts/task-done', ['task-done: --no-probe takes only docs and config paths;', 'has no start line with a tree id, so --no-probe cannot see what it changed',
    "'probe inconclusive:' needs a --probe run of Task $n's whole patch on tree"]);
  const s = steps(readDoc(SKILL).body);
  const at = ['Exit 2: a changed or unapproved tree, review it;', 'a refused `--no-probe`', 'a probe error, stop.'].map((t) => s[10].indexOf(t));
  assert.ok(at[0] >= 0 && at[0] < at[1] && at[1] < at[2], s[10]);
  // The probe stays the path: a refused skip reruns it, and exit 3 keeps its own stop.
  assert.ok(s[10].includes('rerun with `--probe`;'), s[10]);
  // Fix round 1, M3: no start line takes the script's own action, on the step 6 tree: `tree-after` would shrink the change to nothing.
  assertContains('scripts/task-done', ['so --no-probe cannot see what it changed; run task-start']);
  assert.ok(s[10].includes('no start line: run `task-start` with `tree-before`, then rerun;'), s[10]);
  assert.ok(!s[10].match(/\(a path outside[^)]*no start line/), s[10]);
  assert.ok(s[10].includes('Under autopilot, exit 3 with no allowed `--no-probe` reason is a required check that cannot run.'), s[10]);
});

test('task-done\'s Bash timeout covers the test, the probe and its fork', () => {
  // M3 part 1 Task 15: the design's "`task-done` runs a test up to four times", and a call the tool cut off left no
  // complete line. A longer run does not lose a check: it only moves to the background.
  // Fix round 1, I4: three times sat at the normal run count, and a 5 s test fell under the tool's default.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[10].includes("`task-done`'s Bash timeout is the tool's default or five times the test's time plus setup, whichever is longer, capped at the tool's 10 minutes. Longer, or cut off once: the Bash tool's background mode, never `&`; wait for its notification, then read its exit and the ledger."), s[10]);
  assert.ok(!s[10].includes('three times'), s[10]);
});

test('a resumed fix round goes to step 9, and to step 8 only after a refused round', () => {
  // M3 part 1 Task 15: "routes it as above" named step 8's whole review for an ordinary fix round,
  // whose `Task N: fix round=` line step 9 wrote. A `Refused paths` round is the case resume already names.
  const lines = readDoc(RESUME).raw.split('\n');
  const fix = lines.find((l) => l.startsWith('   - `Task N: fix round=<r> tree=<id>`:')) ?? '';
  assert.ok(!fix.includes('as above'), fix);
  assert.ok(fix.includes("to step 9's fix diff (a `Refused paths` file: step 8), else to step 7."), fix);
  assertContains(RESUME, ["A file opening `Refused paths` takes step 8's no, not step 9's default"]);
});

test('step 5 builds {id} from a quoted issue value', () => {
  // M3 part 1 Task 5 review: a bare `#` opens a YAML comment, so a plan quotes it (`issue: "#853"`), and the quotes
  // and the `#` must not reach a branch name.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[5].includes('`{id}` (the plan\'s `issue:`, with quotes and a leading `#` removed)'), s[5]);
});

test('a task still open at step 13 commits its own paths, then takes finish-branch\'s end path', () => {
  // M3 part 1 Task 8 review, I3: commit parked at "no files, no commit", so the push dropped the open task's work; with
  // no complete task, commit step 3 fell back to `git status` and could stage paths step 8 refused; a wave task's work
  // sits in its fork; and finish-branch's end path had two cases, so a green proof could open a draft PR.
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  assert.ok(auto.includes("the dirty paths in that task's `briefs/task-N.files`, under commit's no-PR end rule, then finish-branch's end path, skipping steps 4 to 8 (a wave task: report its fork)"), auto);
  assertContains('skills/finish-branch/SKILL.md', ["The end path is a third round still `fix first`, a task still open at execute-plan's step 13, a required check that cannot run, or run.md's stop"]);
  // "/kern:commit steps 2 to 6" names commit's own steps: Where through the commit call, so step 1's consent and step 7's
  // report stay out, and step 3 takes the named files.
  const c = steps(readDoc('skills/commit/SKILL.md').body);
  assert.match(c[2], /^2\. Where:/);
  assert.ok(c[3].includes('propose this task\'s files or those named'), c[3]);
  assert.match(c[6], /^6\. Write the message .*`git -C <toplevel> commit -F <dir>\/commit-msg`/);
  assertContains('skills/commit/SKILL.md', ['finish-branch and, under autopilot, execute-plan run steps 2 to 6.']);
});

test('an open task\'s end leaves a refused path out, and finish-branch\'s skipped steps are the ones that would stage it', () => {
  // M3 part 1 Task 8 re-review: a path step 8 refused stays dirty, and finish-branch step 8 runs commit with no names,
  // whose step 3 falls back to `git status` when no task is complete. Skipping steps 4 to 8 means the only commit on
  // this path is the one that names `briefs/task-N.files`, and no proof or self-review runs on unreviewed work.
  const f = steps(readDoc('skills/finish-branch/SKILL.md').body);
  assert.ok(section(readDoc(SKILL).body, '## Stops and autopilot').includes("finish-branch's end path, skipping steps 4 to 8"));
  assert.match(f[3], /^3\. Base:/);
  assert.match(f[4], /^4\. Record the proven tree with .*, then prove `test\.full`/);
  assert.match(f[5], /^5\. Read `\$\{CLAUDE_PLUGIN_ROOT\}\/skills\/self-review\/SKILL\.md`/);
  assert.match(f[6], /^6\. Size gate:/);
  assert.match(f[7], /^7\. Show the menu/);
  assert.match(f[8], /^8\. Commit, for options 1 to 3: nothing to commit when `git status --porcelain` prints nothing;/);
  assert.match(f[9], /^9\. Dedup/);
  assert.match(f[10], /^10\. Push, for options 2 and 3: `references\/branch-ops\.md`, section Proven tree/);
  // With step 4 skipped no tree can match, so the push gate proves HEAD on a detached copy and reports `fail` when red.
  assertContains('skills/finish-branch/references/branch-ops.md', ['`git rev-parse HEAD^{tree}` must equal the tree from finish-branch step 4', 'If not, run `git rev-parse HEAD`', '--detach --base <HEAD sha>', 'run `test.full`', "On finish-branch's end path neither no push holds: report `fail`, push."]);
});

test('a refused path counts as a review, so r, the cap and resume all see it', () => {
  // M3 part 1 Task 8 re-review: r is 1 plus the review lines, and a "no" wrote none, so a first-pass "no" gave four
  // implementer passes and compaction lost the count. The saved file is round 2's "previous round's `.txt`".
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[8].includes('r = 1 + the task\'s review lines'), s[8]);
  assert.ok(s[8].includes('save them as `reviews/task-N-r<r>.txt`, opening `Refused paths, no review saw this tree`, record `task-review <ledger> <N> <tree-after> <r> issues needs-fixes`'), s[8]);
  // Task 8 re-review, N4: that line reads like a real review after compaction, and resume hands round r's file on, so
  // the file's first words stop step 9's default `re-review`. Task 8 fix round 4: resume says so, since without it a
  // correct fix shows the refused path as a change, `wt-diff` exits 4, and each round refuses again up to the split stop.
  assertContains(RESUME, ["Round r's findings are the reviewer's return saved as `<ledger dir>/reviews/task-N-r<r>.txt`", 'The next round gets that file.',
    "A file opening `Refused paths` takes step 8's no, not step 9's default: the next round packages from `tree-before` and reviews in mode `task` (a verification task: `evidence`)."]);
  // N3: a verification task's review is `evidence` in its own reference.
  assert.ok(s[8].includes('reviews in mode `task` (a verification task: `evidence`)'), s[8]);
  assertContains('skills/execute-plan/references/verification.md', ['mode `evidence`']);
  assertContains('scripts/task-review', ['# Usage: task-review LEDGER N TREE ROUND SPEC QUALITY', 'case "$spec" in compliant | issues)', 'case "$quality" in approved | needs-fixes)', 'case "$round" in 1 | 2 | 3)']);
  assertContains(RESUME, ['For a task, r is 1 plus its review lines.', '- a review that did not approve: write `Task N: fix round=<r> tree=<id>` with the reviewed tree and continue step 9']);
  // No reviewer saw that tree, so a fix diff alone would leave the task's own change unreviewed, and the refused path's
  // removal would itself be outside `--allow-file`.
  assert.ok(s[9].includes("Each round packages its fix diff with `wt-diff` from the round's tree"), s[9]);
  assert.ok(s[10].includes('After fix rounds, remake `<package>` from `tree-before`.'), s[10]);
});

test('a rerun that writes the same bytes shows nothing, so step 8 moves the path aside first and retakes the tree', () => {
  // M3 part 1 Task 8 re-review: a rerun of the same bytes leaves `git status` clean, and one of other bytes moves the
  // tree off `tree-after`, so `wt-diff` reuses the old tree and task-done exits 2.
  const s = steps(readDoc(SKILL).body);
  const at = (t) => s[8].indexOf(t);
  assert.ok(at('move the path to `kern-dir tmp`') < at('rerun the command in `<wt>`') && at('rerun the command in `<wt>`') < at('see it return') && at('see it return') < at('retake `tree-after`') && at('retake `tree-after`') < at('and rerun `wt-diff`'), s[8]);
  assert.ok(at('move the path to `kern-dir tmp`') > 0, s[8]);
  // Task 8 re-review: G21 denies a remove the default layout resolves outside `<wt>`, a same-effect retry stays blocked,
  // and a removed path that does not return leaves tracked P missing, so the path moves and a no moves it back. The
  // target carries the task and the path, so two paths with one base name do not collide.
  assert.ok(!s[8].includes('remove the path'), s[8]);
  assert.ok(s[8].includes('`task-N/<path>`'), s[8]);
  assert.ok(at('Any other path is a no: move it back,') > at('see it return'), s[8]);
  assert.ok(!s[8].includes('paths a rerun of that command writes'), s[8]);
});

test('step 13 names an applied closed task that stayed uncommitted', () => {
  // M3 part 1 Task 8 re-review, N5: step 10 commits a wave task after step 11, and a red `test.full` at step 11 stops
  // first. Skipping finish-branch step 8 skips commit's ledger pass, so that task stays dirty and out of the push.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[13].includes('Under autopilot, name each path an applied closed task left uncommitted.'), s[13]);
  assert.ok(s[11].includes('says; red: stop.'), s[11]);
  assert.ok(s[10].includes('(a wave task: after step 11)'), s[10]);
});

test('a slow worker gets a second snapshot before any dispatch, and a crash before the `Worktree:` line adopts', () => {
  // M3 part 1 Task 14 review. A worker that finished after the first snapshot had no second one, so a second implementer
  // ran over finished work; and a new session gets no notification from an ended session's worker, so a wait had no end.
  const lines = readDoc(RESUME).raw.split('\n');
  const start = lines.find((l) => l.startsWith('   - `Task N: start`:')) ?? '';
  const order = ['wait for its notification and snapshot again.', 'Still equal, or no such worker (a new session has none): dispatch again.', 'A changed snapshot waits until the implementer has stopped'];
  const at = order.map((o) => start.indexOf(o));
  assert.ok(at[0] >= 0 && at[0] < at[1] && at[1] < at[2], start);
  // A crash before the `Worktree:` line leaves the ledger ending at `Main:`, so step 1 never reads resume.md: only step 5's
  // own call can adopt, and an adopt on a free path makes the worktree as before.
  assert.ok(steps(readDoc(SKILL).body)[1].includes('If the ledger already held lines past `Main:`'));
  assert.ok(steps(readDoc(SKILL).body)[5].includes('scripts/wt-new <plan-slug> --plan <plan> --adopt`'));
  // Task work comes after step 5 writes the `Worktree:` line, so a task's resume takes cases 2 to 4 and never reaches the adopt.
  assert.equal(lines.filter((l) => l.includes('wt-new')).length, 1, 'only case 1 names wt-new');
});

test('a late worker reconciles against the ledger before its tree counts, and every resume re-pastes the standing orders', () => {
  // M3 part 2 project 1 Task 17 (2026-10-22 Opus audit section 5, row L476, from pstack orchestrate's zombie and
  // standing-orders rules). An implementer that could not be reached was replaced, and nothing said what to do when it
  // came back after all, so its tree could be reviewed or applied over the work that replaced it. A resume carried only
  // the findings, so the brief's standing orders faded across resumes.
  const where = section(readDoc(RESUME).body, '## Where to continue') ?? '';
  for (const n of ['a worker that returns after its task was recorded', 'against the ledger',
    'its tree counts only while that task has no `Task N: complete` line and no later round or other worker took it',
    'else discard that tree, unreviewed and unapplied, and note it in a `Decision:` line.', 'standing orders on every resume']) {
    assert.ok(where.includes(n), `resume.md's Where to continue must hold: ${n}`);
  }
  // The rule comes after "Never re-dispatch a completed task.", where a resume decides which worker's tree counts.
  assert.ok(where.indexOf('Never re-dispatch a completed task.') < where.indexOf('a worker that returns after its task was recorded'), where);
});

test('each fix round gets a ledger pointer to the parked findings on its paths', () => {
  // M3 part 2 project 1 Task 17 (audit section 5, row L492, from superpowers' subagent-driven-development, which
  // carries a pointer to a parked ledger entry into the dispatch that touches its area). A round got only the last
  // review's file, so a fix could redo a deferred Minor finding or undo an autopilot default it never saw.
  const memory = section(readDoc(RESUME).body, '## Fix loop memory') ?? '';
  for (const n of ['`parked:`', '`minor (deferred)`', 'a pointer, `<ledger>:<n>`,', 'naming a path in its Files or a task sharing one',
    'the final review owns a parked finding, so the round neither fixes nor undoes it.']) {
    assert.ok(memory.includes(n), `Fix loop memory must hold: ${n}`);
  }
});

test('step 9 sends a fix report back once when it lacks its covering tests, command or output, before the re-review', () => {
  // M3 part 2 project 1 Task 17 (audit section 5, row L492, from superpowers' fix loop: "confirm the fix report
  // contains the covering tests, the command run, and the output"). Step 9 went from the fix straight to its package
  // and re-review, so a round could reach the reviewer with no proof that its tests ran.
  const s = steps(readDoc(SKILL).body);
  const rule = 'A fix report lacking any of the covering tests, the command and its output goes back to its implementer once.';
  assert.ok(s[9].includes(rule), s[9]);
  assert.ok(s[9].indexOf('covering tests, the command and its output') < s[9].indexOf('re-review'), s[9]);
  // The check comes before the package, since a report sent back can change the tree the package is taken from.
  assert.ok(s[9].indexOf(rule) < s[9].indexOf('Each round packages its fix diff'), s[9]);
  // resume.md is read on a resumed run or as round 2's fallback, so step 9 names what its rounds take from it: a round in
  // one session with no compaction never opens resume.md.
  const carry = "Both also get the standing orders and `references/resume.md`'s parked-finding pointers.";
  assert.ok(s[9].includes(carry), s[9]);
  assert.ok(s[9].indexOf('round 3 dispatches') < s[9].indexOf(carry) && s[9].indexOf(carry) < s[9].indexOf(rule), s[9]);
  // A verification task's fix round keeps its own reference and cap.
  assert.ok(s[9].startsWith('9. Fix loop for a spec issue or a Critical or Important finding; a verification task: `references/verification.md` (its two-round cap).'), s[9]);
});
