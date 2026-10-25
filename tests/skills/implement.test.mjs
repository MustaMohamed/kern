// tests/skills/implement.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';
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
  assertMaxBytes(SKILL, 5800);
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
  assert.ok(s[7].includes('a command that step 3 could not resolve was asked for there'), s[7]);
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
