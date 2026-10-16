# Task 16 report
Status: DONE. Commit: see git log ("M2: add prove-it and remove the placeholder skill").
RED: tests/skills/prove-it.test.mjs 4 fail (missing skill, reference, hello still present). GREEN: 4 pass.
Full suite: 99 pass, 0 fail. lint: clean. route-eval: passed, rank-1 66% (baseline 0%). claude plugin validate: passed.
Deviations from brief: none. Interfaces checked against probe, wt-diff, kern-get and kern-detect headers and contract rows.
Other hello references (not fixed): hooks/lib/render.sh:98 skip list names `hello`; docs/plans and docs/research mention it historically.
Note: git rm emptied evals/cases, so the dir was recreated for prove-it.json.

## Fix round 1
1. Step 4 now runs wt-diff first to make the .patch.
2. Outputs line says wt-diff writes a package and .patch under WORK/reviews/ (listed in contract.md:173).
3. Step 1 says: both exit 3 means ask the user, label the claim guess.
4. Added negative "Explain what this test asserts about the exit code"; prove-it is not in its top 3 (distractors lead, 0.08).
5. render.sh:98 skip list drops hello. shellcheck ok; session-start.bats 18/18.
SKILL.md 3407 bytes (cap 3600). Suite 99/99, lint clean, route-eval passed 66%.
