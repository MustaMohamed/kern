# Task 7 report: seeded-diff set

Status: DONE. Commit bd27295 "M2: add the seeded-diff set for review checks".

## Files
- evals/seeded-diffs/base/** (7 files), 20 x `<id>.diff`, labels.json
- scripts/seeded-diffs.mjs, tests/seeded-diffs.test.mjs
All verbatim from the brief. Diffs generated once by the brief's script (not committed).

## Seeded-diffs result (current floor-scan and claim-check)
seeded-diffs: 0 missed, 0 false alarms on 20 diffs. Recall 1/1 or n/n in all 9 classes (silenced-checker 2/2, bar-lowered 3/3).
No decoy flagged, no seeded case missed; floor-scan widening did not change the brief's figures.
`--compare-addy`: addy hit 5 of 12 seeded (s01, s02, s03, s04, s06) and 4 of 8 decoys (d01, d02, d03, d06). Matches the brief.

## Tests
- node --test tests/**/*.test.mjs: 74 pass, 0 fail
- lint-skills: clean
- tests/run-bats tests/scripts: 0 not ok (114 tests)
- ci-local: `hook-shape: 8 cases passed` / `ci-local: all steps passed`

## TDD
Before the script existed: `Cannot find module '.../scripts/seeded-diffs.mjs'`, 1 pass 1 fail. After: 2 pass.

## Self-review
Nothing beyond the brief. Worktree clean after commit, no push, no trailers.

## Concerns
None.
