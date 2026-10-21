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

test('a fix the reply proposes but did not run is labelled inferred', () => {
  // 2026-10-20 prove-it-2 (task-16-diagnosis-2): 3 of 3 runs proposed a guard fix they had not run, unlabelled. The
  // user, asked whether such a fix is a claim kern must label, answered "Yes, label it (Recommended)", 2026-10-21.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[7].endsWith('or label it measured, inferred or guess. A fix you propose but did not run is labelled inferred.'), s[7]);
});

test('evidence reference', () => {
  assertHeadings('skills/prove-it/references/evidence.md', ['# Evidence by claim', '## Claim table', '## Labels', '## Inconclusive is a fail']);
  assertContains('skills/prove-it/references/evidence.md', ['zero tests ran']);
  assertMaxBytes('skills/prove-it/references/evidence.md', 2100);
});

test('the M0 placeholder is gone', () => {
  for (const p of ['skills/hello', 'evals/cases/hello.json', 'evals/fixtures/hello']) assert.ok(!existsSync(join(ROOT, p)), `${p} removed`);
});

test('the gate hands a commit to commit and a push or PR to finish-branch', () => {
  assertContains(SKILL, ['unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step)', 'for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'for a push or a PR, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`']);
});
