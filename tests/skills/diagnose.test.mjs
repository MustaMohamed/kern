import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, section, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

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
  // 6,640 since M3 part 1's Task 14 (raised from 6,500): step 2 names the worktree and step 8 gives a still-red loop its way
  // back, after cutting two defaults Inputs already holds.
  // 6,795 since paid round 2's fix: step 7 keeps an exported signature, and step 8 keeps the state the run found.
  // 6,839 since that fix's re-review: step 8 lets a fix correct what wrote the state.
  // 6,940 since paid round 4's fix: step 7's allowed throw keeps the behaviour the report does not name, a fallback the code had among it.
  assertMaxBytes(SKILL, 6940);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['| `diagnose` | path | M2a | at most 6,940 bytes,']);
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

test('diagnose never prints a secret: step 1 redacts the symptom, and instrumentation shows a secret only as set or unset', () => {
  // Task 17 lane 4 (SP55): superpowers 7.0.0 systematic-debugging/SKILL.md:91-95 prints only whether a secret is set.
  // The boundary line includes the environment, so without this rule it would print a secret's value.
  assert.ok(steps(readDoc(SKILL).body)[1].includes('Redact secrets'));
  const line = readDoc('skills/diagnose/references/root-cause-tracing.md').raw.split('\n').find((l) => l.startsWith('- Include the value,')) ?? '';
  assert.ok(line.endsWith('; a secret only as set or unset, never its value.'), line);
});

test('the loop and instrumentation run in a named worktree, and a loop still red after a fix goes back to the hypotheses (audit D18)', () => {
  // The loop and instrumentation could land in the main checkout, and a still-red loop after a fix had no way back.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[2].includes('The loop and instrumentation run in a named worktree: `<wt>`, as `implement` step 2 picks it.'), s[2]);
  assert.ok(s[8].includes("A loop still red after a fix goes back to step 5, as a failed fix on step 6's ladder."), s[8]);
  assert.ok(s[5].startsWith('5. Write 3 to 5 ranked hypotheses'), s[5]);
  assert.ok(s[6].includes('after three failed fixes, stop'), s[6]);
});

test('a fix keeps the state it was found on and the exported signature (h2h diagnose, 11-01)', () => {
  // Held-out failed on two kern runs and on none of control's: stale-cache-file's run rewrote the cache to get green, and
  // three-calls' run changed `lineTotal`'s signature, so the held-out test's call failed.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[7].includes('Keep an exported signature unless it is the cause.'), s[7]);
  // Paid round 4: two runs made a loader throw where the code had fallen back, so the original test stayed red. The allowed throw
  // read as leave to drop the fallback (inferred), so the line that allows it now keeps the behaviour the report does not name.
  assert.ok(s[7].includes('a loud throw at a boundary the trace crossed is allowed (`references/defense-in-depth.md`), but a fix keeps the behaviour the report does not name, so a fallback the code had stays a fallback.'), s[7]);
  // Its follow-up: the reference's "never substitutes a default" read the same way, so it keeps the fallback and still lets a check refuse undefined input.
  const loud = section(readDoc('skills/diagnose/references/defense-in-depth.md').body, '## Loud, never silent');
  assert.ok(loud.includes('A fallback the code had stays a fallback; a check may refuse bad input where the code had no defined behaviour.'), loud);
  // Re-review I1: with a writer as the cause the fix corrects it and repairs the data, so that fix needs a way past this line.
  assert.ok(s[8].includes('The original scenario runs on the state you found, unless the fix corrects what wrote that state: a fix that only rewrites it has not fixed the code.'), s[8]);
});

test('a go on a bug goes on to finish-branch, as implement\'s kernel row does', () => {
  // M3 part 1 Task 15: no text named finish-branch here, so a go reached a PR only through
  // autopilot's general sentence. implement step 12 skips its own line when diagnose reads it mid-run.
  const line = "From the kernel's row under a go, follow `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md` on `<wt>`.";
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[9].endsWith(line), s[9]);
  assert.ok(steps(readDoc('skills/implement/SKILL.md').body)[12].endsWith(line));
  assertContains('kernel/kernel.md', ['Read {KERN}/diagnose/SKILL.md']);
});

test('under autopilot both diagnose stops wait for a typed reply, as run.md says', () => {
  // Task 14 review: both stops parked with a `default:` neither has, while this section points at run.md, whose rule is a wait.
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  assert.ok(auto.includes('Under autopilot both wait for a typed reply, with the evidence so far and a recommendation, and independent work may finish first.'), auto);
  assert.ok(!auto.includes('parked:'), auto);
  assert.ok(auto.includes('${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md'), auto);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['Under autopilot both wait for a typed reply, with the evidence so far and a recommendation, and independent work may finish first. Production stays read-only (D8).']);
});
