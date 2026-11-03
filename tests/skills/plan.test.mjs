// tests/skills/plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, section, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/plan/SKILL.md';
const RUN = 'skills/autopilot/references/run.md';

test('plan frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'plan',
    description: 'Turn an approved spec into ordered tasks with exact files, test-first steps, verify commands and blocking edges.',
    'disable-model-invocation': 'true',
    'argument-hint': '[spec path | issue id]',
  });
});

test('plan sections and steps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 13);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['one fresh general-purpose subagent on `model.reviewer`', '| `model.investigator`, `model.reviewer` | `opus` |', 'No such file, even for a design the user calls decided: Read `${CLAUDE_PLUGIN_ROOT}/skills/define/SKILL.md` now and follow it, writing no plan;', 'gh pr list --search', 'never parallel', '`step`, `inline` or `delegate`', 'execution:', 'commits: ask',
    '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check', 'gets a spike first', 'prefactor', 'expand, migrate in batches, then contract', "spec's Constraints section",
    'on `model.investigator`', "one whole line of the user's yes, verbatim", 'visual pages not installed',
    'test-first steps that record decisions, not code', 'Self-review it for placeholders, type mismatches and proportion']);
  // 6,600 since the pilot fix plan's Task 5 (raised from 6,500): step 1 reads pr.max_lines, step 9 writes the Size line.
  // 6,700 since the pilot fix plan's Task 5 fix round: step 7 acts on pr.max_lines and states a limit in chat only.
  // 7,900 since M3 part 1 Task 5: a go takes the plan to approved on delegate, and over the threshold to its first slice.
  // 6,900 since its Task 15, a fall: the go's rules moved behind a pointer to run.md, for text most runs never use.
  // 7,041 since its final review's fix (I1, M6): under a go, steps 1 and 3 follow run.md's stop list and not an ask.
  // The full path in step 1, not "define's SKILL.md": case-inputs' closure follows skills/<n>/, and this step is plan's
  // only link to define since it stopped saying "route to define".
  // 7,086 since paid round 1's fix: an unapproved spec reads define now, in place of a route the runs did not take.
  // 7,128 since paid round 2's fix: "Not approved" read as a spec that exists, so step 1 says no such file, even for a decided design.
  // 7,133 since paid round 3's fix: step 9 runs git branch --show-current, and only empty output gives the detached line.
  // 7,238 since M3 part 2 project 1's Task 18, audit row L494: step 7 takes plan-check's warn: line for a task over
  // scope_threshold files.
  // 7,277 since its fix round 1: step 11 leaves a warn: line step 7's stop settled.
  assertMaxBytes(SKILL, 7277);
});

test('under a go the plan asks nothing the stop list does not stop for', () => {
  // M3 part 1 final review, M6: run.md says "Only the stop list stops the run", and these steps said ask.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('Under a go neither asks: `run.md`\'s stop list decides.'), s[1]);
  assert.ok(s[3].includes('both exit 3: ask; under a go, `run.md`\'s stop list decides, and a `verify.fast`'), s[3]);
  assertContains(RUN, ['Only the stop list stops the run.']);
});

test('plan templates are contracts task-brief and plan-check can read', () => {
  assertHeadings('skills/plan/references/plan-template.md', ['# Plan template', '## Global Constraints', '## Review Focus', '## Open questions', '## File map']);
  assertContains('skills/plan/references/plan-template.md', ['Copy from the first `---` line to the end', 'status: draft', 'approved: (set only on an explicit yes', 'execution:', 'commits: ask', '### Task 1:', 'Always, Ask first, Never']);
  assertMaxBytes('skills/plan/references/plan-template.md', 2200);
  assertHeadings('skills/plan/references/task-template.md', ['# Task template', '### Task N: <name>']);
  assertContains('skills/plan/references/task-template.md', ['**Files:**', '**Interfaces:**', 'Consumes:', 'Produces:', '**Blocked by:**', '**Acceptance:**', 'Run it to verify it fails', 'Expected:', '`plan-check` fails a task']);
  assertMaxBytes('skills/plan/references/task-template.md', 2200);
  assertHeadings('skills/plan/references/plan-review.md', ['# Plan reviewer brief', '## What to check', '## Calibration', '## Output']);
  // 1,450 since the pilot fix plan's Task 5 (raised from 1,400): the States, Size, Non-goals and spike checks.
  // 1,600 since pilot fix plan 2's Task 4: the Size check reads the gate's own measure, re-indented lines included.
  // 1,650 since that task's review fix: the gate's measure is named, `git diff --shortstat` or `pr.size_command`.
  // 1,900 since M3 part 1 Task 5: a spec with `## Later slices` must show its overrun.
  // 1,922 since M3 part 2 project 1's Task 18 fix round 1, audit row L494: the plan-check output the reviewer gets may
  // hold a warn: line step 7's stop settled, after cutting "in substance" from the coverage check.
  assertMaxBytes('skills/plan/references/plan-review.md', 1922);
  assertContains('skills/plan/references/plan-review.md', ["Check its line estimate in the gate's own measure (`git diff --shortstat`, or `pr.size_command` when set) against the file map, re-indented lines included"]);
});

test('plan pins its approval, lookup and autopilot rules', () => {
  const skill = readDoc(SKILL).raw;
  const gate = 'ask for the yes and the `step`, `inline` or `delegate` choice as a typed reply in chat, never through AskUserQuestion';
  assert.equal(skill.split(gate).length - 1, 1, 'the AskUserQuestion rule is stated at the approval step');
  assertContains(SKILL, [
    'An AskUserQuestion answer records no prompt line, so Guard G20 denies it',
    "After the user's yes message, leave the plan file untouched until the approval edit",
    'one Edit sets `status: approved`, `approved: <date>, "<one whole line of the user\'s yes, verbatim>"` and `execution:` together',
    'run the same plan-check again',
    'on per the latest kern signal',
    'a turn with no mode line changes nothing',
    'write the plan with `status: draft`',
    'parked: <question>; default: <choice>; why: <one line>',
    '${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-review.md',
    '${CLAUDE_PLUGIN_ROOT}/skills/plan/references/task-template.md',
    '${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-template.md',
    'bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir plans',
    'both exit 3: ask',
    'gh fails or is not signed in: say so and ask',
    'wt-new <slug> --detach',
  ]);
  assertContains('skills/plan/references/task-template.md', ['as a leading list of numbers or ranges such as `1, 3-4`', 'plan-check parses only that list']);
  // Paid round 2026-10-25: two of three plans tested both code paths but never named the states `code given` and `no code`.
  assertContains('skills/plan/references/task-template.md', ["with the spec's exact values, naming each `States:` state it proves by that name"]);
  assertContains('skills/plan/references/plan-review.md', ["`States:` reached and checked by a step that names it"]);
  assertContains('skills/plan/references/plan-review.md', ['`Verdict: approve | revise`', 'Round 1 only', 'a transcript, not a decision', 'Proportion: a plan several times longer than its spec']);
  assertContains('skills/plan/references/task-template.md', ['a code block only for an algorithm they do not determine', "with the spec's exact values", 'a plan longer than the code it describes has written the code instead', 'Proportion: compare the plan with the spec', 'no step that leaves a decision open']);
  assert.doesNotMatch(readDoc('skills/plan/references/task-template.md').raw, /the real code/, 'a code step records decisions, not the whole body');
});

test('plan pins order, routing and stop rules', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const w = s[11].indexOf('kern-dir plans');
  assert.ok(w >= 0 && w < s[11].indexOf('scripts/plan-check'), 'step 11 writes the plan before it runs plan-check');
  assert.ok(!s[12].includes('kern-dir plans') && !s[12].includes('Write tool'), 'step 12 writes nothing new');
  assertContains(SKILL, [
    'An unfinished plan for other work: stop and ask',
    'issue acceptance criteria alone are not approved (its bounded path records them as an approved short spec)',
    'Look for existing PRs with `gh pr list --search <id> --state all`; if gh fails',
    'Get `tracker` from `kern-get`, else `kern-detect`; both exit 3: ask.',
    'else stop and ask the user to confirm the scope or split',
    'Tasks sharing a file or a `shared_services` entry are ordered by Blocked by, never parallel',
    'round 1 only',
    'each demoable on its own',
    'the contract task blocked by every migrate batch',
    'Record its answer under Open questions as the branch or SHA plus the evidence',
    'A yes with a change request: make it, show it, ask again',
    'A reply that is no explicit yes or names no choice: ask again',
    '`tracker`, `tracker.first`',
    'Under autopilot with no go a step 1 stop parks: give the `parked:` line in the reply and create no plan file',
    'the split, never a plan over `scope_threshold` or `pr.max_lines`',
    'Draft tracker sub-issues only on request',
    'execute-plan runs only an approved plan',
    'every stop parks',
    'the step 4 spike is not run and the step 7 scope question takes its default',
    'under Open questions in the plan and in the reply',
  ]);
  assertContains('skills/plan/references/plan-template.md', ['## Open questions', 'branch or SHA plus the evidence', '`parked: <question>; default: <choice>; why: <one line>`', 'every acceptance number covered', 'one line per `checklists` item in each', 'regression check that runs the same scenario on base and head']);
});

test('the base names its source, an undetected base is the current branch and is said, and the base-and-head check names a branch', () => {
  // 2026-10-22 head-to-head, plan category (task-16-h2h-plan-diagnosis): every kern plan wrote `base: main;
  // promotion: none` after `kern-detect base_branch` printed "not detectable", and the grader counted that line, or
  // a base SHA no command printed, as unsupported in 4 of 6 runs. Steps 1 and 3 name a source and say what to do on
  // exit 3; step 9 named neither (Task 16n).
  const s = steps(readDoc(SKILL).body);
  // Paid round 3, reminder-seam run 2: the plan copied the detached line on branch main, and never called git branch --show-current.
  assert.ok(s[9].includes('Get `base_branch` from `kern-get`, else `kern-detect`, naming its source; both exit 3: run `git branch --show-current` and write `base: <branch> (current branch; not detected)`'), s[9]);
  // Task 16n review, M1: on a detached HEAD `git branch --show-current` prints nothing, and the header read
  // `base:  (current branch; not detected)` or a guess.
  assert.ok(s[9].includes('; only empty output gives `base: unknown (detached HEAD; not detected)`.'), s[9]);
  // Step 10 defers to the template, which names the base by branch (Task 16n review, M1 pays its bytes so).
  assert.ok(s[10].includes('the base-and-head regression check as plan-template.md says'), s[10]);
  assert.ok(s[12].startsWith('12. Present a summary in chat, saying when the base was not detected'), s[12]);
  // Task 16n review, M4: the summary still offers a visual page when kern's `visual` skill is installed.
  assert.ok(s[12].includes('(a visual page when kern\'s `visual` skill is installed, else say once "visual pages not installed")'), s[12]);
  const tpl = readDoc('skills/plan/references/plan-template.md').raw;
  assert.ok(tpl.includes('\nbase: <base branch> (<source>); promotion: <branch chain, or none>\n'), 'the header line names the source');
  assert.ok(!tpl.includes('base: <base branch>;'), 'the old header line, with no source, is gone');
  assert.ok(tpl.includes('add a regression check that runs the same scenario on base and head, naming the base by branch, never by a SHA no command printed'), 'the template check names the base by branch');
});

test('the limits are read at step 1, stated in chat only at a scope split or stop with their source, and a default is never "your limit"', () => {
  // 2026-10-23 head-to-head, plan category (task-16-confirming-diagnosis, sections 4 and 6): in 3 of 11 kern task-runs
  // the grader counted "your limit is 4", "against a threshold of 4" and "over the 4-file PR limit" as unsupported.
  // `kern-get scope_threshold` had printed nothing, and the 4 came from the Inputs table, which the grader never sees.
  // Steps 3 and 9 name a verify command's and the base's source (Task 16n); step 7 named none (Task 16q).
  // M2b bfix2 S2 (bfix2-lane-C): Task 16q's `scope_threshold: 4 (kern default; not set)` still drew 2 counts in each
  // of rounds 155cbad and cd4808a, all in scope-split, each citing a `kern-get scope_threshold` that printed nothing.
  // `kern-get KEY DEFAULT` prints `<value><TAB><source>` with exit 0, `4<TAB>default` when unset, so the 4 and its
  // source come from command output the grader sees.
  // M2b bfix3 P3 (bfix3-lane-P, Q4): runs gather every `kern-get` key into one loop at their first lookups. The loop
  // dropped step 7's `4` in 7 of 9 bfix2 plan runs, and 3 never ran the defaulted call. Step 1 now reads the limit with
  // the first lookups, and step 7 states it only where a scope split or stop needs it, so "under `scope_threshold`
  // (default 4)" goes. "Scope" keeps step 12's "Stop the turn" from reading as such a stop (P3 review, Minor 1).
  // Pilot fix plan Task 5 fix round (group B review, Important 1 and 2): the header's Size line states both limits in
  // every plan, so step 7's rule covers chat only, and step 7 splits over `pr.max_lines` as well as `scope_threshold`.
  // Final review M1: a 2026-10-24 head-to-head run looped `kern-get $k 4` over several keys, which would read
  // `pr.max_lines` as 4, so each `kern-get` runs in its own call.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('Get `tracker` from `kern-get`, else `kern-detect`; both exit 3: ask. Under a go neither asks: `run.md`\'s stop list decides. Read the limits now with `kern-get scope_threshold 4` and `kern-get pr.max_lines 300`, each `kern-get` in its own call.'), s[1]);
  assert.ok(s[7].includes('One PR is one change, within `scope_threshold` files and `pr.max_lines` lines, else stop'), s[7]);
  assert.ok(s[7].includes('else stop and ask the user to confirm the scope or split. In chat, state a limit only at a scope split or stop, as `scope_threshold: <value> (<source>)` or `pr.max_lines: <value> (<source>)` from step 1\'s lookup, never "your limit".'), s[7]);
  assert.ok(!s[7].includes('kern default; not set'), 'the prose default is gone');
  assert.ok(!s[7].includes('(kern-get)'), 'the old source label is gone');
  assert.ok(!s[7].includes('wherever the plan or reply states it'), 'the limit is no longer stated wherever the plan or reply goes');
  assert.ok(!s[7].includes('Read the limit with'), 'step 7 no longer runs the lookup; step 1 does');
  // The default the step passes is the Inputs table's.
  assertContains(SKILL, ['| `scope_threshold`, `pr.max_lines` | 4 files; 300 lines | PR size gate |']);
  // The cuts that paid for these bytes left their text where the steps point: step 3's verify keys in the Inputs
  // table, step 8's Interfaces and Acceptance forms in task-template.md, step 9's header fields in plan-template.md.
  assertContains(SKILL, ['| `test.*`, `typecheck`, `lint`, `build` | detected, source printed | task verify commands |']);
  assertContains('skills/plan/references/task-template.md', ['- Consumes: names and signatures', '- Produces: names, parameters and return types', 'as a leading list of numbers or ranges']);
  assertContains('skills/plan/references/plan-template.md', ['**Goal:**', '\nspec: ', '\nissue: ', '\nbase: <base branch> (<source>); promotion: <branch chain, or none>\n']);
});

test('the plan summary cites no plan-check or git output', () => {
  // M2b bfix3 P3 (bfix3-lane-P, Q1 and Q4): in the bfix2 head-to-head the grader counted a summary's "`plan-check`
  // passes", whose calls the digest's 300-character command cut hid, and a "`git status` shows no changes" that no
  // command printed. plan-check still runs at step 11; only the reply stops citing it.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[12].includes('else say once "visual pages not installed"); it cites no plan-check or git output.'), s[12]);
  assert.ok(s[11].includes('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` and fix every line it prints but a warn: line step 7\'s stop settled.'), s[11]);
});

test('only the user\'s word skips the plan review', () => {
  // 2026-10-22 head-to-head: kern skipped step 11's review in 3 of 6 plan runs, "to save budget" or because "the plan
  // is small"; in one the reviewer's catch, a RED step that runs a real fetch, stayed in the plan. The user's answer:
  // "Only by my word" (Task 16n).
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[11].includes('round 1 only. Only the user\'s word skips this review, never size or budget.'), s[11]);
});

test('plan sends its gating review to a fresh subagent, and step 12 waits for it', () => {
  // Audit C-I6 (2026-10-22): in 2 of 3 kern plan transcripts step 12 could ask for the yes before the review returned.
  // M3 part 1 Task 15: the dead Agent parameter went; model-selection.md's wait rule holds the ask.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[11].includes('send the plan to one fresh general-purpose subagent on `model.reviewer`, with `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-review.md` as its brief'), s[11]);
  assertContains('skills/execute-plan/references/model-selection.md', ["- When your next step needs an agent's return, wait for it."]);
});

test('an existing plan goes back to draft before it is updated, so its approval and its ledger are new', () => {
  // Audit C-I5: a plan updated in place kept `status: approved`, and execute-plan reused the old ledger's
  // complete lines. ledger-open now refuses a ledger opened for other plan text; a draft needs a new yes.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('A plan for this spec exists: set `status: draft`, then update it in place.'), s[1]);
});

test('the plan header states its size against both limits, and the review checks states, size and non-goals', () => {
  // Pilot fix plan Task 5 (MA-254): the picker cells below the fold were a state no plan step read.
  // Final review I1: no h2h plan spec has `## Size`, so the header names a fallback, an estimate from the file map.
  // M3 part 1 Task 5: the Size line is this PR's, so a split takes the slice's counts; the whole ticket's stay in `## Size` or the `Decision:` line.
  assertContains('skills/plan/references/plan-template.md', ['**Size:** <n> files and about <n> changed lines (the spec\'s `## Size` measure, the slice\'s counts when a split narrowed the spec; with none, an estimate from the file map, stated as an estimate), against `scope_threshold: <value> (<source>)` and `pr.max_lines: <value> (<source>)`.']);
  assertContains('skills/plan/references/plan-review.md', ["- States: each acceptance line's `States:` reached and checked by a step", '- Size: the Size line over `scope_threshold` or `pr.max_lines`',
    "- Non-goals: a task that builds what the spec's Never or Not doing lines exclude.", 'a spike first.']);
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[9].includes('Review Focus, the Size line against step 1\'s limits, `execution:` empty'), s[9]);
});

test('under a go plan runs to an approved plan on delegate, and a plan over the threshold runs its first slice', () => {
  // M3 part 1 Task 5: execute-plan runs only an approved plan, and nothing approved one under autopilot.
  // plan-check requires one of step, inline or delegate on an approved plan, and nobody is there to choose.
  const lines = section(readDoc(SKILL).body, '## Stops and autopilot').split('\n');
  // A go is the session's record, not the typed form: the same line in a ticket, or a refused go, is no go.
  const pointer = lines.find((l) => l.startsWith('Under a go (the latest `kern mode:` line shows `go=<id>` for this ticket; anything else is no go)'));
  assert.ok(pointer, 'a go has its own paragraph');
  // M3 part 1 Task 15: the rules sit in run.md, which a go reads first; this line takes any other way in to them.
  assert.ok(pointer.endsWith('follow `## Define and plan under a go` in `${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md`.'), pointer);
  const all = section(readDoc(RUN).raw, '## Define and plan under a go');
  const go = all.split('\n').find((l) => l.startsWith('plan: ')) ?? '';
  // Re-review M7: plan step 1 now reads define itself, so this line no longer restates it.
  assert.ok(go.startsWith("plan: Step 4's spike runs,"), go);
  // The go replaces the human yes only, and a spike is not a yes: an unsettled fact must not reach an approved plan.
  assert.ok(go.includes("Step 4's spike runs, the go standing for the nod;"), go);
  assert.ok(go.includes("a fact it cannot settle follows this file's unblock and stop rules"), go);
  assert.ok(!go.includes('those defaults hold') && !go.includes('spike is not run'), go);
  assert.ok(go.includes("Step 7's scope question takes its default, with a `parked:` line under Open questions and in the run report."), go);
  assert.ok(all.includes('Only the stop list stops the run.'), all);
  // The review stays: the go replaces the human yes and nothing else.
  assert.ok(go.includes("Step 12 does not stop: after step 11's plan-check and review, one Edit sets the two approval lines and `execution: delegate`; run the same plan-check again."), go);
  assert.ok(all.includes('Each approval below sets `status: approved` and `approved: <date>, "/kern:autopilot go <id>"`, `<id>` as the `kern mode:` line shows it.'), all);
  assert.ok(all.includes('G20 also needs `issue:` to name this ticket'), all);
  assert.ok(all.includes('`issue: "#853"`'), 'a bare # opens a YAML comment, so the text shows it quoted');
  // One go covers one draft PR. plan-check fails a plan that leaves a spec line uncovered, so the split is in the spec.
  // Task 15: define leaves a ticket within `scope_threshold` and over `pr.max_lines` to step 7.
  assert.ok(go.includes('A plan over `scope_threshold` or `pr.max_lines` takes the split and runs the first slice: one Edit under the go moves the later lines of the approved spec to `## Later slices` as plain bullets, with a `Decision:` line in the plan giving the whole ticket\'s files and lines against the limits, then plan-check runs.'), go);
  // Nobody confirms the split under a go, and a moved line leaves proof-check and self-review's spec lane, so a reviewer checks the overrun.
  assertContains('skills/plan/references/plan-review.md', ['- Later slices: a spec with `## Later slices` must show the overrun, the whole ticket\'s files and lines over the limits in `## Size` or the plan\'s `Decision:` line. No overrun, or a later line that fits the limits and so belongs in this PR, is a finding.']);
  // With no go the plan stays a draft.
  assert.ok(lines.some((l) => l.includes('When on with no go, every stop parks') && l.includes('write the plan with `status: draft`')), 'parking is the no-go path');
});

test('step 7 takes plan-check\'s warn: line for a task over scope_threshold files, and Review Focus lines get their tests', () => {
  // M3 part 2 project 1 Task 18, audit row L494, after addy's planning-and-task-breakdown: a task over the file
  // limit is a PR over it, so plan-check warns and step 7's stop settles it.
  const seven = steps(readDoc(SKILL).body)[7];
  assert.ok(seven.includes('every migrate batch. A task over `scope_threshold` files gets a warn: line from plan-check: slice it, or take the stop below. One PR is one change,'), seven);
  // Audit row L495, after superpowers' writing-plans Self-Review item 4.
  // Fix round 1: a warn: line survives the user's one-PR word and a go's first slice, so neither step 11 nor the
  // reviewer asks for a fix that cannot be made.
  assertContains('skills/plan/references/plan-review.md', ["You receive the plan path, the spec path and plan-check's output, clean or a warn: line step 7's stop settled, nothing about how the plan was written."]);
  const focus = section(readDoc('skills/plan/references/plan-template.md').body, '## Review Focus');
  assert.ok(focus.includes("Each line's pinning test goes into the task that owns the code, which the line names; an empty section means checked and none found, not skipped."), focus);
});
