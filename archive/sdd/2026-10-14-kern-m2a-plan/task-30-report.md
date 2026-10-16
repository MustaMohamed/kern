Status: DONE. Fix round 1 committed as cecdaef; gates pass, 37 of 37 removal mutations killed.

# Task 30 report: routes.md, kernel rows, row evals, lint rules 6, 7 and 12

## SHAs
- BASE: 34b64b5
- Commit: 38835ff "M2: route the M2 skills through kernel/routes.md and evaluate the rows"
- Fix round 1: cecdaef "M2: route-eval and lint fail loudly on missing floors, held-out set or render"
- Branch: main, checked before the first edit and before the commit.

## Tests: failing, then passing

Step 2, `node --test tests/route-eval-rows.test.mjs tests/lint-rules.test.mjs` before any production edit:
```
# Error [ERR_MODULE_NOT_FOUND]: Cannot find module '.../scripts/lib/kernel-rows.mjs' imported from .../tests/route-eval-rows.test.mjs
not ok 2 - tests/route-eval-rows.test.mjs
not ok 46 - rule 6: rows in kernel/routes.md resolve, and the kernel must name the routed file   (expected: 'path', actual: 'slash')
not ok 47 - rule 7: the routed file has its own cap, and the standing cost has a combined budget  (actual [], expected [7])
not ok 48 - rule 12: auto skills and the rows of both kernel files need eval cases once evals/cases exists  (actual [], expected [12])
# tests 49  # pass 45  # fail 4
```

Step 6, after kernel-rows, route-eval and lint-rules, `node --test tests/route-eval-rows.test.mjs tests/lint-rules.test.mjs tests/route-eval.test.mjs`:
```
not ok 54 - the fixed floors and the frozen held-out set are pinned
  error: "ENOENT: no such file or directory, open '.../evals/floors.json'"
# tests 65  # pass 64  # fail 1
```
As the brief expects; Step 8 writes the file.

Model-graded negatives (the lead's ruling), red before the route-eval and rule 12 change:
```
not ok 51 - rule 12: a model-graded negative does not count toward the minimum of 2   (actual [], expected [12])
not ok 58 - a model-graded negative is skipped by the lexical check and listed in the output  (got: recall: ranked #1 for negative prompt "catch me up")
not ok 59 - a positive that carries the grader flag is an error   (errors: [])
not ok 60 - only lexically checked negatives count toward the minimum   (only the ranked-#1 error)
# pass 56  # fail 4
```
Then `# pass 71  # fail 0` for the three files.

Fail-then-pass probes for the checks I added beyond the brief: with each check deleted from the code, its test failed; restored, it passed.
- rule 7 no-settings exit check and rule 12 invalid-JSON check: `not ok 49`, `not ok 50`, `# pass 48 # fail 2`; restored `# pass 50 # fail 0`.
- unknown grader value: `not ok 10 - a negative with a grader other than model is an error`; restored `# pass 10 # fail 0`.

## Step 9 gates, in order, on the committed tree
- `node scripts/lint-skills.mjs`: `lint: clean`, exit 0.
- `node scripts/route-eval.mjs`: exit 0.
  ```
  model-graded, not checked here: prove-it: "Explain what fixed and passing mean in this commit message"
  model-graded, not checked here: prove-it: "What does a passing PR mean for subagent work"
  rank-1 rate: 88% (baseline 0%, fixed floor 85%)
  held-out rank-1 rate: 36% (fixed floor 32%)
  route-eval: passed
  ```
- `node --test 'tests/**/*.test.mjs'`: `# tests 198 # pass 198 # fail 0`, exit 0.
- `tests/run-bats tests/hooks/session-start.bats`: `1..19`, 19 ok, 0 not ok, exit 0; `ok 2 the rendered kernel stays under 4,000 characters with no settings`.
- `node scripts/route-eval.mjs --update-baseline`: `baseline raised to 88%`. Rerun: `rank-1 rate: 88% (baseline 88%, fixed floor 85%)`, `route-eval: passed`.

## Measured numbers
Measured as lint rule 7 measures (session-start in a temp git repo, root replaced by the 52-char installed path), by a scratch script that copies rule 7's steps.

| Measure | Before this task (34b64b5) | After |
|---|---|---|
| Kernel, no settings | 3,352 | 3,496 |
| Kernel, longest fixture (long-settings) | 3,747 | 3,891 |
| kernel/routes.md | none | 759 |
| Auto skill and agent descriptions | 945 | 945 |
| Standing cost (kernel with no settings + descriptions) | 4,297 | 4,441 (limit 4,800) |
| Rank-1, case positives | 83% (baseline 0) | 88% (32/36; floor 85) |
| Held-out rank-1 | none | 36% (9/25; floor 32) |
| evals/baseline.json | `{ "min_rank1": 0 }` | `{ "min_rank1": 88 }` |

Plan predictions were 3,487 / 3,926 / 759 / 4,432 / 88% / 36%. The lead's post-Task-29 figures (3,341 / 3,813) differ from my 3,352 / 3,747 before the edit because the settings summary prints the temp repo's path ("Main worktree: ..."), so the number moves with the temp directory's length. The kernel edit adds 144 chars in both settings states.

held-out sha256: `9b5cb8271f50835c162805b42066d90206bd46ffd7b0af280992b3d5af2a54c0`, as pinned. floors.json is `{ "rank1": 85, "heldout_rank1": 32 }`. Neither file was touched after it was written.

Case positives that miss rank 1 (all within the top 3):
- prove-it #2: "I think that fixes the null check, the tests should be passing now, right?" (systematic-debugging 0.130, prove-it 0.083). From before this task.
- row-execute-plan #2: "Run the plan we agreed on" (row-plan 0.404, row-execute-plan 0.376).
- row-plan #2: "Spec approved; we need a multi-step plan for the migration" (writing-plans 0.384, row-plan 0.354).
- row-plan #2: "Turn the agreed spec into ordered tasks" (writing-plans 0.191, row-plan 0.158).

Held-out hits (9): execute-plan "Go ahead and start on the plan...", implement "Change the retry count...", diagnose "npm test is red on main...", prove-it "Ok I think we're done here...", prove-it "The agent says the migration task passed...", self-review "Before I put this up for review...", recall "Back from vacation...", recall "What's the state of the floci work...", context "We're almost out of context...". Four misses score 0.000 for every target (no shared vocabulary): the SSO, --verbose, getUser rename and 500-on-empty-filter prompts.

## Model-graded negatives and the Task 16 prompts
Ranks with the committed tree (route-eval's ranker):

| Prompt | Case | Rank today |
|---|---|---|
| "Explain what fixed and passing mean in this commit message" | prove-it.json negative, `"grader": "model"` | #1 row-prove-it 0.202, #2 verification-before-completion 0.158, #3 row-technical-writing 0.118; prove-it's skill entry #5 at 0.107 |
| "What does a passing PR mean for subagent work" | prove-it.json negative, `"grader": "model"` (added) | #1 prove-it 0.143, #2 verification-before-completion 0.104, #3 recall 0.094, #4 row-prove-it 0.074 |
| "Explain what 'verified' means in this commit message" | not in any case file | #1 row-technical-writing 0.119, #2 recall 0.111, #3 prove-it 0.103, #4 row-prove-it 0.058 |

The first was a lexical negative before this task and started failing when the row arrived: the row shares fixed, pass and commit with it, and ownerOf() counts the row as prove-it. Per the ruling it stays as data for M2b's grader. The third no longer ranks prove-it first; it now ranks technical-writing first, which is also a wrong route for an explanatory question.

## Case prompts reworded
None. Every case positive ranked in its top 3 as written.

## Notes 4 to 6
- Note 4. `{ROOT}` is not replaced by render.sh; only `{VERSION}`, `{ROOT_PATH}`, `{MODE}` and `{AUTOPILOT}` are. The session-start output keeps `Read {ROOT}/kernel/routes.md` literally (line 16), and line 2 defines it with the absolute path: `kern at /Users/.../kern. Here and in kern files read by path, {ROOT} and ${CLAUDE_PLUGIN_ROOT} mean that path; {KERN} means {ROOT}/skills.` That is how M1's `Read {ROOT}/kernel/context.md` row already resolves. routes.md's own line says `{KERN} is {ROOT}/skills, as the kernel header says`, and the header's "in kern files read by path" clause covers a file the model reads with Read, so both tokens resolve without a render pass.
- Note 5. The two auto skills' case files meet rule 12: prove-it.json has 3 positives, 2 lexical negatives (plus 2 model-graded) and 2 evals; recall.json has 3, 2 and 5. Every row of both files has a row-<route>.json with 3, 2 and 1. No cases added beyond the plan's.
- Note 6. No exemption added; scripts/lint-exemptions.json is unchanged. No skill needed an edit to pass rules 6, 7 or 12. prove-it and recall, routed from routes.md, already open with `## Steps`.

## Deviations
1. Model-graded negatives (the lead's ruling, outside the brief). route-eval skips a negative with `"grader": "model"` in the lexical and owner checks, lists each one on every run as `model-graded, not checked here: <owner>: "<prompt>"`, and counts only lexical negatives toward its minimum of 2. A positive with any `grader` key is an error. A negative with a grader other than `model` is an error, so a typo cannot drop a case silently. Rule 12 counts only lexical negatives. evals/cases/prove-it.json (edit authorized by the lead) marks one negative and adds one.
2. route-eval.mjs takes an optional root argument (the first argument not starting with `--`), as lint-skills.mjs does, so a test can run the CLI against a fixture and check the printed model-graded line. `--update-baseline` still works.
3. Rule 7 checks the exit of `git init` and of the second, no-settings session-start run (D6). Without that check, a failed second run measured 0 chars and the standing cost read low, as a pass. A failure there is reported once, and only when the first run succeeded, so the existing "fails or prints nothing" test still sees one error.
4. Rule 12 reports a case file that is not valid JSON. The brief's code skipped it, so lint read clean on a broken file.
5. Commit message: the brief's two paragraphs plus a third that explains the grader flag.
6. Tests added beyond the brief: rule 7 no-settings failure, rule 12 invalid JSON, rule 12 model-graded minimum, and four route-eval tests (skip and list, positive flag, minimum, unknown grader).

## ci-local
Run on 38835ff: `scripts/ci-local`, output in /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/ci-local-t30.log, exit 0.
```
# tests 198
# pass 198
# fail 0
lint: clean
route-eval: passed
hook-shape: 8 cases passed
ci-local: all steps passed
```
Not rerun for fix round 1: the lead's ruling skips it when no shell file changes, and none did.

## NOTICED BUT NOT TOUCHING
- rank.mjs's stemmer leaves "fixed" unstemmed (`t.length > suf.length + 3` is false for 5 chars), so "fix" and "fixed" do not cluster.
- The writing-plans distractor outranks row-plan on two plan positives and three held-out plan or execute-plan prompts. The row's words ("Agreed spec, more than one step") share little with "plan".
- Four held-out prompts share no vocabulary with any target (score 0.000). The lexical ranker cannot reach them by any row text short of keyword stuffing; M2b's model-graded routing is the measure.
- "Explain what 'verified' means in this commit message" now routes to row-technical-writing lexically. It is in no case file.
- Rule 7's subagent-start run does not check its exit status. A non-zero exit that still prints valid JSON passes. From before this task.
- The session-start bats size test and rule 7 do not normalize the temp repo path in "Main worktree:", so sizes move with the temp directory's length.
- kernelRows() matches `kernel/<name>.md` anywhere in the route cell, so a row reading `{ROOT}/kernel/routes.md` would parse as route "routes". Rule 6 rejects such a row, so no case file is demanded for it in practice.

## Fix round 1 (cecdaef)

The review (scratchpad/task-30-review.md) found 0 Critical, 6 Important and 6 Minor. The lead ruled on all of them, and every ruling is applied in one commit. Six files: scripts/route-eval.mjs, scripts/lib/lint-rules.mjs, scripts/lib/kernel-rows.mjs, tests/route-eval-rows.test.mjs, tests/lint-rules.test.mjs, evals/cases/row-self-review.json. heldout.json, floors.json and the row text are unchanged.

### Important
- I1. The CLI reads evals/baseline.json and evals/floors.json through one check. A missing file, invalid JSON, `{}`, `null`, or a missing, null, string or non-finite `min_rank1`, `rank1` or `heldout_rank1` prints `error: <message>` and `route-eval: FAILED`, and exits 1. Nothing goes to stderr. The fallback to `{ rank1: 0, heldout_rank1: null }` is gone, so both floors are always set.
- I2. `loadHeldout`: with a held-out floor set, a missing evals/heldout.json is an error. Invalid JSON, a non-array, an empty array, or an entry without string `owner` and `prompt` is always an error, with a message and no TypeError.
- I3. With a rank-1 floor set, no case positives is an error: `no case positives to rank, so the rank-1 floor cannot be checked`.
- I4. The CLI is tested against fixture roots. One test (rank-1 rate 92%, held-out 50%): floors 0/0 exit 0; fixed floor 95 exits 1; baseline 95 with floor 0 exits 1; held-out floor 60 exits 1. A second test drives 10 bad gate files, and each exits 1 with its message, an empty stderr and a final `route-eval: FAILED`. The review's three CLI survivors (`Math.max`, `minHeldout`, held-out unknown owner) are now killed. The unknown owner has its own evaluate test.
- I5. A test pins `evaluate(ROOT).modelGraded` to exactly the two prove-it entries, as owner and prompt. loadCases sorts file names, so the list order holds across file systems. Lint rule 12 now also rejects a positive that carries `grader`.
- I6. Rule 7 counts a render only when it exits 0 and has a line starting `kern at <root>. ` (the header that defines {ROOT}). Otherwise the first run reports `exited N with M chars of output[ and no "kern at <root>." header line], so the kernel was not measured`. A failed no-settings run reports `... with no project settings, so the standing cost was not measured`. A "kern did not load" line, which exits 0, is now an error. Test stand-in hooks print the header with builtins only (`${0%/hooks/*}`).

### Minor
- Rule 7 errors when tests/fixtures/projects/long-settings has neither kern.local.yml nor kern.yml.
- One parser. `parseRow(line)` in kernel-rows.mjs returns null for a non-row, `{ error }` for a row in another form (escaped pipe, three cells, backticks, trailing text) or one that routes to kernel/routes.md, else `{ when, base, path, route }`. Rule 6, `kernelRows`, `routedSkills` and so route-eval and rule 12 all read rows through it. A row rule 6 rejects is never a row for evals or tiers. Rule 6's messages are unchanged.
- `ownerOf` lives inside `evaluate` and folds only targets of kind `row`. A distractor named `row-a` no longer counts as a hit, or as a negative failure, for `a`.
- `routed` (the path tier) comes from `routedSkills`, which reads table rows only. A `Read {KERN}/d/SKILL.md` in prose leaves `d` a slash skill.
- row-self-review.json: "Ends with one verdict: split, fix first, rebase first or ready", the order skills/self-review/SKILL.md step 9 tests them in.
- New tests for the review's surviving mutations: rule 7 `git init` (PATH holding only bash), rule 6 "routes.md is not routed by a row" (asserts the message), rule 12 invalid JSON (asserts the message).

### Tests, failing then passing
Red, before the code change, on the three test files:
```
not ok 52 - rule 7: a render without the kernel header line is an error, not a low standing cost
not ok 53 - rule 7: a missing long-settings fixture is an error
not ok 56 - rule 12: a positive that carries the grader flag is an error
not ok 57 - tiers: a Read in prose, not in a row, does not make a path skill
not ok 68 - kernelRows takes only the rows rule 6 accepts
not ok 69 - only a kernel row folds into the skill it routes to; a distractor named row-<x> does not
not ok 71 - a missing, empty or malformed held-out set is an error once a floor is set
not ok 72 - no case positives under a rank-1 floor is an error
not ok 75 - the CLI fails with a message, never a default, when a gate file is missing or malformed
# tests 86  # pass 77  # fail 9
```
Test 75's first real failure: `evals/floors.json is missing: rank-1 rate: 92% (baseline 0%, fixed floor 0%) ... route-eval: passed`, exit 0, the fallback I1 describes. Five new tests passed before the change, because they cover code that already existed (git init, rule 6 routes.md row, held-out unknown owner, the model-graded pin, CLI floors). The mutation run below shows each one fails when its guard is removed.

After: `# tests 86 # pass 86 # fail 0` for the three files. One older test needed floors.json and heldout.json in its fixture now that the CLI requires them.

### Gates (on cecdaef's tree)
- `node scripts/lint-skills.mjs`: `lint: clean`, exit 0.
- `node scripts/route-eval.mjs`: exit 0. Two model-graded lines, `rank-1 rate: 88% (baseline 88%, fixed floor 85%)`, `held-out rank-1 rate: 36% (fixed floor 32%)`, `route-eval: passed`. Same numbers as round 0.
- `node --test 'tests/**/*.test.mjs'`: `# tests 213 # pass 213 # fail 0`, exit 0.
- `tests/run-bats tests/hooks/session-start.bats`: 19 ok, 0 not ok, exit 0.

### Removal mutations
Script: /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t30/mut.mjs. Each mutation removes or disables one guard, runs the three test files, then restores the file. sha1 of the three source files was checked unchanged after each run.
- First run: 38 mutations, 35 killed, 3 survived.
  - Rule 7's exit-0 requirement survived: no test printed the header and then failed. Added: a header followed by `exit 3` is an error.
  - Rule 5's routes.md scan survived: no test put a Skill reference in routes.md. Added.
  - `!r.error` in routeRows survived as an equivalent mutant: an `{ error }` object has no `route`, so the `r.route` filter already drops it. Removed the redundant clause, with a comment.
- Second run: 37 mutations, 37 killed, 0 survived. They cover:
  - CLI: floors missing, finite check, setup exit, `Math.max` either way, `minHeldout` wiring.
  - Held-out: missing, invalid JSON, non-array, entry shape, unknown owner.
  - evaluate: empty corpus, ownerOf by kind, positive grader, unknown grader, model-graded skip, lexical-only minimum, CLI model-graded print.
  - Rule 7: fixture, header, exit, both not-rendered errors, git init, routes.md cap, standing cost.
  - Rule 6: kernel names routes.md, reads routes.md.
  - Rule 12: flagged positive, invalid JSON, lexical-only minimum, rows of routes.md.
  - Path tier: from routes.md, from rows only.
  - Rule 5: routes.md scan.
  - parseRow: routes.md error, bare-form error.

### Deviations in this round
- loadCases sorts case file names, so the model-graded list and error order do not depend on readdir order. The ruling didn't ask for it; the pin test needs it.
- I did not cap model-graded negatives per case file (the review's optional idea). The ruling asked only for the pin.
- route-eval's unknown-grader check has no twin in lint rule 12. The ruling asked rule 12 for the positive flag only.
