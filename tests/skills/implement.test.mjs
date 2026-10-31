// tests/skills/implement.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';
import { CHECKS } from '../../scripts/lib/behave.mjs';

const SKILL = 'skills/implement/SKILL.md';

test('implement frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'implement',
    description: 'Change production code in thin slices: failing test first, minimal green, full suite, out-of-scope listed.',
    'disable-model-invocation': 'true',
  });
});

test('implement sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 13);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['RED for the expected reason', 'NOTICED BUT NOT TOUCHING', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-new', 'adding `--branch <name>` when `branch.pattern` holds `{id}`', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'never guess a command', 'Do not commit.', 'wt-snap', 'wt-diff', 'kern-get', 'kern-detect', 'probe: mutation caught']);
  // Raised from 5,500 in M2b Task 17 (R4 review I1, M5 to M7): step 5's RED, nothing-to-mutate path and stop for
  // tests asked for on existing code, after lossless cuts.
  // 5,650 since the pilot fix plan's Task 7: step 8's spec update.
  // 5,800 since Task 7 fix round 1 (I4): step 8 proposes the new line and asks, and parks under autopilot.
  // 6,245 since M3 part 1 Task 8 and its fix round 1: autopilot's rules for steps 1, 3 and 5, `{id}`'s source, step 9's
  // patch path, a go's way to finish-branch and the stop and park line, after word cuts.
  // 6,425 since its Task 15: step 11 takes the tree before `test.full` and cites a passed run on that exact tree.
  // 6,535 since its fix rounds 1 and 2: step 11 saves that run's log in the main session only, so a kernel-row run can cite it at finish-branch.
  // 6,655 since its Task 16 fix round 1: with no test command a go works on by step 10's closest check to finish-branch's end path.
  // 6,685 since its Task 16 fix round 2: step 7's list names that route.
  assertMaxBytes(SKILL, 6685);
});

test('implement runs define step 1\'s checks for a task with no agreed design, and asks when wt-new exits 2', () => {
  // 2026-10-20 workflow-define-fast-path-stored-data: a quick rename of a stored field routed to implement and
  // never met define's stored-data check; pressure-define-skip-approval run 2 worked around a wt-new exit 2
  // (task-16-diagnosis B2 and X1).
  const s = steps(readDoc(SKILL).body);
  // Task 16i review, I1: workflow-define-fast-path adds a double(n) export, and the skills spec expects the fast path
  // for it, so a new export is not a public API change; only a contract callers outside the repo depend on is.
  // M2b bfix2 S2 (bfix2-lane-A, Fix 2): on 2026-10-24 workflow-define-fast-path-stored-data run 1 said the kernel's
  // line at turn start, read the exemption as covering the ask too, and renamed the field with no question (0 of 3).
  assert.ok(s[1].includes('A change to an existing public API (not a new export), stored data or authorization: say so, and ask whether to keep the fast path, even if that line was said;'), s[1]);
  assert.ok(s[2].includes('`wt-new` exit 2: say why and ask'), s[2]);
});

test('the entry check is step 1 on its own, with a plain condition, and only the fixed-form line said already exempts a task', () => {
  // 2026-10-20 (task-16-diagnosis-2, Y2): the entry check opened a step that went on to say where to edit, and runs
  // did the where-to-edit half only: 3 of 3 workflow-define-fast-path runs and 2 of 3 of its stored-data variant.
  // pressure-define-skip-approval run 1's "this takes the fast path" passed for define's line, though it named no
  // choice. Task 16g review, M2: a diagnosed fix (diagnose step 7) and a kern:implementer worker, which cannot ask,
  // skip it.
  // Task 16k (task-16-diagnosis-3, Z1 and fix group 3): "after your reads and before any edit" held in 1 of 3
  // workflow-define-fast-path runs, which all read implement; the line moves to the route read, as the kernel's
  // `Skipped:` line, said before any tool call, held in 12 of 12.
  // M2b bfix K (bfix-lane-3 S1, the user's "Kernel turn-start line", 2026-10-24): at the route read the line was said
  // in 0 of 18 graded runs. The kernel says it before any tool call for a build the user calls quick or whose approval
  // they waive; step 1 points to it, and says it on entering for any other task with no approved design.
  // M2b bfix2 S2 (bfix2-lane-A, Fix 2): pointing to "the kernel's `Building:` line" lost the form. On 2026-10-24
  // workflow-define-fast-path run 1 said the line before the edit with "Commands:" in place of "My choices:", so
  // step 1 spells the kernel's form again.
  const s = steps(readDoc(SKILL).body);
  assert.match(s[1], /^1\. Entry check, main session only: unless an approved spec or plan covers this change, it fixes a cause diagnose found, or its `Building:` line was said, say `Building: <what>\. My choices: <each>\.` now; restate a choice your reads change before the first edit\. /);
  assert.ok(!s[1].includes("the kernel's `Building:` line"), 'the pointer with no form is gone');
  assert.ok(!s[1].includes('after your reads'), 'the old placement is gone');
  assert.ok(!s[1].includes('right after you read this file'), 'the step carries no anchor of its own');
  assertContains('kernel/kernel.md', ['say `Building: <what>. My choices: <each>.`']);
  // The step's form is the kernel's, and filled in as a run says it, behave's building-line check finds it.
  const form = s[1].match(/say `(Building: [^`]+)` now/)[1];
  assert.equal(form, readFileSync(join(ROOT, 'kernel', 'kernel.md'), 'utf8').match(/say `(Building: [^`]+)`/)[1]);
  const said = form.replace('<what>', '`double(n)` in `src/sum.js`').replace('<each>', 'edit in place');
  const events = [{ type: 'assistant', message: { content: [{ type: 'text', text: said }, { type: 'tool_use', id: 'e', name: 'Edit', input: { file_path: 'src/sum.js' } }] } }];
  assert.equal(CHECKS['building-line'](events, {}).pass, true, said);
  assert.ok(s[1].indexOf('My choices: <each>.` now') < s[1].indexOf('A change to an existing public API'), 'the public API, stored data and authorization ask follows the line');
  assert.ok(!s[1].includes('wt-new'), 'where to edit is not in the entry check');
  assert.match(s[2], /^2\. Pick where to edit\. In a kern worktree, edit there\./);
  assert.match(s[3], /^3\. Resolve `test\.focused`/);
  assert.ok(s[7].includes("a command that step 3 could not resolve was asked for there, parked, or left to step 10's closest check"), s[7]);
  assertContains(SKILL, ['Stops at steps 1, 2, 3, 5 and 8.']);
});

test('step 3 spells kern-detect\'s full path, since kern:implementer reads it under the subagent kernel', () => {
  // 2026-10-22 Opus audit, C-M9: trim a36c751 left `kern-detect <key>` bare, which leans on the main kernel's
  // `Scripts:` line; the subagent kernel has none, so a worker had to infer the path from kern-get beside it.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[3].includes('with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`.'), s[3]);
  assert.ok(s[3].includes('When both exit 3, ask the user; never guess a command.'), s[3]);
});

test('diagnose names implement\'s steps by their numbers', () => {
  // Task 16i split implement step 1, so each later step moved up one; diagnose cites two of them by number.
  const s = steps(readDoc(SKILL).body);
  const d = steps(readDoc('skills/diagnose/SKILL.md').body);
  assert.ok(d[2].includes('as `implement` step 3 does'), d[2]);
  assert.match(s[3], /^3\. Resolve `test\.focused`, `test\.full`/);
  assert.ok(d[8].includes('Make the patch as `implement` step 9 does (`wt-diff <wt> <tree-before>`'), d[8]);
  assert.ok(s[9].includes('`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>`'), s[9]);
});

test('tests asked for on existing code pass at once: probe --mutate is their RED, and a fail stops the run to ask, with no production edit unasked', () => {
  // M2b Task 17, AD47 (t17-lane-4): the kernel routes tests for existing code here, and step 5 called every test that
  // already passes a finding, so tests asked for on working code had no RED (the controller's ruling).
  const { raw, body } = readDoc(SKILL);
  const s = steps(body);
  assert.ok(s[5].includes("A test that already passes is a finding, not a RED. Tests asked for on existing code pass at once: their RED is step 9's `probe --mutate` of the line each covers (nothing to mutate: step 10's closest check)."), s[5]);
  assert.ok(s[9].includes('`bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test command>`'), s[9]);
  assert.match(s[10], /^10\. No correct seam for a test: say so, and give the closest executable check with its output\.$/);
  assertContains('skills/implement/references/test-design.md', ['For tests added to existing code, which pass at once, this check is their RED.']);
  // R4 review I1 (the controller's ruling: the brief's "stop and route to diagnose" was wrong): a new test that fails
  // on the unchanged code may hold a wrong expected value, or pin a quirk the user wants kept, and diagnose step 7
  // fixes at the source without asking. So the run stops and asks; it never routes there or edits code unasked.
  assert.ok(s[5].includes('One that fails on the unchanged code stops the run: show the failure and ask whether it is a bug for diagnose or the behaviour to pin; never route there or edit production code unasked.'), s[5]);
  assert.doesNotMatch(s[5], /stop and route to diagnose/);
  // R4 review M7: step 5's stop is in the Stops list. M5: the test-after red flag allows a mutation's RED.
  assertContains(SKILL, ['Stops at steps 1, 2, 3, 5 and 8.', '| "I\'ll test after" | A test written after passes at once and proves nothing until a mutation turns it red. Watch it fail first. |']);
  // R4 review M4: the acceptance check allows the tests-on-existing-code case.
  assertContains('tests/skills/implement.acceptance.md', ['- [ ] A new test passes before any code change: it is reported as a finding and not used as RED, unless the tests were asked for on existing code. Then each one\'s RED is a caught `probe --mutate` of the line it covers, no production code changes, and one that fails on the unchanged code stops the run: the failure is shown with the question whether it is a bug for diagnose or the behaviour to pin.']);
  // The bytes were paid within the 5,500 cap: the "Reached from" sentence went, as plan's, define's and self-review's
  // did, and step 9 names adversarial inputs without the list that test-design.md holds.
  assert.ok(!raw.includes('Reached from'), 'no Reached from sentence');
  assert.ok(s[9].includes('Add adversarial inputs.'), s[9]);
  assertContains('skills/implement/references/test-design.md', ['Cover empty, zero, false, cleared, several elements, and the value a real caller sends.']);
  // Fix round 1 paid more bytes the same way: step 9 keeps where to point probe, and test-design.md says what it inverts.
  assert.ok(s[9].includes('(`<file>` is relative to `<wt>`; point it at a line with a single condition)'), s[9]);
  assertContains('skills/implement/references/test-design.md', ["it inverts one operator on that line, the first in probe's fixed order"]);
});

test('implement references', () => {
  assertHeadings('skills/implement/references/test-design.md', ['# Test design', '## Name the break', '## Test the real thing', '## Mocks need a reason', '## Mutation check', '## Tautological tests', '## Adversarial inputs', '## Behaviour, not implementation']);
  assertContains('skills/implement/references/test-design.md', ['probe --mutate']);
  assertMaxBytes('skills/implement/references/test-design.md', 5000);
  assertHeadings('skills/implement/references/slicing.md', ['# Slicing', '## Vertical slices', '## Seams', '## Scope discipline']);
  assertMaxBytes('skills/implement/references/slicing.md', 1800);
});

test('a build that departs from an acceptance line proposes the new text and asks before any spec edit', () => {
  // Pilot fix plan Task 7 (MA-254): three acceptance lines described the first commit and were never updated.
  // Fix round 1, I4: "edit that line in the same step" changed an approved spec with no yes from the user, and
  // self-review then checked the build against the rewritten line.
  const s = steps(readDoc(SKILL).body);
  for (const t of ["A build that departs from an approved spec's acceptance line: name the line and the proposed new text, and ask; never edit the spec on your own.",
    'Edit it only on the user\'s yes, keeping its `States:` and `Handles:` form. Under autopilot, write a `parked:` line instead.']) assert.ok(s[8].includes(t), `step 8 lacks: ${t}`);
  assert.ok(!s[8].includes('in the same step'), s[8]);
});

test('under autopilot implement keeps running: only a stop on the run rules waits', () => {
  // M3 part 1 Task 8: the pilot's run stops came from implement's asks. Step 1's ask has no one to answer it, so it
  // says the line and goes on, and only the change no approved spec covers stops. Task 6 review: run.md says a stop
  // waits for a typed reply, so only a judgment call that takes a default gets a `parked:` line.
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const auto = section(body, '## Stops and autopilot');
  assert.ok(s[1].includes('ask nothing. Under autopilot, say the line and go on; such a change no approved spec covers is the design-choice stop in `${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md`.'), s[1]);
  // `lint` and `typecheck` go unresolved in a project with neither, so only a required one is the stop.
  // Task 16 fix round 1: a stop here left no work, so finish-branch's end path pushed an empty branch. The user's rule: push
  // and stop, and a PR needs tested or verified changes.
  assert.ok(s[3].endsWith("never guess a command. Under autopilot, a required one is a required check that cannot run: the work goes on by step 10's closest check and ends on finish-branch's end path; any other parks, and step 7 skips it."), s[3]);
  assert.ok(auto.includes('Under autopilot the steps are the same, RED is never skipped unless step 3 finds no test command, and a file outside the approved list parks the slice.'), auto);
  assert.ok(s[7].includes("a command that step 3 could not resolve was asked for there, parked, or left to step 10's closest check."), s[7]);
  // Task 8 review, M6: finish-branch counts a red step 4 as `fix first`, so the parked test does not stay in the tree.
  assert.ok(s[5].endsWith('edit production code unasked. Under autopilot, it parks the slice with a `parked:` line and the test is left out of the tree.'), s[5]);
  assert.ok(auto.includes('a file outside the approved list parks the slice. A judgment call that takes a default gets a `parked:` line; any other stop waits for a typed reply, with the data and a recommendation.'), auto);
  assertContains('skills/autopilot/references/run.md', ['| A design choice that changes what gets built |', '| A required check that cannot run |', 'then waits for a typed reply']);
});

test('a go that routed straight to implement goes on to finish-branch, and no caller of implement does', () => {
  // M3 part 1 Task 5 review: a bounded spec of 1 or 2 files takes the kernel's implement row with no plan, and step 12
  // ended the run at "Do not commit." with no draft PR. execute-plan and diagnose read this file mid-run and have
  // steps of their own after it, and kern:implementer never commits, so only the kernel's row goes on.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[12].endsWith("Do not commit. From the kernel's row under a go, follow `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md` on `<wt>`."), s[12]);
  // Task 8 review, M8: `<wt>` comes from implement, so finish-branch step 2 takes it before any stale ledger.
  assertContains('skills/finish-branch/SKILL.md', ['or autopilot is on. Otherwise stop.', 'the menu resolves to option 3', '2. Find the work: a worktree the user or caller named, else']);
  assertContains('kernel/kernel.md', ['| One bounded change of 1 or 2 files with an agreed design, or tests for existing code | Read {KERN}/implement/SKILL.md |']);
});

test('step 2 strips a quoted id, and step 9 names the patch wt-diff wrote', () => {
  // M3 part 1 Task 8 review. M7: a bare `#` opens a YAML comment, so `issue:` is quoted, and neither reaches a branch
  // name. M3: the Outputs sentence that placed the patch went for bytes, so step 9 says where it is.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[2].includes("holds `{id}` (the spec's or plan's `issue:`, with quotes and a leading `#` removed),"), s[2]);
  assert.ok(s[9].includes('`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>` (first line: `<package>`)'), s[9]);
  assert.ok(s[9].includes('scripts/probe --exclude-tests <wt> <package>.patch -- <test command>`'), s[9]);
  assert.ok(!s[9].includes('<change.patch>'), s[9]);
});
