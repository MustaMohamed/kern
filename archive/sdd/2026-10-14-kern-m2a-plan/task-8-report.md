# Task 8 report

## Implemented
scripts/ledger-open, scripts/task-brief, scripts/task-start, tests/scripts/ledger.bats (all from the brief). Brief code used verbatim except two hardening edits in ledger-open:
1. `state=$(main_state)` is assigned before the ledger is written. As a printf argument, a main_state failure would not stop the script and would write an empty `Main:` line (silent fallback, D6).
2. The `briefs/reports/reviews/logs` mkdir moved after the identity check, so a refusal for another plan's ledger writes nothing (brief: "nothing is written then").

## Tests
- tests/run-bats tests/scripts/ledger.bats: 9 ok, 0 not ok. Whole tests/scripts: 0 not ok.
- node --test 'tests/**/*.test.mjs': 74 pass, 0 fail. node scripts/lint-skills.mjs: clean.
- shellcheck -x -S warning: clean.

## TDD
RED: tests written first, scripts absent: 9 `not ok`, run exit 127 (command not found). GREEN: after scripts, 9 ok.
Manual: ledger-open outside a git repo exits 2 with "not a git repository" and writes no ledger.

## Self-review
No failure path falls back to allowed: unapproved plan, missing approved quote, foreign ledger, missing ledger/short tree id, no git repo all exit 2. `--summary` main_state failure exits via set -e.
Not covered by a test: the foreign-ledger "writes nothing" assertion and the no-git-repo case (checked by hand only).

## Concerns
None.

## Fix round 1
New tests 10-14 written first, run against the old code.
- Test 10 (unclosed frontmatter refused, nothing written): RED `not ok 10`; GREEN after awk `closed`/`opened` tracking and `frontmatter not closed` exit 2.
- Test 14 (corrupt .git/index so git status fails): RED `not ok 14`; GREEN after `st=$(git status --porcelain) || exit 2`, then hash.
- Test 11 (refusal writes nothing, fresh DIR for unapproved; foreign ledger pre-seeded with only ledger.md, no subdir appears) and 12/13 (no git repo; --summary outside a repo exits 2): already passed against the current code, because the earlier mkdir reorder and kern_main_root check covered them. They now guard those paths; they were not RED.
GREEN: ledger.bats 14 ok, 0 not ok; shellcheck -x -S warning clean; lint clean.

## Fix round 2
Test 15 (recorded `status=` hash equals `git status --porcelain | git hash-object --stdin` on a repo with one untracked file): RED `not ok 15` on the round-1 code; GREEN after hashing `printf '%s\n' "$st"` when `$st` is non-empty (nothing when empty). Round-1 failure handling (`|| exit 2` on a failing status) unchanged. ledger.bats 15 ok, 0 not ok; shellcheck clean.
