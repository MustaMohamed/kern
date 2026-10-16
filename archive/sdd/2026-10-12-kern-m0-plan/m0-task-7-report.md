# Task 7 report: routing evals (tier 1)

Status: DONE_WITH_CONCERNS (typo-level plan fix only). Commit 1581167 "M0: add tier 1 routing evals with distractors and a rank-1 floor".

## TDD
RED: `node --test tests/route-eval.test.mjs` -> `ERR_MODULE_NOT_FOUND: Cannot find module .../scripts/lib/rank.mjs` (# pass 0, # fail 1).
GREEN: after rank.mjs, route-eval.mjs and data: `# pass 6`, `# fail 0`. Full `node --test tests/*.test.mjs`: pass 34, fail 0. `lint-skills`: clean.

## Port checks
- `grep -c 'export function' scripts/lib/rank.mjs` -> 7.
- tokenize('conflicts branching') -> `[ 'conflict', 'branch' ]`.
- diff of upstream lines 62-102 and 121-139 against rank.mjs: only the 4 `function` -> `export function` changes (tokenize, termFreq, vec, cosine).

## Real run
```
rank-1 rate: 100% (baseline 0%)
route-eval: passed
```
baseline.json untouched: `{ "min_rank1": 0 }`. `--update-baseline` not run.

## Distractor descriptions (source: .upstream/superpowers/skills/<name>/SKILL.md line 3)
- writing-plans: unchanged, matches brief.
- systematic-debugging: unchanged, matches brief.
- brainstorming: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior" (first sentence, verbatim, quotes dropped). Differs from the brief's shortened text.
- verification-before-completion: "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs" (first clause, verbatim; matches brief).
NOTICE got the three map lines.

## Files changed
scripts/lib/rank.mjs, scripts/route-eval.mjs, evals/cases/hello.json, evals/distractors.json, evals/baseline.json, evals/fixtures/hello/README.md, tests/route-eval.test.mjs, NOTICE.

## Deviations / concerns
- Brief's test file had a stray 2-line fragment after the "a distractor that outranks the skill" test (`assert.ok(... /positive prompt ranked/ ...));` then `});`), a syntax error. Removed those two lines; no test bent. Plan text should drop them.
- route-eval.mjs is not executable (matches other scripts).

## Fix round 1
Added 5 tests to tests/route-eval.test.mjs (collision, overlap, negative ranked #1, owner must outrank, unknown owner). All pass; no bug found in route-eval.mjs, so it is unchanged.
Overlap pair: "Use when greeting kern hello version" vs "... hello installed", similarity 0.62 (warn 0.5, error 0.75). Note: identical descriptions score 1 only with names under 3 chars ('a','b'); longer names add name tokens and lower it.
Results: route-eval tests 11/11; full suite 39 pass 0 fail; `node scripts/route-eval.mjs` passed, rank-1 100%.
