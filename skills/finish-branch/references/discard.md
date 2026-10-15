# Discard

Only on the typed word `discard`, never under autopilot. In the main checkout, discard stops: it would need a reset or clean there. `git worktree remove --force` never runs here: `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md` allows it only under five conditions, the first needing a `wt-apply`.

1. List what it destroys: `git status --porcelain -uall --ignored` (a remove deletes ignored files too), the branch's commits (`git log --oneline <baseref>..HEAD`) and `<wt>`. Wait for the word.
2. `cd` to the main checkout, the first `git worktree list` line, as its own call.
3. Run `git worktree remove <wt>`, then `git branch -D <branch>` (G1 asks), then `git worktree prune`, each its own call. A refused remove stops; the worktree and branch stay. Report the files that blocked it, and print `git worktree remove --force <wt>` and `git branch -D <branch>` for the user to type with the `!` prefix.
4. Report what went, and that remote branches and PRs stay.
