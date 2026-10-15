# commit: acceptance checks (run during the M2b pilot; Task 26 runs the guard and gh-stub checks)

- [ ] On `CDS-2465/replace-minio` with `commit.convention: "^CDS-[0-9]+: "`: the subject starts `CDS-2465: `; no trailers; only touched files are staged.
- [ ] An untracked `.env.local` exists: it is not staged, and it is listed.
- [ ] On `main`: it stops and asks. Under autopilot it parks and commits nothing. On a detached HEAD: same.
- [ ] After a delegate run with three complete ledger tasks that touch disjoint files: three commits are offered, one per task, in ledger order, each from `git -C <plan worktree>`.
- [ ] Two complete tasks that touch the same file: one commit naming both tasks is offered; no file holding the other task's hunks is staged under one task's name.
- [ ] A complete task whose `reviews/task-N-<tree7>.diff` was deleted: its files come from `git diff --name-only <start tree> <complete tree>`.
- [ ] Called by execute-plan with the plan worktree: the commit lands on the plan worktree's branch and the main checkout's branch and status are unchanged.
- [ ] A project with `.claude/skills/commit/`: kern defers in one line; G5 and G6 still check the commit.
- [ ] A complete task whose file was renamed (`R100`): both old and new paths are staged.
- [ ] A started, incomplete task lists a path a complete task also changed: the complete task is not committed by path; it asks, or under autopilot parks and stays uncommitted.
- [ ] Two ledgers name the same worktree: it asks.
- [ ] A rename whose package is missing: both paths are staged.
