---
name: prove-it
description: Use before saying work is done, fixed, passing or verified; before a commit, push or PR; and when a subagent reports success. Runs the proving command fresh, reads all output, checks each acceptance line, and labels other claims measured, inferred or guess.
---

# prove-it

No claim of done, fixed, passing or verified without a fresh run on the real artifact.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Name the claim and its proving command from `references/evidence.md`. Resolve commands with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`, and print each with its source. When both exit 3, no command is known: ask the user for it, and label the claim guess until it runs.
2. Run it fresh and in full on the tree that will be integrated: the worktree, when the work lives there.
3. Read the exit code, the failure count and the whole output. Inconclusive, skipped, zero tests run, or the wrong environment counts as a fail. Suspect the observation method before the system.
4. For a new guard or regression test, make the change's patch with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>` (it writes `<package>.patch` beside the package it prints) and run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>`; it must print `probe: fail-then-pass ok`. The allow case uses a value a real caller sends. Exit 3 is reported as "probe inconclusive", never as a pass.
5. For "requirements met", re-read the acceptance lines from `spec.source` and tick each one against evidence.
6. For a subagent's "success", read its worktree diff yourself with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before>` and open the artifacts it names.
7. State each claim with its evidence as `claim: command, result`, or label it measured, inferred or guess.

Gate: steps 1 to 7 hold before any commit, push, PR, tracker write, or the words done, fixed, passing, verified. Then, for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`; for a push or a PR, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`; and follow its steps.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint`, `build` | detected, source printed | proving commands |
| `verify.fast` | `typecheck`, then `lint` | quick proof before a commit |
| `verify.browser` | none; ask when a UI claim needs it | UI claims |
| `spec.source` | linked issue, PR body, `WORK/specs` | acceptance lines |

## Outputs

Chat lines `claim: command, result`. Only `wt-diff` writes: a review package and its `.patch` under `WORK/reviews/`.

## Stops and autopilot

A failed proof blocks the claim and the outward action that depended on it. Under autopilot, the failed branch of work is parked with a `parked:` ledger line and disjoint work continues.

## Red flags

| Thought | Reality |
|---|---|
| "It should pass now" | Run the proving command. A claim without its output is a guess. |
| "The subagent said it passed" | Read its diff and re-run its test. A report is a claim. |
| "Lint passed, so it builds" | Each claim has its own command. Lint proves lint. |
| "The focused test is enough" | Done needs the command the claim names, run in full. |
| "It passed earlier this session" | A run proves only the tree it ran on. |
| "Inconclusive is close enough" | Inconclusive is a fail. Report it as one. |
