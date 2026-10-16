# Task 5 report: skill lint

Status: DONE

Commit: 04b5606 "M0: add skill lint rules 1, 2, 3, 4, 8, 10 and 11"

## What was done
Transcribed the brief verbatim: tests first, then frontmatter.mjs, lint-rules.mjs, lint-skills.mjs, lint-exemptions.json (`[]`), lint-names.txt.

## TDD evidence
RED (before implementation): `node --test tests/lint-rules.test.mjs` failed with `ERR_MODULE_NOT_FOUND: Cannot find module '.../scripts/lib/frontmatter.mjs'`.

GREEN: 12 tests, 12 pass, 0 fail (CRLF, quotes/colons, block scalar, tiers, clean skill, rules 1, 2, 3, 4, 8, 10, 11).

## Real-repo lint
`node scripts/lint-skills.mjs` printed `lint: clean`, exit 0.

## Files changed
scripts/lib/frontmatter.mjs, scripts/lib/lint-rules.mjs, scripts/lint-skills.mjs, scripts/lint-exemptions.json, scripts/lint-names.txt, tests/lint-rules.test.mjs (all new).

## Deviations
None.

## Concerns
None. Working tree clean after commit; not pushed.

## Fix round 1
Changes (scripts/lib/lint-rules.mjs): rule 11 scans every non-binary file in `model.shipped` (binary ext list per ruling) plus README.md and CHANGELOG.md when present. Rule 4 local refs resolve against the skill dir then the repo root, and accept a `#anchor` suffix and leading `./` in backtick and link forms; fenced blocks still checked.
Tests added (tests/lint-rules.test.mjs): rule 11 non-.md under hooks/ is an error, .png skipped; rule 4 passing case, repo-root fallback, anchors and `./`, missing-with-anchor is one error. RED first: 2 new tests failed, 12 passed.
Command: `node --test tests/lint-rules.test.mjs && node scripts/lint-skills.mjs`
Output: tests 14, pass 14, fail 0; `lint: clean`.
Commit: see git log ("M0: widen lint rule 11 scope and fix rule 4 path resolution").
