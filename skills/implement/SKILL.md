---
name: implement
description: "Change production code in thin slices: failing test first, minimal green, full suite, out-of-scope listed."
disable-model-invocation: true
---

# implement

## Steps

0. Defer: if the kern settings block names an override for this job, follow that skill instead, say so in one line, and stop.
1. Entry check, main session only: unless an approved spec or plan covers this change, it fixes a cause diagnose found, or its `Building:` line was said, say `Building: <what>. My choices: <each>.` now; restate a choice your reads change before the first edit. A change to an existing public API (not a new export), stored data or authorization: say so, and ask whether to keep the fast path, even if that line was said; under a waiver, say it in that line and ask nothing. Under autopilot, say the line and go on; such a change no approved spec covers is the design-choice stop in `${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md`.
2. Pick where to edit. In a kern worktree, edit there. In the main session, edit the current checkout only when its branch is a non-protected feature branch; otherwise propose `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>`, adding `--branch <name>` when `branch.pattern` holds `{id}` (the spec's or plan's `issue:`, with quotes and a leading `#` removed), and wait for one answer; `wt-new` exit 2: say why and ask. Never switch the main checkout's branch. Under autopilot, always use a worktree. `<wt>` below: the path `wt-new` printed, or the checkout root when editing in place.
3. Resolve `test.focused`, `test.full`, `typecheck` and `lint` with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`. Print each command with its source. When both exit 3, ask the user; never guess a command. Under autopilot, a required one is a required check that cannot run: the work goes on by step 10's closest check and ends on finish-branch's end path; any other parks, and step 7 skips it.
4. Slice the work and list the seams; use the plan's seams when it has them (`references/slicing.md`).
5. For each slice, name the break in one sentence, write the test, run it, and see RED for the expected reason: an assertion failure, not an import or syntax error. A test that already passes is a finding, not a RED. Tests asked for on existing code pass at once: their RED is step 9's `probe --mutate` of the line each covers (nothing to mutate: step 10's closest check). One that fails on the unchanged code stops the run: show the failure and ask whether it is a bug for diagnose or the behaviour to pin; never route there or edit production code unasked. Under autopilot, it parks the slice with a `parked:` line and the test is left out of the tree.
6. Once, before the first production edit (not per slice), record the tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`. Write the minimum code that turns the test GREEN.
7. Run the focused test, `typecheck` and `lint`; a command that step 3 could not resolve was asked for there, or parked. Refactor only code you touched, and stay green.
8. A file outside the approved list pauses the work: name it and ask. Findings outside scope go to a NOTICED BUT NOT TOUCHING list. A build that departs from an approved spec's acceptance line: name the line and the proposed new text, and ask; never edit the spec on your own. Edit it only on the user's yes, keeping its `States:` and `Handles:` form. Under autopilot, write a `parked:` line instead.
9. Check test quality with `references/test-design.md`. For one new condition, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test command>` (`<file>` is relative to `<wt>`; point it at a line with a single condition) and expect `probe: mutation caught`; exit 3 is inconclusive, never a pass. Add adversarial inputs. For each new guard, make the patch with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>` (first line: `<package>`), run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <package>.patch -- <test command>` and expect `probe: fail-then-pass ok`. `wt-diff` exit 3 is an empty diff: nothing to probe; report it, never as a pass.
10. No correct seam for a test: say so, and give the closest executable check with its output.
11. Regenerate `generated_artifacts` for touched trigger paths, take `<id>` with `wt-snap <wt>`, run `test.full` (main session only: saving its output as `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/references/evidence.md` says), and name every red test, marking those red before your change. A `test.full` that passed on tree `<id>` in this run stands for that tree; a step that would rerun it on that tree cites the run. Runs on other trees stay.
12. Report the failing-before and passing-after output, the commands, the files changed and the NOTICED list. Do not commit. From the kernel's row under a go, follow `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md` on `<wt>`.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint` | detected, source printed | RED, GREEN and the full suite |
| `generated_artifacts` | none declared | files to regenerate after a change |
| `scope_threshold` | 4 files | size of the approved list |
| `branch.protected`, `branch.pattern` | `base_branch` plus `deploy.envs` branches; detected | where editing in place is allowed; the worktree branch |

## Outputs

Code and tests in the chosen tree; a chat report.

## Stops and autopilot

Stops at steps 1, 2, 3, 5 and 8. Under autopilot the steps are the same, RED is never skipped unless step 3 finds no test command, and a file outside the approved list parks the slice. A judgment call that takes a default gets a `parked:` line; any other stop waits for a typed reply, with the data and a recommendation.

Under autopilot, stops, unblocking and the run report follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to test" | Simple code breaks, and the test takes a minute. |
| "I'll test after" | A test written after passes at once and proves nothing until a mutation turns it red. Watch it fail first. |
| "I checked it by hand" | A hand check leaves no record and is not re-run on the next change. |
| "The mutation survived, but the test looks fine" | A surviving mutation is an unprotected behaviour. Strengthen the test. |
| "That file is just outside the list" | Pause, name the file and ask. Do not edit it first. |
| "Hard to test, so skip it" | Hard to test means hard to use. Name the closest seam and its check. |
