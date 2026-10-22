# Rounds and packages

A round is one run of self-review on a branch. Each run writes one package, and the packages tell a first round from a later one.

## Package names

`<slug>` is the output of `git -C <wt> rev-parse --abbrev-ref HEAD` with `/` written as `-`; `detached` when it prints HEAD. `<reviews>` is the output of `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir reviews`, run in `<wt>`. This branch's earlier packages are `<reviews>/<slug>-<N>.diff` with N all digits. This run's `<package>` is `<reviews>/<slug>-<N+1>.diff`, or `<reviews>/<slug>-1.diff` when there is none.

## Previous package

The package with the highest N is the previous one. None means a first round: no since package, and `split` cannot apply. A package's first line reads `# Review package: <from>..<to>`; `<previous-tree>` is the text after `..` (git resolves it as a tree).

## Since package

In a later round, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <previous-tree> --out <reviews>/<slug>-<N+1>-since.diff`. It holds what changed since the previous run; exit 3 means nothing did. Its name does not match the `<slug>-<N>.diff` pattern, so it is never taken for a package. A later round's verdict is `split` when this package has more than `scope_threshold` paths and the previous one did not, or a finding in the first two classes lands on a line the previous round's findings asked to change.

