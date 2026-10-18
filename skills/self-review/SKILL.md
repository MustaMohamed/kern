---
name: self-review
description: "Check your own diff before a PR: deterministic checks, blast radius, probes, a fresh doubt pass, then a verdict."
disable-model-invocation: true
---

# self-review

Find what your diff breaks beyond itself and run every cheap check before a PR. Reached by its kernel row, finish-branch step 5 or `/kern:self-review`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Scope. `<wt>` is the work's worktree, else the checkout root; `<base>` is `base_branch`. `git -C <wt> remote get-url origin` failing means no remote: `<baseref>` is local `<base>`, said once. Else `<baseref>` is `origin/<base>` after `git -C <wt> fetch origin <base>`; if the fetch fails, ask whether to use the last fetched one, and report "base not refreshed". `git -C <wt> merge-base HEAD <baseref>` prints `<merge-base>`; failure stops the run, output reported. `references/rounds.md` names `<package>` and what a later round adds. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base> --out <package>`: line 1 is `<package>`, `<package>.patch` sits beside it, lines 3 on are the changed paths. Exit 3 is an empty diff: say there is nothing to review, and stop; any other non-zero exit stops and reports.
2. Deterministic pass, pasting commands and output. Resolve `verify.fast`, else `typecheck` and `lint`, and `test.focused`. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/floor-scan <package>` and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/claim-check <wt> <package>`: exit 1 from either is hits, each fixed or justified in the report; any other non-zero exit, or a red `verify.fast` or test, is a failed check. A skipped check counts as failed (`references/claim-checks.md`).
3. Built-in lane: call the Skill tool with `code-review`, explicit arguments: the worktree path as target, the effort from `review.builtin.self_effort`, `--max-findings` from `review.builtin.max_findings`. Never pass `--comment` and never `--fix`. Unavailable, erroring or `review.builtin: off`: `skip: built-in code-review not available`.
4. Spec lane: the spec `spec.source` names, else this work's plan or `WORK/specs` file; tracker or PR text goes under `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`. Dispatch `kern:task-reviewer` on model `model.reviewer`, mode `whole-branch`, with absolute paths only: the spec (its Constraints are the Global Constraints), `<package>`, `<wt>`, the `review.rules` files; no report. Say the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus. Ask what is missing, partial, unasked or wrong, quoting spec lines. No spec: `skip: no spec`.
5. Walk the `review.rules` files the diff touches, reading any not in context, then the smell baseline (`references/smells.md`).
6. Blast radius, when a changed symbol has callers outside its directory or gates behaviour on a property (`references/blast-radius.md`): sweep every writer with `rg` and read each; look where grep stops; prove the one fact that makes it safe; list Risks and Cleared apart.
7. Probes, with `<package>.patch` from step 1 and `<test>`: `test.focused` with `{file}` or `{dir}` replaced by the one test file covering the change, no shell syntax. For each new guard test: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <package>.patch -- <test>`; it must fail with the branch's non-test changes reversed (one guard alone is implement's per-slice probe). For a new conditional, one `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test>`: `<file>` is relative to `<wt>`, `<line>` from the working file; probe inverts the first operator on that line in a throwaway fork, never the worktree. probe exit 1 (no failure, or the mutation survived), 2 and 3 each fail the check; exit 3 is reported inconclusive, never as a pass. But exit 3 for a module or export the patch adds, or a test-only patch, is `probe inconclusive: new module`, not a failure; `--mutate` on the new code proves it.
8. Doubt cycle, for non-trivial decisions only (`references/doubt-cycle.md`): dispatch `kern:investigator` on model `model.reviewer` with one question, "where does this artifact fail this contract?", both absolute paths as scope, and never your claim or reasoning. Reconcile as that file says; at most 3 cycles.
9. Verdict: findings in `review.taxonomy` classes (ordered high to low), a "Declined to judge" list (what was set aside as outside the spec, and why), then one verdict, tested in order: `split`, `fix first`, `rebase first`, else `ready`. `split`: a later round where this package has more than `scope_threshold` paths and the previous one did not, or a finding lands in an added line of the since package; a first round never splits. `fix first`: a failed or unrun check (step 2 or 7), an unresolved hit, or a finding in the first two classes (the spec lane's Critical and Important count). `rebase first`: `git -C <wt> rev-parse <baseref>` differs from `<merge-base>` and `git -C <wt> diff --name-only <merge-base> <baseref>` names a path the package also changed, or "base not refreshed" is reported; self-review never rebases. If `fix first` wins, still report a rebase need. A lane skip line is reported and does not change the verdict.
10. Propose lessons for `lessons` (unset: they stay in chat); write them only on yes.

## Inputs

Resolve each key with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`; exit 3 takes the table default. `detected` keys, `typecheck` and `lint` then try `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`. When both exit 3, ask, and never guess a command.

| Key | Default |
|---|---|
| `base_branch` | detected |
| `scope_threshold` | 4 files |
| `verify.fast`, `test.focused` | `typecheck` then `lint`; detected |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` |
| `review.builtin`, `review.builtin.self_effort`, `review.builtin.max_findings` | `on`, `low`, `15` |
| `spec.source`, `model.reviewer` | linked issue, PR body, `WORK/specs`; `sonnet` |

## Outputs

A chat report: the deterministic output, findings under Standards and Spec with `path:line`, the Declined to judge list, the verdict. A findings page only when kern's `visual` skill is installed, else say once "visual pages not installed".

## Stops and autopilot

Ask at each stop as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. Under autopilot a stop parks as `parked: <question>; default: <choice>; why: <one line>`: a failed fetch (origin exists) goes on with the last fetched ref; an unresolved command leaves its check failed and named. A missing base, a failed merge-base and any `wt-diff` non-zero exit end the run; lessons are not written.
