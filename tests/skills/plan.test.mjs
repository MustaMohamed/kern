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
  assertContains(SKILL, ['Not approved: stop and route to define', 'gh pr list --search', 'never parallel', '`step`, `inline` or `delegate`', 'execution:', 'commits: ask',
    '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check', 'gets a spike first', 'prefactor', 'expand, migrate in batches, then contract', "spec's Constraints section",
    'on `model.investigator`', "one whole line of the user's yes, verbatim", 'visual pages not installed']);
  assertMaxBytes(SKILL, 6500);
});

test('plan templates are contracts task-brief and plan-check can read', () => {
  assertHeadings('skills/plan/references/plan-template.md', ['# Plan template', '## Global Constraints', '## Review Focus', '## File map']);
  assertContains('skills/plan/references/plan-template.md', ['Copy from the first `---` line to the end', 'status: draft', 'approved: (set only on an explicit yes', 'execution:', 'commits: ask', '### Task 1:', 'Always, Ask first, Never']);
  assertMaxBytes('skills/plan/references/plan-template.md', 2200);
  assertHeadings('skills/plan/references/task-template.md', ['# Task template', '### Task N: <name>']);
  assertContains('skills/plan/references/task-template.md', ['**Files:**', '**Interfaces:**', 'Consumes:', 'Produces:', '**Blocked by:**', '**Acceptance:**', 'Run it to verify it fails', 'Expected:', '`plan-check` fails a task']);
  assertMaxBytes('skills/plan/references/task-template.md', 2200);
  assertHeadings('skills/plan/references/plan-review.md', ['# Plan reviewer brief', '## What to check', '## Calibration', '## Output']);
  assertMaxBytes('skills/plan/references/plan-review.md', 1400);
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
  assertContains('skills/plan/references/plan-review.md', ['`Verdict: approve | revise`', 'Round 1 only']);
});
