# Task 10 report: brief-check

Status: DONE

## Implemented
- scripts/brief-check (verbatim from brief, executable)
- tests/scripts/brief-check.bats (6 tests, verbatim from brief)

## Tests
- brief-check.bats: 6/6 pass. tests/run-bats tests/scripts: 157 ok, 0 not ok. node --test: 74 pass, 0 fail. lint-skills: clean. shellcheck -x -S warning: clean.

## TDD
- RED: before script existed, all 6 tests `not ok` (exit 127, command not found).
- GREEN: after script, 6/6 ok.

## Self-review
- Failure path: awk exit status is the script's last command, so awk failure is nonzero (no fallback to ok).
- Label matching uses index()==1 plus explicit [ \t:] list, no locale ranges.
- Continuation text is joined before the placeholder compare; a placeholder followed by extra indented lines would not be flagged (accepted, brief fixes the logic).
- Removed bats .bak files created by sed -i.bak before commit.

## Concerns
None.

## Fix round 1
- CRLF: strip trailing \r first in awk. RED: tests 8, 9 (test 7, a complete CRLF brief, already passed). GREEN after.
- VERIFY: first word (after optional bash) must have basename wt-check, with at least 2 args. RED: test 10 (wt-checkout, "echo wt-check", bare, one arg); test 11 (plugin-root, path, bare forms pass) green before and after. GREEN after.
- Placeholder: prefix match; test 12 loops all eight fields, bare and with " TODO". RED: test 12 (suffix case). GREEN after.
- brief-check.bats 12/12; shellcheck -x -S warning clean.
