# Worktrees

One writer, one worktree. Never the Agent tool's `isolation` parameter, and never a checkout, switch, reset or stash in the main worktree.

## Creating

- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` makes a detached worktree off a freshly fetched `origin/<base_branch>`, copies `.worktreeinclude` files, runs `worktree.setup` and leaves the setup marker. Add `--branch <name>` instead of `--detach` when `branch.pattern` holds `{id}`.
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <source-wt> <slug>` does the same from a worktree's HEAD and carries its uncommitted state. Exit 3: the state would not apply, fork removed.
- Both print the path. Any non-zero exit: say why and ask. Never fall back to a shared tree.
- Worktrees live under `worktree.dir`, which kern keeps out of git.

## Entry check

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` prints `ok`, or the first mismatch and exits 1: not a linked worktree, unknown or non-ancestor base, setup marker missing. The worker runs it first; a mismatch is BLOCKED.

## Integration

Per worker: `wt-snap` before it starts, then `wt-diff <wt> <starting-tree> --out <package>`, then `wt-apply <package>.patch <integration-wt>`. One patch at a time. A conflict applies nothing and goes to the user. Run the full suite once, after the last patch.

## Teardown

Start from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit`: one line per worktree, `bucket<TAB>path<TAB>branch<TAB>evidence`. A worktree is done when its PR merged (bucket `merged`, read from `gh pr list --head <branch> --state all`) or its work was integrated. An `unknown` worktree is never torn down: a git call failed or the base did not resolve, so nothing is known about its work.

Propose `git worktree remove <path>` for each done one, and `--force` only for a writer's worktree whose work was integrated, since it still holds an uncommitted copy. A worktree holding uncommitted work not yet integrated stays. Run the commands only on yes, never under autopilot, then `git worktree prune`.
