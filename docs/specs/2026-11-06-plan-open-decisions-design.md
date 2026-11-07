# Plan skill: open decisions, writers and spec-only tests

Approved by the user, 2026-11-06 ("Approve design"). Lines marked "my call" are the designer's; the rest are the user's words or accepted playback.

## Intent

kern's head-to-head `plan` score is 0.79 (h2h round 2, Sonnet 5.5 under test, 3 runs per task). `plan/rename-small` (0.97) and `plan/reminder-seam` (0.90) pass. `plan/archive-invoices` (0.73) and `plan/scope-split` (0.57) do not. The goal is a plan mean of at least 0.9 through general changes to the plan skill, with no fact from any eval task written into a skill.

The misses fall into five general patterns. Evidence: `evals/results/kept-2026-11-05-round{1,2}/h2h-2026-11-05/snapshot-sonnet-5-5-plan.json` in the main checkout, kern arm.

| # | Pattern | Rubric misses | Cause in the skill today |
|---|---|---|---|
| 1 | Stops with questions and writes no plan file | scope-split b4, 4 of 6 runs | Step 4 sends product questions to the user, and step 7 says "stop and ask" over the size limits; both read as "stop before writing" |
| 2 | Builds tasks on its own default for a user decision | archive-invoices b2, 3 of 3 round 2 runs | Step 4 asks "with a recommendation"; nothing forbids a task built on it |
| 3 | Names a writer of a gated property only for a side issue | archive-invoices b1, 1 run | Step 3 asks for "stored shapes and their writers", not what each writer does to the new state |
| 4 | Renames a stored value in one step | scope-split b2, 2 of 3 runs | Step 7's expand, migrate, contract rule names "stored shapes"; a renamed value is not read as one |
| 5 | Tests assert behaviour the spec never states | scope-split b5, 2 of 3 runs | Nothing limits a test's assertions to the spec |

The user chose to fix all five ("All five").

## Goals

| # | Goal |
|---|---|
| 1 | Outside step 1's preconditions and a step 4 spike, plan always writes the draft plan file; every user question sits under Open questions as a numbered `Q<n>` entry |
| 2 | No task builds on an unanswered user decision: a task that depends on one is written once per option, each blocked by that `Q<n>` and that option |
| 3 | A scope over `scope_threshold` or `pr.max_lines` gets the split plan by default, with "one PR instead?" as a `Q<n>`; the split gates no task |
| 4 | For each property the change reads to decide or sets, the plan lists every writer and what that writer does to the new state |
| 5 | A renamed or retired stored value is a stored shape change: expand, migrate, contract |
| 6 | A test asserts only what an acceptance line or a Constraint states; other behaviour goes to Review Focus as a question |
| 7 | The h2h plan mean reaches at least 0.9 on a paid round |

## Non-goals

- `skills/autopilot/`, `run.md`, the guards, the exec files and the kernel: untouched (from the brief). Under a go, `run.md` still decides.
- Skill descriptions: untouched, so routing and its held-out floor (`heldout_rank1` in `evals/floors.json`) do not move (my call).
- `skills/define/`: untouched. Every miss is in plan's own steps (my call).
- Eval task files, rubrics and the grader: untouched.

## Anti-goals

- A skill line that names a fact from an eval task: a file, a role, a job, a column.
- A plan longer by more than its option tasks, or one that trips the reviewer's proportion check on `rename-small` or `reminder-seam`.
- An approved plan that still carries an option task or a `Q<n>` blocker.
- A fall on `rename-small` (0.97) or `reminder-seam` (0.90) beyond run noise (see exit rule).

## Decisions

### Open questions format

Each user question is one entry under the plan's `## Open questions`:

```
Q1: <question>. Options: (a) <option>; (b) <option>. Recommended: (a), <one-line why>.
```

A spike's answer and a `parked:` line keep their current forms beside these entries. Under autopilot with no go, a parked question is also a `Q<n>` entry, and its `parked:` line names it (my call).

### Gated tasks, one full task per option

The user chose a full task per option ("Full task per option"). A task whose files, tests or steps depend on the answer to `Q<n>` is written once per option, as consecutive tasks, each with `**Blocked by:** <earlier tasks>; Q1=a` (or `Q1=b`) and a name ending `(Q1=a)`. A later task that differs by option is itself written per option. A later task that does not differ names `Q1` without an option and is blocked by every option task it consumes from. The Size line counts the largest option (my call).

A question whose answer changes no task (the scope question of goal 3, a naming preference) blocks nothing.

### Modes

| Mode | Product question | Scope over a limit |
|---|---|---|
| No autopilot | `Q<n>`, option tasks, draft plan, step 12 asks | split plan, one-PR `Q<n>` |
| Autopilot on, no go | `Q<n>` with a `parked:` line naming it, option tasks, draft plan; no task builds on the parked default | split plan, `parked:` line as today |
| Under a go | unchanged: `run.md`'s stop list decides, and the go's own approval needs a plan with no `Q<n>` blocker, so plan writes no option tasks under a go | unchanged: `run.md` takes the split |

My call: `run.md` stays untouched per the brief, so the option split stops at the go boundary.

### Stops that stay

Step 1's preconditions, the step 4 spike's nod, and step 3's ask when `kern-get` and `kern-detect` both exit 3 for a verify command (my call: a run with no detectable test command is rare, and a plan without one cannot pass plan-check's `Run:` rule).

### Approval

Step 12 lists each `Q<n>` with its recommendation beside the request for the yes. An answer to a `Q<n>` is a change request under step 12's existing rule: keep the chosen option's tasks, delete the others, renumber, drop the `Q<n>` blockers, record `Q1: answered <date>, "<one whole line of the user's message>"`, run plan-check, show it, ask again. A yes that leaves a gating `Q<n>` unanswered is no yes: ask for the answer.

### plan-check

`scripts/plan-check` changes, all in plan mode:

| Input | Today | After |
|---|---|---|
| `**Blocked by:** Q1=a` alone | "names no task and is not none" | passes |
| `Q<n>` in Blocked by with no `Q<n>:` line under `## Open questions` | not checked | problem |
| `Q<n>=x` whose entry lists no `(x)` | not checked | problem |
| Two tasks sharing a file, blocked by the same `Q<n>` with different options | "not blocked by" problem | passes: they are alternatives |
| A `Q1=b` task consuming a name that both a `Q1=a` and a `Q1=b` task produce | "not blocked by" the first producer | checked against the producer with the same option |
| `status: approved` with any `Q<n>` in a Blocked by | not checked | problem: an approved plan answers it first |

Plans with no `Q<n>` behave exactly as today, so G20, ledger-open and task-brief see no change (my call; the builder confirms with their existing bats suites).

### Skill text changes

| Where | Change |
|---|---|
| `skills/plan/SKILL.md` step 3 | Writers: for each property the change reads to decide or sets, every writer and what it does to the new state; a writer that can undo or re-trigger that state gets a task or a `Q<n>` |
| step 4 | A product question becomes a `Q<n>` and the plan goes on; only a spike stops here |
| step 7 | A renamed or retired stored value (an enum member, a status, a role name) is a stored shape. Over a limit: write the split, add the one-PR `Q<n>`, do not stop |
| step 8 | Point to the gated-task rule and the spec-only assertion rule |
| step 12 and "Stops and autopilot" | Step 7 is no longer a stop; the approval rule above |
| `references/task-template.md` | Step 1 asserts only values an acceptance line or Constraint states; the gated-task form |
| `references/plan-template.md` | The `Q<n>` entry form under Open questions |
| `references/plan-review.md` | Two findings: a test asserting behaviour no acceptance line or Constraint states; a task built on an unanswered `Q<n>` without its option split |

Wording is the builder's, within kern's prose rules (no em or en dashes, no task-specific fact).

## Measure and exit rule

Agreed with the user, 2026-11-06 ("Accept"):

- One measure round: `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval scripts/eval-all --jobs 6 --no-cache --only h2h-plan`, after `claude auth status` shows the personal Max account, on the user's yes.
- Exit: plan mean at least 0.9 on one paid round, and neither `rename-small` nor `reminder-seam` more than 0.1 below its round 2 score.
- Same round, in parallel ("Yes, behave too"): `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval node scripts/behave.mjs --changed main...HEAD --jobs 6 --no-cache`, which runs the behave cases whose skills the diff touches (`workflow-plan-review-round` at least). It passes under M3's standing behave rule, the pooled fall test against 0.4.0 (my call: the rule M3 already uses for behave).
- Cap: 3 paid rounds, each on its own yes. Fixes between rounds stay general. No pass after round 3: report and stop.
- diagnose (0.958) and review (0.90): no rerun if the diff touches no file their arms load; the builder lists the diff's files to show it.

## Left to the builder

- Exact skill wording and where each line sits in its step.
- plan-check's parsing of `Q<n>` and `Q<n>=x`, and its new problem messages.
- Which existing tests pin the changed wording, and their updates.
- New bats cases for each plan-check row above.
