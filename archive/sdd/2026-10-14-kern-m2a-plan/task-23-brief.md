### Task 23: `self-review` (path)

**Files:**
- Create: `skills/self-review/SKILL.md`, `skills/self-review/references/blast-radius.md`, `skills/self-review/references/doubt-cycle.md`, `skills/self-review/references/claim-checks.md`, `tests/skills/self-review.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/self-review.test.mjs`

**Interfaces:**
- Consumes: `wt-diff`, `floor-scan`, `claim-check`, `probe --exclude-tests` and `--mutate` (Tasks 2, 5, 6); `kern:task-reviewer` in mode `whole-branch` (Task 13) for the spec lane; Claude Code's built-in `code-review` skill (Skill tool; arguments `[target] <effort> --max-findings <n>`).
- Produces: path skill `self-review`; findings under Standards and Spec, kept apart; a Declined to judge list; verdicts `ready`, `fix first`, `rebase first`, `split` (finish-branch stops on `fix first` and `split`).

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/self-review.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/self-review/SKILL.md';

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
  assertMaxBytes(SKILL, 5500);
});

test('self-review references', () => {
  const refs = {
    'blast-radius.md': [['# Blast radius', '## How sure are you', '## Writer sweep', '## Where grep stops', '## Risks and cleared'], 2600],
    'doubt-cycle.md': [['# Doubt cycle', '## When a decision is non-trivial', '## The fresh reviewer', '## Reconcile', '## Doubt theater', '## Stop after three'], 2400],
    'claim-checks.md': [['# Claim checks', '## floor-scan', '## claim-check', '## probe', '## A skipped check is a failed check'], 1700],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`skills/self-review/references/${f}`, hs);
    assertMaxBytes(`skills/self-review/references/${f}`, max);
  }
  assertContains('skills/self-review/references/claim-checks.md', ['probe --exclude-tests', 'probe --mutate', 'probe: mutation caught']);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/self-review.test.mjs`
Expected: 3 failing tests; `skills/self-review/SKILL.md exists`.

- [ ] **Step 3: Write `skills/self-review/SKILL.md`**

Step 4's spec lane adapts `.upstream/pocock/skills/engineering/code-review/SKILL.md:68-80`; step 9's Declined to judge list adapts `.upstream/superpowers/skills/requesting-code-review/code-reviewer.md:44-48`.

```markdown
---
name: self-review
description: "Check your own diff before a PR: deterministic checks, blast radius, probes, a fresh doubt pass, then a verdict."
disable-model-invocation: true
---

# self-review

The author finds what the diff breaks beyond itself and runs every cheap check before anyone else spends tokens. Reached by the kernel row for a review of your own diff with no PR yet, by finish-branch step 4, or typed as `/kern:self-review`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Scope: name the branch and the worktree, run `git fetch origin <base>`, take the merge base with `git -C <wt> merge-base HEAD origin/<base>`, and build the package from it to the working tree, untracked files included: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base>`.
2. Deterministic pass, with the output pasted: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/floor-scan <package>`; `bash ${CLAUDE_PLUGIN_ROOT}/scripts/claim-check <wt> <package>`; `verify.fast`; the related focused tests. A skipped check counts as failed (`references/claim-checks.md`).
3. Built-in lane: call the Skill tool with `code-review` and arguments stated explicitly every time: the worktree path as the target when the work lives in a worktree, the effort from `review.builtin.self_effort`, and `--max-findings` from `review.builtin.max_findings` (for example `<wt> low --max-findings 15`). Never pass `--comment` and never `--fix`. Not available, or `review.builtin: off`: `skip: built-in code-review not available`.
4. Spec lane: when `spec.source` or a plan names a spec for this work, dispatch `kern:task-reviewer` on `model.reviewer` in mode `whole-branch` with the package and the spec's acceptance lines: what is missing or partial, what was not asked for, and what looks implemented but wrong, each quoting the spec line. No spec: `skip: no spec`. Keep its findings apart from the standards findings.
5. Walk the `review.rules` items the diff touches; the rules are already in context.
6. Blast radius, when a changed symbol has callers outside its directory (`references/blast-radius.md`): sweep every writer with `rg` and read each one; look where grep stops; push the one fact the change is safe because of down to "ran it"; list Risks and Cleared separately.
7. Probes: for each new guard test, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <package>.patch -- <test>`; for each new conditional, one `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test>`, which mutates a throwaway fork, never the worktree.
8. Doubt cycle, for non-trivial decisions only (`references/doubt-cycle.md`): a fresh subagent gets the artifact and the contract, never your claim or reasoning; reconcile each point as contract misread, actionable, trade-off or noise; at most 3 cycles.
9. Verdict, with findings in `review.taxonomy` classes and a "Declined to judge" list (each behaviour you set aside as outside the spec, with the reason): `ready`, `fix first`, `rebase first` or `split`. Split when a round fixes the previous round's fixes, or when fixing findings pushed the diff past `scope_threshold`.
10. Propose lesson candidates for `lessons`; write them only on yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `base_branch` | detected | merge base |
| `verify.fast`, `test.focused` | `typecheck` then `lint`; detected | deterministic pass |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md | rule walk |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` | finding classes |
| `review.builtin`, `review.builtin.self_effort`, `review.builtin.max_findings` | `on`, `low`, `15` | built-in lane |
| `spec.source`, `model.reviewer` | linked issue, PR body, `WORK/specs`; `sonnet` | spec lane |
| `lessons` | none: proposals stay in chat | lesson destination |
| `scope_threshold` | 4 files | split check |

## Outputs

A chat report (a findings page only when kern's `visual` skill is installed; otherwise say once "visual pages not installed"): the deterministic output, findings under Standards and Spec with `path:line`, the Declined to judge list, and the verdict.

## Stops and autopilot

`fix first` or `split` stops finish-branch. Under autopilot the same; lessons are not written.
```

- [ ] **Step 4: Port and write the references**

`skills/self-review/references/blast-radius.md`
Source: `.upstream/pstack/pstack/skills/blast-radius/SKILL.md:1-50`.
Required headings: `# Blast radius`, `## How sure are you`, `## Writer sweep`, `## Where grep stops`, `## Risks and cleared`.
Adaptation: keep the five-level "how sure are you" ladder (said so, pointed at the line, showed it cannot happen, ran it, reproduced it in the app); "Writer sweep" says to grep every writer of a property the change gates on, in every package, and read each one, because a reader sweep only answers who breaks; "Where grep stops" ports step 3 (`blast-radius/SKILL.md:35`): read the source of a library you call at its pinned version, work out when things run, and follow what a symbol search misses (an API's JSON, a DB column, a wire format, another language reading the same bytes, a feature flag, code three hops downstream); "Risks and cleared" is the output shape; no personal names.
Check: `for h in '# Blast radius' '## How sure are you' '## Writer sweep' '## Where grep stops' '## Risks and cleared'; do grep -qxF "$h" skills/self-review/references/blast-radius.md || echo "missing $h"; done && [ "$(wc -c < skills/self-review/references/blast-radius.md)" -le 2600 ]`

`skills/self-review/references/doubt-cycle.md`
Source: `.upstream/addy/skills/doubt-driven-development/SKILL.md:16-191` and `:215` (doubt theater).
Required headings: `# Doubt cycle`, `## When a decision is non-trivial`, `## The fresh reviewer`, `## Reconcile`, `## Doubt theater`, `## Stop after three`.
Adaptation: the fresh subagent receives the artifact and its contract only, never the claim; the four reconcile classes (contract misread, actionable, trade-off, noise) with what each leads to; "Doubt theater" gives the checkable signal: across two or more cycles with substantive findings, none was classed actionable, so you are validating, not doubting; stop and tell the user; three cycles at most, and an artifact too big for three cycles goes back to be split.
Check: `for h in '# Doubt cycle' '## When a decision is non-trivial' '## The fresh reviewer' '## Reconcile' '## Doubt theater' '## Stop after three'; do grep -qxF "$h" skills/self-review/references/doubt-cycle.md || echo "missing $h"; done && [ "$(wc -c < skills/self-review/references/doubt-cycle.md)" -le 2400 ]`

`skills/self-review/references/claim-checks.md` (a contract). Full text:

```markdown
# Claim checks

Three scripts run in seconds and catch what reviewers miss. Paste each command and its output into the report.

## floor-scan

`floor-scan <package>` lists moves that lower the bar: new suppressions and type escapes, skipped or focused tests, deleted test files, removed assertions, empty catch blocks and stubs, debug prints, and a lowered bar (a threshold or `ratchet.<metric>` value moved the loose way, strict typing or a lint rule off, a CI step removed or made non-blocking). Exit 1 means at least one hit; each hit is fixed or justified in the report.

## claim-check

`claim-check <wt> <package>` lists commit ids in added lines that the repo does not know, and added comments with absolute words (always, never, impossible, only caller). Each one gets evidence, a rewrite, or removal.

## probe

`probe --exclude-tests <wt> <package>.patch -- <test>` proves a guard test fails without its guard and passes with it, keeping the test files in the fork. `probe --mutate <file>:<line> <wt> -- <test>` inverts one condition on a throwaway fork and expects the test to fail. `probe: fail-then-pass ok` and `probe: mutation caught` are the only passes; `inconclusive` is reported as such.

## A skipped check is a failed check

A check that did not run, timed out, or ran on the wrong tree is reported as failed, with the reason.
```

- [ ] **Step 5: Write `tests/skills/self-review.acceptance.md`**

```markdown
# self-review: acceptance checks (run during the M2b pilot)

- [ ] The diff adds `it.skip(`: the floor scan flags it; the verdict is not `ready`.
- [ ] The diff changes a shared function with five external callers: the writer sweep lists them with paths, and one fact is run.
- [ ] A spec exists: the Spec lane quotes its acceptance lines and its findings stay apart from the Standards findings.
- [ ] A project with `.claude/skills/self-review/`: kern defers in one line.
- [ ] The built-in `code-review` is missing: a skip line appears; the other steps run.
- [ ] The built-in lane receives the worktree path as its target and reviews that worktree's diff (record what it reviewed; if a path target is not accepted, note it for M3).
```

- [ ] **Step 6: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `self-review` | path | Routed row "Review requested on your own diff, no PR yet"; /kern:self-review | Author's check before a PR |``
Add under `## [Unreleased]`: `- self-review: deterministic checks, built-in code-review at low effort, a spec lane, blast radius, probes, verdict.`

- [ ] **Step 7: Run the tests and lint**

Run: `node --test tests/skills/self-review.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; no lint errors (rule 5 accepts the built-in `code-review`).

- [ ] **Step 8: Commit**

```bash
git add -- skills/self-review tests/skills/self-review.test.mjs tests/skills/self-review.acceptance.md skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the self-review skill" -m "Cheap deterministic checks and the built-in reviewer run before anyone spends tokens on a PR review, and the spec gets its own lane."
```

---

