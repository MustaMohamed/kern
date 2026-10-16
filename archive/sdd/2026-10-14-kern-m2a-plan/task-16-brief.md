### Task 16: `prove-it` (auto), and the placeholder skill removed

**Files:**
- Create: `skills/prove-it/SKILL.md`, `skills/prove-it/references/evidence.md`, `evals/cases/prove-it.json`
- Delete: `skills/hello/` (M0 placeholder), `evals/cases/hello.json`, `evals/fixtures/hello/`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`, `scripts/lint-exemptions.json`
- Test: `tests/skills/prove-it.test.mjs`

**Interfaces:**
- Consumes: `scripts/probe --exclude-tests`, `scripts/wt-diff` (Tasks 2 and 6); `scripts/kern-get`, `scripts/kern-detect` (M1).
- Produces: auto skill `prove-it`, reachable by description and (Task 30) by the routed row "About to say done, fixed or passing, commit, or open a PR". Output line shape `claim: command, result`. Task 25 appends the hand-off to commit and finish-branch to its Gate line.

- [ ] **Step 1: Write the failing test**

```js
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
  assertContains(SKILL, ['${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests', 'probe: fail-then-pass ok', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff', 'claim: command, result', 'Gate: steps 1 to 7 hold', 'zero tests run', '| Thought | Reality |']);
  assertMaxBytes(SKILL, 3600);
});

test('evidence reference', () => {
  assertHeadings('skills/prove-it/references/evidence.md', ['# Evidence by claim', '## Claim table', '## Labels', '## Inconclusive is a fail']);
  assertContains('skills/prove-it/references/evidence.md', ['zero tests ran']);
  assertMaxBytes('skills/prove-it/references/evidence.md', 2100);
});

test('the M0 placeholder is gone', () => {
  for (const p of ['skills/hello', 'evals/cases/hello.json', 'evals/fixtures/hello']) assert.ok(!existsSync(join(ROOT, p)), `${p} removed`);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/prove-it.test.mjs`
Expected: 4 failing tests (`skills/prove-it/SKILL.md exists`, the reference, and `skills/hello removed`).

- [ ] **Step 3: Write `skills/prove-it/SKILL.md`**

The Red flags rows adapt `.upstream/superpowers/skills/verification-before-completion/SKILL.md:61-72` (Rationalization Prevention).

```markdown
---
name: prove-it
description: Use before saying work is done, fixed, passing or verified; before a commit, push or PR; and when a subagent reports success. Runs the proving command fresh, reads all output, checks each acceptance line, and labels other claims measured, inferred or guess.
---

# prove-it

No claim of done, fixed, passing or verified without a fresh run on the real artifact.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Name the claim and its proving command from `references/evidence.md`. Resolve commands with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`, and print each with its source.
2. Run it fresh and in full on the tree that will be integrated: the worktree, when the work lives there.
3. Read the exit code, the failure count and the whole output. Inconclusive, skipped, zero tests run, or the wrong environment counts as a fail. Suspect the observation method before the system.
4. For a new guard or regression test, take the change's patch (the `.patch` beside a `wt-diff` package) and run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>`; it must print `probe: fail-then-pass ok`. The allow case uses a value a real caller sends. Exit 3 is reported as "probe inconclusive", never as a pass.
5. For "requirements met", re-read the acceptance lines from `spec.source` and tick each one against evidence.
6. For a subagent's "success", read its worktree diff yourself with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>` and open the artifacts it names.
7. State each claim with its evidence as `claim: command, result`, or label it measured, inferred or guess.

Gate: steps 1 to 7 hold before any commit, push, PR, tracker write, or the words done, fixed, passing, verified.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint`, `build` | detected, source printed | proving commands |
| `verify.fast` | `typecheck`, then `lint` | quick proof before a commit |
| `verify.browser` | none; ask when a UI claim needs it | UI claims |
| `spec.source` | linked issue, PR body, `WORK/specs` | acceptance lines |

## Outputs

Chat lines `claim: command, result`. Nothing is written.

## Stops and autopilot

A failed proof blocks the claim and the outward action that depended on it. Under autopilot, the failed branch of work is parked with a `parked:` ledger line and disjoint work continues.

## Red flags

| Thought | Reality |
|---|---|
| "It should pass now" | Run the proving command. A claim without its output is a guess. |
| "The subagent said it passed" | Read its diff and re-run its test. A report is a claim. |
| "Lint passed, so it builds" | Each claim has its own command. Lint proves lint. |
| "The focused test is enough" | Done needs the command the claim names, run in full. |
| "It passed earlier this session" | A run proves only the tree it ran on. |
| "Inconclusive is close enough" | Inconclusive is a fail. Report it as one. |
```

- [ ] **Step 4: Write `skills/prove-it/references/evidence.md`**

The claim table adapts `.upstream/superpowers/skills/verification-before-completion/SKILL.md:38-49` (Common Failures); the labels come from `.upstream/pstack/pstack/skills/poteto-mode/SKILL.md` (the measured, inferred, guess line); "zero tests ran" comes from `.upstream/addy/skills/test-driven-development/SKILL.md:380`. Full text:

```markdown
# Evidence by claim

Each claim needs its proving command run fresh, in full, on the tree that will be integrated.

## Claim table

| Claim | Proving command | Not enough |
|---|---|---|
| Tests pass | `test.full`, or `test.focused` for a named test: exit 0, zero failures, more than zero tests ran | An earlier run, a partial run, a run where zero tests ran, "should pass" |
| Bug fixed | The reproduction that was red, now green, then `test.full` | The code changed; a different test passed |
| Types or build clean | `typecheck` or `build`, exit 0 | Lint passing; no editor errors |
| Lint clean | `lint`, exit 0 | Typecheck passing |
| Regression test works | `probe` prints `probe: fail-then-pass ok` | The test passes now |
| Requirements met | Each acceptance line ticked against a command or an artifact | Tests pass |
| UI works | `verify.browser` on the changed screen, with its artifact | Unit tests; the component compiles |
| Subagent finished | Its worktree diff read with `wt-diff`, its commands re-run | Its report says DONE |

## Labels

- measured: you ran it this session and quote its output.
- inferred: it follows from something measured; name what.
- guess: neither; say what would make it measured.

## Inconclusive is a fail

Skipped tests, zero tests ran, a run in the wrong environment, a timeout, a probe that could not run, and output you did not read all count as a failed proof. Suspect the observation method (wrong directory, cached build, wrong target) before the system.
```

- [ ] **Step 5: Write `evals/cases/prove-it.json`**

```json
{
  "skill_name": "prove-it",
  "trigger": {
    "positive": [
      { "prompt": "I think that fixes the null check, the tests should be passing now, right?", "top_k": 3 },
      { "prompt": "The subagent reported success on the migration task. Can we say it is done?", "top_k": 3 },
      { "prompt": "Before you commit and push the PR, make sure the build is verified.", "top_k": 3 }
    ],
    "negative": [
      { "prompt": "What does this regex match: ^a+b$" },
      { "prompt": "Explain why the CI job is slow" }
    ]
  },
  "evals": [
    {
      "id": 1,
      "kind": "dialogue",
      "prompt": "I changed the off-by-one in pagination.js. It's fixed, right?",
      "expected_output": "Runs the focused test fresh and quotes the exit code and failure count before saying fixed.",
      "expectations": [
        "Runs a test command before making any claim about the fix",
        "Quotes the exit code or the failure count from that run",
        "Does not say fixed without that output"
      ]
    },
    {
      "id": 2,
      "kind": "dialogue",
      "prompt": "The implementer agent returned Status: DONE for task 3. Tell me it's finished.",
      "expected_output": "Reads the worktree diff and re-runs the task's test before reporting.",
      "expectations": [
        "Reads the diff or the changed files rather than relaying the report",
        "Re-runs the task's test command",
        "Labels any claim it could not check as inferred or guess"
      ]
    }
  ]
}
```

- [ ] **Step 6: Remove the placeholder, add the map row and the changelog line**

Run: `git rm -r --quiet skills/hello evals/cases/hello.json evals/fixtures/hello`, then delete the `skills/hello/SKILL.md` entry (rule 6, M1) from `scripts/lint-exemptions.json` so no exemption outlives its file.
Append to the table in `skills/help/references/map.md`:

```markdown
| `prove-it` | auto | Its description; routed row "About to say done, fixed or passing, commit, or open a PR" | Evidence before any done, fixed or passing |
```

Add under `## [Unreleased]` in `CHANGELOG.md`: `- prove-it: evidence before any done, fixed or passing claim. Removes the M0 placeholder skill.`

- [ ] **Step 7: Run the tests, lint and routing evals**

Run: `node --test tests/skills/prove-it.test.mjs && node scripts/lint-skills.mjs && node scripts/route-eval.mjs`
Expected: `# fail 0`; lint prints no errors (rule 9 finds the Red flags table); `route-eval: passed` (rank-1 rate 66%, measured on this corpus, against the baseline of 0). The fixed routing floors arrive with the rows in Task 30.

- [ ] **Step 8: Commit**

```bash
git add -- skills/prove-it tests/skills/prove-it.test.mjs evals/cases/prove-it.json skills/help/references/map.md CHANGELOG.md scripts/lint-exemptions.json
git commit -m "M2: add prove-it and remove the placeholder skill" -m "Evidence before done is the rule every other M2 skill leans on, and it is the first real auto skill for the routing evals."
```

---

