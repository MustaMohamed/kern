# Task 3 report: wt-fork and wt-apply

Status: DONE

## Implemented
- `scripts/wt-fork`, `scripts/wt-apply`: verbatim from the brief, mode 755.
- `tests/scripts/wt-fork-apply.bats`: the 11 tests from the brief, verbatim.
- Commit bff5105 `M2: add wt-fork and wt-apply`. Named paths only, no trailers, no push.

## TDD evidence
- RED: `tests/run-bats tests/scripts/wt-fork-apply.bats` before the scripts existed. Every `run` of wt-fork or wt-apply exited 127 (command not found), which is the expected failure.
- GREEN: same command after implementation: `1..11`, `ok 1` to `ok 11`, no `not ok`.
- `shellcheck -x -S warning scripts/wt-fork scripts/wt-apply`: clean.

## Tests
- `tests/run-bats tests/scripts`: 67 ok, 0 not ok.
- `node --test 'tests/**/*.test.mjs'`: pass 72, fail 0.
- `scripts/ci-local` (run after the commit), last lines:
  ```
  ok 450 with settings.sh missing, subagent-start exits 0 and prints nothing or valid JSON
  hook-shape: 8 cases passed
  ci-local: all steps passed
  ```

## Self-review
- Scope: three files, all in the brief. Tasks 1 and 2 files untouched.
- Tests pin the noprefix plumbing choice and the KERN_MAIN export (test 9, run from outside the repo).
- The only `worktree remove --force` calls target the fork this run just created.

## Concerns
None. Working tree was clean at start (only `.superpowers/` untracked) and after the commit.
