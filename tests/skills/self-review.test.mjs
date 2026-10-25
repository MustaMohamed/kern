// tests/skills/self-review.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

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
  // Task 16q paid its bytes partly by naming `claim-check`, `probe --mutate`, `kern-detect` and `kern-dir tmp` bare, as
  // prove-it names `kern-detect` after `kern-get`: the main kernel's `Scripts:` line resolves a bare name, and only the
  // main session reads this skill (the kernel row and finish-branch step 5; no agent does). M2b Task 17 named
  // `floor-scan` (step 2) and `probe --exclude-tests` (step 7) bare the same way, after wt-diff's full path in step 1,
  // to pay for step 9's `bar-lowered` clause (P69) and step 6's manifest trigger (AD11) within the 7,000-byte cap.
  assertContains(SKILL, ['Run `floor-scan <package>` and `claim-check <wt> <package>`', 'For each new guard test: `probe --exclude-tests <wt> <package>.patch -- <test>`.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base> --out <package>`',
    'For a new conditional, one `probe --mutate <file>:<line> <wt> -- <test>`', 'never the worktree', 'Skill tool with `code-review`', 'Never pass `--comment`', 'skip: built-in code-review not available',
    'A skipped check counts as failed', 'mode `whole-branch`', 'skip: no spec', '"Declined to judge" list', 'the Declined to judge list', 'open `references/blast-radius.md`', 'look where grep stops',
    'visual pages not installed', 'then the smell baseline (`references/smells.md`)']);
  assert.ok(!readDoc(SKILL).raw.includes('$(git'), 'no command substitution in a command the skill prescribes');
  // 7,650 since the pilot fix plan's Task 6 (raised from 7,001): proof-check, the shared-piece read, the caller path
  // and the ruling per finding.
  // 7,900 since Task 6 fix round 1 (I1): the spec found before proof-check, and its not-run line for a spec with no numbered lines.
  // 7,950 since Task 6 fix round 2 (I1): step 9's `fix first` exempts the proof-check not-run line.
  // 8,050 since the pilot-fix test round's fix (2026-10-25): "a small diff skips none" and the ruling on each finding in Outputs.
  // 8,250 since its proofs fix: "or a blocker already found, skips nothing" and step 9's pasted-output gate.
  assertMaxBytes(SKILL, 8250);
});

test('self-review exits, order and dispatches', () => {
  assertContains(SKILL, [
    // scope and its exits
    'git -C <wt> remote get-url origin', 'no remote: `<baseref>` is local `<base>`', 'git -C <wt> fetch origin <base>', 'report "base not refreshed"',
    'git -C <wt> merge-base HEAD <baseref>', 'failure stops the run, output reported', 'references/rounds.md',
    '${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base> --out <package>', '`<package>.patch` sits beside it', 'lines 3 on are the changed paths',
    'Exit 3 is an empty diff', 'nothing to review', 'any other non-zero exit stops and reports',
    // settings resolution
    '${CLAUDE_PLUGIN_ROOT}/scripts/kern-get', '`typecheck` and `lint` then try `kern-detect <key>`', 'exit 3 takes the table default', 'never guess a command',
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
    '`fix first`: a failed or unrun check (step 2 or 7; not the `proof-check: not run` line), an unresolved hit, or a finding in the first two classes', "(the spec lane's Critical and Important count)",
    // Task 17a P10: the restated `rev-parse <baseref>` test went to pay for D19; a diff that names a path already
    // means `<baseref>` differs from `<merge-base>`.
    '`rebase first`: `git -C <wt> diff --name-only <merge-base> <baseref>` names a path the package also changed',
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
  for (const s of ['A finding is a defect on a changed line or at a caller or contract the change breaks: `path:line` and how it fails.',
    // Task 17a P10, D3: "a smell is a `nit`" (the user, 2026-10-22: "Smells are nits") is pinned in the test below
    // Task 16q narrowed `pre-existing` and the nit, and moved style into the Cleared clause (pinned in its test below).
    'the change did not cause goes under `pre-existing`;', 'a `nit` is a real defect too small to block',
    'Not findings: a change that keeps behaviour (a moved test, an equivalent helper or rename)', 'or a justified step 2 hit (`bar-lowered`: only the user\'s typed yes), each under Cleared with its check',
    // Fix round 1, M2: a missing test no finding covers stays in the report as its own line. Task 17a P10, D19: that
    // line goes under `Untested` and says it is not a finding (pinned in the test below).
    'a probably-fine guess', 'a first-round split idea.',
    'List findings in `review.taxonomy` classes (ordered high to low)']) assert.ok(nine.includes(s), `step 9 lacks: ${s}`);
  assert.ok(nine.indexOf('A finding is a defect') < nine.indexOf('List findings in'), 'the definition comes before the findings are listed');
  assertContains(SKILL, ['| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` |', 'the Declined to judge list, the Cleared and `Untested` lists, the verdict.']);
  // The "Reached by" sentence went to fit the 7,000-byte cap (Task 16o), as plan's and define's did.
  assert.ok(!readDoc(SKILL).raw.includes('Reached by'), 'no Reached by sentence');
  // Task 17a P10: the acceptance line for the missing test is pinned in the test below.
  assertContains('tests/skills/self-review.acceptance.md', ['behaviour-keeping change', 'lands in Cleared with its check',
    'for any reason but a new module or a test-only patch']);
  // The classes step 9 names must still say so where they live; the smell rule is pinned in the test below.
  assertContains(SKILL, ['`blocker,should-fix,nit,pre-existing`']);
});

test('a smell or an uncovered missing test never blocks, and a later round splits only on a blocking fix-line finding', () => {
  // Task 17a P10, from the Opus audit of 2026-10-22 (docs/research/opus-audit-2026-10-22.md). D3: a smell filed as
  // `should-fix` made the verdict `fix first`, which stops finish-branch. D4: in a later round any finding on an added
  // line of the since package, a nit included, gave `split`. D19: the trim dropped "not a finding" from the missing-test
  // clause, and Outputs had no slot for the line. The user, 2026-10-22: "Smells are nits"; `split` holds on the size
  // rule, or when a `blocker` or `should-fix` finding lands on a line the previous round asked to change. Fix round 1:
  // rounds.md says "the first two classes", as step 9's `fix first` does, so a custom review.taxonomy splits too.
  // Fix round 1, Important 1: the missing-test clause keeps its covered half, so a missing test a finding covers is
  // never filed as a finding of its own; the clause sits in the "Not findings:" list.
  const nine = steps(readDoc(SKILL).body)[9];
  for (const s of ['a smell is a `nit`', 'a missing test, one line under the finding it would catch, else under `Untested`, which the verdict ignores;'])
    assert.ok(nine.includes(s), `step 9 lacks: ${s}`);
  assert.ok(!readDoc(SKILL).raw.includes('`should-fix` at most'), 'step 9 no longer files a smell as should-fix');
  assertContains(`${REF}/smells.md`, ['- A smell is a labelled judgment call, such as "possible Feature Envy", in the `nit` class.']);
  assert.ok(!readDoc(`${REF}/smells.md`).raw.includes('should-fix'), 'smells.md names no should-fix class');
  assertContains(`${REF}/rounds.md`, ['None means a first round: no since package, and `split` cannot apply.']);
  assert.ok(!readDoc(`${REF}/rounds.md`).raw.includes('an added line of the since package'), 'a finding on any added line no longer splits');
  assertContains('tests/skills/self-review.acceptance.md', ['A smell alone leaves the verdict `ready`.',
    'a `nit` on a line the round 1 findings asked to change does not give `split`', 'a `should-fix` finding in the new work gives `fix first`, not `split`',
    'with no such finding, the missing test is one line under `Untested`, not a finding, and the verdict ignores it',
    // Fix round 1, Minor 1: the D16 default must win over Inputs' "When both exit 3, ask" in a lint-only repo
    'A repo with a lint script and no typecheck: `verify.fast` runs lint alone, with no ask and no failed check, under autopilot too.']);
});

test('self-review runs its checks in the worktree, and verify.fast defaults to each of typecheck and lint that resolves', () => {
  // Task 17a P10, D7: step 2 named no tree, so a standalone self-review could prove the main checkout. The `cd` is a
  // call of its own, as finish-branch step 2 does it.
  assert.ok(steps(readDoc(SKILL).body)[2].includes("Run `verify.fast` and step 7's `<test>` from `<wt>`, a `cd <wt>` as its own call first."), 'step 2 names the tree');
  // D16: "`typecheck` then `lint`" read as both, so a repo with lint and no typecheck never got a green verify.fast.
  // prove-it's row and kernel/settings.md:41 are pinned in tests/skills/prove-it.test.mjs.
  assertContains(SKILL, ['| `verify.fast` | each of `typecheck` and `lint` that resolves; at least one |']);
  assert.ok(!/`typecheck`,? then `lint`/.test(readDoc(SKILL).raw), 'no "typecheck then lint" default');
});

test('self-review references', () => {
  const refs = {
    'blast-radius.md': [['# Blast radius', '## How sure are you', '## Writer sweep', '## Where grep stops', '## Risks and cleared'], 2600],
    'doubt-cycle.md': [['# Doubt cycle', '## When a decision is non-trivial', '## The fresh reviewer', '## Reconcile', '## Doubt theater', '## Stop after three'], 2400],
    'rounds.md': [['# Rounds and packages', '## Package names', '## Previous package', '## Since package'], 1400],
    // M2b Task 17 raised claim-checks.md from 1,700 by the 180 bytes P69's `bar-lowered` rule needs, with its earlier
    // yes (M3) and its committed revert (I3), after the lossless 19-byte cut of "run in seconds and" from the opening.
    // 1,939 since Task 6 fix round 2 (I1): the 59 bytes of the proof-check not-run exception.
    'claim-checks.md': [['# Claim checks', '## floor-scan', '## claim-check', '## probe', '## A skipped check is a failed check'], 1939],
    'smells.md': [['# Smell baseline', '## Rules', '## Smells'], 2200],
    'proofs.md': [['# Proofs', '## Table', '## Evidence', '## Gaps'], 1200],
  };
  assertContains(`${REF}/smells.md`, ['A `review.rules` file that endorses what a smell would flag wins',
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
    // Fix round 1, Minor 3: step 2's "pasting commands and output" does not reach step 7's probes
    'catch what reviewers miss; paste each run.',
    // Task 16o: SKILL.md step 7 now names only the two passes and points here, so exit 1 says it fails the check, as step 7 did
    'probe: fail-then-pass ok', 'Exit 1 (no failure, or the mutation survived) fails the check', 'Exit 3 is inconclusive, never a pass, and fails the check']);
  assertContains(`${REF}/rounds.md`, ['<reviews>/<slug>-<N+1>.diff', 'kern-dir reviews', 'the text after `..`', 'wt-diff <wt> <previous-tree> --out', '`detached`',
    // Task 16o: moved from SKILL.md step 9 to fit its cap. Task 17a P10, D4: only a blocking finding on a fix line splits.
    "A later round's verdict is `split` when this package has more than `scope_threshold` paths and the previous one did not, or a finding in the first two classes lands on a line the previous round's findings asked to change."]);
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

test('a nit says how its line fails, an equivalent helper is never pre-existing, and a no-edit request skips no step', () => {
  // Task 16q, from the 2026-10-23 head-to-head review (task-16-confirming-diagnosis, sections 3 and 6). The user,
  // 2026-10-23: "the review skill gets stricter about what counts as a finding and stops skipping code review".
  // Decoy d3, a test moved into `describe` and switched to `strictEqual` (the same check under node:assert/strict),
  // was a nit as "churn unrelated to discounts" in 3 of 3 kern runs. Run 0 filed decoy d1, an equivalent rounding
  // helper, as pre-existing ("It's the same behaviour as before, so I'd call it pre-existing"), and raised
  // "`getInvoice` has no caller in the repo ... Sure: uncertain".
  const { body } = readDoc(SKILL);
  const nine = steps(body)[9];
  for (const s of ['Only a real defect the change did not cause goes under `pre-existing`;',
    // Fix round 1, Minor 2: a smell has no failure of its own, so its name stands in for one and it stays a nit
    // (the user, 2026-10-22: "Smells are nits"), never Cleared as style.
    'a `nit` is a real defect too small to block, naming how its line fails; a smell is a `nit`, its name the failure.',
    'Not findings: a change that keeps behaviour (a moved test, an equivalent helper or rename), churn, style or "unrelated" with no failure, or a justified step 2 hit (`bar-lowered`: only the user\'s typed yes), each under Cleared with its check, never `pre-existing`;',
    'a probably-fine guess or a new export with no caller yet;']) assert.ok(nine.includes(s), `step 9 lacks: ${s}`);
  assert.ok(!nine.includes('style advice'), 'style with no failure goes under Cleared, not a bare not-findings item');
  // kern skipped the step 3 lane in 3 of 3 runs (tool calls Read, Bash, Bash) and, in run 0, every lane: "those
  // scripts write files, which you ruled out", after the prompt's "Do not edit files". wt-diff writes `<package>`
  // where references/rounds.md names it, under `kern-dir reviews`; the step 3 lane passes no `--fix` and no
  // `--comment`, so it writes nothing; only a skill's own rule or the user's word skips a review (Task 16n, kernel).
  const intro = body.slice(0, body.indexOf('## Steps'));
  assert.ok(intro.includes('A no-edit request skips no step: `<package>` goes under `kern-dir reviews`, not the user\'s files, and step 3 writes nothing. Only a request that names a check or lane skips it. A small diff, or a blocker already found, skips nothing: the fix round needs every failed check and unproven line.'), intro);
  // Rerun after 5d6e8be: still 0 of 3 ran proof-check. Two said the diff was small enough to read; one, that the
  // blockers already decided the verdict, so the skipped checks only listed as unfinished. Step 9 now waits for them.
  assert.ok(steps(body)[9].startsWith('9. Verdict, once each step 2 command has its output pasted; run any missing one first.'), steps(body)[9].slice(0, 120));
  // Paid round 2026-10-25: two of three runs skipped proof-check because "the diff is 10 lines", and no run gave each finding its ruling.
  assert.ok(section(body, '## Outputs').includes('findings under Standards and Spec, each ending in its ruling (`fix`, `ticket` or `reject: <citation>`)'));
  assertContains(`${REF}/rounds.md`, ['`<reviews>` is the output of `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir reviews`', "This run's `<package>` is `<reviews>/<slug>-<N+1>.diff`"]);
  assert.ok(steps(body)[3].includes('Never pass `--comment` and never `--fix`.'), 'the step 3 lane writes nothing');
  // The cuts that paid for these bytes left their duties where the steps point: step 2's hit handling in
  // claim-checks.md, step 6's proof and lists in blast-radius.md.
  assertContains(`${REF}/claim-checks.md`, ['Exit 1 means hits: each is fixed or justified in the report.', 'Exit 1 means hits: each gets evidence, a rewrite, or removal.']);
  assertContains(`${REF}/blast-radius.md`, ['find the one or two facts the change is safe because of and prove them by running code', '- Risks: ', '- Cleared: ']);
  // Fix round 1, Important 1: a run that reads SKILL.md alone opens no reference, so step 6 says to open blast-radius.md,
  // as step 8 says for doubt-cycle.md (Task 16o fix round 1); the fact the change is safe because of is in there.
  const s = steps(body);
  assert.ok(s[6].includes('gates behaviour on a property, or a manifest or lockfile changes: open `references/blast-radius.md`; read every writer `rg` finds; look where grep stops.'), s[6]);
  // Fix round 1, Minor 1: "lines 3 on" are wt-diff's output lines, not the package file's (scripts/wt-diff:4).
  assert.ok(s[1].includes('--out <package>`: `<package>.patch` sits beside it, output lines 3 on are the changed paths.'), s[1]);
  // Fix round 1, Minor 3: each new rule has a pilot line.
  assertContains('tests/skills/self-review.acceptance.md', [
    'The prompt says "Do not edit files": steps 1 to 3 still run, the built-in lane included',
    'The diff swaps inline rounding for an equivalent helper: the helper is under Cleared with its check, never a finding or `pre-existing`.',
    'The diff adds an export with no caller yet and nothing wrong in it: no finding names it.']);
});

test('the skills spec names the finish-branch step that runs self-review', () => {
  // Task 16o review, M5: spec C8 said step 4 after finish-branch moved its self-review read to step 5.
  const n = steps(readDoc('skills/finish-branch/SKILL.md').body).findIndex((l) => l.includes('skills/self-review/SKILL.md'));
  assert.equal(n, 5);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [`by \`finish-branch\` step ${n}, or typed \`/kern:self-review\`.`]);
});

test('the author never clears its own lowered bar: revert it, or fix first until the user types yes (coverage P69)', () => {
  // M2b Task 17, coverage P69 (t17-lane-2): pstack countersigns a loosened gate "because the owner is the one who
  // wants green" (poteto-mode/playbooks/autopilot-full.md:20). floor-scan finds the loosening as `bar-lowered`
  // (tests/scripts/floor-scan.bats), but step 9 filed any justified step 2 hit under Cleared, so the author could
  // clear its own lowered bar, reach `ready`, and finish-branch pushed under autopilot. The user's typed yes stands in
  // for the countersign, since in kern only the user merges. Every other floor-scan class keeps "fixed or justified".
  const nine = steps(readDoc(SKILL).body)[9];
  assert.ok(nine.includes('or a justified step 2 hit (`bar-lowered`: only the user\'s typed yes), each under Cleared with its check'), nine);
  // A `bar-lowered` hit the user has not said yes to is unresolved, which `fix first` already names.
  assert.ok(nine.includes('`fix first`: a failed or unrun check (step 2 or 7; not the `proof-check: not run` line), an unresolved hit,'), nine);
  const scan = section(readDoc(`${REF}/claim-checks.md`).body, '## floor-scan');
  // Fix round 1, M3: a yes typed earlier in the session stands. I3: an unstaged revert left HEAD equal to the tree
  // finish-branch step 4 proved, so the push shipped the lowered bar; the verdict now holds until the revert is
  // committed, and a changed head is tested again before any push (branch-ops.md, Proven tree).
  const rule = 'Only the user\'s typed yes this session justifies a `bar-lowered` hit; until one, or a revert committed with the work\'s files, `fix first`.';
  const auto = 'Under autopilot, make that revert and write a `parked:` line.';
  for (const s of ['Exit 1 means hits: each is fixed or justified in the report.', rule, auto]) assert.ok(scan.includes(s), `floor-scan section lacks: ${s}`);
  assert.ok(scan.indexOf('each is fixed or justified') < scan.indexOf(rule), 'the exception follows the rule every other class keeps');
  assert.ok(scan.indexOf(rule) < scan.indexOf(auto), '"that revert" is the committed one the rule names');
  assertContains('skills/finish-branch/references/branch-ops.md', ['Push only the proven tree: `git rev-parse HEAD^{tree}` must equal the tree from finish-branch step 4']);
  // The `parked:` line has the form self-review's Stops section and the execute-plan ledger (ledger-format.md) give;
  // lint rule 16 holds a skill's backticked ledger forms to docs/plans/contract.md, so the short form is named.
  assertContains(SKILL, ['Under autopilot a stop parks as `parked: <question>; default: <choice>; why: <one line>`']);
  assertContains('skills/execute-plan/references/ledger-format.md', ['`parked: <question>; default: <choice>; why: <one line>`']);
  assertContains('tests/skills/self-review.acceptance.md', ['The diff lowers a coverage threshold and the author justifies it: the `bar-lowered` hit is not under Cleared, and the verdict is `fix first` until the user types yes for it in chat or a revert is committed with the work\'s files.',
    'A yes typed earlier in the session stands; with it, the hit is under Cleared and the PR body\'s Merge danger names the change.',
    'Under autopilot, with no yes, the revert is committed with the work\'s files, a `parked:` line says so, and the pushed head holds the revert.',
    'A justified `debug-print` hit still goes under Cleared.']);
  // finish-branch's PR body names each kept one under Merge danger: pinned in tests/skills/finish-branch.test.mjs.
});

test('a manifest or lockfile change opens blast-radius, whose dependency bullet reviews it like code (coverage AD11)', () => {
  // M2b Task 17, coverage AD11 (t17-lane-4): addy checks a new dependency (does the stack already cover it, its size,
  // upkeep, known vulnerabilities and licence) and reviews an upgrade like code (its changelog, one dependency per
  // change, the suite green before and after), code-review-and-quality/SKILL.md:281-300. kern had no counterpart. A
  // version bump changes no symbol with callers outside its directory, so step 6 names the trigger.
  assert.ok(steps(readDoc(SKILL).body)[6].startsWith('6. Blast radius, when a changed symbol has callers outside its directory or gates behaviour on a property, or a manifest or lockfile changes: open `references/blast-radius.md`;'));
  // Step 6 says "look where grep stops", and a symbol search cannot show what a version bump changes.
  const grep = section(readDoc(`${REF}/blast-radius.md`).body, '## Where grep stops');
  for (const s of ['- A manifest or lockfile change (`package.json`, `go.mod`, `Cargo.lock` and the like): for a new dependency, check whether the stack already covers it, and its size, upkeep, known vulnerabilities and licence.',
    'Review an upgrade like code: read its changelog, upgrade one dependency per change, and see the suite green before and after.',
    // Fix round 1, I1: addy's points 4 and 5 and the thin-tests rule (code-review-and-quality/SKILL.md:298-300). The
    // thin-tests finding is named an exception to step 9's `Untested` rule, so the two do not conflict.
    'Read the lockfile diff, not just the manifest: one direct bump can pull in many indirect ones.', 'A hand-edited lockfile is a finding.',
    'Thin tests around what the dependency does are the finding, not `Untested`: a green suite then proves nothing, so add a test first.',
    'A check left undone goes under Risks.']) assert.ok(grep.includes(s), `Where grep stops lacks: ${s}`);
  // Fix round 1, M5: a pilot line for the dependency review.
  assertContains('tests/skills/self-review.acceptance.md', ['The diff bumps one dependency in `package.json` and its lockfile, and no changed symbol has callers outside its directory: step 6 opens `references/blast-radius.md`;',
    'the report names the changelog it read, the lockfile diff it read and the suite runs before and after.', 'Thin tests around what the dependency does are a finding, not `Untested`.']);
});

test('self-review proves each acceptance state, reads every reader of moved code, and rules on each finding', () => {
  // Pilot fix plan Task 6 (MA-254): a duplicate of the shared piece stayed in a second reader; a "Notes not locked"
  // fix had no caller that passes `locked`; no finding had a ruling.
  const s = steps(readDoc(SKILL).body);
  // Fix round 1, I1: a linked issue, PR text or a plan has no numbered acceptance lines, so proof-check exited 2 and
  // the verdict was `fix first`; and step 4 wrote tracker or PR text under `kern-dir tmp` only after step 2 ran.
  const find = 'Find the spec now, as step 4 says. With one, write `<package>.proofs.md` per `references/proofs.md`.';
  const run = 'Run `proof-check <spec> <package>.proofs.md` only on a spec with numbered lines under `## Acceptance criteria`: any non-zero exit is a failed check.';
  for (const t of [find, run, 'For any other spec, check the table by reading, and print `proof-check: not run (<source> has no numbered acceptance lines)`.',
    'A skipped check counts as failed (`references/claim-checks.md`); that printed line is the one exception.']) assert.ok(s[2].includes(t), `step 2 lacks: ${t}`);
  assert.ok(s[2].indexOf(find) < s[2].indexOf(run), 'the spec is found before proof-check runs');
  // Final review M6: with no spec, step 2 said nothing, so the proof-check that never ran read as an unrun check and gave
  // `fix first`. "Skip" would sit beside "A skipped check counts as failed", so the step says no proofs are due.
  assert.ok(s[2].includes(`${find} No spec: no proofs are due. Run`), s[2]);
  // Fix round 2, I1: step 9 still gave `fix first` for an unrun step 2 check, so the not-run line still blocked an
  // issue, PR or plan spec. Step 9 and the reference's skipped-check rule name the same one exception.
  assert.ok(s[9].includes('`fix first`: a failed or unrun check (step 2 or 7; not the `proof-check: not run` line),'), s[9]);
  const skipped = section(readDoc(`${REF}/claim-checks.md`).body, '## A skipped check is a failed check');
  assert.ok(skipped.includes("The one exception is step 2's `proof-check: not run` line."), skipped);
  assert.ok(s[6].includes('look where grep stops. Code moved into a shared piece: read every other reader of the old code; a copy left behind is a finding.'), s[6]);
  assert.ok(s[9].includes('A bug counts only with a caller path that reaches it, as `path:line` steps; none: Cleared as unreachable.'), s[9]);
  assert.ok(s[9].includes("Rule each finding: `fix` inside the spec's Never and Not doing lines, else `ticket` (offered, never filed), or `reject: <citation>`."), s[9]);
  assert.ok(s[9].includes('A finding with no ruling gives `fix first`. After fixes, a later round (`references/rounds.md`) re-checks the fix diff.'), s[9]);
  assertContains(`${REF}/proofs.md`, ['`proof-check <spec> <proofs>`', '| Line | State | Evidence |', 'A path must exist.', 'never file a proof for a state it does not show']);
  // Final review M3: "one row per line and state" read as a `-` row for each line too, which proof-check flags as
  // `unknown` on a line that names states.
  assertContains(`${REF}/proofs.md`, ['then one row per state a line names, or one `-` row for a line with no `States:`.']);
  assert.ok(!readDoc(`${REF}/proofs.md`).body.includes('one row per line and state'), 'the old row rule is gone');
});
