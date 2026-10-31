# Evidence by claim

Each claim needs its proving command run fresh, in full, on the tree that will be integrated. A `test.full` that passed on tree `<id>` in this run stands for that tree; a step that would rerun it on that tree cites the run. Runs on other trees stay. `<id>` is from `wt-snap` before that run; the citing step's `wt-snap` must match it. A subagent's report is no such run.

## Claim table

| Claim | Proving command | Not enough |
|---|---|---|
| Tests pass | `test.full`, or `test.focused` for a named test: exit 0, zero failures, more than zero tests ran | An earlier run on another tree, a partial run, a run where zero tests ran, "should pass" |
| Bug fixed | The reproduction that was red, now green, then `test.full` | The code changed; a different test passed |
| Types or build clean | `typecheck` or `build`, exit 0 | Lint passing; no editor errors |
| Lint clean | `lint`, exit 0 | Typecheck passing |
| Regression test works | `probe` prints `probe: fail-then-pass ok` | The test passes now |
| Requirements met | Each acceptance line ticked against a command or an artifact | Tests pass |
| UI works | `verify.browser` on the changed screen, with its artifact | Unit tests; the component compiles |
| Subagent finished | Its worktree diff read with `wt-diff`, its commands re-run | Its report says DONE |

## Labels

- measured, as `claim: command, result`: you ran it this session and quote its output.
- inferred: it follows from something measured; the claim's own sentence carries the word inferred and names what. A cause read in the code but not tested, and a fix you did not run, are inferred.
- guess: neither; the claim's own sentence carries the word guess and says what would make it measured.

## Inconclusive is a fail

Skipped tests, zero tests ran, a run in the wrong environment, a timeout, a probe that could not run, and output you did not read all count as a failed proof. Suspect the observation method (wrong directory, cached build, wrong target) before the system.

A failed emulator walk resumes from the failed step, at most 2 reruns of a step, then it is a required check that cannot run.
