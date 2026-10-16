# Resume notes for executing kern plans M0 to M2 (subagent-driven)

- Ledger for M0: ../2026-10-12-kern-m0-plan/progress.md (tasks 1-8 complete; task 9 implemented and pushed, its task review and the M0 final whole-branch review are next).
- Plans: docs/plans/ in this repo (task 9 syncs the corrected copies; if its commit is missing, the scratchpad copies are gone and docs/plans may predate the M1 pre-flight fixes listed in m1-rulings.md).
- Briefs: extract with `python3 brief.py <plan> <N> <out>` (respects nested fences); globals = plan text before "### Task 1:".
- M1: pre-flight done (preflight-m1.md); rulings in m1-rulings.md, already applied to the plan text. When M1 starts, create its ledger with `sdd-workspace docs/plans/2026-10-12-kern-m1-plan.md`, paste m1-rulings.md into it, and carry F9 (trim kernel Precedence to <=420 and Autonomy to <=650 chars) in the Task 6 dispatch.
- M1 Task 1 needs the user: they type six commands in a second terminal (see the task).
- M2: pre-flight result in preflight-m2.md if present; rule on its findings before M2 Task 1.
- Environment: PATH="$HOME/.volta/bin:$HOME/.local/bin:$PATH" (Volta node 22; bats 1.14.0 and shellcheck 0.11.0 in ~/.local/bin; Homebrew fails on macOS 27).
- User approvals on 2026-10-12: tools installed; private repo MustaMohamed/kern created; push main at the end of M0, M1 and M2.
- M2 pre-flight (preflight-m2.md, 93 rows, 23 findings, none applied yet). High: F1 help-map rows lack backticks (rule 6 fails); F2 rule 6 wants `1.` after `## Steps` but M2 skills start at `0. Defer` (regex should be `\d+\.`); F3 eight kernel rows grow the rendered kernel to about 4,549 chars, over the 4,000 budget and M1's session-start test: NEEDS A USER DECISION (raise the budget, or move rows out of the kernel); F4 G18 denies `2>&1` pipes because the splitter splits on `&`; F5 shellcheck warnings in G18; F6 recall negatives rank recall first. Medium: F7, F8, F9 (G18 allowlist lets uniq/sed w/git -c/grep -O write), F11. Low: F10, F12 to F23.
