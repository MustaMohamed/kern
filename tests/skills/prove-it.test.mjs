// tests/skills/prove-it.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/prove-it/SKILL.md';

test('prove-it frontmatter is the spec text', () => {
  assertFrontmatter(SKILL, {
    name: 'prove-it',
    description: 'Use before saying work is done, fixed, passing or verified; before a commit, push or PR; and when a subagent reports success. Runs the proving command fresh, reads all output, checks each acceptance line, and labels other claims measured, inferred or guess.',
  });
});

test('prove-it sections, steps, gate and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 8);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'probe: fail-then-pass ok', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff', 'claim: command, result', 'Gate: steps 1 to 7 hold', 'zero tests run', '| Thought | Reality |',
    'for a module or export the patch adds, or a test-only patch, report `probe inconclusive: new module` and prove the new code with `probe --mutate <file>:<line> <wt> -- <test command>`']);
  assertMaxBytes(SKILL, 3800);
});

test('a fix the reply proposes but did not run is labelled inferred, in a fixed form', () => {
  // 2026-10-20 prove-it-2 (task-16-diagnosis-2): 3 of 3 runs proposed a guard fix they had not run, unlabelled. The
  // user, asked whether such a fix is a claim kern must label, answered "Yes, label it (Recommended)", 2026-10-21.
  // On 2026-10-21 and 2026-10-22 no prove-it-2 reply used a label word in 6 of 6 runs (task-16-diagnosis-5), so
  // the label has one form a reply can show: `inferred: <claim>`.
  const s = steps(readDoc(SKILL).body);
  assert.equal(s[7], '7. State each claim with its evidence as `claim: command, result`, or write it as `inferred: <claim>` or `guess: <claim>`; a fix you did not run is `inferred: <fix>`.');
});

test('a subagent\'s diff is read before its test runs, and a failing test does not skip the read', () => {
  // 2026-10-22 prove-it-2 (task-16-diagnosis-5): runs 0 and 1 stopped at the red test and never opened the changed
  // file ("I haven't opened the file to confirm which"); the diff read was step 6, after the run.
  const s = steps(readDoc(SKILL).body);
  assert.equal(s[2], '2. For a subagent\'s "success", read its worktree diff with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>`, or the files it names, before you run its test; a failing test does not skip this.');
  assert.ok(s[3].startsWith('3. Run the proving command fresh and in full on the tree that will be integrated'), s[3]);
  assert.ok(s[5].startsWith('5. For a new guard or regression test, make the patch with `wt-diff` (it writes `<package>.patch` too) and run'), s[5]);
  assert.ok(s[6].startsWith('6. For "requirements met"'), s[6]);
});

test('verify.fast defaults to each of typecheck and lint that resolves, as settings.md says', () => {
  // Task 17a P10, D16 (Opus audit 2026-10-22): "`typecheck`, then `lint`" read as both, so a repo with a lint script and
  // no typecheck left verify.fast unresolved, and under autopilot the check failed every time.
  const d16 = 'each of `typecheck` and `lint` that resolves; at least one';
  assertContains(SKILL, [`| \`verify.fast\` | ${d16} | quick proof before a commit |`]);
  assertContains('kernel/settings.md', [`| \`verify.fast\` | ${d16} | command | self-review, prove-it |`]);
  for (const f of [SKILL, 'kernel/settings.md']) assert.ok(!/`typecheck`,? then `lint`/.test(readDoc(f).raw), `${f}: the two-reading default is gone`);
  // Fix round 1, Minor 1: the default must win over step 1's "When both exit 3, ask" in a lint-only repo.
  assertContains('tests/skills/prove-it.acceptance.md', ['A repo with a lint script and no typecheck: `verify.fast` runs lint alone, with no ask and no failed check, under autopilot too.']);
});

test('evidence reference', () => {
  assertHeadings('skills/prove-it/references/evidence.md', ['# Evidence by claim', '## Claim table', '## Labels', '## Inconclusive is a fail']);
  assertContains('skills/prove-it/references/evidence.md', ['zero tests ran']);
  assertMaxBytes('skills/prove-it/references/evidence.md', 2100);
});

test('the M0 placeholder is gone', () => {
  for (const p of ['skills/hello', 'evals/cases/hello.json', 'evals/fixtures/hello']) assert.ok(!existsSync(join(ROOT, p)), `${p} removed`);
});

test('the gate hands a commit to commit and a push, a PR or a release to finish-branch', () => {
  // Coverage AD24 (M2b Task 17): a release is a commit, a tag and a push, which finish-branch cuts.
  assertContains(SKILL, ['unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step)', 'for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'for a push, a PR or a release, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`']);
});
