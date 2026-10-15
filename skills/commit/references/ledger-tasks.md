# Ledger tasks

Rules for step 3 when execute-plan ledgers hold complete tasks. Every default below is what autopilot parks with.

## Which ledger

`<ledger dir>` is a dir under `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers` whose `ledger.md` `Worktree:` line names `<toplevel>`. Several do: ask (default: commit nothing from ledgers). None: no ledger tasks.

## A task's files

A complete task has a `Task <N>: complete tree=<id> ...` line; keep ledger order. Its package is `<ledger dir>/reviews/task-<N>-<tree7>.diff`, `<tree7>` the first 7 characters of the `tree=` of its `Task <N>: complete` line. Its `## Files changed` lines are name-status: `M<TAB>path`, `D<TAB>path`, `R100<TAB>old<TAB>new`. Take the path fields; stage both paths of a rename.

If the package is missing, run `git -C <toplevel> diff --name-only --no-renames <start tree> <complete tree>` on the trees of its start and complete lines; failing that, ask (default: leave the task uncommitted).

## Overlap

Tasks that share a path cannot be split: `git add` takes whole files. Never stage a file that holds another task's hunks under one task's name. For complete tasks, offer one commit naming each, or ask (default: that commit). A task with a `Task <N>: start` line and no complete line contributes the paths in `<ledger dir>/briefs/task-<N>.files` (a `dir/` entry covers what is under it). A complete task sharing one of them is not committed by path: ask (default: leave it uncommitted).

Autopilot commits each task as it closes, so complete tasks overlap only in a later run; the started-task check applies in both.

## Already committed

A complete task whose paths are clean in `git status --porcelain` is reported as already committed, not as a failure.
