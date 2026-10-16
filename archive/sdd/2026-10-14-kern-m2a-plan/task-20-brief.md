### Task 20: `plan` (path)

**Files:**
- Create: `skills/plan/SKILL.md`, `skills/plan/references/plan-template.md`, `skills/plan/references/task-template.md`, `skills/plan/references/plan-review.md`, `tests/skills/plan.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/plan.test.mjs`

**Interfaces:**
- Consumes: specs with `status: approved` and a Constraints section (Task 19); `kern:investigator`; `scripts/plan-check` (Task 11); `scripts/wt-new --detach` for a spike; guard G20 (Task 14).
- Produces: path skill `plan`; plan files `WORK/plans/<slug>.md` with frontmatter `status: draft | approved`, `spec: <path>`, `approved:` (the date and one whole line of the user's yes), `execution: step | inline | delegate` (empty until approved), `commits: ask`; task headings `### Task N: <name>` (what `task-brief` extracts); a `## Global Constraints` section (what `task-brief` copies into each brief); tasks that pass `plan-check`.

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/plan.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/plan/SKILL.md';

test('plan frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'plan',
    description: 'Turn an approved spec into ordered tasks with exact files, test-first steps, verify commands and blocking edges.',
    'disable-model-invocation': 'true',
    'argument-hint': '[spec path | issue id]',
  });
});

test('plan sections and steps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 13);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['Not approved: stop and route to define', 'gh pr list --search', 'never parallel', '`step`, `inline` or `delegate`', 'execution:', 'commits: ask',
    '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check', 'gets a spike first', 'prefactor', 'expand, migrate in batches, then contract', "spec's Constraints section",
    'on `model.investigator`', "one whole line of the user's yes, verbatim", 'visual pages not installed']);
  assertMaxBytes(SKILL, 6500);
});

test('plan templates are contracts task-brief and plan-check can read', () => {
  assertHeadings('skills/plan/references/plan-template.md', ['# Plan template', '## Global Constraints', '## Review Focus', '## File map']);
  assertContains('skills/plan/references/plan-template.md', ['Copy from the first `---` line to the end', 'status: draft', 'approved: (set only on an explicit yes', 'execution:', 'commits: ask', '### Task 1:', 'Always, Ask first, Never']);
  assertMaxBytes('skills/plan/references/plan-template.md', 2200);
  assertHeadings('skills/plan/references/task-template.md', ['# Task template', '### Task N: <name>']);
  assertContains('skills/plan/references/task-template.md', ['**Files:**', '**Interfaces:**', 'Consumes:', 'Produces:', '**Blocked by:**', '**Acceptance:**', 'Run it to verify it fails', 'Expected:', '`plan-check` fails a task']);
  assertMaxBytes('skills/plan/references/task-template.md', 2200);
  assertHeadings('skills/plan/references/plan-review.md', ['# Plan reviewer brief', '## What to check', '## Calibration', '## Output']);
  assertMaxBytes('skills/plan/references/plan-review.md', 1400);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/plan.test.mjs`
Expected: 3 failing tests; `skills/plan/SKILL.md exists`.

- [ ] **Step 3: Write `skills/plan/SKILL.md`**

Step 4's spike route adapts `.upstream/pstack/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md:6`; step 7's prefactor and wide-refactor rules adapt `.upstream/pocock/skills/engineering/to-tickets/SKILL.md:23` and `:40`; the Red flags rows adapt `.upstream/addy/skills/planning-and-task-breakdown/SKILL.md:219-236`.

```markdown
---
name: plan
description: Turn an approved spec into ordered tasks with exact files, test-first steps, verify commands and blocking edges.
disable-model-invocation: true
argument-hint: "[spec path | issue id]"
---

# plan

Produce a plan a zero-context executor can run, with PR boundaries inside the scope gate. Reached by the kernel row for an agreed spec with more than one step, or typed as `/kern:plan`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Check preconditions: a spec with `status: approved`, or issue acceptance criteria the user pointed to. Not approved: stop and route to define, writing nothing. A plan for this spec exists: update it in place. An unfinished plan for other work: stop and ask. Look for existing PRs with `gh pr list --search <id> --state all`.
2. Skip the plan for 1 or 2 files with an obvious approach: say so, write nothing, and the kernel routes to implement.
3. Ground the plan with `kern:investigator` subagents on `model.investigator` (default `sonnet`): file pointers, conventions, verify commands and their source, stored shapes and their writers.
4. Send open product questions to the user as options with a recommendation; send fact questions to subagents. A question that reading cannot settle (does this library do X?) gets a spike first, through define step 8 in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree.
5. Write a falsifiable done predicate per acceptance criterion, and the baseline to capture before any change.
6. Map the files, then build the dependency graph bottom-up.
7. Slice into vertical tracer bullets sized for one fresh context. Make the change easy first: a behaviour-preserving prefactor is its own task before the feature. Stored shapes, and a wide mechanical refactor whose call sites span the codebase, change by expand, migrate in batches, then contract. One PR is one change, within `scope_threshold` files or an explicit scope confirmation from the user. Tasks sharing a file or a `shared_services` entry are ordered by Blocked by, never parallel.
8. Write each task from `references/task-template.md`: exact Files (create, modify, test); Interfaces (Consumes, Produces, with signatures); test-first steps with real code; verify commands; Acceptance by number; Blocked by; one line per `checklists` item. No placeholders.
9. Write the header from `references/plan-template.md`: Goal, issue, spec link, base and promotion path, Global Constraints copied verbatim from the spec's Constraints section, Review Focus (inputs the spec implies but no test exercises, each pinned to a task), `execution:` empty, `commits: ask`.
10. Order the riskiest tasks first, put a checkpoint every 2 or 3 tasks, and add a regression check that runs the same scenario on base and head.
11. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` and fix every line it prints: structure, ordering of shared files and services, each consumed name blocked by its producer, every acceptance number covered. Then self-review for placeholders and type consistency, and send the plan to one reviewer subagent with `references/plan-review.md`, round 1 only.
12. Write `WORK/plans/<slug>.md` with `status: draft` and present a summary in chat (a visual page only when kern's `visual` skill is installed; otherwise say once "visual pages not installed"). Stop: the user approves and picks `step`, `inline` or `delegate`, given your one-line recommendation. On yes, set `status: approved`, `approved: <date>, "<one whole line of the user's yes, verbatim>"` and `execution:` in one edit. Draft tracker sub-issues only on request.

## Inputs

| Key | Default | Use |
|---|---|---|
| `work_dir` | `.kern` | where plans go |
| `base_branch`, `deploy.envs` | detected, none | base and promotion path |
| `scope_threshold` | 4 files | PR size gate |
| `test.*`, `typecheck`, `lint`, `build` | detected, source printed | verify commands in tasks |
| `checklists`, `shared_services` | see define; none | extra lines; ordering |
| `tracker` | detected | issue ids and sub-issue drafts |
| `model.investigator` | `sonnet` | grounding |

## Outputs

`WORK/plans/<slug>.md`; a summary in chat.

## Stops and autopilot

Stops at steps 1, 4 (a spike), 7 and 12. Under autopilot the plan is written and parked with `status: draft`; G20 denies an approval nobody gave, and execute-plan runs only an approved plan.

## Red flags

| Thought | Reality |
|---|---|
| "The tasks are obvious" | Write them down. Written tasks surface hidden ordering and forgotten edges. |
| "These two tasks can run side by side" | Not when they share a file or a service. plan-check says which. |
| "I'll work out the unknown during the build" | A question reading cannot settle gets a spike before the plan. |
| "One big task is simpler" | A task too big for one fresh context will be half done. Slice it. |
```

- [ ] **Step 4: Write `skills/plan/references/plan-template.md`**

A contract: `task-brief` reads `## Global Constraints` and `### Task N:` headings, and plan-check reads the frontmatter. Full text:

```markdown
# Plan template

Copy from the first `---` line to the end into `WORK/plans/<slug>.md`. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` checks the result.

---
status: draft
spec: WORK/specs/<slug>.md
issue: (tracker id, or none)
base: <base branch>; promotion: <branch chain, or none>
approved: (set only on an explicit yes, in the same edit as status: approved: the date, then one whole line of the user's message in double quotes)
execution:
commits: ask
---

**Goal:** one sentence.

**Architecture:** two or three sentences.

## Global Constraints

The spec's Constraints lines (Always, Ask first, Never), verbatim, then one line each for other exact values the spec fixes. Every task's brief includes this section.

## Review Focus

Inputs or conditions the spec implies but no test exercises, most likely first, each naming the task whose test pins it.

## File map

| Path | Task | Responsibility |
|---|---|---|

