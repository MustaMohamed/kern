# Task 4 report: wt-audit

Status: DONE

## Implemented
- scripts/wt-audit (mode +x), tests/scripts/wt-audit.bats; both verbatim from the brief.

## Tests
- macOS (bash 3.2 via tests/run-bats): wt-audit.bats 7/7 ok; tests/scripts 74 ok, 0 not ok; node --test 72 pass, 0 fail.
- Ubuntu (Docker kern-ci:task17, repo mounted at /kern-repo, safe.directory set): 7/7 ok.
- shellcheck -x -S warning scripts/wt-audit: clean.

## TDD
- RED: before the script existed, every test ran `bash .../scripts/wt-audit` and got exit 127 (command not found).
- GREEN: after the script, `1..7` with 7 `ok`.

## Self-review
- Diff matches the brief; --no-optional-locks, find -print -quit and the --days 0 skip kept as written. No extra files. No CHANGELOG line (task touches no skills/agents/kernel/hooks).

## Concerns
None.

## Fix round 1
Changes: scripts/wt-audit gains bucket `unknown` (git status failed, rev-list failed, no base ref; evidence names which; gh buckets still take precedence). A failed `log` adds "last commit unknown" and is never idle. Header comment updated. Tests: test 3 PATH now a temp dir of symlinks (no gh reachable); main-checkout assertion compares `pwd -P` of REPO; new tests 8 (corrupt index -> "git status failed") and 9 (origin/main ref deleted -> "no base ref").
RED (new script change stashed): `not ok 8`, `not ok 9`, 1-7 ok.
GREEN: `tests/run-bats tests/scripts/wt-audit.bats` 9/9 ok on macOS; tests/scripts 0 not ok; Docker kern-ci:task17 9/9 ok; shellcheck -x -S warning clean.
Commit: M2: wt-audit reports unknown when a git call fails.
