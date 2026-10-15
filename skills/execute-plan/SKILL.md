---
name: execute-plan
description: Run an approved plan task by task in step, inline or delegate mode, with a resumable ledger and two-verdict review.
disable-model-invocation: true
argument-hint: "[plan path] [step|inline|delegate]"
---

# execute-plan

Turn an approved plan into verified, reviewed changes, with a record that survives compaction. Reached by the kernel row for executing an agreed plan, or typed as `/kern:execute-plan`.

Review needs no commits: a task's change is the diff between snapshot trees of its worktree, `tree-before` at dispatch and `tree-after` at return; a verdict holds for that `tree-after` only. Serial tasks share the plan worktree, one writer at a time; wave tasks get forks. A subagent gets absolute paths (`${CLAUDE_PLUGIN_ROOT}` resolved) and a named model (`references/model-selection.md`). A script exit not named here stops the run: report its output.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Gate and ledger: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger-open <plan>`. It prints the ledger dir (`<ledger>` below is `<ledger dir>/ledger.md`), or exits 2 when the plan has no `status: approved` with the user's quoted words, or when the dir holds another plan's ledger: stop and report it. Never edit the plan's approval. The mode is the typed one, else `execution:`. A ledger with `Task N: start` lines resumes as `references/ledger-format.md` says. After compaction, trust the ledger and the worktree over memory.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`; any exit but 0 is a plan defect: stop before Task 1 and report its output. Then `plan-check --graph <plan>`: each `overlap` row becomes a `Preflight:` line with its ruling; keep the `wave` rows for step 4.
3. Read the plan and spec once; one todo per task. A spec or scope conflict the graph does not show: stop and ask before Task 1. A mechanical one gets a `Decision:` line.
4. In `delegate` mode a `wave` row's tasks may run together, each in its fork, at most `parallel.max`, unless parallel-work step 1 finds an overlap; spawn them in one message as `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` step 4 does. Other tasks run serially, in task order. Batch small tasks of one shape (the same one-line edit across files) into one dispatch and one review over their joined Files lists; the ledger scripts still run per task.
5. Once, unless a `Worktree:` line exists, make the plan worktree: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <plan-slug> --base <plan base>` (`<plan-slug>` is the ledger dir's name), adding `--branch <name>` when `branch.pattern` holds `{id}` (the plan's `issue:`). Exit 2: say why and ask. Write `Worktree: <path> branch=<name> base-tree=<id>`, the id from `wt-snap`. Run the baseline `test.full` there (`kern-get`, else `kern-detect`; both exit 3: ask); a red baseline goes to the user.
6. Per task, in the plan worktree or a wave task's fork from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <plan-wt> <plan-slug>-task-<N>` (exit 2 or 3: say why and ask), run `plan-check --files <plan> <N> > <ledger dir>/briefs/task-N.files`, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-brief <plan> <N> <ledger dir>` (`briefs/task-N.md`), `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` (`tree-before`) and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-start <ledger> <N> <tree-before>`; exit 2 from any: stop. Write `Wave: tasks <list> forks=<paths>` once a wave's forks exist. Then by mode:
   - `step`: do this task with `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, reporting to `<ledger dir>/reports/task-N.md`; run steps 8 to 10, report, and stop.
   - `inline`: the same for each task, in the plan worktree, with absolute paths and `git -C`.
   - `delegate` (serial or wave): write `<ledger dir>/briefs/task-N.brief.md` from `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/brief-template.md`: SCOPE the `.files` paths, the worktree and `<base-ref>` (the plan branch); CONTEXT `briefs/task-N.md`, the upstream Interfaces and the step 3 rulings; VERIFY `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` first, then the task's `Run:`; REPORT `<ledger dir>/reports/task-N.md`. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check` on it; dispatch only on `brief-check: ok` (else fix each printed line): `kern:implementer` with its model, the brief, worktree, `<base-ref>`, report path and implement SKILL.md path. Pass no `isolation` parameter; kern made the worktree.
7. Status line (none: BLOCKED). DONE goes to review. DONE_WITH_CONCERNS: read the concerns, then review. NEEDS_CONTEXT: answer from the plan or spec, else ask the user, then resume the implementer. BLOCKED: add context or go one model tier up, with a `Decision:` line; a task that must be split: stop with a split proposal. Never re-dispatch unchanged.
8. Review: take `tree-after` with `wt-snap`, then run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before> <tree-after> --out <ledger dir>/reviews/task-N-<tree7>.diff --allow-file <ledger dir>/briefs/task-N.files`. Its first line is `<package>`, beside `<package>.patch`. Exit 3 (empty): return the task to the implementer. Exit 4 names a file outside the task's Files: pause and ask. Dispatch `kern:task-reviewer` on `model.reviewer` in mode `task` with `briefs/task-N.md`, the report, the package, the worktree and the `review.rules` paths; do not pre-judge findings in the prompt. Resolve every "cannot verify" item yourself; a real gap is a spec issue. Record the verdicts with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger> <N> <tree-after> <round> <compliant|issues> <approved|needs-fixes>`, round 1 here, adding `--minor "<finding>"` for each Minor finding, which waits for step 12.
9. Fix loop for a spec issue or a Critical or Important finding. Round r is the r-th review, 1 to 3. Before rounds 2 and 3 write `Task N: fix round=<r> tree=<id>`, the tree just reviewed. Round 2 resumes the implementer with the findings verbatim (SendMessage to its agent id; inline and step: fix it yourself); round 3 dispatches a fresh `kern:implementer` one tier up with a step 6 brief, the report and the open findings. Each round packages its fix diff with `wt-diff` from the round's tree to a new `tree-after` (`--out <ledger dir>/reviews/task-N-fix<r>-<tree7>.diff`, same `--allow-file` and exits), gets a `re-review` with the findings, and is recorded with `task-review`. Still open after round 3, or a re-review finds a bug in an earlier round's fix: stop and escalate with a split proposal. There is no fourth round; `task-review` refuses one.
10. Close: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-done <ledger> <N> <wt> <tree-after> --probe <package>.patch -- <task test command>`, one command (task-done runs no shell), or `--no-probe "<why>"` in place of `--probe` for a task with no test to probe (docs, config); after fix rounds, remake `<package>` from `tree-before`. It writes the complete line only when an approved review saw this tree, the command passes, and the test fails with the change reversed (`probe=ok`). `probe=inconclusive` stands only for a change with nothing to reverse, such as a new module's first test: label that proof inferred; any other reason: ask. A refusal writes nothing and says why. `command exited <n>` (`<ledger dir>/logs/task-N.log`), or exit 1 (the test passes with the change reversed): return the task to the implementer as the next round. A changed or unapproved tree: review it. A probe error: stop. Under autopilot only, then commit the task's files with `/kern:commit` steps 3 to 6, a wave task's after step 11.
11. After a wave, each wave task has been closed in its fork through steps 6 to 10. Apply each worker's patch to the plan worktree one at a time with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <package>.patch <plan-wt>`, writing `Applied: Task N patch=<path>` after each `applied`. Exit 3 is a conflict with nothing applied: stop. Then run `test.full` there; red: stop.
12. Final review: `ledger-open --summary <ledger dir>` lists the Decision, parked, Preflight and deferred-minor lines and the main checkout's state. Package everything with `wt-diff <plan-wt> <base-tree> --out <ledger dir>/reviews/final.diff` (`<base-tree>` from the `Worktree:` line) and dispatch `kern:task-reviewer` in mode `whole-branch` on `model.final_review` with the package, the plan and that list, to triage which minors block. Re-grade findings by effect. One fix subagent gets the complete findings list in a step 6 brief, each fix red then green; then one re-review scoped to that fix diff, packaged with an `--allow-file` per task. Residual findings go to the user in step 13.
13. Finish: report decisions with the cost if wrong, parked items, deferred minors and their triage, verification commands with output, the worktree and the branch. `ledger-open --summary` must end with `main: unchanged`; anything else goes first in the report. No push or PR, no commit beyond step 10's; offer `/kern:commit` and `/kern:finish-branch`.
14. Propose teardown, do not run it: each fork with the `git worktree remove` command `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows, the plan worktree once committed; run them only on yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `base_branch`, `branch.pattern` | detected; `kern/{slug}` | plan worktree |
| `test.focused`, `test.full`, `typecheck` | detected, source printed | checks |
| `worktree.dir`, `worktree.setup` | `.claude/worktrees` under MAIN; none | worktrees |
| `shared_services`, `parallel.max` | none; 3 | waves |
| `scope_threshold`, `review.rules`, `generated_artifacts` | 4; project prose; none | review |
| `model.implementer`, `model.reviewer`, `model.final_review` | `sonnet`, `sonnet`, `opus` | models |

## Outputs

`WORK/ledgers/<plan-slug>/` holding `ledger.md`, `briefs/`, `reports/`, `reviews/` and `logs/`. A plan worktree with uncommitted changes. A chat summary.

## Stops and autopilot

Stops at steps 1 to 3 and 5 to 11; ask as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, steps 1 and 2 and a failed `wt-new` still end the run, as nothing approves a plan (G20). A later stop parks as `parked: <question>; default: <choice>; why: <one line>` in the ledger: a question takes its default (the plan's text; a red baseline goes on, its red tests named as red before), a stopped task stays open with every task blocked by it, and disjoint tasks continue. One commit per closed task when its checks pass, through `/kern:commit`; G5 allows only `git commit -m` or `-F <file>` on an unprotected branch. Without autopilot `commits: ask` holds: no commit. Push and a draft PR only through finish-branch; teardown never runs. Isolation, serialization, expand and contract, read-only production, the round cap, tests and secrets rules do not loosen.

## Red flags

| Thought | Reality |
|---|---|
| "Close enough on spec compliance" | Spec issues mean not done. Fix them or reach round 3 and escalate. |
| "I'll fix it myself; dispatching is overhead" | A fix outside the loop skips review. Resume the implementer, then re-review. |
| "One more round will converge" | Past round 3 the failure is structural. Stop with a split proposal. |
| "The fix was small, skip the re-review" | task-done refuses a tree no review approved. Re-review every fix. |
| "This finding is wrong, I'll drop it" | Record a Decision line with the cost if wrong. A silent drop is forbidden. |
| "Ledger bookkeeping is overhead" | The ledger is what survives compaction. Write each line as it happens. |
