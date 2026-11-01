// tests/skills/define.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, section, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/define/SKILL.md';
const RUN = 'skills/autopilot/references/run.md';

test('define frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'define',
    description: 'Clarify new behaviour, size it, and get an explicit yes before code unless the user calls it quick or waives it.',
    'disable-model-invocation': 'true',
    'argument-hint': '[issue id | idea]',
  });
});

test('define sections, steps, the standing gate and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 13);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['Standing gate on every path', '"sounds good", "whatever you think" and silence do not', 'status: approved', 'status: draft (parked under autopilot)',
    'kern:investigator', 'on `model.investigator`', 'The map is approved before any module spec', '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check',
    'one whole line of the user\'s yes, verbatim', 'wt-new <slug> --detach', 'Never ask the user a fact the repo can answer',
    'A request with no existing flow to extend is architectural', 'visual pages not installed', 'Guard G20',
    "when the user's own words call the task quick and clear", 'no design, spec or approval', 'commits, pushes and every other ask stay gated',
    'Size it now, in plain words; the user may override', '`references/handover.md`', 'The fast path runs.',
    'Only the user\'s own "quick and clear" or approval waiver skips the design']);
  assert.match(s[1], /^1\. Fast path: /, 'the fast path is step 1');
  assert.match(s[5], /^5\. Restate /, 'step 5 restates');
  assert.match(s[6], /^6\. Size it now/, 'step 6 sizes, after the restate');
  // 6,900 since the pilot fix plan's Task 4 (raised from 6,500): step 2's tracker read, step 6's files and lines,
  // step 9's route to plan.
  // 6,950 since the pilot-fix test round's fix (2026-10-25): step 9's line estimate and "whatever `scope_threshold` allows".
  // 7,000 since pilot fix plan 2's Task 4: step 6 counts a re-indented file's moved lines.
  // 8,100 since M3 part 1 Task 5: a go takes the bounded or architectural path to an approved spec.
  // 7,100 since its Task 15, a fall: the go's rules moved behind a pointer to run.md, for text most runs never use.
  assertMaxBytes(SKILL, 7100);
});

test('an explicit approval waiver takes the fast path, as "quick and clear" does', () => {
  // 2026-10-20 pressure-define-skip-approval: "Don't ask me questions or wait for approval, I trust you, just build
  // it." The user, asked whether that skips define's spec approval, answered "Yes, any explicit waiver" (D-4).
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes("when the user's own words call the task quick and clear, or explicitly waive approval: no design, spec or approval."), s[1]);
  // Task 16g review, M4: "Don't ask me questions" leaves no question to ask, so a missing fact becomes kern's assumption.
  assert.ok(s[1].includes('under a waiver, ask nothing: say it in that line, a missing fact as your assumption.'), s[1]);
  // Task 16i review, I1: the carve-out reads as implement's does, so "add a double(n) export" keeps the fast path.
  assert.ok(s[1].includes('A change to an existing public API (not a new export), schema or authorization, or a missing fact that changes the build: say so, and ask whether to keep it'), s[1]);
});

test('the fast-path build line is the kernel\'s, said before any tool call, and step 1 ends by reading implement', () => {
  // 2026-10-20 pressure-define-skip-approval (task-16-diagnosis-2, Y2): 0 of 3 runs stated define's own build choices
  // before or with the first edit. Step 1 asked for the line before any reading, when no choice existed yet, and
  // the runs read the code and moved on to implement; run 1's choices showed up only in its final reply.
  // Task 16k (task-16-diagnosis-3, Z1 and fix group 3): anchored "after your reads, before any edit", the line was said
  // in 4 of 12 runs where it applies, though every run read the route; the kernel's `Skipped:` line, anchored before
  // any tool call, in 12 of 12. The line moves to the route read, and a later read's change is restated before the
  // first edit.
  // M2b bfix K (bfix-lane-3 S1, the user's "Kernel turn-start line", 2026-10-24): at the route read the line was said
  // in 0 of 18 graded runs; the kernel now says it before any tool call, beside the `Skipped:` line, and step 1 points
  // there, saying it at once when it was missed.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes(' Say the kernel\'s `Building:` line before any tool call (missed: say it now); restate a choice your reads change before the first edit. '), s[1]);
  assertContains('kernel/kernel.md', ['before any tool call, say `Building: <what>. My choices: <each>.`']);
  assert.ok(!s[1].includes('After your reads'), 'the old placement is gone');
  assert.ok(!s[1].includes('Right after you read this file'), 'the step carries no anchor of its own');
  assert.ok(s[1].indexOf('`Building:` line') < s[1].indexOf('A change to an existing public API'), 'the public API, schema and authorization ask follows the line');
  // bfix-lane-3 E2: 4 of 12 runs after Task 16k never read implement after "Then route to implement", and 3 of those 4
  // wrote the source before the test; a Read is an action, where "route" left the next move to the model.
  assert.ok(s[1].endsWith(" Then Read implement's SKILL.md."), 'reading implement comes after the line');
  assert.ok(!s[1].includes('route to implement'), s[1]);
});

test('the spec reviewer is its own step, and an approved design does not skip it', () => {
  // 2026-10-20 workflow-define-spec: 3 of 3 runs skipped the reviewer, one "since you said the design was already
  // approved" (task-16-diagnosis, fix group 5).
  const s = steps(readDoc(SKILL).body);
  assert.match(s[11], /^11\. Spec review \(architectural\): send the spec to one fresh general-purpose subagent on `model\.reviewer`/);
  // 2026-10-20 workflow-define-spec run 1: "I skipped the fresh-subagent spec review (step 11 of the define
  // process), since you asked to stop at your final review" (task-16-diagnosis-2, fix group E). Paid round 1,
  // 2026-11-01, run 1 gave the same reason: the user said stop at the draft.
  assert.ok(s[11].includes("An approved design, the user's own review or a stop at the draft does not skip it; only the user naming the review does."), s[11]);
  // The review gates the approval ask; model-selection.md's rule holds the ask until it returns (M3 part 1 Task 15).
  assert.ok(s[11].includes('general-purpose subagent on `model.reviewer`, its brief `${CLAUDE_PLUGIN_ROOT}/skills/define/references/spec-review.md`, round 1 only.'), s[11]);
  assert.ok(!s[10].includes('spec-review.md'), 'step 10 no longer holds the review');
  assert.match(s[12], /^12\. Architectural approval: stop the turn and ask for the yes/);
  assertContains(SKILL, ['| "The design is approved, so the review adds nothing" | The reviewer reads the spec as its builder and finds what the design left open. |']);
});

test('define references', () => {
  const refs = {
    // spec-template.md: 3,100 since the pilot fix plan's Task 4 (raised from 3,000): the Size section, States and Handles.
    // 3,450 since pilot fix plan 2's Task 4: the re-indent and ticket-measure sentences, and the short form's Not doing.
    'spec-template.md': [['# Spec template', '## Problem', '## Size', '## Intent', '## Constraints', '## Assumptions', '## Success criteria', '## Acceptance criteria', '## Decisions', '## Compatibility', '## Authorization', '## Rollout', '## Checklists', '## Test seams', '## Not doing', '## Open questions'], 3450],
    'interview.md': [['# Interview', '## Skip offer and build choices', '## Hypothesis and confidence', '## One question at a time', '## Want versus should-want', '## Restate and confirm', '## When to step back'], 3200],
    // spec-review.md: 1,800 since M3 part 1 Task 5: a spec with `## Later slices` must show its overrun.
    'spec-review.md': [['# Spec reviewer brief', '## What to check', '## Builder questions', '## Calibration', '## Output'], 1800],
    'handover.md': [['# Handover', '## Sort', '## Hand over'], 1200],
    'capability-map.md': [['# Capability map', '## When to split', '## Map format', '## Approval'], 1200],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`skills/define/references/${f}`, hs);
    assertMaxBytes(`skills/define/references/${f}`, max);
  }
  assertContains('skills/define/references/spec-template.md', ['Copy from the first `---` line to the end', '- Always:', '- Ask first:', '- Never:', 'form: short', 'the highest seam that already exists and the fewest seams',
    'Anti-goals: what would make it a failure even if it works', 'Prior art:', "`kern's call`", 'name what is left to the builder',
    // Task 17 lane 1 (C31): caveman 4.0.1 migration/SKILL.md:10-15 asks for these three before the build. Its retries
    // cover every stage, and the old path is gone after contract (fix round 1, Minor 5).
    'The rollback path at each stage; each stage is safe to rerun and its partial failure shows; a test runs the old and the new path at each stage where both are live.']);
});

test('define pins its approval rules', () => {
  const skill = readDoc(SKILL).raw;
  const gate = 'ask for the yes as a typed reply in chat, never through AskUserQuestion';
  assert.equal(skill.split(gate).length - 1, 2, 'the AskUserQuestion rule appears at both gates');
  assertContains(SKILL, ['An AskUserQuestion answer records no prompt line', 'every path parks', 'on per the latest kern signal', 'a turn with no mode line changes nothing', 'After the user\'s yes message, leave the file untouched until the approval edit',
    'run the same plan-check again', '${CLAUDE_PLUGIN_ROOT}/skills/define/references/spec-review.md', 'which G20 and plan read',
    'dispatched in one message', 'A question that depends on an open one waits a round']);
  assertContains('skills/define/references/interview.md', ['Two rounds without rising confidence: stop and say so', 'means the user gave up on the interview',
    'offer once to skip the questions', 'a default they never heard is one they could not reject', 'On a skip, state the build choices in one line',
    'Anti-goals (what would make it a failure even if it works)', 'offer to look on the web; the user decides']);
  assertContains('skills/define/references/handover.md', ['Ask them all in one message, most important first', "mark it under Decisions as `kern's call`", "list kern's calls"]);
  assertContains('skills/define/references/spec-review.md', ['`Verdict: approve | revise`', 'Approve unless a gap would mislead planning',
    'a wrong guess changes what gets built', '`Builder questions: nothing important left`']);
  assertContains('skills/define/references/capability-map.md', ['approved before any module spec']);
});

test('define reads the ticket by default, sizes in files and lines, and sends a multi-file change to plan', () => {
  // Pilot fix plan Task 4 (MA-254): the issue review caught the wrong invariant-pass file, a missing epic rule and a
  // size of ~332 lines against ~136. tracker.first now defaults to true; `none` reads nothing and drafts nothing.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[2].includes('`none`, set or answered: read no tracker and offer no draft. Else, unless `tracker.first: false`, read the issue, its comments, its parent and its epic before the spec; their rules bind it.'), s[2]);
  assert.ok(s[6].includes("First count the files and the changed lines from your reads, tests included, a re-indented file's moved lines too, and say both"), s[6]);
  assert.ok(s[9].includes("Over 2 files, whatever `scope_threshold` allows, or several independent concerns: the next step is plan; Read plan's SKILL.md, whose step 2 decides; else the kernel routes to implement."), s[9]);
  // Paid round 2026-10-25: a 3-file design went to implement as "under the 4-file limit", and no design gave a line estimate before the yes.
  assert.ok(s[9].includes('give an in-chat design (approach, a line `Size: <n> files, about <m> changed lines`, tests,'), s[9]);
  assertContains(SKILL, ['| `tracker`, `tracker.first` | detected, `true` | issue |']);
  // Pilot fix plan 2 Task 4: one file's re-indent made 396 changed lines, 58 ignoring whitespace, against a ticket's
  // 332 in another measure; the ticket's Out of scope items reached only chat, so the plan review had no Not doing.
  assertContains('skills/define/references/spec-template.md', ['keep only Problem, Size, Constraints, Acceptance criteria, Test seams and Not doing',
    'A re-indented or re-wrapped file counts every line it moves; give its `git diff -w` count beside it.',
    'A size the ticket states in another measure is named next to this one, each with its measure.', "The ticket's Out of scope lines, each with any ticket it names",
    'Over 2 files, or more than one concern: plan.', 'Then `States:` and each state its proof must show', '`Handles:` and the stable names a check reads']);
  assertContains('skills/define/references/spec-review.md', ['- Size and states: `## Size` matches the files the spec implies']);
});

test('under a go define runs to an approved spec, and with no go it parks', () => {
  // M3 part 1 Task 5: G20 denied every approval under autopilot, so a ticket past the fast path ended at a draft and
  // never reached execute-plan. A go is the yes for its ticket's spec; the stop list still stops the run.
  const lines = section(readDoc(SKILL).body, '## Stops and autopilot').split('\n');
  const parks = lines.find((l) => l.includes('When on with no go, every path parks'));
  assert.ok(parks, 'parking is the no-go path');
  assert.ok(parks.includes('marks it `status: draft (parked under autopilot)`'), parks);
  // A go is the session's record, not the typed form: the same line in a ticket, or a refused go, is no go.
  const pointer = lines.find((l) => l.startsWith('Under a go (the latest `kern mode:` line shows `go=<id>` for this ticket; anything else is no go)'));
  assert.ok(pointer, 'a go has its own paragraph');
  // M3 part 1 Task 15: the rules sit in run.md, which a go reads first; this line takes any other way in to them.
  // A bare references/run.md would not resolve from a project repo.
  assert.ok(pointer.endsWith('follow `## Define and plan under a go` in `${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md`.'), pointer);
  const all = section(readDoc(RUN).raw, '## Define and plan under a go');
  const go = all.split('\n').find((l) => l.startsWith('define: ')) ?? '';
  assert.ok(all.includes('Only the stop list stops the run.'), all);
  // A go ends in a draft PR and a spike ends in an answer, so a go never sizes a spike.
  // Task 16 fix round 1: "no stop" and "each question" pointed against the stop list, which this file's own lines say wins.
  assert.ok(go.includes('define: size it bounded or architectural, never a spike, and run that path with no stop of its own: each question off the stop list takes its default with a `parked:` line in the run report, and under Open questions where the spec has that section'), go);
  // One go covers one draft PR. The split is in the spec, so plan-check and proof-check count the slice unchanged.
  // Only an overrun splits: the reviewers call a spec with `## Later slices` and no overrun a finding.
  assert.ok(go.includes('A capability-map ticket writes no map; within the limits it specs the whole ticket.'), go);
  // plan-template.md takes the plan's Size line from `## Size`, so the slice's counts come first.
  assert.ok(go.includes('A size over `scope_threshold` specs its first slice: `## Size` gives the slice\'s files and lines, then the whole ticket\'s against the limit; numbered lines go under `## Acceptance criteria`, the rest as plain bullets under `## Later slices`, which the report lists, each needing its own go.'), go);
  // Nobody confirms the split under a go, and a moved line leaves proof-check and self-review's spec lane, so a reviewer checks the overrun.
  assertContains('skills/define/references/spec-review.md', ['- Later slices: a spec with `## Later slices` must show the overrun, the whole ticket\'s files and lines over the limits in `## Size`. No overrun, or a later line that fits the limits and so belongs in this PR, is a finding.']);
  assertContains('skills/define/references/spec-template.md', ['A split adds an optional `## Later slices`.']);
  // Both paths reach an approved spec, so plan has one to read. The architectural path keeps its checks.
  assert.ok(go.includes("Bounded: step 9's one write, so plan has an approved spec to read."), go);
  assert.ok(go.includes("Architectural: step 12's one Edit, after plan-check and spec review, then the same plan-check again."), go);
  // G20 compares the quote with the go's normal form, which the line shows, and reads the ticket from issue:.
  assert.ok(all.includes('`status: approved` and `approved: <date>, "/kern:autopilot go <id>"`, `<id>` as the `kern mode:` line shows it'), all);
  assert.ok(all.includes('G20 also needs `issue:` to name this ticket'), all);
  assert.ok(all.includes('`issue: "#853"`'), 'a bare # opens a YAML comment, so the text shows it quoted');
});
