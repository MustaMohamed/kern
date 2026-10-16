# Task 6 report

Implemented scripts/claim-check, scripts/probe, tests/scripts/claim-probe.bats verbatim from the brief. Commit: "M2: add claim-check (G9) and probe (G10)".

## Tests
- macOS bash 3.2: claim-probe.bats 14/14; `tests/run-bats tests/scripts` 110 ok, 0 not ok; node --test 72 pass 0 fail; lint-skills clean; shellcheck -x -S warning clean.
- Ubuntu kern-ci:task17 (mount /kern-repo): claim-probe.bats 14/14.

## TDD
- RED: scripts moved away, bats run: 14 not ok (scripts missing).
- RED for test 11 (the pre-flight false-pass case): probe with the path-existence loop removed fails test 11 at the exact-message assertion (line 113). Status was still 3 there, because the "No such file or directory" blocked-pattern catches the missing runner.sh; the loop gives the precise reason and also covers commands whose failure text is not in the pattern.
- GREEN: restored probe, 14/14.
- Caveat: scripts were first written, then RED shown by removal, not written after a failing run.

## Self-review
No leaked probe forks (worktree list clean). No files changed beyond the brief. wt-fork and test-paths.awk untouched.

## Concerns
None.

## Fix round 1
Tests 15-18 added first; RED against the old probe: 15, 16, 17, 18 all `not ok` (status was not 3: ok/exit 128).
Changes in scripts/probe: positive control (CMD run in the fork before reverse or mutate; exit 3 with the ruled message, detail tail to stderr so stdout is the one line); numstat pipeline split so an unreadable patch gives `probe: inconclusive (cannot read the patch)`; blocked list gained `command not found`, `: not found`, `Permission denied`, `ENOENT`.
GREEN: 18/18 on macOS and in kern-ci:task17; shellcheck clean; no probe-* worktree left.
Test 18 checks both a status 1 exit and the new status 3 exit.
