# self-review: acceptance checks (run during the M2b pilot)

- [ ] The diff adds `it.skip(`: the floor scan flags it; the verdict is not `ready`.
- [ ] The diff changes a shared function with five external callers: the writer sweep lists them with paths, and one fact is run.
- [ ] A spec exists: the Spec lane quotes its acceptance lines and its findings stay apart from the Standards findings.
- [ ] A project with `.claude/skills/self-review/`: kern defers in one line.
- [ ] The built-in `code-review` is missing: a skip line appears; the other steps run.
- [ ] The built-in lane receives the worktree path as its target and reviews that worktree's diff (record what it reviewed; if a path target is not accepted, note it for M3).
- [ ] The branch has no remote: the fetch fails, the skill asks (under autopilot it parks and goes on with the last fetched ref), and the report says "base not refreshed".
- [ ] `origin/<base>` moved on a file the package changed since the merge base: the verdict is `rebase first`, and the skill rebases nothing.
- [ ] The tree equals the merge base: wt-diff exits 3 and the skill says there is nothing to review.
- [ ] A new guard test whose probe exits 3: the report says inconclusive, and the verdict is not `ready` on that test's account.
