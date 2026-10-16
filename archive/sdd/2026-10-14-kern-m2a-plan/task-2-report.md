# Task 2 report

Implemented scripts/wt-snap, scripts/wt-diff, tests/scripts/wt-snap-diff.bats exactly as in the brief (extracted verbatim, executable bit set).

## TDD
RED: tests/run-bats tests/scripts/wt-snap-diff.bats with scripts absent: 14 of 14 `not ok` (1..14), exit 127 command not found, as expected.
GREEN: same command after adding scripts: ok 1..14, no failures. shellcheck -x -S warning clean.
Full: tests/run-bats tests/scripts: 1..56, no `not ok`. node --test: pass 72, fail 0.

## Self-review
No deviations from the brief. Only the three named paths committed. No concerns.
