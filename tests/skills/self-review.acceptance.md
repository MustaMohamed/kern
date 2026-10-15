# self-review: acceptance checks (run during the M2b pilot)

- [ ] The diff adds `it.skip(`: the floor scan flags it; the verdict is not `ready`.
- [ ] The diff changes a shared function with five external callers: the writer sweep lists them with paths, and one fact is run.
- [ ] A spec exists: the Spec lane quotes its acceptance lines and its findings stay apart from the Standards findings.
- [ ] A project with `.claude/skills/self-review/`: kern defers in one line.
- [ ] The built-in `code-review` is missing: a skip line appears; the other steps run.
- [ ] The built-in lane receives the worktree path as its target and reviews that worktree's diff (record what it reviewed; if a path target is not accepted, note it for M3).
- [ ] `origin` exists but the fetch fails: the skill asks (under autopilot it parks and goes on with the last fetched ref), the report says "base not refreshed", and a clean diff gets `rebase first`.
- [ ] The repo has no `origin` remote: the base ref is the local base branch, said once, and the rebase check runs against it.
- [ ] `origin/<base>` moved on a file the package changed since the merge base: the verdict is `rebase first`, and the skill rebases nothing.
- [ ] The tree equals the merge base: wt-diff exits 3 and the skill says there is nothing to review.
- [ ] A new guard test whose probe exits 3: the report says inconclusive and the verdict is `fix first`.
- [ ] A second run on the same branch writes `<slug>-2.diff` and a since package; a finding in an added line of the since package, or a package newly over `scope_threshold` paths, gives `split`; the first run never does.
