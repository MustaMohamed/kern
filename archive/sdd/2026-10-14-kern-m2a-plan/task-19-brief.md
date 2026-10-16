### Task 19: `define` (path)

**Files:**
- Create: `skills/define/SKILL.md`, `skills/define/references/spec-template.md`, `skills/define/references/interview.md`, `skills/define/references/spec-review.md`, `skills/define/references/capability-map.md`, `tests/skills/define.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/define.test.mjs`

**Interfaces:**
- Consumes: `kern:investigator` (Task 13), `scripts/wt-new --detach` (Task 1), `scripts/plan-check` (Task 11), guard G20 (Task 14).
- Produces: path skill `define`; spec files `WORK/specs/<slug>.md` with frontmatter `status: draft | approved | draft (parked under autopilot)`, `form: full | short`, `date`, `approved` (the date and one whole line of the user's message, in double quotes), `issue`, and a `## Constraints` section of `- Always:`, `- Ask first:` and `- Never:` lines that plan copies into Global Constraints. `plan` (Task 20) gates on `status: approved`.

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/define.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/define/SKILL.md';

test('define frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'define',
    description: 'Clarify new behaviour, classify it spike, bounded or architectural, and get explicit approval before any code.',
    'disable-model-invocation': 'true',
    'argument-hint': '[issue id | idea]',
  });
});

test('define sections, steps, the standing gate and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 11);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['Standing gate on every path', '"sounds good", "whatever you think" and silence do not', 'status: approved', 'status: draft (parked under autopilot)',
    'kern:investigator', 'on `model.investigator`', 'The map is approved before any module spec', '${CLAUDE_PLUGIN_ROOT}/scripts/plan-check',
    'one whole line of the user\'s yes, verbatim', 'wt-new <slug> --detach', 'Never ask the user a fact the repo can answer',
    'A request with no existing flow to extend is architectural', 'visual pages not installed', 'Guard G20']);
  assertMaxBytes(SKILL, 6500);
});

test('define references', () => {
  const refs = {
    'spec-template.md': [['# Spec template', '## Problem', '## Intent', '## Constraints', '## Assumptions', '## Success criteria', '## Acceptance criteria', '## Decisions', '## Compatibility', '## Authorization', '## Rollout', '## Checklists', '## Test seams', '## Not doing', '## Open questions'], 3000],
    'interview.md': [['# Interview', '## Hypothesis and confidence', '## One question at a time', '## Want versus should-want', '## Restate and confirm', '## When to step back'], 3200],
    'spec-review.md': [['# Spec reviewer brief', '## What to check', '## Calibration', '## Output'], 1400],
    'capability-map.md': [['# Capability map', '## When to split', '## Map format', '## Approval'], 1200],
  };
  for (const [f, [hs, max]] of Object.entries(refs)) {
    assertHeadings(`skills/define/references/${f}`, hs);
    assertMaxBytes(`skills/define/references/${f}`, max);
  }
  assertContains('skills/define/references/spec-template.md', ['Copy from the first `---` line to the end', '- Always:', '- Ask first:', '- Never:', 'form: short', 'the highest seam that already exists and the fewest seams']);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/define.test.mjs`
Expected: 3 failing tests; `skills/define/SKILL.md exists`.

- [ ] **Step 3: Write `skills/define/SKILL.md`**

The Red flags rows adapt `.upstream/superpowers/skills/brainstorming/SKILL.md:98-108` and `.upstream/addy/skills/spec-driven-development/SKILL.md:225-246`; step 2's last sentence comes from `.upstream/pocock/skills/engineering/grilling/SKILL.md:28`.

```markdown
---
name: define
description: Clarify new behaviour, classify it spike, bounded or architectural, and get explicit approval before any code.
disable-model-invocation: true
argument-hint: "[issue id | idea]"
---

# define

Turn an ask into an approved shared understanding, and for architectural work an approved spec, before any code. Reached by the kernel row for new behaviour with no agreed spec, or typed as `/kern:define`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Ticket. With `tracker.first: true`, find and read the issue: body, comments, parent. No issue: offer an issue draft, and never post it.
2. Explore read-only with `kern:investigator` subagents on `model.investigator` (default `sonnet`), dispatched in one message: relevant files, recent commits, related PRs, the stored shape of any persisted field, every writer of a property the change gates on, and whether the gap is real on `origin/<base>`. Keep asking the questions that do not wait on those facts. Never ask the user a fact the repo can answer.
3. Classify and say it: spike; bounded (an existing flow, within `scope_threshold` files, no change to a public API, a persisted schema or authorization); else architectural. A request with no existing flow to extend is architectural. Take the heavier class when in doubt; upgrade mid-task, never downgrade.
4. For several independently testable capabilities, draw a capability map with a build order (`references/capability-map.md`). The map is approved before any module spec.
5. Intent: state a HYPOTHESIS and a CONFIDENCE, naming what is missing below about 70%. Ask intent questions one at a time, each with your guess; probe want versus should-want; skip what the issue already states (`references/interview.md`).
6. Decisions: ask in numbered frontier rounds, each question with a recommended answer worded so "yes" accepts it. A question that depends on an open one waits a round. Three or more options: a visual page only when kern's `visual` skill is installed; otherwise chat, saying once "visual pages not installed".
7. Restate: Outcome, User, Why now, Success, Constraint, Out of scope; then what was said versus what is assumed. Only an explicit yes approves; "sounds good", "whatever you think" and silence do not.
8. Spike: state the question and the probe in 2 or 3 sentences and wait for a nod. Probe in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree or under `WORK`, never in the main checkout. Return an answer, not code; the code is throwaway.
9. Bounded: give an in-chat design (approach, files, tests, constraints as always, ask first and never, one line per `checklists` item) and stop for an explicit yes. On yes, write `WORK/specs/<slug>.md` in short form (`form: short`) from `references/spec-template.md`, with `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in the same write, and run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>`. The kernel then routes to implement.
10. Architectural: offer 2 or 3 approaches, recommendation first; present the design in sections and get approval per section; write the spec from `references/spec-template.md` (or the project's spec system) with `status: draft`; run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` and fix what it reports; self-review it for contradictions, scope and two-reading ambiguity; send it to one reviewer subagent with `references/spec-review.md`, round 1 only. Stop the turn. On an explicit yes in a later turn, set `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in one edit; the kernel then routes to plan.

Standing gate on every path: no code, scaffold, dependency install, migration or branch before that path's approval. An approval covers only the stage presented. Guard G20 denies an approval whose quote is not a line of the user's last message.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker`, `tracker.first` | detected, `false` | read the issue first |
| `scope_threshold` | 4 files | bounded versus architectural |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | extra design lines |
| `base_branch` | detected | where the gap is checked |
| `work_dir` | `.kern` | where specs go |
| `model.investigator` | `sonnet` | read-only exploration |

The project's own spec system wins when it exists (`docs/specs`, `docs/rfcs`, an ADR directory); else specs go to `WORK/specs`.

## Outputs

`WORK/specs/<slug>.md`. Questions in chat.

## Stops and autopilot

Every product or preference call goes to the user. After two rounds without rising confidence, step back and say so. Under autopilot define cannot approve itself (G20 denies it): it writes the draft with open questions and recommended answers, marks it `status: draft (parked under autopilot)`, writes a `parked:` ledger line, and only work that does not depend on it continues.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a design" | A bounded change still gets a short design and an explicit yes. |
| "I'll call it bounded and skip the spec" | Reaching for the lighter class to skip work is the doubt. Take the heavier one. |
| "The design is obvious, I'll start while they read" | The gate is the approval, not the design's length. Stop until you hear yes. |
| "It grew, but I'm nearly done" | Hidden scope upgrades the class mid-task. Stop and say so. |
| "They said sounds good" | Only an explicit yes approves, quoted in the spec. |
| "I'll write the spec and the plan in one turn" | The turn ends after the spec. The plan waits for the yes. |
```

- [ ] **Step 4: Write `skills/define/references/spec-template.md`**

This file is a contract: plan copies its Constraints lines, and plan-check reads its sections. The Constraints section adapts addy's Boundaries (`.upstream/addy/skills/spec-driven-development/SKILL.md:138-142`); the Test seams line adapts `.upstream/pocock/skills/engineering/to-spec/SKILL.md:15-17`. Full text:

```markdown
# Spec template

Copy from the first `---` line to the end into `WORK/specs/<slug>.md`. Fill every section, or write `none` and why. Decisions name modules and contracts, not file paths; paths belong in the plan. A bounded change uses the short form: set `form: short` and keep only Problem, Constraints, Acceptance criteria and Test seams. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` checks the sections for either form.

---
status: draft
form: full
date: YYYY-MM-DD
approved: (set only on an explicit yes, in the same edit as status: approved: the date, then one whole line of the user's message in double quotes)
issue: (tracker id, or none)
---

## Problem

What is wrong or missing today, for whom, with evidence.

## Intent

Outcome. User. Why now. Success. Constraint. Out of scope.

## Constraints

- Always: what every change in this work does (a check to run, a convention to keep).
- Ask first: what needs the user's yes before it happens (a schema change, a new dependency).
- Never: what no task may do (a file not to touch, a system that stays read-only).

plan copies these three lines verbatim into the plan's Global Constraints.

## Assumptions

Each one marked said (the user said it) or assumed (you inferred it).

## Success criteria

How the user will judge it, measurable where possible.

## Acceptance criteria

1. One observable, testable line per criterion.

## Decisions

Modules, interfaces, schema and contracts chosen, each with the alternative rejected.

## Compatibility

Existing data and consumers; every writer of a gated property; the stored shape as it is today; the regression test by name.

## Authorization

Who may call or see what, and the check that scopes it.

## Rollout

Base branch, promotion chain, flags, migration order (expand, migrate, contract).

## Checklists

One line per extra `checklists` item.

## Test seams

Where tests attach: public functions, handlers, CLI entries, components. Prefer the highest seam that already exists and the fewest seams, and confirm the list with the user.

## Not doing

## Open questions
```

- [ ] **Step 5: Port the other three references**

`skills/define/references/interview.md`
Source: `.upstream/addy/skills/interview-me/SKILL.md:40-140` and `:132-140` (the step-back floor).
Required headings: `# Interview`, `## Hypothesis and confidence`, `## One question at a time`, `## Want versus should-want`, `## Restate and confirm`, `## When to step back`.
Adaptation: confidence is a number with the missing facts named; each question carries the asker's guess; a fact the repo can answer goes to a subagent, never to the user; "Restate and confirm" lists Outcome, User, Why now, Success, Constraint, Out of scope and says only an explicit yes approves, quoted as one whole line of the user's message; "When to step back" says two rounds without rising confidence means stop and say so; no source tags.
Check: `for h in '# Interview' '## Hypothesis and confidence' '## One question at a time' '## Want versus should-want' '## Restate and confirm' '## When to step back'; do grep -qxF "$h" skills/define/references/interview.md || echo "missing $h"; done && [ "$(wc -c < skills/define/references/interview.md)" -le 3200 ]`

`skills/define/references/spec-review.md`
Source: `.upstream/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md:1-49`.
Required headings: `# Spec reviewer brief`, `## What to check`, `## Calibration`, `## Output`.
Adaptation: the reviewer is a fresh subagent given the spec path and the restated intent, never the author's reasoning; checks placeholders, contradictions, scope, two-reading ambiguity, Constraints lines that are not checkable, missing Compatibility and Authorization content; calibration: approve unless a gap would lead to a flawed plan; output: `Verdict: approve | revise`, then findings as `section: problem. fix.`; round 1 only.
Check: `for h in '# Spec reviewer brief' '## What to check' '## Calibration' '## Output'; do grep -qxF "$h" skills/define/references/spec-review.md || echo "missing $h"; done && [ "$(wc -c < skills/define/references/spec-review.md)" -le 1400 ]`

`skills/define/references/capability-map.md`
Source: `.upstream/addy/skills/spec-driven-development/SKILL.md:34-65`.
Required headings: `# Capability map`, `## When to split`, `## Map format`, `## Approval`.
Adaptation: split when the ask holds several independently testable capabilities; the map is a table (capability, user-visible outcome, depends on, build order); the map is approved before any module spec, then each module goes through define in build order.
Check: `for h in '# Capability map' '## When to split' '## Map format' '## Approval'; do grep -qxF "$h" skills/define/references/capability-map.md || echo "missing $h"; done && [ "$(wc -c < skills/define/references/capability-map.md)" -le 1200 ]`

- [ ] **Step 6: Write `tests/skills/define.acceptance.md`**

```markdown
# define: acceptance checks (run during the M2b pilot)

- [ ] "Add a CSV export to the reports page": classified bounded; one intent question with a guess; no Edit or Write outside `WORK` before the yes; the short-form spec quotes the user's yes and passes plan-check.
- [ ] "Make billing multi-tenant": classified architectural; sections approved one at a time; spec written with `status: draft` and a Constraints section; the turn ends after the spec; no plan written.
- [ ] The user answers the design with "whatever you think": an explicit yes is requested; the status stays draft (G20 denies an approval quoting it).
- [ ] A project with `.claude/skills/define/`: kern defers in one line.
```

- [ ] **Step 7: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `define` | path | Routed row "New behaviour and no agreed spec"; /kern:define | Clarify, classify and approve before code |``
Add under `## [Unreleased]`: `- define: clarify, classify and get an explicit, quoted approval before code; specs carry a Constraints section.`

- [ ] **Step 8: Run the tests and lint**

Run: `node --test tests/skills/define.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; no lint errors.

- [ ] **Step 9: Commit**

```bash
git add -- skills/define tests/skills/define.test.mjs tests/skills/define.acceptance.md skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the define skill" -m "Approval is recorded in the spec with the user's own words, which G20 checks; the Constraints section is what plan copies into every task's brief."
```

---

