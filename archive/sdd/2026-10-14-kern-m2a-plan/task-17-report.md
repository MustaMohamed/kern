# Task 17 report: implement

Status: DONE. RED: 3 fail (SKILL.md missing). GREEN: implement test 3 pass; full suite 102 pass; lint clean; route-eval passed (rank-1 66%); plugin validate passed; Step 4 and 5 Checks silent; no dashes or curly quotes.

Deviations from the brief:
1. Step 5 now records the tree with `wt-snap <wt>` before the first production edit (contract row exists). Brief's step 8 used `<change.patch>` and tree-before without saying how they are produced.
2. Step 8 now names `wt-diff <wt> <tree-before>` as the patch producer (like prove-it step 4), and says a mutation survivor means a stronger test and exit 3 is inconclusive, not a pass.
3. Step 2: says when both kern-get and kern-detect exit 3, ask the user (brief said "unresolvable"); "never guess a command" kept.
4. Step 8 split into sentences; the `probe: fail-then-pass ok` expectation kept.
5. Outputs: mentions wt-diff writing WORK/reviews/ (brief said only "no commit"; WORK/reviews is in contract).
6. Map row inserted after the prove-it row inside the table, not appended after "Close calls".

## Fix round 1
Six minors fixed: `<wt>` defined and wt-snap once per change (step 1, 5); lint run in step 6; wt-diff exit 3 (empty diff, nothing to probe) and `<file>` relative to `<wt>` stated in step 8; "first operator on that line" in SKILL.md and test-design.md (probe tries a fixed operator order, so "first" means first it finds); slicing scope list regained comments and modernize-syntax; red flags row 4 now the surviving mutation, row 5 Reality says pause, name, ask; test asserts wt-snap, wt-diff, kern-get, kern-detect, `probe: mutation caught`, and `probe --mutate` in test-design.md. Removing each string on a scratch edit made the test fail (4 of 4 tried, restored, not committed). Suite 102 pass, lint clean, route-eval passed, Checks silent. Sizes: SKILL 4900, test-design 4007, slicing 1161.
