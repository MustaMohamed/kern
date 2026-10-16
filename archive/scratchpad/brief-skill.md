---
name: execute-plan
description: Run an approved plan task by task in step, inline or delegate mode, with a resumable ledger and two-verdict review.
disable-model-invocation: true
argument-hint: "[plan path] [step|inline|delegate]"
---

# execute-plan

Turn an approved plan into verified, reviewed changes, with a record that survives compaction. Reached by the kernel row for executing an agreed plan, or typed as `/kern:execute-plan`.

Review needs no commits. Each task's change is the diff between two snapshot trees of its worktree: `tree-before` at dispatch and `tree-after` at return. A verdict holds for that `tree-after` id only, and `task-done` refuses any other tree. Serial tasks share one plan worktree, one writer at a time; wave members each get a fork.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Gate and ledger: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open <plan>`. It prints the ledger dir (`<ledger>` below is `<ledger dir>/ledger.md`), or exits 2 when the plan has no `status: approved` with the user's quoted words, or when the dir holds another plan's ledger: stop and report it. The mode is the typed one, else `execution:`. When `ledger.md` has `Task N: complete` lines, resume at the first task without one; a task whose last line is a fix round resumes that loop. After compaction, trust the ledger and the worktree over memory. Line formats: `references/ledger-format.md`.
2. Check the plan with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`; any line it prints is a plan defect, so stop before Task 1 and report it. Then run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check --graph <plan>`: write each `overlap` row to the ledger as a `Preflight:` line with its ruling, and keep the `wave` rows for step 4.
3. Read the plan and the spec once and make one todo per task. A spec or scope conflict the graph does not show: stop and ask before Task 1. A mechanical one gets a `Decision:` line.
4. Tasks in one `wave` row may run together through `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` in `delegate` mode; the rest run serially. Batch small tasks of one shape (the same one-line edit across files) into one dispatch and one review.
5. Create the plan worktree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <plan-slug> --branch <name from branch.pattern>`, off a freshly fetched `origin/<base>`; `worktree.setup` runs inside it. Record it as a `Worktree:` ledger line. Run the baseline `test.full` there; a red baseline goes to the user.
6. Per task, in the plan worktree, or for a wave task in its own `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <plan-wt> task-<N>` fork: write its Files list with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check --files <plan> <N> > <ledger dir>/briefs/task-N.files`, take `tree-before` with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`, and run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-start <ledger> <N> <tree-before>`. Then by mode:
   - `step`: do this one task by following `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, run steps 7 to 10 for it, report, and stop.
   - `inline`: do each task yourself with implement in the plan worktree, using absolute paths and `git -C`.
   - `delegate` (serial or wave): extract the task with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-brief <plan> <N> <ledger dir>`, then write `<ledger dir>/briefs/task-N.brief.md` from `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/brief-template.md`: CONTEXT names `briefs/task-N.md`, the upstream Interfaces and the step 3 rulings; VERIFY starts with `wt-check <wt> <base-ref>`; REPORT is `<ledger dir>/reports/task-N.md`. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check` on it; dispatch only on `brief-check: ok`: `kern:implementer` with an explicit model (`references/model-selection.md`), the brief path, the worktree path and the absolute path of the implement SKILL.md. Pass no `isolation` parameter; kern made the worktree.
7. Handle the status line. DONE goes to review. DONE_WITH_CONCERNS: read the concerns, then review. NEEDS_CONTEXT: answer from the plan or spec, else ask the user. BLOCKED: split the task, add context, or go one model tier up. Never re-dispatch unchanged.
8. Review: take `tree-after` with `wt-snap`, then run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before> <tree-after> --out <ledger dir>/reviews/task-N-<tree7>.diff --allow-file <ledger dir>/briefs/task-N.files`. Exit 4 names a file outside the task's Files: pause and ask. Dispatch `kern:task-reviewer` on `model.reviewer` in mode `task` with the brief, the report, the package, the plan's Global Constraints and the `review.rules` paths; do not pre-judge findings in the prompt. Resolve every "cannot verify" item yourself. Record the verdicts with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger> <N> <tree-after> <round> <compliant|issues> <approved|needs-fixes>`, adding `--minor "<finding>"` for each Minor finding, which waits for step 12.
9. Fix loop for Critical and Important findings: rounds 1 and 2 resume the implementer with the findings; round 3 dispatches a fresh implementer one tier up. Each round takes a new `tree-after`, gets a `re-review` scoped to its own fix diff, and is recorded with `task-review`. Still open after round 3, or a round finds a bug in an earlier round's code: stop and escalate with a split proposal.
10. Close the task: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-done <ledger> <N> <wt> <tree-after> --probe <package>.patch -- <task test command>`, or `--no-probe "<why>"` in place of `--probe` for a task with no test to probe (docs, config). It writes the complete line only when the tree is the one an approved review saw, the command passes, and the test fails with the change reversed (`probe=ok`). `probe=inconclusive` is accepted only for a change with nothing to reverse, such as a new module's first test; label that task's proof inferred. Exit 1 means the test passes without the change: return the task to the implementer. Under autopilot only, then commit the task's files with `/kern:commit` steps 3 to 6.
11. After a wave, each wave task has been closed in its fork through steps 6 to 10. Apply each worker's patch into the plan worktree one at a time with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <package>.patch <plan-wt>`. A conflict stops the run. Then run `test.full` in the plan worktree.
12. Final review: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open --summary <ledger dir>` lists the Decision, parked and deferred-minor lines. Package the whole change from the `Worktree:` base tree to a fresh snapshot with `wt-diff`, and dispatch `kern:task-reviewer` in mode `whole-branch` on `model.final_review` with that list, to triage which minors block. Re-grade findings by effect. One fix subagent gets the complete findings list, each fix red then green; then one re-review scoped to that fix diff. Residual findings go to the user in step 13.
13. Finish: report decisions with the cost if wrong, parked items, the deferred minors and their triage, verification commands with their output, the worktree path and the branch. `ledger-open --summary` must end with `main: unchanged`; anything else goes first in the report. No commit, push or PR; offer `/kern:commit` and `/kern:finish-branch`.
14. Propose teardown, do not run it: list the worktrees and their `git worktree remove` commands, and run them only on yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `base_branch`, `branch.pattern` | detected | the plan worktree's base and branch |
| `test.focused`, `test.full`, `typecheck` | detected, source printed | baseline, task and final checks |
| `worktree.dir`, `worktree.setup` | `.claude/worktrees` under MAIN; none | worktrees |
| `shared_services`, `parallel.max` | none; 3 | waves |
| `scope_threshold`, `review.rules`, `generated_artifacts` | 4; project prose; none | review inputs |
| `model.implementer`, `model.reviewer`, `model.final_review` | `sonnet`, `sonnet`, `opus` | dispatch models |

## Outputs

`WORK/ledgers/<plan-slug>/` holding `ledger.md`, `briefs/`, `reports/`, `reviews/` and `logs/`. A plan worktree with uncommitted changes. A chat summary.

## Stops and autopilot

Stops on a missing approval, a plan-check defect, a spec or scope conflict, a red baseline, a file outside the task's Files, three fix rounds, a probe that shows the test passes without the change, and a wave conflict. Under autopilot it runs to the end: judgment calls are parked with the default chosen and disjoint tasks continue; one commit per closed task when the checks pass; push and a draft PR only through finish-branch. Worktree isolation, serialization, expand and contract, read-only production, fix-loop limits, tests and secrets rules stay as they are.

## Red flags

| Thought | Reality |
|---|---|
| "Close enough on spec compliance" | Spec issues mean not done. Fix them or reach the cap and escalate. |
| "I'll fix it myself; dispatching is overhead" | A controller fix skips review. Resume the implementer. |
| "One more round will converge" | Past round 3 the failure is structural. Stop with a split proposal. |
| "The fix was small, skip the re-review" | task-done refuses a tree no review approved. |
| "This finding is wrong, I'll drop it" | Record a Decision line with the cost if wrong. A silent drop is forbidden. |
| "Ledger bookkeeping is overhead" | The ledger is what survives compaction. |
