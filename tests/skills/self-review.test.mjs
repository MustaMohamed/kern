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
    '| `scope_threshold` | 4 files |', '| `base_branch`, `test.focused` | detected |',
    // deterministic exits
    'exit 1 from either is hits', 'any other non-zero exit, or a red `verify.fast` or test, is a failed check',
    // probe
    // Fix round 2: what --exclude-tests proves ("non-test changes reversed") is pinned in claim-checks.md below; the
    // pass lines decide the check
    '`{file}` or `{dir}` replaced by the one test file covering the change, no shell syntax',
    '`<file>` is relative to `<wt>`', '`<line>` from the working file', 'probe inverts the first operator on that line', 'For each new guard test',
    // Task 16o: the other exits, and the new-module exit 3, are stated in references/claim-checks.md (pinned below)
    // Task 16o fix round 1, M1: the test-only exception is inline again; probe prints it as inconclusive (scripts/probe)
    'Only `probe: fail-then-pass ok` and `probe: mutation caught` pass; any other exit fails the check, except a new module or a test-only patch (`references/claim-checks.md`).',
    // dispatches
    '`kern:task-reviewer` on model `model.reviewer`', '`kern:investigator` on model `model.reviewer`', "the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus",
    'with absolute paths only',
    // Task 16o fix round 1 left the doubt cycle's dispatch text to references/doubt-cycle.md (pinned below). Re-review 1:
    // a run that dispatches from memory could send its own claim, so step 8 keeps the hard rule inline (fix round 2).
    '8. Doubt cycle, for non-trivial decisions only: open `references/doubt-cycle.md` before dispatching `kern:investigator` on model `model.reviewer`, and never send it your claim or reasoning; at most 3 cycles.',
    // verdict
    '(ordered high to low)', 'then one verdict, tested in order: `split`, `fix first`, `rebase first`, else `ready`',
    // Task 16o: the later-round split rule is in references/rounds.md (pinned below). Task 17a P10: "a first round
    // never splits" went to fit the cap; rounds.md says it ("`split` cannot apply", pinned below), and step 1 reads it.
    '`split`: a later round, as `references/rounds.md` says.',
    '`fix first`: a failed or unrun check (step 2 or 7), an unresolved hit, or a finding in the first two classes', "(the spec lane's Critical and Important count)",
    // Task 17a P10: the restated `rev-parse <baseref>` test went to pay for D19; a diff that names a path already
    // means `<baseref>` differs from `<merge-base>`.
    '`rebase first`: `git -C <wt> diff --name-only <merge-base> <baseref>` names a path the package also changed', 'names a path the package also changed',
    'or "base not refreshed" is reported', 'self-review never rebases', 'If `fix first` wins, still report a rebase need', 'A lane skip line is reported and does not change the verdict',
    // autopilot
    'never through AskUserQuestion', '`autopilot ON:` reminder', '`kern mode:` line with `autopilot=on`', 'the kernel\'s "Autopilot:" line',
    'parked: <question>; default: <choice>; why: <one line>', 'a failed fetch (origin exists) goes on with the last fetched ref', 'any `wt-diff` non-zero exit end the run', 'lessons are not written',
  ]);
});

test('a self-review finding is a defect on a changed line, a nit is a small one, and what is checked and fine goes to Cleared', () => {
  // Task 16o: on 2026-10-22 six of kern's 11 head-to-head review false alarms sat under Nits: a behaviour-keeping
  // test move (decoy d3), a missing test as its own item, a guess kern called probably fine, and a split suggestion
  // (task-16-h2h-review-diagnosis). The user kept the nit class, limited to real defects ("Keep, but limited").
  const nine = steps(readDoc(SKILL).body)[9];
  // Fix round 1, I1: the definition agrees with the `pre-existing` class, the smell baseline and step 6's callers.
  for (const s of ['9. Verdict. A finding is a defect on a changed line or at a caller or contract the change breaks: `path:line` and how it fails.',
    // Task 17a P10, D3: a smell is a `nit` (the user, 2026-10-22: "Smells are nits"), pinned in the test below
    'A defect the change did not cause goes under `pre-existing`;', 'a `nit` is a real defect too small to block;', 'a smell is a `nit`.',
    'Not findings: a change that keeps behaviour (a moved test, an equivalent helper or rename) or a justified step 2 hit, each under Cleared with its check;',
    // Fix round 1, M2: a missing test no finding covers stays in the report as its own line. Task 17a P10, D19: that
    // line goes under `Untested` and says it is not a finding (pinned in the test below).
    'a probably-fine guess;', 'style advice;', 'a first-round split idea.',
    'List findings in `review.taxonomy` classes (ordered high to low)']) assert.ok(nine.includes(s), `step 9 lacks: ${s}`);
  assert.ok(nine.indexOf('A finding is a defect') < nine.indexOf('List findings in'), 'the definition comes before the findings are listed');
  assertContains(SKILL, ['| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` |', 'the Declined to judge list, the Cleared and `Untested` lists, the verdict.']);
  // The "Reached by" sentence went to fit the 7,000-byte cap (Task 16o), as plan's and define's did.
  assert.ok(!readDoc(SKILL).raw.includes('Reached by'), 'no Reached by sentence');
  assertContains('tests/skills/self-review.acceptance.md', ['behaviour-keeping change', 'lands in Cleared with its check', 'with no such finding, the missing test is one line under `Untested`',
    'for any reason but a new module or a test-only patch']);
  // The classes and the smell rule step 9 now names must still say so where they live.
  assertContains(SKILL, ['`blocker,should-fix,nit,pre-existing`']);
  assertContains(`${REF}/smells.md`, ['in the `nit` class.']);
});

test('a smell or an uncovered missing test never blocks, and a later round splits only on a blocking fix-line finding', () => {
  // Task 17a P10, from the Opus audit of 2026-10-22 (docs/research/opus-audit-2026-10-22.md). D3: a smell filed as
  // `should-fix` made the verdict `fix first`, which stops finish-branch. D4: in a later round any finding on an added
  // line of the since package, a nit included, gave `split`. D19: the trim dropped "not a finding" from the missing-test
  // clause, and Outputs had no slot for the line. The user, 2026-10-22: "Smells are nits"; `split` holds on the size
  // rule, or when a `blocker` or `should-fix` finding lands on a line the previous round asked to change.
  const nine = steps(readDoc(SKILL).body)[9];
  for (const s of ['a smell is a `nit`.', 'a missing test no finding covers: one line under `Untested`, not a finding; the verdict ignores it;'])
    assert.ok(nine.includes(s), `step 9 lacks: ${s}`);
  assert.ok(!readDoc(SKILL).raw.includes('`should-fix` at most'), 'step 9 no longer files a smell as should-fix');
  assertContains(`${REF}/smells.md`, ['- A smell is a labelled judgment call, such as "possible Feature Envy", in the `nit` class.']);
  assert.ok(!readDoc(`${REF}/smells.md`).raw.includes('should-fix'), 'smells.md names no should-fix class');
  assertContains(`${REF}/rounds.md`, ['None means a first round: no since package, and `split` cannot apply.']);
  assert.ok(!readDoc(`${REF}/rounds.md`).raw.includes('an added line of the since package'), 'a finding on any added line no longer splits');
  assertContains('tests/skills/self-review.acceptance.md', ['A smell alone leaves the verdict `ready`.',
    'a `nit` on a line the round 1 findings asked to change does not give `split`', 'a `should-fix` finding in the new work gives `fix first`, not `split`',
    'one line under `Untested`, not a finding, and the verdict ignores it']);
});

test('self-review runs its checks in the worktree, and verify.fast defaults to each of typecheck and lint that resolves', () => {
  // Task 17a P10, D7: step 2 named no tree, so a standalone self-review could prove the main checkout. The `cd` is a
  // call of its own, as finish-branch step 2 does it.
  assert.ok(steps(readDoc(SKILL).body)[2].includes("Run `verify.fast` and step 7's `<test>` from `<wt>`, a `cd <wt>` as its own call first."), 'step 2 names the tree');
  // D16: "`typecheck` then `lint`" read as both, so a repo with lint and no typecheck never got a green verify.fast.
  const d16 = 'each of `typecheck` and `lint` that resolves; at least one';
  assertContains(SKILL, [`| \`verify.fast\` | ${d16} |`, '| `base_branch`, `test.focused` | detected |']);
  assertContains('skills/prove-it/SKILL.md', [`| \`verify.fast\` | ${d16} | quick proof before a commit |`]);
  assertContains('kernel/settings.md', [`| \`verify.fast\` | ${d16} | command | self-review, prove-it |`]);
  for (const f of [SKILL, 'skills/prove-it/SKILL.md', 'kernel/settings.md']) assert.ok(!/`typecheck`,? then `lint`/.test(readDoc(f).raw), `${f}: no "typecheck then lint" default`);
});

test('self-review references', () => {
  const refs = {
    'blast-radius.md': [['# Blast radius', '## How sure are you', '## Writer sweep', '## Where grep stops', '## Risks and cleared'], 2600],
    'doubt-cycle.md': [['# Doubt cycle', '## When a decision is non-trivial', '## The fresh reviewer', '## Reconcile', '## Doubt theater', '## Stop after three'], 2400],
    'rounds.md': [['# Rounds and packages', '## Package names', '## Previous package', '## Since package'], 1400],
    'claim-checks.md': [['# Claim checks', '## floor-scan', '## claim-check', '## probe', '## A skipped check is a failed check'], 1700],
    'smells.md': [['# Smell baseline', '## Rules', '## Smells'], 2200],
  };
  assertContains(`${REF}/smells.md`, ['in the `nit` class.', 'A `review.rules` file that endorses what a smell would flag wins',
    'Skip what lint, the formatter or the type checker already enforces', ...['Mysterious Name', 'Duplicated Code', 'Feature Envy', 'Data Clumps', 'Primitive Obsession',
      'Repeated Switches', 'Shotgun Surgery', 'Divergent Change', 'Speculative Generality', 'Message Chains', 'Middle Man', 'Refused Bequest'].map((s) => `- ${s}: `)]);
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`${REF}/${f}`, hs);
    assertMaxBytes(`${REF}/${f}`, max);
  }
  assertContains(`${REF}/claim-checks.md`, ['probe --exclude-tests', 'probe --mutate', 'probe: mutation caught', 'non-test changes reversed', "implement's per-slice probe", 'Exit 2 is a usage error',
    'shows a guard test fails', 'except when its reason is a module or export the patch adds or the patch holds test files only: report `probe inconclusive: new module`',
    'prove the new code with `--mutate` on its condition',
    // Task 17a P10, from the P4 review: probe refuses an absolute or `..` `--mutate` path with exit 2
    '`probe --mutate <file>:<line> <wt> -- <test>`, `<file>` relative to `<wt>`, inverts the first operator on that line',
    // Task 16o: SKILL.md step 7 now names only the two passes and points here, so exit 1 says it fails the check, as step 7 did
    'probe: fail-then-pass ok', 'Exit 1 (no failure, or the mutation survived) fails the check', 'Exit 3 is inconclusive, never a pass, and fails the check']);
  assertContains(`${REF}/rounds.md`, ['<reviews>/<slug>-<N+1>.diff', 'kern-dir reviews', 'the text after `..`', 'wt-diff <wt> <previous-tree> --out', 'means a first round', '`detached`',
    // Task 16o: moved from SKILL.md step 9 to fit its cap. Task 17a P10, D4: only a blocking finding on a fix line splits.
    "A later round's verdict is `split` when this package has more than `scope_threshold` paths and the previous one did not, or a `blocker` or `should-fix` finding lands on a line the previous round's findings asked to change."]);
  assertContains(`${REF}/blast-radius.md`, ['You said so', 'You pointed at the line', 'You showed the bad case can\'t happen', 'You ran it', 'You reproduced it in the app', 'every writer', 'reader sweep only answers who breaks', 'feature flag', 'reported as unproven', 'or "unproven"', 'never make up a caller or an API', 'Paste what happened']);
  assertContains(`${REF}/doubt-cycle.md`, ['Never the claim', '- contract misread: ', '- actionable: a real fault', '- trade-off: ', '- noise: ', 'none was classed actionable', 'assume the author is overconfident', 'say explicitly when no fault turns up', 'under autopilot, park it', 'validating, not doubting', 'goes back to be split',
    // Task 16o fix round 1: moved here from SKILL.md step 8, which points to this file
    'Dispatch `kern:investigator` on model `model.reviewer`', 'the question "where does this artifact fail this contract?"', 'the two absolute paths as scope', 'Never the claim, never your reasoning']);
});

test('self-review text hygiene', () => {
  for (const f of [SKILL, `${REF}/rounds.md`, `${REF}/blast-radius.md`, `${REF}/doubt-cycle.md`, `${REF}/claim-checks.md`, 'tests/skills/self-review.acceptance.md']) {
    const { raw } = readDoc(f);
    assert.ok(!/[—–‘’“”]/.test(raw), `${f}: no long dashes or curly quotes`);
  }
});

test('the skills spec names the finish-branch step that runs self-review', () => {
  // Task 16o review, M5: spec C8 said step 4 after finish-branch moved its self-review read to step 5.
  const n = steps(readDoc('skills/finish-branch/SKILL.md').body).findIndex((l) => l.includes('skills/self-review/SKILL.md'));
  assert.equal(n, 5);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [`by \`finish-branch\` step ${n}, or typed \`/kern:self-review\`.`]);
});
