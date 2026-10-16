# Task 30 re-review, fix round 1 (38835ff..cecdaef)

## 1. Status of round 0 findings

| Finding | Status | Where |
|---|---|---|
| I1 floors, baseline silently off | ADDRESSED | `route-eval.mjs:156-176` (`gateFile`: missing, invalid JSON and non-finite values are `error:` plus `route-eval: FAILED`, exit 1) |
| I2 held-out missing, empty or malformed | ADDRESSED | `route-eval.mjs:42-55` (`loadHeldout`); `heldout_rank1` required finite in `floors.json`, so held-out is always required in the real run |
| I3 empty corpus passes | ADDRESSED | `route-eval.mjs:134` |
| I4 CLI floor wiring untested | ADDRESSED | the new CLI tests in `tests/route-eval-rows.test.mjs` kill the `Math.max`, `minHeldout` and unknown-owner mutations |
| I5 model-graded list not pinned, flagged positive not rejected in lint | ADDRESSED | pin test (`route-eval-rows.test.mjs` test 16); lint rule 12 `lint-rules.mjs:427-428` |
| I6 one-line render read as a kernel | ADDRESSED | `lint-rules.mjs:241` (exit 0 and a `kern at <root>. ` header line) |
| Minor 1 missing long-settings fixture | ADDRESSED | `lint-rules.mjs:224-226` |
| Minor 2 weak tests | ADDRESSED | the `git init`, R6 routes-not-a-row and R12 invalid-JSON mutations are now killed |
| Minor 3 `kernelRows` vs rule 6 disagree | ADDRESSED | `kernel-rows.mjs:8-24`, one shared `parseRow` |
| Minor 4 `ownerOf` by name | ADDRESSED | `route-eval.mjs:60-62` (folds by kind) |
| Minor 5 `routed` from prose | ADDRESSED | `lint-rules.mjs:70` via `routedSkills` |
| Minor 6 verdict order | ADDRESSED | `evals/cases/row-self-review.json:36` |

## 2. Bad-input matrix (scratch copy of cecdaef, `scratchpad/t30/r2`)

Every case below exits 1 with an `error:` message and never prints `passed`, except the two noted under Minor 1.

- floors.json: missing; `{}`; null values; string values; `{"rank1":NaN}` (invalid JSON); `{"rank1":85}` (no held-out key). Each fails with a named message.
  - `{"rank1":150,...}` fails as a rate below the floor.
  - Negative values exit 0: see Minor 1.
- baseline.json: missing; `{}`; null; string. Each fails with a named message.
  - `-5` exits 0 (still bounded by the floor of 85): see Minor 1.
- heldout.json: missing; `{}`; `[]`; `[{"owner":"plan"}]`; `[null]`; invalid JSON. Each fails with a named message. An unknown owner gives `heldout: no owner "nope"`.
- Empty corpus: with floors set, `no case positives to rank, so the rank-1 floor cannot be checked`, exit 1.
- Failed render under lint rule 7:
  - `cannot load library`, exit 0: error.
  - Header text with exit 1: error.
  - Empty output: error.
  - A header that is not this root's: error.
  - No `long-settings` fixture: its own rule 7 error.

## 3. Grader values (item 3)

Tested on a recall negative with `grader` set to each value below.

| Value | Result |
|---|---|
| `"Model"`, `"modle"`, `""`, `true`, `null`, `0` | `unknown grader` error, exit 1; the negative also stays in the lexical check (`route-eval.mjs:101-102`: error, then no `continue`) |
| `"model"` | skipped lexically and listed on every run |

Nothing is skipped silently. With `"model"` set on a recall negative the run also failed on minimums (`3/1/5`), which confirms the minimum excludes flagged negatives.

Lint rule 12 does not report unknown grader values; route-eval does, and both run in CI. That is fine.

## 4. Pin (item 4)

- A third flagged negative (an extra prompt added to recall.json) fails `the model-graded negatives are pinned: flagging one more means editing this list`. The CLI still exits 0, so the pin is the only gate, as intended.
- Flagging an existing lexical negative (row-define) also fails the pin test.
- A positive with `grader` fails lint rule 12: `has 1 positive prompt(s) with "grader"`.

## 5. Shared `parseRow` (item 5)

Checked on a set of lines in `parseRow`, with routing through `kernelRows` and `routedSkills`:

| Line | Result |
|---|---|
| header row, `|---|---|` | `null` (not a row) |
| escaped pipe `Bug \| crash` | `error`; no route |
| three cells `a \| b \| Read ...` | `error`; no route |
| prose line `See Read {KERN}/define/SKILL.md` | `null`; not in `routedSkills` |
| two Reads in one cell | `error` |
| `{ROOT}/kernel/routes.md` row | `error` (named in the Routing rule) |
| `Define` (uppercase) | `route: null`; rule 6 then reports it does not exist |
| a real row with trailing spaces | parsed |

- Rule 6 now reads `parseRow`, `kernelRows` reads the same function, and the path tier reads `routedSkills` over `routeRows`. All three share one definition of a row.
- No existing row changes meaning: `kernel.md` and `routes.md` are byte-identical to 38835ff, and the route list is unchanged (`technical-writing, context, define, plan, execute-plan, implement, diagnose, prove-it, self-review, recall`). No skill changed tier (lint clean).

## 6. Mutations (item 6)

18 removal mutations, 17 killed.

Round 0 survivors, all now killed:
- R6 routes-not-a-row (now in `parseRow`)
- R7 `git init`
- R12 invalid-JSON
- `Math.max(baseline, floors)`
- `minHeldout`
- heldout unknown owner

Also killed:
- the finite check
- the `process.exit(1)` on setup errors
- the no-positives guard
- the heldout array guard
- the heldout entry guard
- `ownerOf` by kind
- the R7 header check
- the R7 fixture check
- the R12 flagged positive
- `routed` via `routedSkills`
- the unknown grader error

One survivor: removing `.sort()` in `loadCases` (`route-eval.mjs:34`) survives. It is the declared deviation and is untested. Minor 2.

## 7. New findings

No Critical or Important findings.

Minor:
1. **Floor values are not range-checked** (`route-eval.mjs:163`, `Number.isFinite` only). `floors.json` with `rank1: -5` or `heldout_rank1: -1` runs `passed`; it is a disabled floor, though still an explicit file the pin test would catch. Fix: require 0 to 100.
2. **`.sort()` in `loadCases` has no test.** Cheap to add a test that fixtures with a name-order-sensitive failure list errors in sorted order.
3. The header check can be satisfied by a stub that prints `kern at <root>. ` and exits 0 (accepted: the check says it must carry the header, not that the body is right). The standing-cost and 4,000 checks still apply to its length. No action.

Stop rule: this round authored no defect in round 0's code. Round 0's code was changed only to harden it (`gateFile`, `loadHeldout`, `parseRow`, `ownerOf`), and the survivors it exposed are all killed.

## 8. Gates

- `node scripts/lint-skills.mjs`: `lint: clean`
- `node scripts/route-eval.mjs`: rank-1 88% (baseline 88, floor 85), held-out 36% (floor 32), `route-eval: passed`; the 2 model-graded negatives are listed
- `node --test 'tests/**/*.test.mjs'`: 213 tests, pass 213, fail 0
- `tests/run-bats tests/hooks/session-start.bats`: 19 ok, 0 not ok

Verdict: APPROVED
