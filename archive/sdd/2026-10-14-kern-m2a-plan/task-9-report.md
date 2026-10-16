# Task 9 report

Implemented scripts/task-review and scripts/task-done as in the brief, plus tests/scripts/task-done.bats (11 brief tests + 2 added).

TDD: bats run before the scripts existed gave 11 failures, status 127 "No such file or directory" for scripts/task-review / task-done (RED). After the scripts: 11/11 ok (GREEN).

Hardening beyond the brief (D6, each with a test): empty `--probe ""` refused (probe would have returned inconclusive and recorded it); failing wt-snap gives an explicit exit 2 message; unreadable or missing ledger refused; a malformed review line (extra suffix) refused as not approving.

Results: tests/run-bats tests/scripts 0 not ok; node --test 74 pass 0 fail; lint-skills clean; shellcheck -x -S warning clean.

Concerns: probe exit 3 (inconclusive) is recorded as probe=inconclusive per the brief, not refused.

## Fix round 1
RED before fix: test 12 (missing patch exit 0), 14 (multi-line TREE accepted), 15 (newline in REASON/CMD closed task) failed. Tests 16 (later needs-fixes overrides approval) and 17 (Task 1 vs Task 10) already passed, kept as covering tests.
Fix: TREE validated by case pattern (only 0-9a-f) plus length 40 or 64 in task-review and task-done; REASON and every CMD arg refused with exit 2 if holding LF or CR, before any write; --probe PATCH must be a non-empty readable file else exit 2.
GREEN: task-done.bats 17/17, tests/scripts 0 not ok, shellcheck clean.
Note: scripts/task-start:10 (Task 8) uses the same grep-based TREE idiom, not touched.

## Fix round 1b
task-start: same case-pattern TREE check (0-9a-f, 40 or 64). N was already digits-only; TREE is its only free-text argument. New ledger.bats test RED (multi-line TREE exit 0, ledger grew), GREEN after. ledger.bats and shellcheck clean.

## Fix round 2
RED (4 new tests failed before the fix): 18 UTF-8 tree ids (task-review accepted ...ÉÉ), 19 --probe directory, 20 CR in --minor, 21 CR kept in last=. Fix: explicit [!0123456789abcdef] in task-start/review/done; -f check on patch; CR refused in --minor; last= stripped of control chars via tr. GREEN: task-done.bats 21/21, ledger.bats pass, tests/scripts 0 not ok, shellcheck clean.
