# Task 5 report: floor-scan

Status: DONE. Commit: see `git log -1` (subject "M2: add floor-scan, the G7 check as a script").

Files: scripts/lib/test-paths.awk, scripts/lib/floor-scan.awk, scripts/floor-scan, tests/scripts/floor-scan.bats, kernel/settings.md (one row), CHANGELOG.md (one line). All text verbatim from the brief.

TDD
- RED: `tests/run-bats tests/scripts/floor-scan.bats` before implementation: every `run` exited 127 (script missing), all 17 failed.
- GREEN: after the three files were written, 17/17 ok on macOS (bash 3.2, BSD awk).
- Tests 11 and 12 already carry `[ "$status" -eq 0 ]` in the brief text, so they cannot pass before floor-scan exists.

Results
- macOS: floor-scan.bats 17/17; `tests/run-bats tests/scripts` 93 ok, 0 not ok; `node --test` 72 pass, 0 fail; lint-skills clean; shellcheck -x -S warning clean.
- Ubuntu (kern-ci:task17, mawk 1.3.4): floor-scan.bats 17/17.

Self-review: nothing beyond the brief; no existing file changed other than the two doc lines. test-paths.awk interface (`is_test`, `-v print_tests=1`) unchanged for Task 6.

Concerns: none. `-v print_tests=1` mode not exercised by a test in this task's bats file (the brief has none); Task 6 will use it.

## Fix round 1

Changes (scripts/lib/floor-scan.awk, tests/scripts/floor-scan.bats):
- assertion-removed also matches assert-prefixed names (assertX, assert_x, debug_assert!, self.assertX) and `require.<Upper>`; testify `assert.Equal` already matched via `assert` plus a non-letter. A JS `require('y')` has a lowercase next char and is not flagged. Pairing after norm() unchanged.
- thr() now returns every key:number match on a line (TK/TV/TN); flush() loops over all of them, pairing the k-th removed and k-th added value per key.

RED (before fix): `tests/run-bats tests/scripts/floor-scan.bats` gave `not ok 18` (four assertion styles) and `not ok 20` (one-line thresholds); 19 (require import not flagged) passed as a guard.
GREEN: 20/20 on macOS; 20/20 in kern-ci:task17 (mawk); `tests/run-bats tests/scripts` all ok, no not ok; shellcheck clean.
