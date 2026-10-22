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
- [ ] A new guard test whose probe exits 3 for any reason but a new module or a test-only patch: the report says inconclusive and the verdict is `fix first`.
- [ ] The branch changes only test files: the probe exits 3 as inconclusive, and that alone does not fail the check or make the verdict `fix first`.
- [ ] The branch adds `src/two.js` and `test/two.test.js`: the probe exits 3 on the missing module, the report says `probe inconclusive: new module`, a `--mutate` probe on the new code's condition runs, and that probe alone does not make the verdict `fix first`.
- [ ] A second run on the same branch writes `<slug>-2.diff` and a since package; a finding in an added line of the since package, or a package newly over `scope_threshold` paths, gives `split`; the first run never does.
- [ ] The diff moves a test into a `describe` block with the same assertions and renames a variable: no finding names either; each behaviour-keeping change lands in Cleared with its check. A function the diff adds with no test gets no finding of its own: the missing test is one line under the finding it would have caught; with no such finding, the missing test is a line of its own, not a finding, and does not change the verdict. No nit is a guess called probably fine, style advice or a first-round split idea.
- [ ] The diff breaks a caller in a file it does not touch: that is a finding at the caller's `path:line`. A defect the diff did not cause is filed as `pre-existing`. A smell from the baseline is reported as a `should-fix` judgement at most.
