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

`--force` runs only when ALL of these hold:
1. `wt-apply` printed `applied` for this worker's package. Record wt-diff's second line (TO_TREE) only then; a conflicted or exit 4 worker has no recorded tree.
2. The recorded TO_TREE equals `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` now.
3. The path is in this run's recorded list.
4. Every ignored file in `git -C <wt> status --ignored --porcelain` is named to the user: wt-snap skips them and `--force` deletes them.
5. The user said yes. G1 asks on `git worktree remove --force` and denies it under autopilot, so list the worktrees instead.

If any condition is not proven, use plain `git worktree remove <path>`, or keep the worktree and report it. Then `git worktree prune`.
