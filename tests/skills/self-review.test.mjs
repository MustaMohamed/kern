// tests/skills/self-review.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/self-review/SKILL.md';
const REF = 'skills/self-review/references';

test('self-review frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'self-review',
    description: 'Check your own diff before a PR: deterministic checks, blast radius, probes, a fresh doubt pass, then a verdict.',
    'disable-model-invocation': 'true',
  });
});

test('self-review sections and steps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot']);
  const s = steps(body);
  assert.equal(s.length, 11);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['${CLAUDE_PLUGIN_ROOT}/scripts/floor-scan', '${CLAUDE_PLUGIN_ROOT}/scripts/claim-check', '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests',
    '${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate', 'never the worktree', 'Skill tool with `code-review`', 'Never pass `--comment`', 'skip: built-in code-review not available',
    'A skipped check counts as failed', '`ready`, `fix first`, `rebase first` or `split`', 'mode `whole-branch`', 'skip: no spec', 'Declined to judge', 'look where grep stops',
    'visual pages not installed']);
  assert.ok(!readDoc(SKILL).raw.includes('$(git'), 'no command substitution in a command the skill prescribes');
  assertMaxBytes(SKILL, 6400);
});

test('self-review exits, order and dispatches', () => {
  assertContains(SKILL, [
    // scope and its exits
    'git -C <wt> fetch origin <base>', 'report "base not refreshed"', 'never with "base not refreshed" reported', 'git -C <wt> merge-base HEAD origin/<base>',
    '${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base>', '`<package>.patch` sits beside it', 'with `<package>.patch` from step 1', 'Exit 3 is an empty diff', 'nothing to review',
    // settings resolution
    '${CLAUDE_PLUGIN_ROOT}/scripts/kern-get', '${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect', 'never guess a command',
    // deterministic exits
    'floor-scan exit 1', 'claim-check exit 1', 'any other non-zero exit is a failed check',
    // probe exits
    'probe exit 1 (no failure, or the mutation survived)', 'a probe exit 1,', 'probe exit 3', 'inconclusive', 'never as a pass',
    // dispatches
    '`kern:task-reviewer` on model `model.reviewer`', '`kern:task-reviewer`', "the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus",
    '`kern:investigator` on model `model.reviewer`', 'where does this artifact fail this contract?', 'never your claim or reasoning', 'with absolute paths only', 'both absolute paths as scope',
    // rebase first trigger
    'git -C <wt> rev-parse origin/<base>', 'git -C <wt> diff --name-only <merge-base> origin/<base>', 'names a path the package also changed', 'never rebases',
    // autopilot
    'never through AskUserQuestion', '`autopilot ON:` reminder', '`kern mode:` line with `autopilot=on`', 'the kernel\'s "Autopilot:" line',
    'parked: <question>; default: <choice>; why: <one line>', 'lessons are not written',
  ]);
});

test('self-review references', () => {
  const refs = {
    'blast-radius.md': [['# Blast radius', '## How sure are you', '## Writer sweep', '## Where grep stops', '## Risks and cleared'], 2600],
    'doubt-cycle.md': [['# Doubt cycle', '## When a decision is non-trivial', '## The fresh reviewer', '## Reconcile', '## Doubt theater', '## Stop after three'], 2400],
    'claim-checks.md': [['# Claim checks', '## floor-scan', '## claim-check', '## probe', '## A skipped check is a failed check'], 1700],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`${REF}/${f}`, hs);
    assertMaxBytes(`${REF}/${f}`, max);
  }
  assertContains(`${REF}/claim-checks.md`, ['probe --exclude-tests', 'probe --mutate', 'probe: mutation caught']);
  assertContains(`${REF}/blast-radius.md`, ['You said so', 'You pointed at the line', 'You showed the bad case can\'t happen', 'You ran it', 'You reproduced it in the app', 'every writer', 'reader sweep only answers who breaks', 'feature flag', 'unproven']);
  assertContains(`${REF}/doubt-cycle.md`, ['Never the claim', 'contract misread', 'actionable', 'trade-off', 'noise', 'none was classed actionable', 'validating, not doubting', 'goes back to be split']);
});

test('self-review text hygiene', () => {
  for (const f of [SKILL, `${REF}/blast-radius.md`, `${REF}/doubt-cycle.md`, `${REF}/claim-checks.md`, 'tests/skills/self-review.acceptance.md']) {
    const { raw } = readDoc(f);
    assert.ok(!/[—–‘’“”]/.test(raw), `${f}: no long dashes or curly quotes`);
  }
});
