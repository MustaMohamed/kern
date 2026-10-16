# M0 Task 1 report
Status: DONE_WITH_CONCERNS
Commit: c8a78b1 M0: start the kern repo with its spec, plans and research notes
Did: created ~/Code/projects/kern (branch main), .gitignore, README.md verbatim, copied 2 specs, 4 plans (contract + m0/m1/m2), 12 research notes. Committed named paths only, no trailers, no push.
Verify: pre-commit status = ?? .gitignore, ?? README.md, ?? docs/. After commit: git status --porcelain empty; 20 tracked files (4 plans, 12 research, 2 specs, .gitignore, README.md).
Toolchain: node v18.19.0 (plan wants v22+), git 2.54.0, claude 2.1.296, bats and shellcheck in ~/.local/bin. gh not checked beyond the brief's command (output not shown because node check ran first; gh not printed).
Concern: node is v18.19.0, below the v22 floor; later tasks use node:test and may need Node 22.
