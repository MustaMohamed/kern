// tests/skills/define.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/define/SKILL.md';

test('define frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'define',
    description: 'Clarify new behaviour, size it after the intent, and get an explicit yes before code unless the user calls it quick.',
    'disable-model-invocation': 'true',
    'argument-hint': '[issue id | idea]',
  });
});

test('define sections, steps, the standing gate and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 11);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['Standing gate on every path', '"sounds good", "whatever you think" and silence do not', 'status: approved', 'status: draft (parked under autopilot)',
    'kern:investigator', 'on `model.investigator`', 'The map is approved before any module spec', '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check',
    'one whole line of the user\'s yes, verbatim', 'wt-new <slug> --detach', 'Never ask the user a fact the repo can answer',
    'A request with no existing flow to extend is architectural', 'visual pages not installed', 'Guard G20',
    "when the user's own words call the task quick and clear", 'no design, spec or approval', 'commits, pushes and every other ask stay gated',
    'Size it now, in plain words; the user may override', '`references/handover.md`', 'The fast path runs.',
    'Only the user\'s own "quick and clear" skips the design']);
  assert.match(s[1], /^1\. Fast path: /, 'the fast path is step 1');
  assert.match(s[5], /^5\. Restate /, 'step 5 restates');
  assert.match(s[6], /^6\. Size it now/, 'step 6 sizes, after the restate');
  assertMaxBytes(SKILL, 6500);
});

test('define references', () => {
  const refs = {
    'spec-template.md': [['# Spec template', '## Problem', '## Intent', '## Constraints', '## Assumptions', '## Success criteria', '## Acceptance criteria', '## Decisions', '## Compatibility', '## Authorization', '## Rollout', '## Checklists', '## Test seams', '## Not doing', '## Open questions'], 3000],
    'interview.md': [['# Interview', '## Skip offer and build choices', '## Hypothesis and confidence', '## One question at a time', '## Want versus should-want', '## Restate and confirm', '## When to step back'], 3200],
    'spec-review.md': [['# Spec reviewer brief', '## What to check', '## Builder questions', '## Calibration', '## Output'], 1600],
    'handover.md': [['# Handover', '## Sort', '## Hand over'], 1200],
    'capability-map.md': [['# Capability map', '## When to split', '## Map format', '## Approval'], 1200],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`skills/define/references/${f}`, hs);
    assertMaxBytes(`skills/define/references/${f}`, max);
  }
  assertContains('skills/define/references/spec-template.md', ['Copy from the first `---` line to the end', '- Always:', '- Ask first:', '- Never:', 'form: short', 'the highest seam that already exists and the fewest seams',
    'Anti-goals: what would make it a failure even if it works', 'Prior art:', "`kern's call`", 'name what is left to the builder']);
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
