# Task 18 report: diagnose

Status: DONE. Commit: see git log ("M2: add the diagnose skill").

RED (Step 2): diagnose.test.mjs 3 fail (`... exists`); the 6 script tests fail (script missing); g18-parity fails at `[ -f forensics.md ]`.
GREEN: diagnose.test.mjs 3/3; bats 7/7 (find-polluter 3, loop-rate 3, g18-parity 1); node --test 'tests/**/*.test.mjs' 105/105; shellcheck -x -S warning clean on the three scripts; lint-skills `lint: clean`; route-eval passed; ci-local `ci-local: all steps passed`.

## Deviations from the brief
1. find-polluter.sh: `find` failure is exit 2 with a message (was an unchecked `$(...)`); absolute or empty TEST_GLOB exits 2; missing TEST_CMD exits 2 (was a false "no polluter found"); a dangling symlink counts as pollution; sort under LC_ALL=C; CR stripped from file lines. Final line is `no polluter found among <n> test files` (contract.md line 169 and the bats test), not the bare brief text.
2. Pollution path handling: the loop stops at the first file that creates the path, so the path is absent before every candidate and cannot mask a later run. The path is left in place for inspection; the script and flaky-and-async.md say to remove it before another run, and a rerun exits 2.
3. loop-rate.sh: uses bash `time` with `TIMEFORMAT=%R` and LC_ALL=C instead of `/usr/bin/time -p` (not present everywhere); N validated with explicit digit lists, 9 digit cap, leading zeros normalized, `00` rejected; missing CMD and unreadable timing exit 2.
4. hitl-loop.template.sh: closed stdin exits 1 with a message instead of a silent set -e exit; CR stripped from answers.
5. SKILL.md: step 2 resolves test.focused/test.full as implement step 2 does (ask, never guess) and says where the hitl copy goes (`kern-dir tmp`) and what `<sha>` is; "no loop" now says what to ask for; step 6 "census that premise" replaced by "list every place that premise is assumed and check each"; step 7 names the blind-reproduction agent and model (`kern:implementer`, `model.implementer`); step 8 says how the patch is produced (`wt-diff` and `wt-snap` as in implement step 8) and what probe exit 1, exit 3 and an empty diff mean; loop-rate takes one command (wrap a pipeline in `sh -c`); `parked:` line is not backticked so lint rule 16 does not read it as a ledger format. Inputs gained `model.implementer`. 5816 bytes (cap 6500).
6. References are ported from the named upstream ranges, condensed; sizes 1837, 1974, 2167, 1551 bytes. No long dashes or curly quotes in any new file (grepped). No lint exemptions.

## Concerns
- loop-rate/ find-polluter swallow the tested command's output by design; a test command that exits 127 itself counts as red/ignored.
- find-polluter does not skip node_modules; a broad glob will run vendored tests (same as upstream).

## Fix round 1
- find-polluter: exit 126/127 gives exit 2 `find-polluter: the test command could not run (exit <n>) on <file>`; every run failing with no polluter gives exit 2; a mix keeps exit 0. loop-rate: 126/127 gives exit 2 `loop-rate: the command could not run (exit <n>)`. Each new bats test failed on e7ca3cb first (tests 4, 5, 13). contract.md:169 updated.
- New bats: glob with no match, missing TEST_CMD, spaces in names, mixed runs, 003, 10-digit N, missing CMD in loop-rate, hitl closed stdin and CR (new tests/scripts/hitl-loop.bats), G18 deny cases. Against a stub g18_allowed that always returns 0 (scratch copy), the deny tests fail.
- Restored the determinism prompt and the "no correct seam is itself the finding" line; hitl and step 2 say the user runs it with `! bash <path>`; Red flags row 3 has an action; newline-in-name limit named in the header.
- diagnose.test.mjs asserts find-polluter.sh, wt-new with --detach, the `! bash <path>` line and the seam line; removing `--detach`, find-polluter.sh or the probe call each fails it.
