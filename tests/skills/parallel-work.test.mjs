// tests/skills/parallel-work.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/parallel-work/SKILL.md';
const TEMPLATE = 'skills/parallel-work/references/brief-template.md';
const ROOT = fileURLToPath(new URL('../..', import.meta.url));

test('parallel-work frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'parallel-work',
    description: 'Fan out independent work: one worktree per writer, overlaps serialized, results integrated and re-tested.',
    'disable-model-invocation': 'true',
  });
});

test('parallel-work sections and steps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot']);
  const s = steps(body);
  assert.equal(s.length, 9);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['run_in_background: true', 'Never poll a worker', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply',
    '${CLAUDE_PLUGIN_ROOT}/scripts/wt-check', '${CLAUDE_PLUGIN_ROOT}/scripts/brief-check', 'a gap is not a pass', 'DONE_WITH_CONCERNS is ISSUES',
    'BLOCKED and NEEDS_CONTEXT are BLOCKED', 'silent past its TIMEBOX', 'never resume it', 'one pilot unit first', 'wt-new <slug> --detach']);
  assertMaxBytes(SKILL, 6400);
});

test('parallel-work pins the drain mapping, entry check, package location, teardown and stops', () => {
  const { body } = readDoc(SKILL);
  const s = steps(body);
  const at = (n) => s[n]; // s[0] is step 0
  // Step 3: VERIFY starts at wt-check and brief-check runs before any spawn.
  assert.ok(at(3).includes('its VERIFY starting with the entry check `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>`'));
  assert.ok(at(3).includes('anything but `brief-check: ok` means do not spawn'));
  assert.ok(at(3).includes('A reader gets no worktree and no brief'));
  assert.ok(at(4).includes('Spawn every worker in one message'));
  // Step 5: the drain mapping, word for word from the agents' return contracts.
  assert.ok(at(5).includes('DONE is PASS, DONE_WITH_CONCERNS is ISSUES, BLOCKED and NEEDS_CONTEXT are BLOCKED'));
  assert.ok(at(5).includes('`Status:` line'));
  assert.ok(at(5).includes('every fact carries a citation and a label'));
  assert.ok(at(5).includes('"could not trace" list is ISSUES'));
  assert.ok(at(5).includes('names a command it needs run'));
  // Step 6: the package location and the patch it makes.
  assert.ok(at(6).includes('--out <dir>/<worker>.diff'));
  assert.ok(at(6).includes('<dir>/<worker>.diff.patch'));
  assert.ok(at(6).includes('the caller\'s ledger `reviews/` folder, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir reviews`'));
  assert.ok(at(6).includes('--allow'));
  assert.ok(at(6).includes('Exit 4 is a write outside SCOPE'));
  assert.ok(at(6).includes('Exit 3 is no change'));
  // Step 8 points at the worktrees reference, where the teardown rules are pinned.
  assert.ok(at(8).includes('${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md'));
  assert.ok(at(8).includes('`--force` only when all five preconditions there hold'));
  assert.ok(at(8).includes("only on the user's yes"));
  // Minor rules from the review round.
  assert.ok(at(2).includes('a model named in every dispatch'));
  assert.ok(at(2).includes('A script exit this skill does not name stops that unit'));
  assert.ok(at(3).includes('resolve `${CLAUDE_PLUGIN_ROOT}` to the absolute root'));
  assert.ok(at(4).includes('the absolute path of `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`'));
  assert.ok(at(5).includes('(none: BLOCKED)'));
  assert.ok(at(5).includes('with an empty or "none" could-not-trace list, is PASS'));
  assert.ok(at(5).includes('a silent reader, which has neither, is re-asked once, then BLOCKED'));
  assert.ok(at(6).includes('a directory ends in `/`, a prefix in `*`'));
  assert.ok(at(6).includes('name each red test as before or after'));
  assert.ok(at(6).includes('spot-check one claim per worker against its diff'));
  assert.ok(at(7).includes('each recorded tree in evidence'));
  assert.ok(at(6).includes("prints `applied`, and only then record wt-diff's second line"));
  assert.ok(at(6).includes('stop, no tree recorded'));
  // Stops and autopilot.
  const stops = body.slice(body.indexOf('## Stops and autopilot'));
  for (const n of ['Stops at steps 1, 3, 6, 7 and 8', 'on per the latest kern signal', 'a turn with no mode line changes nothing',
    'parked: <question>; default: <choice>; why: <one line>', 'Teardown never runs under autopilot', 'AskUserQuestion', 'parks that unit while the rest continue']) {
    assert.ok(stops.includes(n), `stops section must contain: ${n}`);
  }
});

test('brief template fields and worktrees reference', () => {
  assertHeadings(TEMPLATE, ['# Brief template', '## Fields', '## Standing orders']);
  assertContains(TEMPLATE, ['GOAL', 'SCOPE', 'CONTEXT', 'ACCEPTANCE', 'VERIFY', 'TIMEBOX', 'FORBIDDEN', 'REPORT', 'STANDING', 'brief-check']);
  assertMaxBytes(TEMPLATE, 1800);
  // The template copied unfilled is not a brief: brief-check names every placeholder but FORBIDDEN's.
  // VERIFY's placeholder cannot also start with wt-check, so brief-check adds its VERIFY line after them.
  const fields = readFileSync(join(ROOT, TEMPLATE), 'utf8').split('```')[1];
  const f = join(mkdtempSync(join(tmpdir(), 'brief-')), 'brief.md');
  writeFileSync(f, fields);
  const r = spawnSync('bash', [join(ROOT, 'scripts/brief-check'), f], { encoding: 'utf8' });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.deepEqual(r.stdout.trim().split('\n'), [...['GOAL', 'SCOPE', 'CONTEXT', 'ACCEPTANCE', 'VERIFY', 'TIMEBOX', 'REPORT', 'STANDING'].map((k) => `placeholder: ${k}`), 'VERIFY must start with the wt-check entry check']);
  assertHeadings('skills/parallel-work/references/worktrees.md', ['# Worktrees', '## Creating', '## Entry check', '## Integration', '## Teardown']);
  assertMaxBytes('skills/parallel-work/references/worktrees.md', 2200);
  assertContains(TEMPLATE, ['a directory entry ends in /, a prefix in *']);
});

test('worktrees teardown pins the force check', () => {
  const t = readDoc('skills/parallel-work/references/worktrees.md').raw;
  for (const n of ['${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit', 'keep only the paths this run recorded. Never propose the integration worktree or a wt-fork source.', 'An `unknown` worktree is never torn down',
    'A worktree whose PR merged (bucket `merged`) may go with plain `git worktree remove <path>`.',
    '`--force` runs only when ALL of these hold:',
    "1. `wt-apply` printed `applied` for this worker's package. Record wt-diff's second line (TO_TREE) only then; a conflicted or exit 4 worker has no recorded tree.",
    '2. The recorded TO_TREE equals `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` now.',
    '3. The path is in this run\'s recorded list.\n',
    '4. Every ignored file in `git -C <wt> status --ignored --porcelain` is named to the user',
    '5. The user said yes. G1 asks on `git worktree remove --force` and denies it under autopilot',
    'If any condition is not proven, use plain `git worktree remove <path>`, or keep the worktree and report it'
  ]) {
    assert.ok(t.includes(n), `worktrees.md must contain: ${n}`);
  }
});

test('a filled brief passes brief-check', () => {
  const brief = [
    'GOAL        add the flag parser',
    'SCOPE       may write src/flags.js; may not write tests/; worktree /tmp/wt-a, base origin/main',
    'CONTEXT     see src/cli.js',
    'ACCEPTANCE  --x sets x',
    'VERIFY      bash /k/scripts/wt-check /tmp/wt-a origin/main',
    '            then node --test tests/flags.test.js',
    'TIMEBOX     20 minutes',
    'FORBIDDEN   commit, push',
    'REPORT      status line, files',
    'STANDING    work only in your worktree',
    '',
  ].join('\n');
  const f = join(mkdtempSync(join(tmpdir(), 'brief-')), 'brief.md');
  writeFileSync(f, brief);
  const r = spawnSync('bash', [join(ROOT, 'scripts/brief-check'), f], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(r.stdout.trim(), 'brief-check: ok');
});
