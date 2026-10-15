# Ledger format

One ledger per plan at `WORK/ledgers/<plan-slug>/ledger.md`, append only, opened by `ledger-open`. Beside it: `briefs/`, `reports/`, `reviews/`, `logs/`.

## Lines

| Line | Written by | Meaning |
|---|---|---|
| `# kern ledger: <plan path>` | `ledger-open` | first line, once; another plan's ledger is refused |
| `Main: <root> branch=<name> status=<hash>` | `ledger-open` | the main checkout's state, compared at the end by `ledger-open --summary` |
| `Worktree: <path> branch=<name> base-tree=<id>` | step 5 | the plan worktree and its starting tree |
| `Preflight: Task A x Task B: <shared file or interface>: <ruling>` | step 2 | one per `plan-check --graph` overlap row |
| `Decision: <what>; why: <one line>; cost if wrong: <one line>` | any step | a mechanical call made without the user |
| `Task N: start tree=<id> at=<iso>` | `task-start` | dispatch |
| `Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>` | `task-review` | one per review or re-review |
| `Task N: minor (deferred): <text>` | `task-review --minor` | a Minor finding for the final review to triage |
| `Task N: fix round=<r> tree=<id>` | step 9 | a fix round began from that reviewed tree |
| `Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok, inconclusive or skipped (reason)> last=<line>` | `task-done` | done, only on an approved, unchanged, proven tree |
| `Wave: tasks <list> forks=<paths>` | step 6 | a parallel wave's forks exist |
| `Applied: Task N patch=<path>` | step 11 | a worker's patch integrated |
| `parked: <question>; default: <choice>; why: <one line>` | autopilot | a judgment call parked |

Lines no script writes are appended with `printf '%s\n' '<line>' >> <ledger>`; one holding the word approved goes in with the Edit tool, as G20 denies that shell write to a Markdown file.

## Resume rule

A task is done only when its `Task N: complete` line exists. Resume at the first task without one; when every task has one, go to the final review. A started task keeps its `Task N: start` tree as `tree-before` (no second `task-start`), so its review sees every change since dispatch; a snapshot still equal to it means nothing landed: dispatch again. If a task's last line is a `fix round`, resume that fix loop with a fresh snapshot. A wave task resumes in the fork its `Wave:` line names. Never re-dispatch a completed task.

## Tree ids

Snapshot trees are unreferenced objects. `git gc` keeps them for two weeks by default (`gc.pruneExpire`); a plan idle longer than that takes fresh snapshots and re-reviews.
