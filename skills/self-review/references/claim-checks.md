# Claim checks

Three scripts run in seconds and catch what reviewers miss. Paste each command and its output into the report.

## floor-scan

`floor-scan <package>` lists moves that lower the bar: new suppressions and type escapes, skipped or focused tests, deleted test files, removed assertions, empty catch blocks and stubs, debug prints, and a lowered bar (a threshold or `ratchet.<metric>` value moved the loose way, strict typing or a lint rule off, a CI step removed or made non-blocking). Exit 1 means hits: each is fixed or justified in the report. Exit 2 means the input is not a diff: a failed check.

## claim-check

`claim-check <wt> <package>` lists commit ids in added lines that the repo does not know, and added comments with absolute words (always, never, impossible, only caller). Exit 1 means hits: each gets evidence, a rewrite, or removal. Any other non-zero exit is a failed check.

## probe

`probe --exclude-tests <wt> <package>.patch -- <test>` shows a test fails with the branch's non-test changes reversed and passes with them, keeping the patch's test files. A proof of one guard alone stays with implement's per-slice probe. `probe --mutate <file>:<line> <wt> -- <test>` inverts the first operator on that line on a throwaway fork and expects the test to fail. `probe: fail-then-pass ok` and `probe: mutation caught` are the only passes. Exit 1 (the test did not fail, or the mutation survived) is a finding. Exit 3 is inconclusive and reported as such, never as a pass. Exit 2 is a usage error: a failed check.

## A skipped check is a failed check

A check that did not run, timed out, or ran on the wrong tree is reported as failed, with the reason.
