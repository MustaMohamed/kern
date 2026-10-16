# Claim checks

Three scripts run in seconds and catch what reviewers miss. Paste each command and its output into the report.

## floor-scan

`floor-scan <package>` lists moves that lower the bar: new suppressions and type escapes, skipped or focused tests, deleted test files, removed assertions, empty catch blocks and stubs, debug prints, and a lowered bar (a threshold or `ratchet.<metric>` value moved the loose way, strict typing or a lint rule off, a CI step removed or made non-blocking). Exit 1 means at least one hit; each hit is fixed or justified in the report.

## claim-check

`claim-check <wt> <package>` lists commit ids in added lines that the repo does not know, and added comments with absolute words (always, never, impossible, only caller). Each one gets evidence, a rewrite, or removal.

## probe

`probe --exclude-tests <wt> <package>.patch -- <test>` proves a guard test fails without its guard and passes with it, keeping the test files in the fork. `probe --mutate <file>:<line> <wt> -- <test>` inverts one condition on a throwaway fork and expects the test to fail. `probe: fail-then-pass ok` and `probe: mutation caught` are the only passes; `inconclusive` is reported as such.

## A skipped check is a failed check

A check that did not run, timed out, or ran on the wrong tree is reported as failed, with the reason.
