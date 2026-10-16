# Task 11 report: plan-check

Status: DONE. Commit 11ddef7 "M2: add plan-check".

## Implemented
- `scripts/plan-check`: the brief's script, plus hardening listed below.
- `tests/scripts/plan-check.bats`: the brief's 12 tests plus 5 added.

## Hardening beyond the brief
- CRLF: trailing \r stripped in the main awk, the spec: lookup awk and the acceptance awk (test 13).
- shared_services match is a whole word (`redistribute` does not match `redis`) (test 14).
- Spec with no numbered acceptance criteria, or `spec:` not a .md file: error, not silent pass (test 15).
- Unclosed frontmatter: error (test 16).
- `--graph` on a non-plan exits 2 instead of printing nothing with exit 0 (test 17).
- A backticked `none` in Consumes/Produces is not a name.

## Tests
- RED: before the script existed, 12 of 12 failed (exit 127). Brief's script passed 12/12; the 5 added tests failed 5/5 against it, then passed after the edits.
- 17/17 plan-check bats; `tests/run-bats tests/scripts` 0 failures; node --test 74 pass 0 fail; lint-skills clean; shellcheck -x -S warning clean.
- ci-local last lines: `hook-shape: 8 cases passed` / `ci-local: all steps passed`.

## Self-review
Not hardened (left as in brief): Run:/Expected: matched as substrings anywhere in a task; Acceptance numbers read from the one line only.

## Concerns
None blocking.

## Fix round 1
Tests 18-25 added first. RED against commit 11ddef7: 18, 19, 20, 21, 22, 23, 24 failed; 25 (backticked none) already passed, it only adds the missing test. After the fix: 25/25 pass, shellcheck clean.
- Overlap: two Files paths overlap when equal or when one `/`-terminated directory is a prefix of the other (18, 19; `docs/` vs `doc.md` does not).
- Acceptance: only the leading comma-separated list of numbers and ranges counts; ranges expand; no leading list is `Task N: Acceptance names no criterion number`; a backwards range is an error (20, 21, 22).
- Unclosed fence: `fence not closed` at the opening line, exit 1 (23).
- `-` is now a boundary in service matching, so `redis-cli` uses `redis` (24).
