# Worktrees

One writer, one worktree. Never the Agent tool's `isolation` parameter, and never a checkout, switch, reset or stash in the main worktree.

## Creating

- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` makes a detached worktree off a freshly fetched `origin/<base_branch>`, copies `.worktreeinclude` files, runs `worktree.setup` and leaves the setup marker. Use `--branch <name>` instead of `--detach` when `branch.pattern` holds `{id}`.
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <source-wt> <slug>` does the same from a worktree's HEAD and carries its uncommitted state. Exit 3: the state would not apply, fork removed.
- Both print the path. Any non-zero exit: say why and ask. Never fall back to a shared tree.

## Entry check

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` prints `ok`, or the first mismatch and exits 1. The worker runs it first; a mismatch is BLOCKED.

## Integration

`wt-snap` before the worker starts, then `wt-diff <wt> <starting-tree> --out <package>`, then `wt-apply <package>.patch <integration-wt>`, one patch at a time. A conflict applies nothing and goes to the user.

## Teardown

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit` and keep only the paths this run recorded. Never propose the integration worktree or a wt-fork source. An `unknown` worktree is never torn down. A worktree whose PR merged (bucket `merged`) may go with plain `git worktree remove <path>`.

`--force` needs the recorded integrated tree (wt-diff's second line) to equal `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`. Equal trees: run `git -C <wt> status --ignored --porcelain` and name every ignored file, since wt-snap skips them and `--force` deletes them. Trees differ, or none was recorded: no `--force`; report it, because the worker wrote after its package was cut.

Run each removal only on the user's yes. G1 asks on `git worktree remove --force` and denies it under autopilot, so list the worktrees instead. Then `git worktree prune`.
