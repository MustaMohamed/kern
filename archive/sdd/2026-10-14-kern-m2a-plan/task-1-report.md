# Task 1 report: wt-new and wt-check

## Implemented
Created verbatim from the brief: `scripts/lib/wt-common.sh`, `scripts/wt-new`, `scripts/wt-check`, `tests/helpers/wt.bash`, `tests/scripts/wt-new.bats` (16 tests). Scripts chmod +x. No changes to existing files.

## Tests
- `tests/run-bats tests/scripts/wt-new.bats`: 16 ok, 0 not ok.
- `tests/run-bats tests/scripts`: 1..42, no `not ok`.
- `node --test 'tests/**/*.test.mjs'`: pass 72, fail 0.
- `shellcheck -x -S warning` on the three scripts: clean.

## TDD evidence
- RED: `tests/run-bats tests/scripts/wt-new.bats` before the scripts existed: 16 `not ok` (scripts/wt-new and wt-check missing, so first `[ "$status" -eq 0 ]` fails). Expected.
- GREEN: same command after implementing: `1..16`, all `ok`.

## Self-review
Matches brief, nothing extra. Commit staged by named paths, no trailers, not pushed. No concerns. CHANGELOG not touched: brief does not list it and the files are outside skills/agents/kernel/hooks.

## Fix round 1
Added `export KERN_MAIN="$MAIN"` right after `MAIN=...` in `scripts/wt-check` (Global Constraint). No new test. `tests/run-bats tests/scripts/wt-new.bats`: 1..16, no `not ok`. `shellcheck -x -S warning scripts/wt-check`: clean. Committed as "M2: wt-check exports KERN_MAIN after setting MAIN".
