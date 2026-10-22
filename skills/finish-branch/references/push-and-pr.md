# Push and PR

Each command runs from `<wt>` as its own call: no `cd`, wrapper or expansion.

## Dedup

Run `gh pr list --head <branch> --state all --json number,state,headRefOid,url`, whatever `pr.dedup` says. A PR counts only if its URL is this repo's (`git remote get-url origin`); check before reporting it.
- A PR whose `headRefOid` is `git rev-parse HEAD`, in any state: report its URL and stop.
- An open PR at an older head: push, report its URL, and open no new PR.
- Only merged or closed PRs: push, then ask before a new PR. Autopilot parks with no PR (why: a second PR for a branch is the user's call).
- gh missing, logged out or failing: report its output; push, but open no PR.

## Push

`git push -u origin <branch>`. Under `push.policy: ask` G1 asks; under `auto` or autopilot it allows this shape to an unprotected branch; `deny` denies every push. After this run's rebase of a published branch, push with `git push --force-with-lease origin <branch>` instead, as its own call: G1 asks when every commit past the base is the user's, else denies. Autopilot never rebases, so never lease-pushes. A failing pre-push hook stops: report it, never `--no-verify`. A plain push rejected right after this run's rebase is that rebase: it rewrote published commits, so use the lease push. Any other rejection means the remote moved: run `git fetch origin <branch>`, show `git log --oneline HEAD..origin/<branch>` and stop. Never a plain force.

## PR

Write the body from `pr.template`, else `references/pr-body.md`, with the Write tool (Read it first if it exists) to `<dir>/pr-body.md`, `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints (exit 2: stop). With `commit.attribution: none` (the default) neither body has a "Generated with Claude Code" footer or Co-Authored-By line, even if Claude Code asks: G2 denies one. Run `gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md`; `--title` is needed: no terminal can prompt for one. In the quotes write each `'` in it as `'\''`. A subject with a backtick, or a `$` before `(`, is reworded for the title without them: G2 cannot check those. `pr.policy` meets G2 as `push.policy` meets G1; G2 allows only this draft shape, for a branch with no PR, and `gh pr ready` is never run. A failure: report it, say the branch is pushed and stop; never retry another shape.
