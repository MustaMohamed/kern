---
name: prove-it
description: Use before saying work is done, fixed, passing or verified; before a commit, push or PR; and when a subagent reports success. Runs the proving command fresh, reads all output, checks each acceptance line, and labels other claims measured, inferred or guess.
---

# prove-it

No claim of done, fixed, passing or verified without a fresh run on the real artifact.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Name the claim and its proving command from `references/evidence.md`. Resolve each with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`, else `kern-detect <key>`, and print each with its source. When both exit 3, ask for the command; the claim is a guess until it runs.
2. For a subagent's "success", Read the package `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <tree-before, else HEAD>` writes, or the files it names, before you run its test; a failing test does not skip this. `git diff` omits untracked files.
3. Run the proving command fresh and in full on the tree that will be integrated: the worktree, if the work is there.
4. Read the exit code, the failure count and the whole output. Inconclusive, skipped, zero tests run, or the wrong environment counts as a fail. Suspect the observation method before the system.
5. For a new guard or regression test, make the patch with `wt-diff` (it writes `<package>.patch` too) and run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>`; it must print `probe: fail-then-pass ok`. The allow case uses a value a real caller sends. Exit 3 is reported as "probe inconclusive"; for a module or export the patch adds, or a test-only patch, report `probe inconclusive: new module` and prove the new code with `probe --mutate <file>:<line> <wt> -- <test command>`.
6. For "requirements met", re-read the acceptance lines from `spec.source` and tick each against evidence.
7. Back a claim a command showed with `claim: command, result`. A claim no command showed carries the word inferred or guess in its own sentence, with what it rests on: "The cause, inferred from `src/x.js:42`, is …"; "The fix, inferred and not run, is …".

Gate: steps 1 to 7 hold before any commit, push, PR, tracker write, or the words done, fixed, passing, verified. Then, unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step), for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`; for a push, a PR or a release, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`; and follow its steps.

## Inputs

| Key | Default | Use |
|---|---|---|
| `test.focused`, `test.full`, `typecheck`, `lint`, `build` | detected | proving commands |
| `verify.fast` | each of `typecheck` and `lint` that resolves; at least one | quick proof before a commit |
| `verify.browser` | none; ask when a UI claim needs it | UI claims |
| `spec.source` | linked issue, PR body, `WORK/specs` | acceptance lines |

## Outputs

Claims in chat, in step 7's forms. Only `wt-diff` writes: a package and its `.patch` under `WORK/reviews/`.

## Stops and autopilot

A failed proof blocks the claim and the outward action that needs it. Under autopilot, the failed work is parked with a `parked:` ledger line and disjoint work goes on.

## Red flags

| Thought | Reality |
|---|---|
| "It should pass now" | Run the proving command. A claim without its output is a guess. |
| "The subagent said it passed" | Read its diff and re-run its test. A report is a claim. |
| "Lint passed, so it builds" or "the focused test is enough" | Each claim needs the command it names, run in full. |
| "It passed earlier this session" | A run proves only the tree it ran on. |
| "Inconclusive is close enough" | It is a fail. Report it as one. |
| "I said I haven't run it" or "read in the code" | That discloses; it does not label. Put inferred in the sentence. |
