# M2 plan vs goal 0: consolidated (2026-10-14)

Three read-only opus reviewers. Reports: define-execute.md, build-verify.md, ship-evals.md.

Verdict: the M2 plan as written does not meet goal 0. Every M2 category is BELOW its strongest source; only the infrastructure (worktree scripts, snapshots, forks, agents, floor-scan once U2 lands) MEETS or EXCEEDS.

| Category | Verdict |
|---|---|
| define, plan, execute-plan | BELOW |
| parallel-work, recall | BELOW (small) |
| implement, diagnose, self-review | BELOW |
| prove-it | BELOW (EXCEEDS once the probe false pass is fixed) |
| commit, finish-branch | BELOW (skill text conflicts with G2/G5) |
| routing, adherence grader, CI/acceptance, pilot | BELOW |
| Tasks 1-4, 8 | MEETS; EXCEEDS on commit-free snapshots and forks |
| Task 5 floor-scan | MEETS with U2 |
| Task 7 G18 + investigator | BELOW (sort -o, file -C, Output writes files) |

Five patterns:
1 Gates in prose where code can enforce: approval quotes, the review stamp in task-done, RED in implement, out-of-Files edits, ledger identity, brief completeness, plan ordering and interfaces.
2 Silent drops from the research merge maps: red flags in define, defense-in-depth (already U7), redirection signals, forensics proof rules, where grep stops, doubt theater, Declined to judge, recall source lines, C11 acceptance.
3 Skill text vs kern's own guards: commit -F temp file and PR body file outside WORK, gh pr create without --title, finish-branch outside the worktree, dedup blocking follow-up pushes, investigator told to write files.
4 No comparison measurement: no head-to-head for planning, debugging or review in M2; no coverage re-audit step; no pilot protocol; no token measurement; routing evidence tuned to pass.
5 Eval validity: adherence runs on the user's config, a bare-name Skill call is a false pass, the probe passes when the patch deletes the test, results gitignored.

About 35 items after dedupe, beyond the decided pre-flight fixes and gaps 5-19.
