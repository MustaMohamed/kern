# Branch operations

Under autopilot only the proven-tree check runs, without its teardown. `git worktree remove --force` never runs here: `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows it only under five conditions, the first needing a `wt-apply`.

## Rebase

For a stale base (step 3) or a `rebase first` verdict (step 5). Propose `git rebase <baseref>` and run it only on yes; on no, go on. git refuses a rebase over uncommitted changes: then offer it again after step 8's commit, and if refused again, go on. A rebase stopped by a conflict: run `git rebase --abort`, report the conflicting paths, and stop. After a rebase in step 3 or 5, run again from step 4; after one in step 8, the check below proves the new tree.

## Proven tree

Push only the proven tree: `git rev-parse HEAD^{tree}` must equal the tree from step 4. If not, run `git rev-parse HEAD`, then `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>-check --detach --base <HEAD sha>` (`<slug>`: the base name of `<wt>`). A non-zero exit: report its output and ask; no push. Else `cd` to the path it prints, run `test.full`, then `cd <wt>`, each its own call. Red: no push; name what the commit left out (`git status --porcelain`). Then propose `git worktree remove <check>`, run on yes; a refusal keeps it, reported.

## Discard

Only on the typed word `discard`. In the main checkout, discard stops: it would need a reset or clean there.

1. List what it destroys: `git status --porcelain -uall --ignored` (a remove deletes ignored files too), the branch's commits (`git log --oneline <baseref>..HEAD`) and `<wt>`. Wait for the typed word.
2. `cd` to the main checkout, the first `git worktree list` line, as its own call.
3. Run `git worktree remove <wt>`, then `git branch -D <branch>` (G1 asks), then `git worktree prune`, each its own call. A refused remove stops: report the files that blocked it; the worktree and branch stay.
4. Report what went, and that remote branches and PRs stay.
