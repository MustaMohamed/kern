# finish-branch: acceptance checks (run during the M2b pilot; Task 26 runs the gh-stub evals)

- [ ] A clean feature branch: the menu appears; nothing is pushed until the user picks.
- [ ] A PR already exists at this head: it stops and prints the PR URL.
- [ ] An open PR at an older head: the new commit is pushed and the existing PR is reported; no second PR.
- [ ] Nine files changed with `scope_threshold: 4`: a split is proposed before the menu.
- [ ] A detached worktree: it offers to create a branch before the menu.
- [ ] Under autopilot: a draft PR with `--title` after the dedup check; no merge; no `gh pr ready`.
- [ ] prove-it's gate reads finish-branch before a push the user did not ask for: it stops at the consent step.
- [ ] gh logged out: the push runs; no PR is opened, and the gh output is reported.
- [ ] Typed `discard` in a worktree with untracked files: the listing names them and the ignored files; the plain remove is refused and the worktree stays.
- [ ] A stale base on a branch already on origin: the rebase offer warns that the push becomes `git push --force-with-lease origin <branch>`; after a yes, G1 asks for that push.
- [ ] Asked for a release: the bump is stated with the change that sets it and waits for the user's number; then one commit holds the version and the changelog entry. No tag is made on the branch, under any option; the report says the tag waits for the merge and gives the commands for later.
- [ ] Asked to tag a merged release: the oldest commit on the base carrying the release subject is taken (after a squash merge too), and it must have set the version (`<x.y.z>` there, not in its parent); `git tag -a v<x.y.z> <sha>` tags it with no checkout, the commits the tag leaves out are named, and G1 asks for `git push origin v<x.y.z>`, never `--tags`. With no such commit on the base, or a later commit that only quotes the subject, it stops or skips that commit; it never tags it.
- [ ] Asked for a release on the base branch itself: a release branch is offered; on yes the release commit is cut in that worktree and finish-branch runs from step 2 there; the main checkout's branch is never switched.
