# Push and PR

Steps 9 to 11. Each command runs from `<wt>` as its own call: no `cd`, wrapper or expansion.

## Dedup

Run `gh pr list --head <branch> --state all --json number,state,headRefOid,url`, whatever `pr.dedup` says (its one value is `on`).
- A PR whose `headRefOid` is `git rev-parse HEAD`, in any state: report its URL and stop.
- An open PR at an older head: push, report its URL, and open no new PR.
- Only merged or closed PRs: push, then ask before a new PR. Autopilot parks with no PR (why: a second PR for a branch is the user's call).
- gh missing, logged out or failing: report its output; push, but open no PR.

## Push

`git push -u origin <branch>`. Under `push.policy: ask` G1 asks, and its prompt is the confirmation; under `auto` or autopilot it allows this shape to a branch that is not protected; `deny` denies every push. A denial, a declined prompt or a failing pre-push hook stops: report it, never `--no-verify`. Rejected: the remote moved. Run `git fetch origin <branch>`, show `git log --oneline HEAD..origin/<branch>` and stop; never force.

## PR

Write the body from `pr.template`, else `references/pr-body.md`, with the Write tool (Read it first if it exists) to `<dir>/pr-body.md`, `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints (exit 2: stop). Run `gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md`; it needs `--title` because no terminal can prompt for one. In the quotes write each `'` in it as `'\''`, with no backtick and no `$` before `(`: G2 cannot check those. `pr.policy` meets G2 as `push.policy` meets G1, and G2 allows only this draft shape, for a branch with no PR. G2 denies a PR that is not a draft, and `gh pr ready` is never run. A failure: report it, say the branch is pushed, and stop; never retry another shape.
