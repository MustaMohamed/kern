# Task 22 report: execute-plan

Status: DONE_WITH_CONCERNS. Commit d664a4b (base 9ed34e1), only the brief's Step 9 paths.

RED: the Step 1 test failed 3 of 3 (`skills/execute-plan/SKILL.md exists` for tests 1 and 2; test 3 on `ledger-format.md exists`).
GREEN: `node --test tests/skills/execute-plan.test.mjs` 6/6; full suite `node --test 'tests/**/*.test.mjs'` 126/126; `node scripts/lint-skills.mjs` prints `lint: clean`; `node scripts/route-eval.mjs` prints `route-eval: passed`; `claude plugin validate .` passed.
Sizes: SKILL.md 11,845 of 12,000 (cap raised from 10,000 by the lead's ruling, option a); ledger-format.md 2,595 of 2,600; model-selection.md 974 of 1,600.
Mutation: on a scratch copy, removing each of 118 pinned strings from its own step, bullet or section, and 3 order swaps (task-start before the Files list, task-review before the reviewer dispatch, `Applied:` before wt-apply), each failed the test: 121 mutations, 0 survivors.
ci-local: `scripts/ci-local` exit 0, last line `ci-local: all steps passed` (node 126/126, lint clean, versions agree, route-eval passed, both strict validates, bats scripts 1..208 and hooks 1..548 with no `not ok`, `hook-shape: 8 cases passed`, shellcheck clean).

## Dry walk

Scratch repo outside kern (bare origin plus a clone, node test runner), with an approved 2-task plan from plan-template.md (`approved: 2026-10-15, "yes, go with step"`, `execution: step`) and an approved short spec. I ran Task 1 in the skill's order:

- ledger-open: it printed the ledger dir and wrote `# kern ledger:` and `Main: ... status=e69de29...` (the empty status). It also made `briefs/ reports/ reviews/ logs/`.
- plan-check: exit 0. `--graph` printed `wave 1 1 2`.
- wt-new `sum-guard --base main`: it printed the path, and the branch was `kern/sum-guard`. A `Worktree:` line followed, with the base tree from wt-snap. The baseline `npm test` (kern-detect `package.json scripts.test`) gave `# fail 0`.
- `plan-check --files`, task-brief, wt-snap and task-start, in that order. task-start printed `Task 1: start tree=... at=...`.
- Wrapped brief: brief-check printed `brief-check: ok`. task-brief's raw output fails it (`missing: GOAL`, and so on). wt-check against the plan branch printed `ok`.
- Fake implementer change, then wt-snap and wt-diff `--out reviews/task-1-<tree7>.diff --allow-file briefs/task-1.files`. Exit 0, and both the package and `.patch` were written. An extra notes.txt gave exit 4 with `wt-diff: outside the allowed paths: notes.txt`. Identical trees gave exit 3.
- task-done with no review exits 2. The first review was `task-review ... 1 issues needs-fixes --minor ...`, and task-done exits 2 on it. Round 4 is refused (`ROUND is 1, 2 or 3 (D10): 4`, exit 2).
- The `Task 1: fix round=2 tree=` line, then review round 2 (compliant, approved). task-done `--probe` printed `probe: fail-then-pass ok` and the complete line with `probe=ok`.
- Task 2 (docs): `--no-probe ""` exits 2. With `--no-probe "docs only, no test to probe"` it wrote `probe=skipped (docs only, no test to probe)`. A probe on that patch would print `inconclusive (... No such file or directory)`, the new-file case the skill accepts.
- Other task-done exits: a comment-only change gives exit 1, `the test passes with the change reversed`. A tree changed after review gives exit 2. A failing CMD gives exit 1, `command exited 1`.
- `ledger-open --summary`: it printed the deferred minor and then `main: unchanged` (exit 0). `wt-diff` from the base tree wrote `reviews/final.diff`. `git -C <wt> log` shows no new commit.
- Every ledger line matched the contract formats (checked by regex, 12 of 12).

Hook check (real `hooks/pre-tool-use`, all guards, interactive and autopilot sessions):
- A `printf ... >> ledger.md` line gets no vote.
- The same line holding "approved" is denied by G20 in both modes.
- task-review with `approved`, plan-check `--files >`, ledger-open, wt-new, wt-fork, task-done, wt-apply and `git -C rev-parse` get no vote.
- `task-done ... -- bash -c "..."` is denied by G00 under autopilot.

## Deviations

1. SKILL.md cap is 12,000 (lead ruling). The brief's own text was 9,495 bytes before the exit handling below.
2. Rounds: round r is the r-th review. Round 1 is the first review, round 2 resumes the implementer, and round 3 is a fresh implementer one tier up. The loop stops after round 3. The brief's "rounds 1 and 2 resume, round 3 fresh" needs 4 reviews, and task-review accepts ROUND 1 to 3 only. The test pins "There is no fourth round".
3. task-done exit 1 is not only the probe. CMD's own exit code passes through, so a test failing with code 1 exits 1 with `command exited 1`. Step 10 reads the message. `command exited <n>`, or exit 1 from the probe, goes back to the implementer as the next round. A changed or unapproved tree goes back to review. A probe error stops.
4. `<task test command>` is one command (task-done runs no shell). Under autopilot G00 denies `-- bash -c` (measured). A compound `Run:` goes in a script under `kern-dir tmp`, passed as `-- bash <path>`; G00 gives that no vote in either mode (measured; corrected in fix round 1).
5. `--probe <package>.patch` after fix rounds: the package is remade from `tree-before`. Step 8's package covers round 1 only, and a fix package covers only its fix.
6. Fix packages are `reviews/task-N-fix<r>-<tree7>.diff`, so they do not overwrite the task's package. The final package is `reviews/final.diff`, because its tree is unknown before the call.
7. `step` mode runs steps 8 to 10 (the brief said 7 to 10). Step 7 parses an implementer's status line, which step mode has none of.
8. task-brief runs in every mode, because the reviewer needs `briefs/task-N.md`. Step and inline modes write their report to `reports/task-N.md`.
9. `<base-ref>` is the plan branch. `origin/<base>` goes stale after any later fetch, and wt-check then fails its ancestor check. The branch is also on the `Worktree:` line, so it survives compaction.
10. wt-new gets `--base <the plan's base>`, so a plan off another branch is honoured. `--branch` is passed only when `branch.pattern` holds `{id}`, as implement does, because wt-new fills `{slug}` from settings. The Inputs default for `branch.pattern` reads `detected; kern/{slug}`.
11. The fork slug is `<plan-slug>-task-<N>`, not `task-<N>`, so two plans cannot collide in `worktree.dir`.
12. Waves borrow only parallel-work's spawn (its step 4) and its overlap rule (its step 1). execute-plan reviews and closes in each fork and integrates at step 11, because parallel-work step 6 would integrate before review.
13. The `Wave:` line is written when the forks exist (step 6). The ledger-format "Written by" column says step 6, not step 4.
14. Under autopilot, a wave task is committed after step 11's apply, because a fork is detached.
15. ledger-format.md adds three things. First, how a line no script writes is appended (`printf`, or the Edit tool for one holding "approved", as G20 denies that shell write). Second, a resume rule for a started task: it keeps its start tree as `tree-before` with no second task-start, and a snapshot still equal to that tree means dispatch again. Third, "all complete" goes to the final review, and a wave task resumes in its fork.
16. Added: the intro's catch-all for unnamed script exits; "Never edit the plan's approval"; exit handling for wt-new, wt-fork, plan-check `--files`, task-brief, wt-snap, task-start, brief-check exit 1, wt-diff exit 3 and wt-apply exit 3; a red test after integration; an `--allow-file` per task on the final fix package; a step 6 brief, so brief-check runs for the round-3 and final-fix dispatches; inconclusive for another reason asks; the plan worktree is torn down only once committed, and forks follow parallel-work's worktrees.md.
17. Stops and autopilot: the sibling autopilot line, verbatim. Steps 1, 2 and a failed wt-new end the run under autopilot. Later stops park, with stated defaults. G5's commit shape is named, and so is `commits: ask` (no commit without autopilot).
18. Each Red flags Reality now says what to do, for example "Re-review every fix" and "Write each line as it happens".

## Concerns

- `docs/specs/2026-10-12-kern-m1-m2-skills.md` holds the lead's uncommitted edit. I did not touch it or stage it.
- The `/kern:commit` steps 3 to 6 and `/kern:finish-branch` named here ship in Tasks 24 and 25. The routed row ships in Task 30, so lint reads execute-plan as slash until then.
- `base-tree` is taken right after wt-new, before the baseline run. A test run that writes untracked, unignored files shows them in the final package (inferred).
- Under autopilot, the final review's fix stays uncommitted. finish-branch's commit step picks it up (inferred from the Task 24 and 25 briefs).
- task-review exit 2 and other usage exits rely on the catch-all ("A script exit not named here stops the run").

## Fix round 1 (base e68bdb8)

Commits: 8738c9e `M2: task-done refuses to close a task on an inconclusive probe` (scripts/task-done, tests/scripts/task-done.bats, contract.md:159); df11156 `M2: execute-plan resumes waves and fix loops from the ledger` (SKILL.md, references, test, contract.md:188).

- Critical 1:
  - task-done now exits 3 when probe exits 3. It prints probe's line and writes nothing. The new bats test was RED on HEAD (`[ "$status" -eq 3 ]` failed on a scratch copy holding HEAD's task-done) and GREEN after the change. task-done.bats passes 22/22 on /bin/bash, and shellcheck is clean.
  - The reviewer's probes now behave:
    - walk/p1 (setup gap): exit 3, no complete line.
    - walk/st (stale round-1 patch): exit 3, no complete line.
    - The remade package for walk/st gives exit 3 with a missing export `mul`. That is a named case, so `--no-probe "probe inconclusive: <reason>"` closes it with `probe=skipped (probe inconclusive: ...)`.
  - Step 10's complete-line sentence now reads "...(`probe=ok`) or `--no-probe` gave a reason". Exit 3 reruns with that `--no-probe` reason only for a new module or export, or a patch of test files only. Any other reason stops and asks.
  - Who reads `probe=inconclusive`: task-done, contract :159 and :188, ledger-format.md, SKILL.md and the test, all updated. The ledger line format is now `probe=<ok or skipped (reason)>`. Not updated: docs/specs/...m1-m2-skills.md:422 (lead-owned spec text) and the historical plans.
- Important 1: resume.md case 2. A task on a `Wave:` line that is complete but has no `Applied:` line goes to step 11 before the final review or any later task. A parked task stays out. Read literally (an awk reading of the order), the reviewer's wave ledger resolves to "step 11 for Task 2".
- Important 2:
  - Step 8 saves the reviewer's return as `reviews/task-N-r<r>.txt` before task-review runs, and rounds 2 and 3 pass that file.
  - resume.md "Fix loop memory" holds the SDD fallback: a fresh `kern:implementer` with the brief, the report and that file.
  - Resume cases: a review that did not approve writes the fix-round line and continues step 9, with r of 4 meaning the split proposal. A changed start snapshot is reviewed at step 8 as round r.
- Important 3: SKILL.md (intro) and ledger-format.md state that only the scripts write the `Task N: start`, review, minor and `Task N: complete` lines. The Edit route is kept for the other lines. The M3 guard is named as a limit.
- Minors:
  1. base-tree is taken after the baseline run (order pinned).
  2. r = 1 + the task's review lines.
  3. Exit 4: on a yes, append the path to the `.files` list with a `Decision:` line; on a no, return the task to the implementer.
  4. `command exited 126/127` stops, and a failure after round 3 goes to the split proposal.
  5. Steps 2 and 3 run once, and resume.md says they ran.
  6. A compound `Run:` goes in a `kern-dir tmp` script, passed as `-- bash <path>`. G00 gives no vote in either mode (measured). Deviation 4's "cannot be wrapped" is corrected.
  7. All six unpinned lines are now pinned.
  8. Red-flag row 5 says to adjudicate only at the cap.
  9. Step 12 names `kern:implementer`, the re-review on `model.final_review`, and FROM `final.diff`'s second line.
- Room: the new references/resume.md (1,772 of 2,500) holds the resume rules. The skill reads it only when the ledger held lines past `Main:`, or after compaction. ledger-format.md keeps a one-line pointer under its `## Resume rule` heading.
- Sizes: SKILL.md 11,979 of 12,000; ledger-format.md 2,467 of 2,600; resume.md 1,772 of 2,500 (in the test's size checks). To fit, I removed the Stops step list and the intro's "Serial tasks share the plan worktree" line, which steps 4 and 6 already state. I also moved the batch rule's ledger half to ledger-format.md. No behaviour was dropped.
- Pins: 145 strings across SKILL.md, ledger-format.md and resume.md, plus 6 order swaps (baseline before `Worktree:`, the saved return before task-review, and others). Removing each on a scratch copy fails the test: 151 mutations, 0 survivors.
- Checks: node 126/126, `lint: clean`, `route-eval: passed`, validate passed. `scripts/ci-local` exit 0, last line `ci-local: all steps passed`, no `not ok` (scripts/ci-local-3.log).

## Fix round 2 (base 7429056)

Commit: 5232640 `M2: execute-plan reruns its plan checks on every invocation` (SKILL.md, references/resume.md, the test).

- Important A, redesigned rather than patched. The "Once" wording is gone from steps 2 and 3, and resume.md no longer says "ran already ... rebuild only the todo list". The new rule, by effect:
  - Steps 2 and 3 run on every invocation, fresh or resumed: plan-check, `--graph`, reading the plan and spec, and the conflict scan. Step 4's wave rows always come from that run's `--graph`.
  - Their ledger writes (`Preflight:`, `Decision:`, `parked:`) are added only when the ledger lacks that exact line.
  - Every step 3 answer, and every mechanical call, is recorded as a `Decision:` line. resume.md says a step 3 conflict with no `Decision:` line is asked again on resume, and parked once under autopilot.
- Minor d: step 1 names `references/ledger-format.md` ("Line formats and how to append them").
- Minor c: red-flag row 5 reads "Argue it in the re-review. At the cap, the split proposal names it."
- Minor a: in resume.md, a changed snapshot after a start line or a fix round goes to review only once the implementer has stopped, meaning its report holds that round's `Status:` line. Until then, wait for it or resume it; in step and inline mode, finish the change first. To make the status-line test true, the delegate brief's REPORT now asks for each round to open with its `Status:` line.
- Minors b and e: deferred, as ruled.
- Fit: SKILL.md is 12,229 bytes, over 12,000 and under the 12,400 ceiling. I first moved the re-ask rule into resume.md, which is read on every resume. The rest is the every-invocation rule, the ledger-format pointer and the REPORT status line, none of which is detail I could move. The test cap is now 12,400. resume.md is 2,116 of 2,500; ledger-format.md 2,467 of 2,600.
- Tests:
  - Pins: the every-invocation rule (step 2), the add-only-missing rule (step 2) and the re-ask on resume (resume.md), plus the step 1 pointer, the REPORT status line, the red-flag text and the minor-a lines.
  - A new test asserts that steps 2 and 3 hold no "Once" and that resume.md holds neither "ran already" nor "rebuild only the todo list".
  - Mutations: 159, 0 survivors. These include removing each of the three rules and reintroducing each old once-only phrase (3 mutations).
- Repro, reading resume.md literally. The ledger held the header, `Main:` and one `Preflight:` line, and step 3 had stopped to ask.
  - Step 1 finds lines past `Main:`, so it reads resume.md.
  - Steps 2 and 3 run again. plan-check exits 0, and `--graph` prints `overlap 1 2 src/sum.js`, `wave 1 1` and `wave 2 2`.
  - The `Preflight:` line is present, so it is not added again (count stays 1).
  - The conflict has no `Decision:` line, so it is asked again.
  - Case 1 (no `Worktree:` line) then continues at step 5.
- Checks: node 127/127, `lint: clean`, `route-eval: passed`. `scripts/ci-local` exit 0, last line `ci-local: all steps passed`, no `not ok` (ci-local-4.log).
