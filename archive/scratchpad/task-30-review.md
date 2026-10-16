# Task 30 review (38835ff, base 34b64b5)

Spec verdict: compliant with the brief. Every file the brief names exists and matches it, and heldout.json is byte-identical to the brief's text (sha256 9b5cb82...). The D6 gaps below are in the plan's own design, which the implementer copied faithfully.

Quality verdict: needs-fixes. There are no Criticals, but the floors can be switched off silently, which is the main thing the floors exist to prevent.

Line numbers refer to `scripts/route-eval.mjs` and `scripts/lib/lint-rules.mjs` at 38835ff.

## Critical
None.

## Important

1. **A missing or malformed floors.json silently disables the floors** (`route-eval.mjs:136-139`, D6).
   - Scenario: delete `evals/floors.json`. The CLI falls back to `{ rank1: 0, heldout_rank1: null }` and prints `fixed floor 0%` and `route-eval: passed` (exit 0).
   - `{}` and `{"rank1":null,"heldout_rank1":null}` also pass: `Math.max(88, undefined)` is NaN, and `NaN` comparisons are false, so no floor applies. `baseline.json` as `{}` does the same, leaving only the 85 floor.
   - The pin test only reads the file when tests run, and it cannot see the CLI fallback.
   - Fix: when `floors.json` is absent, throw. Require `Number.isFinite` on `rank1` and on `heldout_rank1` (when held-out prompts exist), and on `baseline.min_rank1`; error if not.

2. **A missing or empty held-out set skips the held-out gate silently** (`route-eval.mjs:116-128`, D6).
   - Scenario: `rm evals/heldout.json`, or write `[]`. The output has no held-out line and says `passed`.
   - Fix: if `floors.heldout_rank1` is set, a missing or empty held-out file is an error.
   - Related, same line: a held-out file that is a JSON object (`{}`) crashes with a TypeError stack. It fails, but with a bad message. Check `Array.isArray`.

3. **An empty corpus passes under floors** (`route-eval.mjs:112`, `evaluate`).
   - Scenario: a repo with no skills and no cases gives `rank-1 rate: n/a%`, `fixed floor 85%`, `route-eval: passed`.
   - Cause: `rank1Rate` is null and the `< minRank1` check is skipped.
   - Fix: when `minRank1` is a number and `positives === 0`, error.

4. **The floor wiring in the CLI has no test.** Removal mutations on `Math.max(baseline.min_rank1, floors.rank1)` and on `minHeldout: floors.heldout_rank1` both survive all 198 tests.
   - A heldout `no owner` error also survives.
   - The pin test checks the values in the files, not that the CLI enforces them.
   - Fix: a spawned-CLI test in `route-eval-rows.test.mjs`.
     - A fixture with `baseline {min_rank1:0}`, `floors {rank1:100}` and a 50% rate must exit 1.
     - A fixture with a missing `floors.json` must exit 1 once finding 1 is fixed.

5. **The `grader: "model"` flag is visible on every run but not bounded or pinned** (`route-eval.mjs:31-32`, `:84-85`; `lint-rules.mjs:418`).
   - Positives with the flag are rejected, by route-eval only; lint rule 12 does not reject them (checked: lint says clean). Rule 12 does exclude flagged negatives from its minimum, and route-eval does too, so a file whose negatives are all flagged fails both (verified: `3 positive, 0 negative`).
   - The hole is that a flag hides any lexical miss, and nothing checks it:
     - there is no cap on how many negatives a skill may flag;
     - no test pins the current list (2 prove-it entries);
     - the CLI exits 0 whatever the count is.
   - Scenario: a future change flags a failing negative to turn the run green. The only trace is two extra output lines.
   - Fix: pin the model-graded list in a test, as heldout.json is pinned (array of owner and prompt, compare exactly), so adding a flag means editing a test the reviewer sees. Optionally also cap the number per case file at 1 in route-eval.
   - A good minimum fix is the pin.

6. **Rule 7 treats a one-line broken render as a low standing cost** (`lint-rules.mjs:~232-250`, D6).
   - Scenario: `hooks/session-start` prints `kern: cannot load library` and exits 0 (a legitimate state, see bats test 16). Lint says `clean`: the output is non-empty, so `ran()` is true, and 25 chars is a tiny cost.
   - Fix: also require the render to contain `## Routing`, or at least 1,500 chars, before reading it as the kernel.

## Minor

1. **Rule 7 does not report a missing `long-settings` fixture** (`lint-rules.mjs:~228`). Without it the "longest settings" render is measured with default settings, so the 4,000 warning understates. Rule 15 catches it today, by luck. Fix: error in rule 7 if the fixture dir is absent.
2. **Weak test assertions.**
   - The rule 7 `git init` check survives mutation. Test: PATH without git.
   - The rule 6 `routes.md is not routed by a row` branch survives.
   - The rule 12 invalid-JSON branch survives: the fallthrough also yields rule 12 via the count, with a worse message. Assert the message.
3. **`kernelRows` accepts rows that rule 6 rejects.**
   - An escaped pipe gives `when` = `Bug \`.
   - A three-cell row `| a | b | Read ... |` gives `when` = `a`.
   - Both are caught by rule 6 (verified), so there is no escape, but the two parsers disagree. Rule 12 will demand `row-x.json` for a row rule 6 already rejects.
4. **`ownerOf` folds by name only** (`route-eval.mjs:31`). A skill or distractor literally named `row-x` folds into `x`. A distractor named `row-plan` ranking first would count as a plan hit. Fold only when `kind === 'row'`. Real rows are folded correctly.
5. **`routed` in `loadModel` matches `Read {KERN}/x/SKILL.md` anywhere in the kernel or routes text, not just in table rows.** A prose line in `routes.md` (verified) makes a skill a `path` tier skill with no row, so no case is required. Same pre-existing pattern as `kernel.md`; the task widened it to a second file. Fix: derive `routed` from `kernelRows`.
6. **The `row-self-review` expectation lists verdicts as "ready, fix first, rebase first or split".** The skill tests them in the order `split`, `fix first`, `rebase first`, else `ready`. Set membership is right and the order only matters if graded as a sequence; reorder the text to match.

## Checks with no finding

- **Rule 6.**
  - A routes.md row naming a missing skill errors (`route skills/ghost/SKILL.md does not exist`).
  - A kernel that does not name `{ROOT}/kernel/routes.md` errors.
  - Pipe and extra-cell rows error.
- **Rule 12.**
  - Every existing auto skill and row passes with no exemptions (lint clean on the tree).
  - A new auto skill with no case file errors (rule 12, plus rule 6 for the map).
  - A model-graded negative does not count toward the minimum, in lint or route-eval.
- **Header and routes.md.**
  - The kernel header defines `{ROOT}` ("kern at {ROOT_PATH}. ... {ROOT} ... mean that path"), so the Routing sentence resolves.
  - The kernel renders under 4,000 with the longest settings, as lint shows no rule 7 warning. Rule 7 itself has an error cap of 9,000 and a standing cost limit of 4,800.
- **Pin and floors.**
  - The sha pin is real: changing one byte of heldout.json fails the pin test.
  - Changing floors.json to `{50,10}` fails it too.
  - Baseline 88 matches the measured 88%. A baseline of 95 fails the run. Lowering the baseline to 0 still leaves the pinned floor of 85.
- **D6 cases that fail correctly.**
  - A malformed or missing case file: exit 1.
  - No cases directory: exit 1.
  - No routes.md: exit 1.
  - A malformed heldout.json or floors.json: exits with a stack trace (nonzero).
  - Rule 7 on a failing render (exit 3), on an empty render, and on git init failing (PATH without git): each errors.
  - Rule 12 invalid JSON: errors.
- **Case files.**
  - No negative equals another row's positive (30 positives, 15 distinct negatives checked).
  - The positives use the rows' words.
  - The prove-it handoff (commit and finish-branch), the self-review gates (floor-scan, claim-check) and recall's behaviour all match the skills as they stand.

## Commands run (all in /Users/musta/Code/projects/kern, `main` at 38835ff, or in scratch copies under /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t30/)

- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: rank-1 88% (baseline 88, floor 85), held-out 36% (floor 32), `route-eval: passed`; the 2 model-graded negatives are listed.
- `node --test 'tests/**/*.test.mjs'`: 198 tests, pass 198, fail 0.
- `tests/run-bats tests/hooks/session-start.bats`: 19 ok (including the under-4,000 test).
- Scratch bad-input matrix (route-eval): missing floors, `{}`, null floors, missing heldout, `[]` heldout, `{}` baseline each exit 0 and print `passed`. A malformed case file, no cases directory and no routes.md exit 1. An empty corpus with floor 85 exits 0.
- Scratch bad-input matrix (lint): the cases are listed above under Checks with no finding. A `cannot load library` one-liner from session-start gives `lint: clean`.
- Removal mutations (27, script at scratchpad/t30/mut.py), run against the lint, route-eval and rows tests. 21 killed (counting the rerun), 6 survived: R6 `routes.md not routed by row`, R7 `git init`, R12 `invalid json` (equivalent outcome), RE `Math.max(floors)`, RE `heldout floor`, and RE `heldout unknown owner`. (The last three are CLI wiring, so Important 4.) One mutation string did not match first time and was re-run: the R12 routes-source mutation is killed.
