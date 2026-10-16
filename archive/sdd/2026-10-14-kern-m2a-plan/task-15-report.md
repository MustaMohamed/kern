# Task 15 report: lint rules 5, 9, 16

Status: DONE_WITH_CONCERNS. Commit ab596a9 (base e815f09). Files: scripts/lib/lint-rules.mjs, tests/lint-rules.test.mjs, scripts/lint-exemptions.json.

RED: 12 of 40 tests failed before implementation, all as "actual [] vs expected [5|9|16]" (rules reported nothing).
GREEN: node --test tests/lint-rules.test.mjs -> tests 40, pass 40, fail 0.
Full suite: node --test 'tests/**/*.test.mjs' -> tests 90, pass 90, fail 0.
lint-skills on real tree: only skills/unslop/SKILL.md rule 9; exemption added; then "lint: clean".
ci-local: last line "ci-local: all steps passed".

Beyond the brief (each has a test that failed first): shared scanMarkdown helper (CRLF, ``` and ~~~ fences, unclosed fence reported as an error), exact H2 match for Steps / Red flags / output sections, strict Red flags table (header, separator row, 2 to 6 rows, only rows before the next H2), kernel and agent bodies scanned for rule 5, rule 16 scans agents and skill references, CRLF contract.

## Follow-up: rules 5 and 16 read fenced blocks
Ruling: fences are skipped only for heading structure (rule 9). Rules 5 and 16 now scan the whole CRLF-normalized body.
Tests changed: rule 5 "kernel and agents" test now expects [5] for a fenced Skill-tool reference and adds a fenced agent `${CLAUDE_PLUGIN_ROOT}/<missing>` case; rule 16 test now expects findings (WORK folder, ledger line) for fenced text and adds a fenced script with no contract row. Both tests failed on ab596a9 first, pass now.
Results: lint-rules 40/40, glob suite 90/90, lint-skills clean (no new findings from fenced references). ci-local not re-run (lint-rules.mjs changed only in rules 5 and 16 plus a comment).

## Fix round 1 (3 minors)
1. Fence parser pinned (3 tests, rule 9): mixed ``` / ~~~ close, 4-backtick fence holding a ``` line, 0-3 space opener vs 4 spaces. Mutation evidence: removing the marker-char check reddens test 41; removing the length check reddens 42; widening the indent to any reddens 43; narrowing it to 0 reddens 43. Parser unchanged.
2. Rule 16 script names read whole (up to whitespace, quote, bracket, `<>|`; trailing `.,;:` stripped). Tests: dotted listed passes, lib path flagged under full name, underscore name matched whole. Failed on 3cac4c5.
3. Rule 16 WORK subs read whole, any case (`WORK/spec-2/x` flagged when only `WORK/spec/` listed; `WORK/Plan` checked). `WORK/<sub>` placeholders still match nothing. Failed on 3cac4c5.
Results: lint-rules 45/45, glob suite 95/95, lint-skills clean on the real tree (no new findings).
