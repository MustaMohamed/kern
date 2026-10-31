---
name: self-review
description: "Check your own diff before a PR: deterministic checks, blast radius, probes, a fresh doubt pass, then a verdict."
disable-model-invocation: true
---

# self-review

A no-edit request skips no step: `<package>` goes under `kern-dir reviews`, not the user's files, and step 3 writes nothing. Only a request that names a check or lane skips it. A small diff, or a blocker already found, skips nothing: the fix round needs every failed check and unproven line.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that skill instead, say so in one line, and stop.
1. Scope. `<wt>` is the work's worktree, else the checkout root; `<base>` is `base_branch`. `git -C <wt> remote get-url origin` failing means no remote: `<baseref>` is local `<base>`, said once. Else `<baseref>` is `origin/<base>` after `git -C <wt> fetch origin <base>`; if the fetch fails, ask whether to use the last fetched one, and report "base not refreshed". `git -C <wt> merge-base HEAD <baseref>` prints `<merge-base>`; failure stops the run, output reported. `references/rounds.md` names `<package>` and what a later round adds. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <merge-base> --out <package>`: `<package>.patch` sits beside it, output lines 3 on are the changed paths. Exit 3 is an empty diff: say there is nothing to review, and stop; any other non-zero exit stops and reports.
2. Deterministic pass, pasting commands and output. Run `verify.fast` and step 7's `<test>` from `<wt>`, a `cd <wt>` as its own call first. Find the spec now, as step 4 says. With one, write `<package>.proofs.md` per `references/proofs.md`. No spec: no proofs are due. Run `floor-scan <package>` and `claim-check <wt> <package>`, adding `--spec <spec> --proofs <package>.proofs.md` with a spec: exit 1 from either is hits, and a proof line among them a failed check; any other non-zero exit, or a red `verify.fast` or test, is a failed check. On `proof-check: n/a`, check the table by reading. A skipped check counts as failed (`references/claim-checks.md`).
3. Built-in lane: call the Skill tool with `code-review`, explicit arguments: the worktree path as target, the effort from `review.builtin.self_effort`, `--max-findings` from `review.builtin.max_findings`. Never pass `--comment` and never `--fix`. Unavailable, erroring or `review.builtin: off`: `skip: built-in code-review not available`.
4. Spec lane: the spec `spec.source` names, else this work's plan or `WORK/specs` file; tracker or PR text goes under `kern-dir tmp`. Dispatch `kern:task-reviewer` on model `model.reviewer`, mode `whole-branch`, with absolute paths only: the spec (its Constraints are the Global Constraints), `<package>`, `<wt>`, the `review.rules` files; no report. Say the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus. No spec: `skip: no spec`. When a whole-branch review passed on this exact tree, `skip: spec lane, whole-branch review passed on <tree>`, `<tree>` being step 1's second output line. In the `kern-dir ledgers` ledger whose `Worktree:` path is `<wt>`, that needs `<ledger dir>/reviews/final.txt` to open `Spec given: <this spec> tree=<tree>` and say `Spec: compliant` and `Task quality: approved`, and the `Worktree:` line's base tree to equal `git -C <wt> rev-parse <merge-base>^{tree}`. Any mismatch: the lane runs.
5. Walk the `review.rules` files the diff touches, reading any not in context, then the smell baseline (`references/smells.md`).
6. Blast radius, when a changed symbol has callers outside its directory or gates behaviour on a property, or a manifest or lockfile changes: open `references/blast-radius.md`; read every writer `rg` finds; look where grep stops. Code moved into a shared piece: read every other reader of the old code; a copy left behind is a finding. Search every other reader for each moved element's class list, style object and literal props or strings (`references/blast-radius.md`).
7. Probes, with `<package>.patch` and `<test>`: `test.focused` with `{file}` or `{dir}` replaced by the one test file covering the change, no shell syntax. For each new guard test: `probe --exclude-tests <wt> <package>.patch -- <test>`. For a new conditional, one `probe --mutate <file>:<line> <wt> -- <test>`: `<file>` is relative to `<wt>`, `<line>` from the working file; probe inverts the first operator on that line, or drops a lone `!` when it has none, in a throwaway fork, never the worktree. Never mutate in a fork you make yourself: probe makes and removes its own, and its inconclusive exit fails the check as below. Only `probe: fail-then-pass ok` and `probe: mutation caught` pass; any other exit fails the check, except a new module or a test-only patch (`references/claim-checks.md`).
8. Doubt cycle, for non-trivial decisions only: open `references/doubt-cycle.md` before dispatching `kern:investigator` on model `model.reviewer`, and never send it your claim or reasoning; at most 3 cycles.
9. Verdict, once each step 2 command has its output pasted; run any missing one first. A finding is a defect on a changed line or at a caller or contract the change breaks: `path:line` and how it fails. Only a real defect the change did not cause goes under `pre-existing`; a `nit` is a real defect too small to block, naming how its line fails; a smell is a `nit`, its name the failure. Not findings: a change that keeps behaviour (a moved test, an equivalent helper or rename), churn, style or "unrelated" with no failure, or a justified step 2 hit (`bar-lowered`: only the user's typed yes), each under Cleared with its check, never `pre-existing`; a missing test, one line under the finding it would catch, else under `Untested`, which the verdict ignores; a probably-fine guess or a new export with no caller yet; a first-round split idea. A bug counts only with a caller path that reaches it, as `path:line` steps; none: Cleared as unreachable. Rule each finding: `fix` inside the spec's Never and Not doing lines, else `ticket` (offered, never filed), or `reject: <citation>`. List findings in `review.taxonomy` classes (ordered high to low), a "Declined to judge" list (outside the spec, and why), then one verdict, tested in order: `split`, `fix first`, `rebase first`, else `ready`. `split`: a later round, as `references/rounds.md` says. `fix first`: a failed or unrun check (step 2 or 7), an unresolved hit, or a finding in the first two classes (the spec lane's Critical and Important count). `rebase first`: `git -C <wt> diff --name-only <merge-base> <baseref>` names a path the package also changed, or "base not refreshed" is reported; self-review never rebases. If `fix first` wins, still report a rebase need. A finding with no ruling gives `fix first`. After fixes, a later round (`references/rounds.md`) runs every step, the checks the last skipped included, and re-checks the fix diff. A lane skip line is reported and does not change the verdict.
10. Propose lessons for `lessons` (unset: chat only); write them only on yes.

## Inputs

Resolve each key with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>`; exit 3 takes the table default. `detected` keys, `typecheck` and `lint` then try `kern-detect <key>`. When both exit 3, ask, and never guess a command.

| Key | Default |
|---|---|
| `base_branch`, `test.focused` | detected |
| `scope_threshold` | 4 files |
| `verify.fast` | each of `typecheck` and `lint` that resolves; at least one |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` |
| `review.builtin`, `review.builtin.self_effort`, `review.builtin.max_findings` | `on`, `medium`, `15` |
| `spec.source`, `model.reviewer` | linked issue, PR body, `WORK/specs`; `opus` |

## Outputs

A chat report: the deterministic output, findings under Standards and Spec, each ending in its ruling (`fix`, `ticket` or `reject: <citation>`), the Declined to judge list, the Cleared and `Untested` lists, the verdict. A findings page when kern's `visual` skill is installed, else say once "visual pages not installed".

## Stops and autopilot

Ask at each stop as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. Under autopilot a judgment call parks as `parked: <question>; default: <choice>; why: <one line>`: a failed fetch (origin exists) goes on with the last fetched ref; an unresolved command leaves its check failed and named. Any other stop brings the data and a recommendation, then waits for a typed reply: a missing base, any `wt-diff` non-zero exit. Lessons are not written.

Under autopilot, stops, unblocking and the run report follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md.
