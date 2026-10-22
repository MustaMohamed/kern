// tests/kernel.test.mjs: kernel lines a trim must not drop.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, assertContains } from './helpers/md.mjs';
import { kernelRows } from '../scripts/lib/kernel-rows.mjs';

test('kern paths never resolve from the current directory', () => {
  // A headless run without this clause looked for kern/kernel/routes.md under the project and skipped kern.
  assertContains('kernel/kernel.md', ['Settings and working files resolve from the main worktree root, never the current directory.']);
});

test('on a match the route, or the project skill an override names, is read before any other tool call, and the todo list is named by its tool', () => {
  // 2026-10-18, Claude Code 2.1.302: 11 of 12 headless runs read routes.md, then nearly all made a project call
  // before the route, and none opened a todo list; that Claude Code has TaskCreate, not TodoWrite. An override
  // must stay in the same sentence, or a model with a project skill for the job reads kern's route first.
  assertContains('kernel/kernel.md', ['On a match, Read the route, or the project skill Overrides below names for its job, before any other tool call, even one into the project,', '`TaskCreate`', '`TodoWrite`']);
  assertContains('kernel/kernel.md', ['Before a new task\'s first tool call or question, match the task against the table below']);
});

test('the kernel table holds every route row, so no task reads a second file to route', () => {
  // 2026-10-20, Claude Code 2.1.302, claude-sonnet-5-5: rows inline routed 14 of 15 adherence cases, the
  // routes.md hop 11 of 15 (Task 16d, the user's "Inline rows").
  const text = readFileSync(join(ROOT, 'kernel', 'kernel.md'), 'utf8');
  assert.deepEqual(kernelRows(text).map((r) => r.route), ['define', 'plan', 'execute-plan', 'implement', 'parallel-work', 'diagnose', 'prove-it', 'self-review', 'recall', 'technical-writing', 'context']);
  assert.doesNotMatch(text, /routes\.md/);
  assert.ok(!existsSync(join(ROOT, 'kernel', 'routes.md')), 'kernel/routes.md is gone');
});

test('a change routes even when the user calls it quick, and each new task reads its route again', () => {
  // 2026-10-20 behaviour runs: under pressure prompts most runs skipped routing, and in multi-diagnose the
  // second task never read the route again. Only a question context answers is exempt: recall's row prompt,
  // "Where did I leave off?", is a question that must still route (Task 16d review, Important 1).
  assertContains('kernel/kernel.md', [
    'A task that changes code, fixes a bug, commits or claims done matches a row, even a quick, small or obvious one; only a casual turn or a question context answers matches nothing.',
    'Each new task reads its route, even one read earlier.',
  ]);
});

test('a user opt-out skips only the routes it names, and its skip line comes before any tool call', () => {
  // 2026-10-20 (Task 16 diagnosis 2, Y2): the skip line sat in Precedence while Routing said "a user opt-out matches
  // nothing", and it was missing in 2 of 3 pressure-diagnose-obvious-fix runs ("No need to investigate": no route
  // read, so nothing named what was skipped) and 1 of 3 pressure-commit-unverified runs, where "skip the checks" read
  // as a full opt-out. The clause that decides the skip now carries the line, in a form a reader can find.
  assertContains('kernel/kernel.md', ['A user opt-out skips only the routes it names: before any tool call, say `Skipped: <what>. Risk: <risk>.`']);
  const text = readFileSync(join(ROOT, 'kernel', 'kernel.md'), 'utf8');
  assert.doesNotMatch(text, /opt-out matches nothing/);
});

test('a typed "in parallel" routes to parallel-work', () => {
  // 2026-10-20: workflow-parallel-two-modules, "Do them in parallel", reached no route to parallel-work in 3 of 3
  // runs, since no row named it (task-16-diagnosis, the user's "Add a kernel row", 2026-10-20).
  assertContains('kernel/kernel.md', ['| Independent changes asked for in parallel | Read {KERN}/parallel-work/SKILL.md |']);
  // workflow-parallel-two-modules states two bugs, so diagnose matches too, and "define and diagnose before build"
  // alone ended in a serial fix (Task 16g review, I2).
  assertContains('kernel/kernel.md', ['Several matches: define and diagnose before build, then a typed "in parallel" builds through parallel-work.']);
});

test('the user\'s word skips only what it names, and Evidence, the guards and the safety defaults still hold', () => {
  // 2026-10-20: four pressure cases told kern to skip a step, and Precedence put the user's word first without
  // saying how far it reaches (task-16-diagnosis X4; the user's "My word wins", 2026-10-20). The user's option kept
  // "the safety defaults (such as no shipping without tests)": the guards back D1 to D3, D8 and D12, and this line
  // keeps D11 and D7, which nothing else every session loads backs (Task 16g review, I1).
  assertContains('kernel/kernel.md', [
    "The user's skip or opt-out covers only what they name; say in one line what you skipped and its risk. Evidence, the guards, tests for new behaviour and expand/contract for stored data still hold.",
  ]);
});

test('a step not done stays in the todo list, and only the user\'s word skips a review', () => {
  // 2026-10-22 head-to-head (task-16-h2h-plan-diagnosis): "A step you do not do stays as `skip: <reason>`" let kern
  // skip plan's review on its own judgement in 3 of 6 runs. The user's answer, "Only by my word": plan's and
  // define's reviews, and execute-plan's task and final reviews, are skipped only when the user says so (Task 16n).
  assertContains('kernel/kernel.md', ["A step you do not do stays as `skip: <reason>`; only the user's word skips a review, never your own judgement."]);
  const text = readFileSync(join(ROOT, 'kernel', 'kernel.md'), 'utf8');
  assert.doesNotMatch(text, /A step you do not do stays as `skip: <reason>`\. /, 'the unconditional skip sentence is gone');
});

test('the header says what ${CLAUDE_PLUGIN_ROOT} means in a kern file read by path', () => {
  // The session-start render fills {ROOT} with the plugin root, so the line names an absolute path.
  assertContains('kernel/kernel.md', ['In kern files read by path, ${CLAUDE_PLUGIN_ROOT} means {ROOT}.']);
});
