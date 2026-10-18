import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/diagnose/SKILL.md';

test('diagnose frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'diagnose',
    description: "Find a bug's root cause before fixing it: red-capable loop, minimise, ranked hypotheses, fix with a regression test.",
    'disable-model-invocation': 'true',
    'argument-hint': '[symptom | failing test]',
  });
});

test('diagnose sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 10);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['a debugger or REPL before logs when the environment has one', "carry it into the commit body's why (commit step 5) or the PR body's Why",
    'red-capable, deterministic, fast and runnable by an agent', 'form no hypotheses', '[kern-dbg]', 'three failed fixes',
    '${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md', '--detach --base', 'scripts/hitl-loop.template.sh',
    '${CLAUDE_PLUGIN_ROOT}/skills/diagnose/scripts/loop-rate.sh', 'on `model.investigator`', '"stop guessing"', 'then the original scenario',
    '${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'blind reproduction', 'references/defense-in-depth.md',
    'find-polluter.sh', 'wt-new bisect-<n> --detach', '`! bash <path>`', 'itself the finding',
    'propose the cheap always-on signal (a log line, a metric, an assertion message) that would have shown it at first look, as a separate item']);
  assertContains('skills/diagnose/references/flaky-and-async.md', ['find-polluter.sh', 'loop-rate.sh', 'pin time']);
  assertMaxBytes(SKILL, 6500);
});

test('diagnose references', () => {
  const refs = {
    'root-cause-tracing.md': [['# Root-cause tracing', '## Trace backward', '## Instrument the boundaries', '## Fix at the source'], 2200],
    'flaky-and-async.md': [['# Flaky and async bugs', '## Raise the reproduction rate', '## Wait for conditions, not time', '## Test pollution'], 2200],
    'forensics.md': [['# Forensics', '## Runtime forensics', '## Trace forensics', '## Proof rules', '## Reducing safely'], 2600],
    'defense-in-depth.md': [['# Defense in depth', '## When a guard belongs', '## Four layers', '## Loud, never silent', '## Prove each layer'], 2200],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`skills/diagnose/references/${f}`, hs);
    assertMaxBytes(`skills/diagnose/references/${f}`, max);
  }
  assertContains('skills/diagnose/references/forensics.md', ['not yet a diagnosis', 'strongest hypothesis']);
});
