# Claim checks

Three scripts run in seconds and catch what reviewers miss. Paste each command and its output.

## floor-scan

`floor-scan <package>` lists moves that lower the bar: suppressions, type escapes, skipped, focused or deleted tests, removed assertions, empty catches, stubs, debug prints, and a loosened threshold, `ratchet.<metric>`, typing, lint rule or CI step. Exit 1 means hits: each is fixed or justified in the report. Exit 2 means the input is not a diff: a failed check.

## claim-check

`claim-check <wt> <package>` lists commit ids in added lines the repo does not know, and added comments with absolute words (always, never, impossible, only caller). Exit 1 means hits: each gets evidence, a rewrite, or removal. Any other non-zero exit is a failed check.

## probe

`probe --exclude-tests <wt> <package>.patch -- <test>` shows a guard test fails with the branch's non-test changes reversed and passes with them. One guard alone is implement's per-slice probe. `probe --mutate <file>:<line> <wt> -- <test>` inverts the first operator on that line in a throwaway fork; the test must fail. `probe: fail-then-pass ok` and `probe: mutation caught` are the only passes. Exit 1 (no failure, or the mutation survived) fails the check. Exit 2 is a usage error: a failed check. Exit 3 is inconclusive, never a pass, and fails the check, except when its reason is a module or export the patch adds or the patch holds test files only: report `probe inconclusive: new module`, and prove the new code with `--mutate` on its condition.

## A skipped check is a failed check

A check that did not run, timed out, or ran on the wrong tree is reported as failed, with the reason.
