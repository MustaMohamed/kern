---
name: self-review
description: "Check your own diff before a PR: deterministic checks, blast radius, probes, a fresh doubt pass, then a verdict."
disable-model-invocation: true
---

# self-review

Find what your diff breaks beyond itself, and run every cheap check, before a PR. Reached by the kernel row for a review of your own diff before a PR, by finish-branch step 4, or typed as `/kern:self-review`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Scope. `<wt>` is the work's worktree, else the checkout root; `<base>` is `base_branch`. Run `git -C <wt> fetch origin <base>`; if it fails (no remote, offline), ask whether to use the last fetched `origin/<base>`, and report "base not refreshed". Run `git -C <wt> merge-base HEAD origin/<base>`: its output is `<merge-base>`; on failure stop, reporting its output. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base>`: line 1 is `<package>`, `<package>.patch` sits beside it, lines 3 on are the changed paths. Exit 3 is an empty diff: say there is nothing to review, and stop. Exit 2, a usage error or not a tree: stop and report.
2. Deterministic pass, pasting each command and its output. Resolve `verify.fast`, else `typecheck` and `lint`, and `test.focused` (on tests covering the changed paths). Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/floor-scan <package>` and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/claim-check <wt> <package>`. floor-scan exit 1 and claim-check exit 1 are hits, each fixed or justified in the report; any other non-zero exit is a failed check, as is a red `verify.fast` or test. A skipped check counts as failed (`references/claim-checks.md`).
3. Built-in lane: call the Skill tool with `code-review`, arguments always explicit: the worktree path as the target for worktree work, the effort from `review.builtin.self_effort`, and `--max-findings` from `review.builtin.max_findings`. Never pass `--comment` and never `--fix`. Unavailable, erroring or `review.builtin: off`: `skip: built-in code-review not available`.
4. Spec lane: the spec `spec.source` names, else this work's plan or `WORK/specs` file; a spec in a tracker or PR body is saved under `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`. Dispatch `kern:task-reviewer` on model `model.reviewer`, mode `whole-branch`, with absolute paths only: the spec (its Constraints are the Global Constraints), `<package>`, `<wt>`, the `review.rules` files; no report. Say the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus. Ask what is missing or partial, not asked for, or implemented but wrong, each quoting its spec line. No spec: `skip: no spec`.
5. Walk the `review.rules` files the diff touches, reading any not in context.
6. Blast radius, when a changed symbol has callers outside its directory or gates behaviour on a property (`references/blast-radius.md`): sweep every writer with `rg` and read each; look where grep stops; push the one fact the change is safe because of down to "ran it"; list Risks and Cleared apart.
7. Probes, with `<package>.patch` from step 1 and `<test>` the step 2 `test.focused` command on one test. A new guard test: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <package>.patch -- <test>`. A new conditional: one `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --mutate <file>:<line> <wt> -- <test>`, which mutates a throwaway fork, never the worktree. probe exit 1 (no failure, or the mutation survived) is a finding; probe exit 3 is reported inconclusive, never as a pass; probe exit 2 is a failed check.
8. Doubt cycle, for non-trivial decisions only (`references/doubt-cycle.md`): dispatch `kern:investigator` on model `model.reviewer` with one question, "where does this artifact fail this contract?", both absolute paths as scope, and never your claim or reasoning. Reconcile as that file says; at most 3 cycles.
9. Verdict, with findings in `review.taxonomy` classes and a "Declined to judge" list (each behaviour set aside as outside the spec, with why): `ready`, `fix first`, `rebase first` or `split`, the first that applies. `split`: more changed paths than `scope_threshold` that the spec or plan does not approve, or a finding in an earlier self-review round's fix. `fix first`: a failed check, an unresolved hit, a probe exit 1, or a finding in the two highest classes. `rebase first`: `git -C <wt> rev-parse origin/<base>` differs from `<merge-base>` and `git -C <wt> diff --name-only <merge-base> origin/<base>` names a path the package also changed; never rebases here. Else `ready`, never with "base not refreshed" reported.
10. Propose lesson candidates for `lessons` (unset: proposals stay in chat); write them only on yes.

## Inputs

Resolve each key with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`; unset takes the default. `base_branch`, `typecheck`, `lint` and `test.focused` then try `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`. When both exit 3, ask, and never guess a command.

| Key | Default |
|---|---|
| `verify.fast`, `test.focused` | `typecheck` then `lint`; detected |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` |
| `review.builtin`, `review.builtin.self_effort`, `review.builtin.max_findings` | `on`, `low`, `15` |
| `spec.source`, `model.reviewer` | linked issue, PR body, `WORK/specs`; `sonnet` |

## Outputs

A chat report: the deterministic output, findings under Standards and Spec with `path:line`, the Declined to judge list, the verdict. A findings page only when kern's `visual` skill is installed, else say once "visual pages not installed".

## Stops and autopilot

Ask at each stop as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. `fix first` or `split` stops finish-branch. Under autopilot a stop parks as `parked: <question>; default: <choice>; why: <one line>`: a failed fetch goes on with the last fetched ref; an unresolved command leaves its check failed and named; a trade-off is kept and listed. A missing base, a failed merge-base and `wt-diff` exit 2 or 3 end the run; lessons are not written.
