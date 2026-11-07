# Plan skill open decisions: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementers and reviewers run on Opus.

**Goal:** Raise kern's h2h `plan` mean from 0.79 to at least 0.9 through five general plan-skill fixes and a plan-check change that lets a draft plan carry open user decisions.

**Architecture:** plan-check learns `Q<n>` and `Q<n>=<option>` blockers tied to `## Open questions` entries, treats option tasks of the same question as alternatives, and refuses an approved plan that still has one. The plan skill writes the draft plan instead of stopping, writes one task per option for an open decision, lists what every writer does to the new state, treats a renamed stored value as a stored shape, and limits test assertions to the spec. Its references carry the forms; the plan reviewer checks two new findings.

**Tech Stack:** BWK awk and bash 3.2 (`scripts/plan-check`), bats, Node 22 `node:test`, markdown skills.

**Spec:** `docs/specs/2026-11-06-plan-open-decisions-design.md`.

## Global Constraints

- Untouched: `skills/autopilot/`, `hooks/guards/`, the exec files (`scripts/exec-eval.mjs`, `evals/exec/`), `kernel/`, `skills/define/`, every skill's `description`, `evals/h2h/`, `evals/heldout.json`, `evals/heldout-pilot.json`.
- No skill line names a fact from an eval task: a file, a role, a job, a column, a status value.
- Opus for all build, review and audit work; the eval model under test stays Sonnet 5.5.
- Paid runs: each on the user's own yes, after `claude auth status` shows the personal Max eval account, under `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval`. Never the default CLI login, which is Team.
- Exit rule (the user's "Accept"): plan mean at least 0.9 on one paid round, and neither `plan/rename-small` (0.97) nor `plan/reminder-seam` (0.90) more than 0.1 below its round 2 score. Behave cases the diff touches pass M3's pooled fall test against 0.4.0. Cap: 3 paid rounds. No pass after round 3: report and stop.
- Bats only through `bash tests/run-bats <file>`. `node` below means `PATH="$HOME/.volta/tools/image/node/22.23.3/bin:$HOME/.local/bin:$PATH" node`.
- Focused suites per task; full `bash scripts/ci-local` once, in Task 4.
- A skill size cap moves only with its test's `assertMaxBytes` value, the test's comment, and the size sentence in `docs/specs/2026-10-12-kern-m1-m2-skills.md` section C2 item 8, in one commit naming the task. Today: plan `SKILL.md` 7,503 of 7,509; `plan-review.md` 1,922 of 1,922; `plan-template.md` 1,969 of 2,200; `task-template.md` 1,945 of 2,200.
- A changed script updates its row in `docs/plans/contract.md`; a changed contract or spec sentence gets a pin in `tests/skills-control.test.mjs` where that file already pins its neighbours.
- Unslop for persisted prose: no em or en dashes. Commit subjects start `M3: `, stage named paths only, carry no attribution lines. No push without the user's yes, then over HTTPS with the gh credential helper.

## Review Focus

1. A plan with no `Q<n>` anywhere: plan-check's output and exit are byte for byte today's, so G20, ledger-open and task-brief see no change. Pinned in Task 1 by the existing 42 bats tests passing unchanged.
2. A `Q` inside a Blocked by line that is no blocker (a task title quoted there): only a token `Q<digits>` or `Q<digits>=<letter>` bounded by a non-word character counts. Pinned in Task 1.
3. A later task blocked by `Q1` alone that consumes a name both option tasks produce: it must be blocked by both. Pinned in Task 1.
4. A run under a go reads the new step 4: it writes no option tasks, since the go's own approval would fail plan-check. Pinned in Task 2 by a text pin on step 4's go clause.
5. The scope question stops no run and gates no task: step 7 no longer says "stop". Pinned in Task 2.

## Decisions made in this plan

| Decision | Why |
|---|---|
| plan-check's new problem lines: `Task N: Blocked by names Qk, which Open questions does not list`; `Task N: Blocked by names Qk=x, but Qk lists no option (x)`; `Task N: blocked by open question Qk; an approved plan answers it first` | One message per rule, in the existing `Task N:` form |
| An Open questions entry is a line under `## Open questions` that opens `Q<k>:`; its options are each `(<letter>)` on that line | The spec's entry form, one line per question |
| Two tasks conflict when both name the same `Q<k>` with different options; conflicting tasks skip the overlap rule and each other in the consume rule | The spec's alternatives, generalised to every producer |
| The consume rule checks every producer of a name that does not conflict with the consumer, not only the first | A `Q1` task consuming from both option tasks must be blocked by both |
| New gated-task and assertion rules live in `task-template.md`; the `Q<n>` form lives in `plan-template.md`; SKILL.md carries one clause per step pointing there | SKILL.md has 6 bytes of headroom; the references are read at steps 8 and 9 |

## File map

| Path | Task | Responsibility |
|---|---|---|
| `scripts/plan-check` | 1 | `Q<n>` blockers, alternatives, approved-plan refusal |
| `tests/scripts/plan-check.bats` | 1 | one test per new rule |
| `docs/plans/contract.md` | 1 | plan-check row |
| `skills/plan/SKILL.md` | 2 | steps 3, 4, 7, 8, 12 and Stops and autopilot |
| `tests/skills/plan.test.mjs` | 2, 3 | pins and caps |
| `docs/specs/2026-10-12-kern-m1-m2-skills.md` | 1, 2, 3 | A3 plan-check row; C2 steps and size sentence |
| `skills/plan/references/plan-template.md` | 3 | `Q<n>` entry form |
| `skills/plan/references/task-template.md` | 3 | option tasks; spec-only assertions |
| `skills/plan/references/plan-review.md` | 3 | two findings |
| `CHANGELOG.md` | 4 | Unreleased entry |

### Task 1: plan-check reads open-question blockers

**Files:**
- Modify: `scripts/plan-check:130-134` (Blocked by), `:200-250` (end checks, overlap, consume)
- Modify: `docs/plans/contract.md:193`, `docs/specs/2026-10-12-kern-m1-m2-skills.md` (A3 plan-check row)
- Test: `tests/scripts/plan-check.bats`

**Interfaces:**
- Consumes: none.
- Produces: plan-check accepts `**Blocked by:** Task 3; Q1=a`, `**Blocked by:** Q1` and `**Blocked by:** Q1=b`; the three problem lines in Decisions.

**Blocked by:** none.

**Acceptance:** design goals 1-3 (plan-check rows).

- [ ] Step 1: Write the failing bats tests, each building on the setup's `plan.md` with `sed` and an appended `## Open questions` section (`printf '%s\n' '## Open questions' '' 'Q1: Which? Options: (a) one; (b) two. Recommended: (a), simpler.' >> plan.md`), the setup's status set to `draft` where the test needs it:
  - `a draft with option tasks blocked by Q1=a and Q1=b passes`: Tasks 5 and 6 share `src/opt.js`, Blocked by `Q1=a` and `Q1=b`; `[ "$status" -eq 0 ]`, `[ -z "$output" ]`.
  - `a Q1=b consumer checks only the Q1=b producer`: Tasks 5 (`Q1=a`) and 6 (`Q1=b`) both produce `` `opt()` ``; Task 7 consumes it, Blocked by `Task 6; Q1=b`; passes.
  - `a Q1 task consuming from both options must be blocked by both`: Task 7 Blocked by `Task 6; Q1` consumes `` `opt()` ``; exit 1; `says "Task 7 consumes \`opt()\` from Task 5 but is not blocked by it"`.
  - `a blocker naming an unlisted question is a problem`: Blocked by `Q2=a`; `says "Task 5: Blocked by names Q2, which Open questions does not list"`.
  - `a blocker naming an unlisted option is a problem`: Blocked by `Q1=c`; `says "Task 5: Blocked by names Q1=c, but Q1 lists no option (c)"`.
  - `an approved plan with an open-question blocker is a problem`: status `approved`, Task 5 Blocked by `Q1=a`; `says "Task 5: blocked by open question Q1; an approved plan answers it first"`.
  - `a Q inside a word in Blocked by is no blocker`: Blocked by `Task 1 (FAQ1 page)`; passes with no Open questions section.
  - `--graph prints no overlap for alternatives`: the first test's plan; `--graph` output has no `overlap` line naming both 5 and 6.
- [ ] Step 2: Run: `bash tests/run-bats tests/scripts/plan-check.bats`. Expected: the 8 new tests fail (the first with "Blocked by names no task and is not none"), the 42 old ones pass.
- [ ] Step 3: Implement in `scripts/plan-check`: in the Blocked by rule, collect tokens matching `(^|[^A-Za-z0-9_])Q[0-9]+(=[a-z])?` into `qb[cur]` and skip the "names no task" problem when `qb[cur]` is set; record `## Open questions` lines that open `Q<k>:` and the `(<letter>)` options on them; in the end checks, emit the three problems; add `conflict(a, b)` (same `Q<k>`, different letters) and skip conflicting pairs in the overlap loop and in `ov`; replace `producer[w]` (first producer) with a per-name producer list and check each non-conflicting producer. BWK awk only: no `gensub`, no arrays of arrays, no `\<` word boundaries.
- [ ] Step 4: Run: `bash tests/run-bats tests/scripts/plan-check.bats tests/scripts/task-brief.bats tests/scripts/ledger.bats tests/hooks/g20-probes.bats`. Expected: all pass.
- [ ] Step 5: Update the `plan-check` row in `docs/plans/contract.md` and the A3 row in the skills spec with the three problem lines and the alternatives rule; add a pin in `tests/skills-control.test.mjs` if it pins that row today. Run: `node --test tests/skills-control.test.mjs`. Expected: pass. Commit `M3: plan-check reads open-question blockers`.

### Task 2: plan writes the draft and gates open decisions

**Files:**
- Modify: `skills/plan/SKILL.md` steps 3, 4, 7, 8, 12, `## Stops and autopilot`
- Modify: `docs/specs/2026-10-12-kern-m1-m2-skills.md` section C2 (steps 3, 4, 7, 12; item 8 size sentence)
- Test: `tests/skills/plan.test.mjs`

**Interfaces:**
- Consumes: Task 1's `Q<n>` and `Q<n>=<option>` blocker forms.
- Produces: SKILL.md text Task 3's references are pointed to: "as task-template.md says", "in plan-template.md's form".

**Blocked by:** Task 1.

**Acceptance:** design goals 1-5.

- [ ] Step 1: Write the failing pins in `tests/skills/plan.test.mjs`. Replace the two pins of `else stop and ask the user to confirm the scope or split` (lines 128 and 194) and add, by step:
  - `s[3]` includes `every writer and what it does to the new state` and `undo or re-trigger`.
  - `s[4]` includes `becomes a \`Q<n>\``, `the plan goes on`, `written once per option` and `Under a go, \`run.md\` decides`; does not include `as options with a recommendation`.
  - `s[7]` includes `A renamed or retired stored value` and `is a stored shape`; includes `write the split` and `whether one PR instead`; does not include `else stop`.
  - `s[8]` includes `asserts only what an acceptance line or a Constraint states`.
  - `s[12]` includes `An answer to a \`Q<n>\` is a change request` and `A yes that leaves a gating \`Q<n>\` open`.
  - The Stops section includes `Stops at steps 1, 4 (a spike) and 12.` and `no task builds on the default`.
  - `assertMaxBytes(SKILL, <new size>)` with its comment naming this plan's Task 2.
- [ ] Step 2: Run: `node --test tests/skills/plan.test.mjs`. Expected: the new pins fail on the old text.
- [ ] Step 3: Edit SKILL.md to this content, worded within kern's rules and as few bytes as it allows:
  - Step 3: grounding lists, for each property the change reads to decide or sets, every writer and what it does to the new state; a writer that can undo or re-trigger that state gets a task or a `Q<n>`.
  - Step 4: a product question becomes a `Q<n>` under Open questions in plan-template.md's form, and the plan goes on; a task that depends on its answer is written once per option, as task-template.md says; no task builds on the recommendation. Under a go, `run.md` decides, and plan writes no option tasks. Fact questions and the spike keep today's text.
  - Step 7: add that a renamed or retired stored value (an enum member, a status, a role name) is a stored shape. Over a limit: write the split, each PR within both limits, and add a `Q<n>` asking whether one PR instead; it gates no task. Keep the limit-statement sentence, reworded from "at a scope split or stop" to "at a scope split".
  - Step 8: each test asserts only what an acceptance line or a Constraint states; other behaviour goes to Review Focus as a question.
  - Step 12: list each `Q<n>` with its recommendation beside the request for the yes. An answer to a `Q<n>` is a change request: keep that option's tasks, delete the others, renumber, drop its blockers, record `Q<n>: answered <date>, "<one whole line of the user's message>"`, then the existing make, show, ask again. A yes that leaves a gating `Q<n>` open: ask for the answer.
  - Stops and autopilot: `Stops at steps 1, 4 (a spike) and 12.` With autopilot on and no go, a product question's `parked:` line names its `Q<n>`, and no task builds on the default; the step 7 sentence keeps "the split, never a plan over".
- [ ] Step 4: Run: `node --test tests/skills/plan.test.mjs tests/skills-control.test.mjs tests/lint-rules.test.mjs`. Expected: pass. Then `node scripts/lint-skills.mjs`. Expected: no finding on `skills/plan/`.
- [ ] Step 5: Update C2 steps 3, 4, 7, 12 and the item 8 size sentence ("at most <new> bytes (7,509 until this plan's Task 2: ...)") in the skills spec. Commit `M3: plan writes the draft and gates open decisions`.

### Task 3: plan references carry the forms and review findings

**Files:**
- Modify: `skills/plan/references/plan-template.md` (Open questions section)
- Modify: `skills/plan/references/task-template.md` (Blocked by line; a new paragraph after the steps)
- Modify: `skills/plan/references/plan-review.md` (What to check)
- Modify: `docs/specs/2026-10-12-kern-m1-m2-skills.md` section C2 item 8 (only if a cap moves)
- Test: `tests/skills/plan.test.mjs`

**Interfaces:**
- Consumes: Task 1's blocker forms; Task 2's pointers.
- Produces: the `Q<n>` entry form `Q<n>: <question>. Options: (a) <option>; (b) <option>. Recommended: (a), <why>.` and the answer form `Q<n>: answered <date>, "<one whole line of the user's message>"`.

**Blocked by:** Task 2.

**Acceptance:** design goals 2, 5 and 6.

- [ ] Step 1: Write the failing pins in `tests/skills/plan.test.mjs`:
  - `plan-template.md` includes `Q<n>: <question>. Options: (a) <option>; (b) <option>. Recommended: (a), <why>.` and `Q<n>: answered <date>`.
  - `task-template.md` includes `` `Q<n>` or `Q<n>=<option>` `` on the Blocked by line, `written once per option`, `(Q1=a)`, and `asserts only what an acceptance line or a Constraint states`.
  - `plan-review.md` includes `a test asserting behaviour no acceptance line or Constraint states` and `built on an open \`Q<n>\`'s recommendation`.
  - `plan-review.md`'s `assertMaxBytes` raised to its new size, with the comment naming this plan's Task 3; the other two caps move only if exceeded.
- [ ] Step 2: Run: `node --test tests/skills/plan.test.mjs`. Expected: the new pins fail.
- [ ] Step 3: Edit the three references. task-template.md's paragraph: a task whose files, tests or steps depend on an open `Q<n>` is written once per option, as consecutive tasks named `<name> (Q1=a)`, each blocked by its `Q1=<option>`; a later task that does not differ is blocked by `Q1` and by every option task it consumes from; the Size line counts the largest option. Step 1's test line gains: asserts only what an acceptance line or a Constraint states; other behaviour goes to Review Focus. plan-review.md gains two `What to check` lines for the two findings.
- [ ] Step 4: Run: `node --test tests/skills/plan.test.mjs tests/skills-control.test.mjs`. Expected: pass. Then write a throwaway draft plan from the edited templates with one question and two option tasks under `$TMPDIR` and run `bash scripts/plan-check <it>`. Expected: exit 0, no output.
- [ ] Step 5: Update the skills spec size sentence for each moved cap. Commit `M3: plan references carry open-question forms and two review findings`.

### Task 4: Changelog, full CI and whole-branch review

**Files:**
- Modify: `CHANGELOG.md` (Unreleased: one entry naming the design, the plan, the five fixes, the plan-check rows and each moved cap)
- Test: `bash scripts/ci-local`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: a branch ready for the paid round.

**Blocked by:** Task 3.

**Acceptance:** design goals 1-6.

- [ ] Step 1: Write the CHANGELOG entry. Run: `LC_ALL=C grep -c -e "$(printf '\342\200\224')" -e "$(printf '\342\200\223')" CHANGELOG.md docs/plans/2026-11-06-plan-open-decisions-plan.md skills/plan/SKILL.md skills/plan/references/*.md`. Expected: every count 0 except any count CHANGELOG.md already had on main.
- [ ] Step 2: Run: `bash scripts/ci-local`. Expected: pass.
- [ ] Step 3: Send the branch diff (`git diff main...HEAD`) and the design to one fresh Opus reviewer subagent: correctness of the awk, a task-specific fact in any skill line, a rule that changes a plan with no `Q<n>`, byte caps. Fix Critical and Important findings; park Minors in the CHANGELOG entry's known limits.
- [ ] Step 4: Run: `git diff --stat main...HEAD -- skills/diagnose skills/self-review skills/review kernel hooks`. Expected: empty, so diagnose and review need no rerun.
- [ ] Step 5: Commit `M3: changelog for the plan open-decisions fixes`.

### Task 5: Paid measure round (on the user's yes)

**Files:**
- Test: `evals/results/` (git-ignored)

**Interfaces:**
- Consumes: Task 4's branch head.
- Produces: the round's snapshot paths and the exit-rule verdict.

**Blocked by:** Task 4.

**Acceptance:** design goal 7.

- [ ] Step 1: Ask the user for the yes, naming both commands and the cost of each round. No run without it.
- [ ] Step 2: Run: `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval claude auth status`. Expected: the personal Max account. Otherwise stop and say so.
- [ ] Step 3: Run both in the background, at once: `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval scripts/eval-all --jobs 6 --no-cache --only h2h-plan` and `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval node scripts/behave.mjs --changed main...HEAD --jobs 6 --no-cache`. Expected: both exit 0.
- [ ] Step 4: Read the kern arm per task from the h2h snapshot and the behave cases' results. Expected (pass): plan mean at least 0.9; `rename-small` at least 0.87; `reminder-seam` at least 0.80; behave cases pass the pooled fall test.
- [ ] Step 5: Pass: report and stop. No pass and fewer than 3 rounds run: one general fix from the grader's "why" text, focused tests, then back to Step 1. Round 3 with no pass: report and stop.
