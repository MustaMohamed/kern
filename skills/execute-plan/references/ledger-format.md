# Ledger format

One ledger per plan at `WORK/ledgers/<plan-slug>/ledger.md`, append only, opened by `ledger-open`. Beside it: `briefs/`, `reports/`, `reviews/`, `logs/`.

## Lines

| Line | Written by | Meaning |
|---|---|---|
| `# kern ledger: <plan path>` | `ledger-open` | first line, once; another plan's ledger is refused |
| `Plan: <hash>` | `ledger-open` | the plan's blob id; a changed plan is refused |
| `Main: <root> branch=<name> head=<sha> status=<hash>` | `ledger-open` | the main checkout's state, compared by `ledger-open --summary` |
| `Worktree: <path> branch=<name> base-tree=<id>` | step 5 | the plan worktree and its starting tree |
| `Preflight: Task A x Task B: <shared file or interface>: <ruling>` | step 2 | one per `plan-check --graph` overlap row |
| `Decision: <what>; why: <one line>; cost if wrong: <one line>` | any step | a ruling: the user's answer to a stop, a mechanical call made without the user, or a "Declined to judge" ruling |
| `Task N: start tree=<id> at=<iso>` | `task-start` | dispatch |
| `Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>` | `task-review` | one per review or re-review |
| `Task N: minor (deferred): <text>` | `task-review --minor` | a Minor finding the final review triages |
| `Task N: fix round=<r> tree=<id>` | step 9 | a fix round began from that reviewed tree |
| `Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok or skipped (reason)> last=<line>` | `task-done` | done, only on an approved, unchanged, proven tree |
| `Wave: tasks <list> forks=<paths>` | step 6 | a wave's forks exist |
| `Applied: Task N patch=<path>` | step 11 | a worker's patch integrated |
| `parked: <question>; default: <choice>; why: <one line>` | autopilot | a judgment call parked |

Only the scripts write `Task N: start`, review, minor and `Task N: complete` lines; never write or edit one by hand. A batch of tasks shares one brief, package and review, and the scripts still write each task's lines. The other lines are appended with `printf '%s\n' '<line>' >> <ledger>`; one holding the word approved goes in with the Edit tool, as G20 denies that shell write to a Markdown file. So does a line appended in a command that holds the word anywhere else, a `task-review ... approved` call included: append it in a call of its own. Limit: no guard yet stops an Edit or Write that forges a script's line; that guard is deferred to M3.

## Resume rule

A task is done only when its `Task N: complete` line exists. Where a run resumes is in `resume.md`.

## Tree ids

Snapshot trees are unreferenced objects: `git gc` keeps them two weeks by default (`gc.pruneExpire`); a plan idle longer takes fresh snapshots and re-reviews.
