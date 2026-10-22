---
name: implement
description: "Change production code in thin slices: failing test first, minimal green, full suite, out-of-scope listed."
disable-model-invocation: true
---

# implement

Write production code in slices, each proven by a test seen failing for the right reason. Reached from the kernel row for one bounded change, from execute-plan inline mode, from diagnose step 7, and by the `kern:implementer` agent, whose brief gives this file's absolute path.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Entry check, main session only: unless an approved spec or plan covers this change, it fixes a cause diagnose found, or define said its `Building:` line, say `Building: <what>. My choices: <each>.` right after you read this file, before your next tool call; restate a choice your reads change before the first edit. A change to an existing public API (not a new export), stored data or authorization: say so, and ask whether to keep the fast path; under a waiver, say it in that line and ask nothing.
2. Pick where to edit. In a kern worktree, edit there. In the main session, edit the current checkout only when its branch is a non-protected feature branch; otherwise propose `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>`, adding `--branch <name>` when `branch.pattern` holds `{id}`, and wait for one answer; `wt-new` exit 2: say why and ask. Never switch the main checkout's branch. Under autopilot, always use a worktree. `<wt>` below is that path: the one `wt-new` printed, or the checkout root when editing in place.
3. Resolve `test.focused`, `test.full`, `typecheck` and `lint` with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`. Print each command with its source. When both exit 3, ask the user; never guess a command.
4. Slice the work and list the seams; use the plan's seams when it has them (`references/slicing.md`).
5. For each slice, name the break in one sentence, write the test, run it, and see RED for the expected reason: an assertion failure, not an import or syntax error. A test that already passes is a finding, not a RED.
6. Once, before the first production edit of the whole change (not per slice), record the tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`. Write the minimum code that turns the test GREEN.
7. Run the focused test, `typecheck` and `lint`; a command that step 3 could not resolve was asked for there. Refactor only code you touched, and stay green.
8. A file outside the approved list pauses the work: name it and ask. Findings outside scope go to a NOTICED BUT NOT TOUCHING list.
9. Check test quality with `references/test-design.md`. For one new condition, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test command>` (`<file>` is relative to `<wt>`; it inverts one operator on that line, the first in probe's fixed order, so point it at a line with a single condition) and expect `probe: mutation caught`; a survivor means a stronger test, and exit 3 is reported as inconclusive, never as a pass. Add adversarial inputs (empty, zero, false, cleared, several elements). For each new guard, make the patch with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>` and expect `probe: fail-then-pass ok`. `wt-diff` exit 3 is an empty diff: no production change, so nothing to probe; report it, never count it as a pass.
10. No correct seam for a test: say so, and give the closest executable check with its output.
11. Regenerate `generated_artifacts` for touched trigger paths, run `test.full`, and name every red test, marking the ones that were red before your change.
12. Report the failing-before and passing-after output, the commands, the files changed and the NOTICED list. Do not commit.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint` | detected, source printed | RED, GREEN and the full suite |
| `generated_artifacts` | none declared | files to regenerate after a change |
| `scope_threshold` | 4 files | size of the approved list |
| `branch.protected`, `branch.pattern` | `base_branch` plus `deploy.envs` branches; detected | where editing in place is allowed; the worktree branch |

Project test obligations come from the project rules already in context.

## Outputs

Code and tests in the chosen tree; a chat report. `wt-diff` writes a review package and its `.patch` under `WORK/reviews/`. No commit.

## Stops and autopilot

Stops at steps 1, 2, 3 and 8. Under autopilot the steps are the same, RED is never skipped, and a file outside the approved list parks the slice with a `parked:` line.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to test" | Simple code breaks, and the test takes a minute. |
| "I'll test after" | A test written after passes at once and proves nothing. Watch it fail first. |
| "I checked it by hand" | A hand check leaves no record and is not re-run on the next change. |
| "The mutation survived, but the test looks fine" | A surviving mutation is an unprotected behaviour. Strengthen the test. |
| "That file is just outside the list" | Pause, name the file and ask. Do not edit it first. |
| "Hard to test, so skip it" | Hard to test means hard to use. Name the closest seam and its check. |
