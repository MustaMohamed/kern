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
    'A skipped check counts as failed', 'mode `whole-branch`', 'skip: no spec', '"Declined to judge" list', 'the Declined to judge list', 'look where grep stops',
    'visual pages not installed', 'then the smell baseline (`references/smells.md`)']);
  assert.ok(!readDoc(SKILL).raw.includes('$(git'), 'no command substitution in a command the skill prescribes');
  assertMaxBytes(SKILL, 7000);
});

test('self-review exits, order and dispatches', () => {
  assertContains(SKILL, [
    // scope and its exits
    'git -C <wt> remote get-url origin', 'no remote: `<baseref>` is local `<base>`', 'git -C <wt> fetch origin <base>', 'report "base not refreshed"',
    'git -C <wt> merge-base HEAD <baseref>', 'failure stops the run, output reported', 'references/rounds.md',
    '${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base> --out <package>', '`<package>.patch` sits beside it', 'lines 3 on are the changed paths',
    'Exit 3 is an empty diff', 'nothing to review', 'any other non-zero exit stops and reports',
    // settings resolution
    '${CLAUDE_PLUGIN_ROOT}/scripts/kern-get', '${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect', 'exit 3 takes the table default', 'never guess a command',
    '| `scope_threshold` | 4 files |', '| `base_branch` | detected |',
    // deterministic exits
    'exit 1 from either is hits', 'any other non-zero exit, or a red `verify.fast` or test, is a failed check',
    // probe
    '`{file}` or `{dir}` replaced by the one test file covering the change, no shell syntax', "one guard alone is implement's per-slice probe",
    '`<file>` is relative to `<wt>`', '`<line>` from the working file', 'probe inverts the first operator on that line',
    'probe exit 1 (no failure, or the mutation survived), 2 and 3 each fail the check', 'exit 3 is reported inconclusive, never as a pass',
    'For each new guard test', 'But exit 3 for a module or export the patch adds, or a test-only patch, is `probe inconclusive: new module`, not a failure',
    '`--mutate` on the new code proves it', 'finish-branch step 5',
    // dispatches
    '`kern:task-reviewer` on model `model.reviewer`', '`kern:investigator` on model `model.reviewer`', "the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus",
    'where does this artifact fail this contract?', 'never your claim or reasoning', 'with absolute paths only', 'both absolute paths as scope',
    // verdict
    '(ordered high to low)', 'then one verdict, tested in order: `split`, `fix first`, `rebase first`, else `ready`',
    '`split`: a later round where this package has more than `scope_threshold` paths and the previous one did not',
    'a finding lands in an added line of the since package', 'a first round never splits',
    '`fix first`: a failed or unrun check (step 2 or 7), an unresolved hit, or a finding in the first two classes', "(the spec lane's Critical and Important count)",
    '`rebase first`: `git -C <wt> rev-parse <baseref>` differs from `<merge-base>`', 'git -C <wt> diff --name-only <merge-base> <baseref>', 'names a path the package also changed',
    'or "base not refreshed" is reported', 'self-review never rebases', 'If `fix first` wins, still report a rebase need', 'A lane skip line is reported and does not change the verdict',
    // autopilot
    'never through AskUserQuestion', '`autopilot ON:` reminder', '`kern mode:` line with `autopilot=on`', 'the kernel\'s "Autopilot:" line',
    'parked: <question>; default: <choice>; why: <one line>', 'a failed fetch (origin exists) goes on with the last fetched ref', 'any `wt-diff` non-zero exit end the run', 'lessons are not written',
  ]);
});

test('self-review references', () => {
  const refs = {
    'blast-radius.md': [['# Blast radius', '## How sure are you', '## Writer sweep', '## Where grep stops', '## Risks and cleared'], 2600],
    'doubt-cycle.md': [['# Doubt cycle', '## When a decision is non-trivial', '## The fresh reviewer', '## Reconcile', '## Doubt theater', '## Stop after three'], 2400],
    'rounds.md': [['# Rounds and packages', '## Package names', '## Previous package', '## Since package'], 1400],
    'claim-checks.md': [['# Claim checks', '## floor-scan', '## claim-check', '## probe', '## A skipped check is a failed check'], 1700],
    'smells.md': [['# Smell baseline', '## Rules', '## Smells'], 2200],
  };
  assertContains(`${REF}/smells.md`, ['in the `should-fix` class at most, never a blocker', 'A `review.rules` file that endorses what a smell would flag wins',
    'Skip what lint, the formatter or the type checker already enforces', ...['Mysterious Name', 'Duplicated Code', 'Feature Envy', 'Data Clumps', 'Primitive Obsession',
      'Repeated Switches', 'Shotgun Surgery', 'Divergent Change', 'Speculative Generality', 'Message Chains', 'Middle Man', 'Refused Bequest'].map((s) => `- ${s}: `)]);
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`${REF}/${f}`, hs);
    assertMaxBytes(`${REF}/${f}`, max);
  }
  assertContains(`${REF}/claim-checks.md`, ['probe --exclude-tests', 'probe --mutate', 'probe: mutation caught', 'non-test changes reversed', "implement's per-slice probe", 'Exit 2 is a usage error',
    'shows a guard test fails', 'except when its reason is a module or export the patch adds or the patch holds test files only: report `probe inconclusive: new module`',
    'prove the new code with `--mutate` on its condition']);
  assertContains(`${REF}/rounds.md`, ['<reviews>/<slug>-<N+1>.diff', 'kern-dir reviews', 'the text after `..`', 'wt-diff <wt> <previous-tree> --out', 'means a first round', '`detached`']);
  assertContains(`${REF}/blast-radius.md`, ['You said so', 'You pointed at the line', 'You showed the bad case can\'t happen', 'You ran it', 'You reproduced it in the app', 'every writer', 'reader sweep only answers who breaks', 'feature flag', 'reported as unproven', 'or "unproven"', 'never make up a caller or an API', 'Paste what happened']);
  assertContains(`${REF}/doubt-cycle.md`, ['Never the claim', '- contract misread: ', '- actionable: a real fault', '- trade-off: ', '- noise: ', 'none was classed actionable', 'assume the author is overconfident', 'say explicitly when no fault turns up', 'under autopilot, park it', 'validating, not doubting', 'goes back to be split']);
});

test('self-review text hygiene', () => {
  for (const f of [SKILL, `${REF}/rounds.md`, `${REF}/blast-radius.md`, `${REF}/doubt-cycle.md`, `${REF}/claim-checks.md`, 'tests/skills/self-review.acceptance.md']) {
    const { raw } = readDoc(f);
    assert.ok(!/[—–‘’“”]/.test(raw), `${f}: no long dashes or curly quotes`);
  }
});
