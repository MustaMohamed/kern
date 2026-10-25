// tests/skills/plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/plan/SKILL.md';

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
  assertContains(SKILL, ['one fresh general-purpose subagent on `model.reviewer`', '| `model.investigator`, `model.reviewer` | `opus` |', 'Not approved: stop and route to define', 'gh pr list --search', 'never parallel', '`step`, `inline` or `delegate`', 'execution:', 'commits: ask',
    '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check', 'gets a spike first', 'prefactor', 'expand, migrate in batches, then contract', "spec's Constraints section",
    'on `model.investigator`', "one whole line of the user's yes, verbatim", 'visual pages not installed',
    'test-first steps that record decisions, not code', 'Self-review it for placeholders, type mismatches and proportion']);
  // 6,600 since the pilot fix plan's Task 5 (raised from 6,500): step 1 reads pr.max_lines, step 9 writes the Size line.
  // 6,700 since the pilot fix plan's Task 5 fix round: step 7 acts on pr.max_lines and states a limit in chat only.
  assertMaxBytes(SKILL, 6700);
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
  assertMaxBytes('skills/plan/references/plan-review.md', 1450);
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
    'Under autopilot a step 1 stop parks: give the `parked:` line in the reply and create no plan file',
    'the split, never a plan over `scope_threshold`',
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
  assert.ok(s[9].includes('Get `base_branch` from `kern-get`, else `kern-detect`, naming its source; both exit 3: `base: <current branch> (current branch; not detected)`, from `git branch --show-current`'), s[9]);
  // Task 16n review, M1: on a detached HEAD `git branch --show-current` prints nothing, and the header read
  // `base:  (current branch; not detected)` or a guess.
  assert.ok(s[9].includes('; it prints nothing: `base: unknown (detached HEAD; not detected)`.'), s[9]);
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
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('Get `tracker` from `kern-get`, else `kern-detect`; both exit 3: ask. Read the limits now with `kern-get scope_threshold 4` and `kern-get pr.max_lines 300`.'), s[1]);
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
  assert.ok(s[11].includes('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` and fix every line it prints.'), s[11]);
});

test('only the user\'s word skips the plan review', () => {
  // 2026-10-22 head-to-head: kern skipped step 11's review in 3 of 6 plan runs, "to save budget" or because "the plan
  // is small"; in one the reviewer's catch, a RED step that runs a real fetch, stayed in the plan. The user's answer:
  // "Only by my word" (Task 16n).
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[11].includes('round 1 only. Only the user\'s word skips this review, never size or budget.'), s[11]);
});

test('plan runs its gating review in the foreground', () => {
  // Audit C-I6 (2026-10-22): in 2 of 3 kern plan transcripts the review's Agent call passed no
  // run_in_background, so Claude Code ran it in the background and step 12 could ask for the yes before the
  // review returned. define's spec review and execute-plan's reviews already pass false (ff764f9).
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[11].includes('send the plan to one fresh general-purpose subagent on `model.reviewer` (`run_in_background: false`), with `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-review.md` as its brief'), s[11]);
});

test('an existing plan goes back to draft before it is updated, so its approval and its ledger are new', () => {
  // Audit C-I5: a plan updated in place kept `status: approved`, and execute-plan reused the old ledger's
  // complete lines. ledger-open now refuses a ledger opened for other plan text; a draft needs a new yes.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('A plan for this spec exists: set `status: draft`, then update it in place.'), s[1]);
});

test('the plan header states its size against both limits, and the review checks states, size and non-goals', () => {
  // Pilot fix plan Task 5 (MA-254): the picker cells below the fold were a state no plan step read.
  assertContains('skills/plan/references/plan-template.md', ['**Size:** <n> files and about <n> changed lines (the spec\'s measure), against `scope_threshold: <value> (<source>)` and `pr.max_lines: <value> (<source>)`.']);
  assertContains('skills/plan/references/plan-review.md', ["- States: each acceptance line's `States:` reached and checked by a step", '- Size: the Size line over `scope_threshold` or `pr.max_lines`',
    "- Non-goals: a task that builds what the spec's Never or Not doing lines exclude.", 'a spike first.']);
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[9].includes('Review Focus, the Size line against step 1\'s limits, `execution:` empty'), s[9]);
});
