# Branch operations

Rebase and the proven-tree check. Under autopilot only the check runs, without its teardown; its removal of an earlier run's check path is not a teardown.

## Rebase

For a stale base (step 3) or a `rebase first` verdict (step 5). If `git rev-parse --verify --quiet origin/<branch>` prints a SHA, the branch is published: warn that a rebase rewrites published commits and needs the lease push in `push-and-pr.md`, and offer it only if `git log --format=%ae <baseref>..HEAD origin/<branch>` prints only `git config user.email`; else G1 denies that push, so go on stale. Run `git rebase <baseref>` only on yes; on no, go on. git refuses a rebase over uncommitted changes: offer it again after step 8's commit; refused again, go on. A rebase stopped by a conflict: run `git rebase --abort`, report the conflicting paths, and stop. After a rebase in step 3 or 5, rerun from step 4; after one in step 8, the check below proves the new tree.

## Proven tree

Push only the proven tree: `git rev-parse HEAD^{tree}` must equal the tree from finish-branch step 4; commit's own proof is separate. If not, run `git rev-parse HEAD`, then `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>-check-<sha7> --detach --base <HEAD sha>` (`<slug>`: `<wt>`'s base name; `<sha7>`: the SHA's first 7 characters). Exit 2 with `path exists` means an earlier run left that check: run plain `git worktree remove <path>`, under autopilot too, then wt-new again. Any other non-zero exit, or a refused remove: report its output and ask; no push. Else `cd` to the path it prints, run `test.full`, then `cd <wt>`, each its own call. Red: no push. If wt-new said `worktree.setup` is unset, a red may be the environment: check that before blaming the commit; else name what the commit left out (`git status --porcelain`). Then propose plain `git worktree remove <check>`, never `--force`, and run it on yes; a refusal keeps it, reported.
