# kern Opus audit, 2026-10-22: consolidated findings

HEAD 0c2d9dc on main. The seven lane reports (lane-A.md to lane-G.md) stay in the git-ignored audit workspace `.superpowers/sdd/2026-10-22-opus-audit/`; this file is the committed record. The visual page is https://claude.ai/artifact/QuqvQF7BCy3ypYP4cQkZeh.

ID prefixes: lane C's own IDs become `C-I1` to `C-I6` and `C-M1` to `C-M14`; lane B's numbered rows become `B1` to `B13`; lane F's mutation IDs become `F-H1`, `F-G20b`, `F-P2`, `F-K1` and so on; lane A's third mutation is `A-mut3`; lane B's first test gap is `B-T1`.

## 1. Totals

| Lane | Area | Critical | Important | Minor | Mutations run / caught / survived |
|---|---|---:|---:|---:|---|
| A | Guards | 0 | 5 | 10 | 7 / 5 / 2 (one survivor equivalent) |
| B | Session hooks, state, kernel, modes, agents | 0 | 2 | 11 | 1 / 0 / 1 (four kernel safety lines deleted together) |
| C | Plan and build skills and scripts | 0 | 6 | 14 | 14 / 8 / 6 |
| D | Debug, verify and ship skills and scripts | 0 | 8 | 12 | 6 / 3 / 3 |
| E | Context, writing and control skills | 0 | 3 | 11 | 12 / 8 / 4 |
| F | Tests, CI and lint | 0 | 2 | 12 | 43 / 27 / 15 (one more equivalent) |
| G | Eval harness | 0 | 4 | 10 | 14 / 9 / 5 |
| All, as reported | | 0 | 30 | 80 | 97 / 60 / 36 |

After dedup and re-grading: 0 Critical, 30 Important, 78 Minor, 108 findings.
- Merged: A12 into A4 (same fail-open read, same sentinel fix); E9 into B11 (the autopilot rules are worded three times and each wording drifts).
- Re-graded up: A11, Minor to Important. Under autopilot, `x='$(git push --force origin main)'; echo ${(e)x}` gets no vote from any guard, while the plain force push is denied. Rerun on a `git archive HEAD` copy; zsh runs the inner command.
- Re-graded down: A5, Important to Minor. On this machine the hook took 4.0 s at 40 substitutions and 7.75 s at 80, against lane A's 7 s and 19 s, so the 20 s timeout needs about 200 substitutions in one call. It fails closed.

Verification of the 31 Important rows (the 30 lane Importants plus A11): 28 CONFIRMED, 3 PLAUSIBLE (B2, C-I3, C-I4), 0 DOUBTFUL. After the re-grades the 30 Important findings are 27 CONFIRMED and 3 PLAUSIBLE.
- Rerun here: A1, A2, A3, A4 (stub awk), A5 (timing), A11, D8, E3, F2 (dash drops exported functions), plus evidence reads for C-I6, E1, F1, G1 and G3.
- Read at the cited lines: the rest.

Minor verdicts: 42 fix-now, 34 M3, 2 drop.

Packages: 20. P1 to P14 are before-run, P15 is before-release, P16 to P20 are M3. Two change kernel text (P11, P13).

Corrections to the lane reports:
- Lane B's "lossless" cut of the kernel's `Scripts:` line (83 chars) is not lossless. Skills, references and agents name kern scripts bare 103 times (`grep -rnoE` over skills, kernel and agents), and C-M9 plus lane D's prove-it note depend on that line. The real lossless cuts total about 250 to 300 chars, almost all from the three agent descriptions.
- Lane B says both kernel budgets have zero headroom. Only the standing cost (6,345 of 6,345) does. The subagent kernel is about 903 of 1,200 chars by lane B's own numbers, and the rendered kernel plus terse rules is about 7,640 to 8,080 of 9,000.
- Lane A's A5 timings are about 2.5 times what this machine measured; lane A's A11 is understated (above).
- Lane G's G1 evidence also confirms C-I6: in 2 of the 3 kern plan transcripts of 2026-10-22, the plan-review Agent call passed no `run_in_background`, so it ran in the background. The third passed `false`.

## 2. Important findings

Timing: `before-run` means the package edits code, text or harness that the confirming paid run loads or measures. Kernel, skills, hooks and the scripts the steps call all count, so any of those that ships in 0.4.0 must land before the run. `before-release` changes nothing the run loads. `M3` waits.

| ID(s) | Title | Where | Verdict | Package | Timing |
|---|---|---|---|---|---|
| A11 | zsh `${(e)x}` and bash `${x@P}` run a stored `$( )` that no guard reads; under autopilot a wrapped force push to main gets no vote | hooks/guards/g00-unproven.sh:226-240, 271-285 | CONFIRMED, rerun; re-graded from Minor | P1 | before-run |
| E3 | `kern_main_root` returns the git dir in a submodule or `--separate-git-dir` checkout, so the committed `.claude/kern.yml` (`never_commit`, `branch.protected`) is ignored and recall finds nothing | hooks/lib/settings.sh:6-11 | CONFIRMED, rerun (`worktree .../super/.git/modules/mod` against toplevel `.../super/mod`) | P2 | before-run |
| A1 | gh writes outside the listed verbs get no vote: `gh repo delete --yes`, `gist create --public`, `secret set`, `pr close`; spec D2 says autopilot denies them | hooks/guards/g02-pr.sh:33-53, g03-review.sh:29-36, g14-tracker.sh:211-227, g15-deploy.sh:74 | CONFIRMED, rerun (all `none` under autopilot) | P3 | before-run |
| A2 | `gh pr checkout` and `gh repo sync` change the main checkout with no vote; `git checkout feat` asks | hooks/guards/g01-git.sh:142-160 | CONFIRMED, rerun | P3 | before-run |
| A3 | `git restore .`, `checkout-index -a -f`, `read-tree -u --reset` discard main-checkout work with no vote; `git checkout .` asks | hooks/guards/g01-git.sh:350-367 | CONFIRMED, rerun | P3 | before-run |
| A4 = A12 | A failed `git_words` parse, or an empty command capture, votes nothing outside autopilot; spec 8.4 rule 4 says ask | hooks/lib/gitctx.sh:543, 566, 748; g01-git.sh:42-46 | CONFIRMED, rerun (stub awk: `git reset --hard HEAD~3` in main gives none interactively) | P3 | before-run |
| C-I2 | A task test script that `cd`s to the worktree's absolute path runs the "reversed" probe in the real worktree, so a correct task reads as unproven | scripts/probe:78, 117, 122; agents/implementer.md:17 | CONFIRMED (code; lane repro) | P4 | before-run |
| D1 | probe reads a missing-name error in the reversed fork (TypeError, NameError, ReferenceError, Rust `cannot find`) as a guard failure and prints `fail-then-pass ok` | scripts/probe:126-131 | CONFIRMED (blocked list lacks them) | P4 | before-run |
| D2 | `--exclude-tests` reverses fixtures, `testdata/`, snapshots and golden files, so a test that fails only for lost data passes the probe | scripts/lib/test-paths.awk:4, scripts/probe:49-61 | CONFIRMED | P4 | before-run |
| G1 | h2h grades kern's plan from its first Write; later Edits to `.kern/plans/` never reach the grader | scripts/h2h.mjs:80, scripts/lib/claude-run.mjs:60 | CONFIRMED (3 kern transcripts: 4, 2 and 3 Edits after the Write) | P5 | before-run |
| G2 | h2h grader counters are not validated: `"decoys": 2` gives 0 false alarms, `"unmatched": "2"` gives `"02"` | scripts/lib/h2h.mjs:88-113, 219-227 | CONFIRMED | P5 | before-run |
| G3 | A filtered, partial or all-VOID behave or h2h run overwrites the day's snapshot and key.json | scripts/behave.mjs:34-38, 76; scripts/h2h.mjs:102-107 | CONFIRMED (the 2026-10-22 h2h snapshot holds only review/invoice-branch; 157 diagnose and plan transcripts exist) | P5 | before-run |
| G4 | Unknown or valueless flags are ignored, so `--dryrun` or `--case=x` starts a full paid run | scripts/behave.mjs:16-22, scripts/h2h.mjs:21-28, scripts/kernel-adherence.mjs:18-22 | CONFIRMED | P5 | before-run |
| F1 | GitHub CI is red on every push since 0.3.0: billing stops most runs, and the one that started fails 2 Linux-only unit tests, skipping every later Ubuntu step | .github/workflows/ci.yml; tests/behave.test.mjs:665; tests/exec-eval.test.mjs:1410 | CONFIRMED (`gh run view 39803282404`, `39693866048`) | P5 (tests), P15 (CI), decision 2 | before-release |
| D8 | claim-check exits 0 when awk aborts (UTF-8 locale and a Latin-1 byte) and on non-diff input | scripts/claim-check:10-61 | CONFIRMED, rerun (exit 0 under en_US.UTF-8, exit 1 under C) | P6 | before-run |
| C-I6 | plan's gating review omits `run_in_background: false` and runs in the background | skills/plan/SKILL.md:25 | CONFIRMED (2 of 3 kern plan transcripts) | P7 | before-run |
| C-I5 | The ledger is keyed by the plan path only; a plan re-approved in place reuses old `Task N: complete` lines | scripts/ledger-open:90-95, skills/plan/SKILL.md:15 | CONFIRMED | P7 | before-run |
| C-I1 | wt-new bases only on a fresh `origin/<base>`: a local base ahead of origin gives a stale worktree with no warning, and no reachable origin fails every worktree | scripts/wt-new:62-73 | CONFIRMED (this repo is 200 ahead of origin/main, and SSH has no key) | P8 | before-run |
| D5 | With `pr.template` set, the no-attribution-footer rule is never read, and no guard checks a PR body | skills/finish-branch/references/push-and-pr.md:19, pr-body.md:3 | CONFIRMED | P9 | before-run |
| D3 | A smell may be `should-fix`, and `should-fix` gives `fix first`, so a judgement call stops finish-branch | skills/self-review/SKILL.md:22, references/smells.md:7 | CONFIRMED | P10 | before-run |
| D4 | In a later round any finding on an added line, a nit included, gives `split` | skills/self-review/references/rounds.md:15 | CONFIRMED | P10 | before-run |
| D6 | kern-detect gives a bun project `bun test`, which runs bun's own runner, not `scripts.test` | scripts/kern-detect:45-49 | CONFIRMED | P10 | before-run |
| D7 | self-review step 2 never says to run `verify.fast` and the focused test in `<wt>` | skills/self-review/SKILL.md:15 | CONFIRMED (the text omits it; the wrong-tree run is inferred) | P10 | before-run |
| B2 | A codebase question that changes nothing matches no row, and the fallback sends "non-trivial work" to plan, which bounces to define | kernel/kernel.md:18 | PLAUSIBLE (text supports it; needs a model run) | P11 | before-run |
| B1 | `overrides.<job>: off`, a documented value, renders as "project skill off" | hooks/lib/render.sh:108-114 | CONFIRMED | P13 | before-run |
| E1 | recall-sessions slugs bytes, Claude Code slugs UTF-16 code units and cuts at 200 chars plus a hash, so non-ASCII and long paths find no sessions and exit 0 | scripts/recall-sessions:59 | CONFIRMED (Claude Code 2.1.308 binary: `function k(e){return e.replace(/[^a-zA-Z0-9]/g,"-")}`, `J0` with `K_e`) | P14 | before-run |
| E2 | recall skips the newest transcript as "usually this one"; a second active session in the project gets skipped instead | skills/recall/SKILL.md:16, references/transcripts.md:7 | CONFIRMED (`CLAUDE_CODE_SESSION_ID` is set in Bash) | P14 | before-run |
| F2 | `run-bats --jobs` runs bats through `sh -c`; dash drops exported functions, so nested bats breaks on Ubuntu | tests/run-bats:50 | CONFIRMED (`/bin/dash` drops an exported function, `/bin/sh` keeps it) | P15 | before-release |
| C-I3 | After compaction, resume re-dispatches a wave worker whose fork is still unchanged, putting two writers in one fork | skills/execute-plan/references/resume.md:13 | PLAUSIBLE (text supports it; needs a compaction mid-wave) | P16 | M3 |
| C-I4 | Wave integration applies `<package>.patch` with nothing tying it to the completed tree; after fix rounds the round-1 patch can win | skills/execute-plan/SKILL.md:29-30, references/resume.md:10, scripts/wt-apply | PLAUSIBLE (the script gap is real; the wrong pick needs a run) | P16 | M3 |
| A5 | Each guard parses again, so hook time grows with each `$( )`; past the 20 s timeout the call is blocked | hooks/guards/g01-git.sh:44, g05-commit.sh:29, g06-secrets.sh:117 | CONFIRMED, overstated; re-graded Minor | P20 | M3 |

## 3. Fix packages, ranked

Payoff is risk removed per implementer hour. Security and fail-open items first, then what the paid run depends on, then wrong behaviour users hit.

| Rank | ID | Name | Findings | Size | Timing | Kernel text | Order |
|---:|---|---|---|---|---|---|---|
| 1 | P1 | Guard holes: stored-string re-evaluation, settings paths, approval-gate tests | A11, A9, A13, F-G20b, F-H1 | M | before-run | no | none |
| 2 | P2 | Main root in submodules and separate git dirs | E3 | M | before-run | no | before P13, P14 |
| 3 | P3 | gh and git write coverage; fail closed on an unread parse | A1, A2, A3, A4 = A12, A6, A7 | L | before-run | no | before P9 |
| 4 | P4 | probe proves what it claims | C-I2, D1, D2, D9, F-P2 | M | before-run | no | none |
| 5 | P5 | Eval harness correctness for the confirming run | G1, G2, G3, G4, G5, G7, G9, G10, G11, G13, F1 tests | L | before-run | no | before P15 |
| 6 | P6 | Review scanners fail closed | D8, D15, D10, D20, C-M4 comment, F-T3 | M | before-run | no | none |
| 7 | P7 | Plan review in the foreground; ledger bound to the plan | C-I6, C-I5, C-M1, C-M2, C-M3 | M | before-run | no | after P8 if both |
| 8 | P8 | wt-new base: local ahead, fetch errors, include loop | C-I1, C-M5, C-M6 | M | before-run | no | before P7 |
| 9 | P9 | Commit and PR message checks | D5, D12, D11, A-mut3, F-H6 | M | before-run | no | after P3 |
| 10 | P10 | Self-review verdicts and proof surface | D3, D4, D7, D6, D16, D19 | M | before-run | no | before P13 |
| 11 | P11 | Kernel text: pins, cuts, question fallback, precedence | B2, B5, B3, C-M9, B-T1 = F-K1, F-K2 | M | before-run | yes | before P17 |
| 12 | P12 | Per-prompt hook text and prompt hashing | B4, B9, B10, B11 = E9 (B11 part) | M | before-run | no (per-prompt text) | before P18 |
| 13 | P13 | Settings block render | B1, B6, B7, B8 | M | before-run | yes (the rendered settings block) | after P2, P10 |
| 14 | P14 | Recall finds the right sessions | E1, E2, E4, E5, E14 | M | before-run | no | after P2; before P18 |
| 15 | P15 | CI green and honest | F1 (with P5 and decision 2), F2, F3, F4, F5, F6, F13 | M | before-release | no | after P5; before P17 |
| 16 | P16 | Resume and wave integration | C-I3, C-I4, C-M14 | M | M3 | no | none |
| 17 | P17 | Lint soundness | F7, F8, F9, F10, F12, F14, F-L3, F-L4, F-L5, F-RE1 | M | M3 | no | after P11, P15 |
| 18 | P18 | Control and help text | E6, E7, E8, E9, E10, E11, E12, E13 | M | M3 | no | after P12, P14 |
| 19 | P19 | Diagnose and finish text | D13, D14, D17, D18 | M | M3 | no | after P9 |
| 20 | P20 | Guard speed: one parse per call; hook suite split | A5, lane F speed items | L | M3 | no | after P1, P3, P9 |

Shared files, and the order that keeps them serial:
- `hooks/guards/g02-pr.sh` and `tests/hooks/g02-g04-gh.bats`: P3, then P9.
- `hooks/lib/settings.sh` and `tests/hooks/settings.bats`: P2, then P13 only if P13 drops `route.<name>` from the known keys.
- `kernel/settings.md`: P10 (row 41), then P13 (rows 90-91).
- `scripts/lib/lint-rules.mjs`: P11 (rule 7 limits), then P17.
- `tests/lint-rules.test.mjs`, `tests/route-eval.test.mjs`: P15 (temp-dir cleanup), then P17.
- `skills/technical-writing/SKILL.md`: P12 (step 0), then P18 (E7).
- `skills/recall/SKILL.md`: P14, then P18.
- `skills/commit/SKILL.md`: P9, then P19 (D14).
- `scripts/lib/wt-common.sh`: P8 edits it; P7 only calls `wt_exclude_dir` from it, so P8 first.
- Every guard file: P1, P3 and P9 before P20.

### P1. Guard holes: stored-string re-evaluation, settings paths, approval-gate tests

Findings: A11, A9, A13; tests for F-G20b and F-H1.
Files: hooks/guards/g00-unproven.sh, hooks/guards/g16-state.sh, tests/hooks/g00-unproven.bats, tests/hooks/g16-state.bats, tests/hooks/g20.bats, tests/hooks/pre-tool-use.bats.
Fix sketch:
- A11: in `_G00_AWK`, flag a zsh parameter flag group that holds `e` (`${(e)x}`, `${(Le)x}`) and the bash `@P` transform, the way `g0_sqsub` flags the arithmetic builtins. Autopilot denies with "re-evaluates a stored string".
- A9: add `${CLAUDE_CONFIG_DIR}/settings.json` to `_g16_file` and `_g16_name` when the variable is set.
- A13: lower-case all candidates in one `env LC_ALL=C tr` pass that ends with a sentinel line; a missing sentinel denies.
Tests to add:
- autopilot deny for `x='$(git push --force origin main)'; echo ${(e)x}` and `${x@P}`; `${(L)x}` and `${x@Q}` get no vote;
- Write and `>` redirect to `$CLAUDE_CONFIG_DIR/settings.json` ask, and deny under autopilot;
- a failing `tr` (the `read_fails` helper) denies a state-file Write;
- G20: a quoted yes ending in `?` ("Yes, go ahead?") is denied;
- dispatcher: an ask beats a later allow.
Run: `bash tests/run-bats tests/hooks/g00-unproven.bats`, `g00-arithmetic.bats`, `g16-state.bats`, `g20.bats`, `g20-probes.bats`, `pre-tool-use.bats`.
Size M. before-run: the guards run on every eval Bash call. No kernel text.

### P2. Main root in submodules and separate git dirs

Findings: E3 (root cause in lane B's file; it disables lane A's settings-driven guards in such repos).
Files: hooks/lib/settings.sh, tests/hooks/settings.bats, tests/scripts/kern-dir.bats.
Fix sketch: in `kern_main_root`, when the first `worktree` path holds no `.git` entry, it is a git dir. Use that git dir's `core.worktree` (set for submodules). Otherwise, from a checkout that is not a linked worktree, use `git rev-parse --show-toplevel`. Otherwise return 2. `_settings_walk_root` already reads submodules this way and can be the model.
Tests to add: `kern-get never_commit` and `kern-get branch.protected` read a submodule's committed `.claude/kern.yml`; the same for a `--separate-git-dir` checkout; `kern-dir` writes under the submodule checkout, not under `.git/modules`; a plain repo and a linked worktree are unchanged. Both bashes.
Run: `bash tests/run-bats tests/hooks/settings.bats`, `tests/scripts/kern-dir.bats`, `tests/hooks/git-refused.bats`, `tests/hooks/session-start.bats`.
Size M. before-run: every hook resolves settings through this function. No kernel text.

### P3. gh and git write coverage; fail closed on an unread parse

Findings: A1, A2, A3, A4 = A12, A6, A7.
Files: hooks/guards/g01-git.sh, hooks/guards/g02-pr.sh, tests/hooks/g01-git.bats, tests/hooks/g02-g04-gh.bats.
Fix sketch:
- A1: in G2, give each `_GH_CMDS` group a closed read-verb list (view, list, status, diff, checks, search and the like). Any other verb of a known group that no other guard owns asks, and autopilot denies it. G2, G3, G14 and G15 keep their own verbs. Keep `auth status`, `pr list` and `pr view` allowed, since kern's skills and the exec gh stub use them.
- A2: in `_g01_gh`, send `pr checkout` and `repo sync` without a repository operand through `_g01_main_op`.
- A3: add `restore` (any form that touches the worktree), `checkout-index` with `-f` and `read-tree` with `-u` or `--reset` to `_g01_main_op`.
- A6: ask on `branch -f`, `-M` or `-C` onto a `branch_protected` name, and on `update-ref` of a protected `refs/heads/` ref.
- A7: ask on `stash clear` and `stash drop` in any worktree.
- A4 = A12: G1 reads `git_words` with an end sentinel inside the same substitution. A missing sentinel, an empty Bash command or a `$KERN_UNREAD` record calls `fail_closed` in every mode.
Tests to add: a table driven from `_GH_CMDS` that gives each group a write verb and expects ask, or deny under autopilot; the five main-checkout discards in both modes; protected-branch rewrites; stash clear from a linked worktree; an interactive parse failure with a stub awk asks.
Run: `bash tests/run-bats tests/hooks/g01-git.bats`, `g02-g04-gh.bats`, `ship-commands.bats`, `git-hardening.bats`, `aliases.bats` (about 3 minutes; its corpus test compares decisions across aliases).
Size L. before-run: exec cases run gh under autopilot through these guards. No kernel text. Decision 5 picks the interactive behaviour.

### P4. probe proves what it claims

Findings: C-I2, D1, D2, D9; test for F-P2.
Files: scripts/probe, scripts/lib/test-paths.awk, tests/scripts/claim-probe.bats.
Fix sketch:
- D1: match the blocked list case-insensitively and add the missing-name errors: `is not a function`, `is not defined`, `NameError`, `has no attribute`, `cannot find (function|value|type)`, `unresolved import`, `could not compile`, `NoMethodError`, `uninitialized constant`, `cannot find '.*' in scope`, `Unresolved reference`, `undeclared identifier`. Keep the list narrow: a plain `TypeError` can be a real assertion. Print the last five lines of `without.log` beside the `ok` line.
- D2: add `is_probe_keep(p)` to test-paths.awk: `is_test` plus `testdata/`, `fixtures/`, `__fixtures__/`, `__snapshots__/`, `*.snap` and `*.golden`. probe excludes those; floor-scan keeps `is_test`.
- C-I2: before the reversed run, exit 3 when an argument word, or the text of a readable file an argument names, holds the worktree's absolute path.
- D9: refuse a `--mutate` path that is absolute, holds a `..` part, or resolves through a symlink outside the fork.
Tests to add: lane D's TypeError repro and golden-file repro, lane C's absolute-`cd` script, the `--mutate` symlink and `../` cases, and each zero-test marker (`No tests found`, `collected 0 items`, `Ran 0 tests`, `no tests ran`).
Run: `bash tests/run-bats tests/scripts/claim-probe.bats`, `tests/scripts/task-done.bats`, `tests/scripts/floor-scan.bats`.
Size M. before-run: execute-plan's task-done and implement call probe. A new export now reads as inconclusive, which execute-plan step 10 already routes to `--no-probe`.

### P5. Eval harness correctness for the confirming run

Findings: G1, G2, G3, G4, G5, G7, G9, G10, G11, G13; F1's two Linux-only test failures.
Files: scripts/h2h.mjs, scripts/lib/h2h.mjs, scripts/behave.mjs, scripts/kernel-adherence.mjs, scripts/lib/exec-run.mjs (or a new scripts/lib/args.mjs), scripts/lib/claude-run.mjs, scripts/lib/exec-grade.mjs, tests/h2h.test.mjs, tests/behave.test.mjs, tests/adherence.test.mjs, tests/exec-eval.test.mjs.
Fix sketch:
- G1: before `rmSync`, read the final contents of every changed or ignored file (`git status --porcelain --ignored --untracked-files=all`) and give them to the grader; drop the Write-input list.
- G2: `matched`, `decoys` and `extras` must be arrays of the key's label ids, and `unmatched` and `unsupported` non-negative integers; anything else VOIDs the task-run. Count decoy hits by label kind across all lists.
- G3: behave and h2h write the committed snapshot only for a full, unfiltered run; otherwise beside the transcripts, as adherence does. Add `complete` and `cases` fields, and merge key.json.
- G4: share exec-run's `parseArgs` with a per-runner flag table; reject unknown or valueless flags and a non-numeric `--runs`.
- G5: adherence passes a case with `caseResult`.
- G7: `messageFiles` reads only Bash calls whose result is not an error.
- G9: `env: childEnv(process.env)` for the heldout tests and floor-scan; VOID on a floor-scan exit other than 0 or 1.
- G10: VOID a run whose `init.plugins` lacks the arm's plugin or whose SessionStart failed; for neg-kern-off, assert kern is absent.
- G11: record `git rev-parse HEAD` and a dirty flag in every snapshot, and refuse a dirty tree for a gating run unless a flag overrides.
- G13: catch each arm's git calls; a failure VOIDs that task-run only.
- F1: tests/behave.test.mjs:665 also accepts git's "Stopping at filesystem boundary"; tests/exec-eval.test.mjs:1410 normalises `SHLVL`.
Tests to add: a stub-runner seam for behave, h2h and kernel-adherence, as exec has, with tests for G1, G3, G4 and G5; malformed grader replies (lane G's table); arg-parser cases; G7's failed `-F` then `-m` commit; G10's missing plugin.
Run: `node --test tests/h2h.test.mjs tests/behave.test.mjs tests/adherence.test.mjs tests/exec-eval.test.mjs tests/pilot.test.mjs tests/behave-fixtures.test.mjs tests/standing-cost.test.mjs`, then each runner with `--dry-run`.
Size L. before-run: the run depends on it. Lane G says G1 to G4 must land first; G9 to G11 are cheap and make the run's numbers attributable.

### P6. Review scanners fail closed

Findings: D8, D15, D10, D20, the C-M4 header comment, F-T3.
Files: scripts/claim-check, scripts/lib/floor-scan.awk, scripts/wt-diff, tests/scripts/claim-check.bats (new), tests/scripts/floor-scan.bats, tests/scripts/wt-snap-diff.bats.
Fix sketch:
- D8: run awk as `env LC_ALL=C awk`, write candidates to a temp file and check awk's status, and exit 2 on input with no `diff --git` line. That is addy's "never let a 2 read as a 0", which floor-scan already follows.
- D15: skip doc files for the absolute-word check (floor-scan's `is_doc`), or accept only `<!--` comments there.
- D10: floor-scan.awk reads `rename from` and `rename to`, and flags a test path renamed to a non-test path.
- D20: the three porcelain `git diff` calls in wt-diff add `--no-textconv --src-prefix=a/ --dst-prefix=b/`.
- C-M4: fix the glob example in wt-diff's header.
Tests to add, in a new claim-check.bats so P4 keeps claim-probe.bats: a UTF-8 locale abort exits 2; non-diff input exits 2; the three surviving mutations (`0x`, the a-f rule, the comment gate); a Markdown heading is not a hit. floor-scan.bats: `foo.test.js` renamed to `foo.test.js.disabled`. wt-snap-diff.bats: `diff.dstPrefix=new/` set.
Run: `bash tests/run-bats tests/scripts/claim-check.bats`, `tests/scripts/floor-scan.bats`, `tests/scripts/wt-snap-diff.bats`, `tests/scripts/claim-probe.bats`, and `node --test tests/seeded-diffs.test.mjs`.
Size M. before-run: self-review step 2 runs both scanners in the finish-branch exec cases.

### P7. Plan review in the foreground; ledger bound to the plan

Findings: C-I6, C-I5, C-M1, C-M2, C-M3.
Files: skills/plan/SKILL.md, scripts/ledger-open, scripts/task-brief, tests/scripts/ledger.bats, tests/scripts/task-brief.bats (new), tests/skills/plan.test.mjs.
Fix sketch:
- C-I6: plan step 11's review passes `run_in_background: false` (29 bytes). plan is at 6,497 of 6,500 bytes; trim "(no issue id: the slug or title words)" in step 1 or the autopilot-signal sentence four skills repeat.
- C-I5: ledger-open writes `Plan: <git hash-object of the plan>` into a new ledger's header. A mismatch exits 2: "the plan changed since this ledger opened; pass another DIR". plan step 1 says an approved plan goes back to `status: draft` before any edit, paid by the same trim.
- C-M1: task-brief uses plan-check's `fence_run` rule in both awk programs.
- C-M2: `Main:` records `head=<sha>`, and `--summary` compares it.
- C-M3: ledger-open runs `wt_exclude_dir` for `worktree.dir` before it records `Main:`.
Tests to add: a changed plan meets its old ledger and exits 2; a commit on the main checkout reads `main: changed`; an untracked worktree dir gives no false alarm; a `~~~` fence holding a backtick line keeps Task 2; a pin for `run_in_background: false` in plan.
Run: `bash tests/run-bats tests/scripts/ledger.bats`, `tests/scripts/task-brief.bats`, `tests/scripts/plan-check.bats`, `tests/scripts/task-done.bats`; `node --test tests/skills/plan.test.mjs tests/skills/execute-plan.test.mjs`; `node scripts/lint-skills.mjs`.
Size M. before-run: h2h's plan category and the execute-plan workflow case read this text.

### P8. wt-new base: local ahead, fetch errors, include loop

Findings: C-I1, C-M5, C-M6.
Files: scripts/wt-new, scripts/lib/wt-common.sh, tests/scripts/wt-new.bats.
Fix sketch:
- C-I1: after the fetch, when `refs/heads/<name>` exists and `git rev-list --count origin/<name>..<name>` is above 0, exit 2: "local <name> is N commits ahead of origin/<name>; push, or pass --base <sha>". Let `--plan` take a `--base <sha>` override. execute-plan step 5 already says "Exit 2: say why and ask".
- C-M5: fetch `+refs/heads/<name>:refs/remotes/origin/<name>` so a single-branch clone works, and print the fetch's last stderr line on failure.
- C-M6: `wt_include` refuses a `.worktreeinclude` entry that is a parent of `worktree.dir`, with a message.
Tests to add: local ahead exits 2 with the count; `--plan` with `--base <sha>`; a single-branch clone with another base; an unreachable origin shows git's reason; `.worktreeinclude` holding `.claude/`.
Run: `bash tests/run-bats tests/scripts/wt-new.bats`, `tests/scripts/wt-fork-apply.bats`, `tests/scripts/task-done.bats`, `tests/scripts/ledger.bats`.
Size M. before-run: the execute-plan and parallel-work workflow cases make worktrees. Check first that no eval fixture has a local base ahead of its origin. In this repo every plan worktree will exit 2 until main is pushed (over HTTPS) or `--base` is passed. Decision 6 confirms the rule.

### P9. Commit and PR message checks

Findings: D5, D12, D11; tests for A-mut3 and F-H6.
Files: hooks/guards/g05-commit.sh, hooks/guards/g02-pr.sh, skills/finish-branch/references/push-and-pr.md, skills/finish-branch/references/pr-body.md, skills/commit/SKILL.md, tests/hooks/g05-g06-commit.bats, tests/hooks/g02-g04-gh.bats, tests/skills/finish-branch.test.mjs, tests/skills/commit.test.mjs.
Fix sketch:
- D5: move the no-attribution sentence from pr-body.md into push-and-pr.md's PR section, so a `pr.template` body gets it too. G2 reads a `--body-file` and denies an attribution footer or trailer under `commit.attribution: none`, with G5's matcher.
- D12: G5's matcher reads only trailer lines (`^[A-Za-z-]+: ` in the last paragraph) and the exact Claude Code footer line, so "generated by Claude" in prose passes.
- D11: commit step 5 resolves `commit.convention` with `kern-get`, then `kern-detect`, names the regex, and allows one retry whose subject matches it.
Tests to add: a prose mention passes; a trailer and the footer are denied; a PR body file with the footer is denied; lane A's survivor (an autopilot `git commit -m "feat: add x $EXTRA"` in one record is denied, and `${EXTRA}` too); one secret sample per `_G06_RULES` entry, driven from the table.
Run: `bash tests/run-bats tests/hooks/g05-g06-commit.bats`, `tests/hooks/g02-g04-gh.bats`, `tests/hooks/ship-commands.bats`; `node --test tests/skills/finish-branch.test.mjs tests/skills/commit.test.mjs tests/exec-eval.test.mjs`.
Size M. before-run: the commit and finish-branch exec cases grade attribution. After P3 (g02-pr.sh).

### P10. Self-review verdicts and proof surface

Findings: D3, D4, D7, D6, D16, D19.
Files: skills/self-review/SKILL.md, skills/self-review/references/rounds.md, skills/self-review/references/smells.md, skills/prove-it/SKILL.md, kernel/settings.md (row 41), scripts/kern-detect, tests/skills/self-review.test.mjs, tests/skills/self-review.acceptance.md, tests/skills/prove-it.test.mjs, tests/scripts/kern-detect.bats.
Fix sketch:
- D3: step 9 "a smell is a `nit`" (shorter than today's clause); smells.md "in the `nit` class". Acceptance: "A smell alone leaves the verdict `ready`."
- D4: rounds.md: `split` holds when the size rule holds, or when a `blocker` or `should-fix` finding lands on a line the previous round's findings asked to change.
- D19: "a missing test no finding covers: one line under `Untested`, not a finding; the verdict ignores it", with an Outputs slot. Pay with step 9's restated `rebase first` test.
- D7: step 2 runs `verify.fast` and step 7's `<test>` from `<wt>`, a `cd <wt>` as its own call first.
- D16: the default becomes "each of `typecheck` and `lint` that resolves; at least one", in self-review, prove-it and settings.md:41.
- D6: kern-detect prints `bun run test` for bun's `test` key.
Bytes: self-review is 6,990 of 7,000 and prove-it 3,797 of 3,800; the package must be net zero or less in each.
Tests to add: acceptance lines for D3, D4 and D19; string pins for D7 and D16; kern-detect bun and yarn rows.
Run: `node --test tests/skills/self-review.test.mjs tests/skills/prove-it.test.mjs tests/skills/finish-branch.test.mjs`; `bash tests/run-bats tests/scripts/kern-detect.bats`; `node scripts/lint-skills.mjs`.
Size M. before-run: finish-branch exec cases run self-review. Decision 7 confirms the verdict rules.

### P11. Kernel text: pins, cuts, question fallback, precedence

Findings: B2, B5, B3, C-M9; B-T1 = F-K1, F-K2.
Files: kernel/kernel.md, kernel/kernel-subagent.md, agents/implementer.md, agents/investigator.md, agents/task-reviewer.md, skills/implement/SKILL.md, tests/kernel.test.mjs, tests/agents.test.mjs, tests/skills/implement.test.mjs, scripts/lib/lint-rules.mjs (rule 7 limits only), evals/adherence/cases.json.
Fix sketch, in commit order:
1. Pin the safety lines first: every Autonomy line, "Inconclusive is not a pass.", the consent line, "Only the user starts it, with /kern:autopilot on.", Learning, and the subagent Autonomy line.
2. Cut the three agent descriptions to role plus "kern only" (about 250 chars), with tests/agents.test.mjs updated. Keep the `Scripts:` line: 103 bare script names depend on it.
3. B5: "Only policy keys may set auto or deny." becomes "Only a policy key loosens an ask to auto."
4. B2: "only a casual turn or a question that changes nothing matches nothing: answer it, reading what you need" and "A non-trivial change with no match: plan." About 35 chars more. Add a negative adherence case such as "How does money() in src/format.js round?" with `route: null`.
5. B3: "Precedence: your agent definition and the brief, then the project's CLAUDE.md and rules (they only tighten), then kern steps" and "Never merge or message anyone; commit, push or post only when the brief says so." The subagent budget has about 297 chars free.
6. C-M9: implement step 3 spells `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect <key>`; the subagent kernel has no Scripts line.
7. Set rule 7's limit to the new measured standing cost (decision 3).
Net standing cost: about 215 chars less.
Tests to add: the pins; the new adherence case; implement's spelled path.
Run: `node --test tests/kernel.test.mjs tests/agents.test.mjs tests/skills/implement.test.mjs tests/lint-rules.test.mjs tests/standing-cost.test.mjs tests/adherence.test.mjs`; `node scripts/lint-skills.mjs`; `node scripts/kernel-adherence.mjs --dry-run`; `bash tests/run-bats tests/hooks/session-start.bats`, `tests/hooks/subagent-start.bats`.
Size M. before-run, kernel text: it changes routing, so the paid run must come after it. Decisions 1 and 3.

### P12. Per-prompt hook text and prompt hashing

Findings: B4, B9, B10, and B11 (the hook's part of B11 = E9).
Files: hooks/prompt-submit, hooks/lib/state.sh, skills/technical-writing/SKILL.md, tests/hooks/prompt-submit.bats, tests/hooks/state.bats, tests/skills-writing.test.mjs.
Fix sketch:
- B4: the reminder becomes "kern: new request? Match it against the Routing table; Read its route, or the override named for its job, first." That is about 30 chars more per prompt. technical-writing gets the step 0 Defer every other route has.
- B9: `prompt_hashes` starts with `if (length($0) > 20000) next`.
- B10: a failed `state_set` on `/kern:autopilot on` sets `NOTICE="kern: autopilot not turned on: the session state could not be written; retry."`.
- B11: the autopilot line says "commit on a non-protected branch with ..." and "no unparseable shell script, no code piped to a shell".
Tests to add: the reminder text; a mode-000 state file gives the notice; a 3 MB single-line prompt finishes under 2 s; the autopilot line pins.
Run: `bash tests/run-bats tests/hooks/prompt-submit.bats`, `tests/hooks/state.bats`, `tests/hooks/g20.bats` (G20 reads the prompt hashes); `node --test tests/skills-writing.test.mjs`.
Size M. before-run: per-prompt routing text that every multi-turn case sees. No kernel.md change, but it costs about 30 chars per prompt.

### P13. Settings block render

Findings: B1, B6, B7, B8.
Files: hooks/lib/render.sh, kernel/settings.md, tests/hooks/session-start.bats; hooks/lib/settings.sh and tests/hooks/settings.bats only if `route.*` leaves the known keys.
Fix sketch:
- B1: `overrides.<job>: off` drops the job's Overrides entry and its same-name detection.
- B6: unknown keys stay out of `Set:`; a value equal to a literal default is skipped.
- B7: cap the whole block at 600 chars. Cut the Unknown list first ("and N more"), and keep `*.policy` entries first in `Set:`.
- B8: drop `route.<name>`, or render it into the Overrides line (decision 4).
- Print `Main worktree: <path>` only when the session's cwd is not the main root (lane B's cut, about 70 chars in a typical session).
Tests to add: `off` with and without a project skill of that name; 25 routes and 60 unknown keys stay under 600 with `push.policy=deny` kept; a typo key is not under `Set:`.
Run: `bash tests/run-bats tests/hooks/session-start.bats`, `tests/hooks/settings.bats`; `node --test tests/kernel.test.mjs tests/lint-rules.test.mjs`.
Size M. before-run, kernel text: the block is part of the rendered kernel, and neg-project-skill reads the Overrides line. After P2 and P10.

### P14. Recall finds the right sessions

Findings: E1, E2, E4, E5, E14.
Files: scripts/recall-sessions, skills/recall/SKILL.md, skills/recall/references/transcripts.md, tests/scripts/recall-sessions.bats, tests/skills/recall.test.mjs.
Fix sketch:
- E1: slug per character in a C-locale awk. A 2- or 3-byte UTF-8 sequence becomes one `-`, a 4-byte one `--`, any other non-alnum byte `-`. Above 200 chars, glob `<first 200>-*` and keep the folder whose first transcript's `cwd` equals the path. NFD paths are a stated limit.
- E2: recall-sessions marks the session whose id is `CLAUDE_CODE_SESSION_ID` as `current`; step 4 and transcripts.md say "skip the `current` session". In a subagent the variable holds the parent session's id, which is the one to skip.
- E4: `WORK` is line 1 of `kern-root`, a `/`, then `kern-get work_dir .kern`; this frees 137 of recall's 7,200 bytes.
- E5: `--days 0` is a usage error.
- E14: step 6 names `kern-get`, then `kern-detect tracker`.
Tests to add: `é`, a 3-byte character, an emoji and a 210-char path, with the expected slug from a JS-equivalent function rather than the same `tr`; the `current` marker; `--days 0`; a submodule after P2; recall.test.mjs pins updated.
Run: `bash tests/run-bats tests/scripts/recall-sessions.bats`; `node --test tests/skills/recall.test.mjs`; `node scripts/lint-skills.mjs`.
Size M. before-run: row-recall in the adherence set reads this skill. After P2.

### P15. CI green and honest

Findings: F2, F3, F4, F5, F6, F13. F1 also needs P5's two test fixes and decision 2.
Files: tests/run-bats, tests/scripts/run-bats.bats, .github/workflows/ci.yml, scripts/ci-local, tests/hook-shape.sh, tests/scripts/task-done.bats, tests/lint-rules.test.mjs, tests/route-eval.test.mjs, tests/route-eval-rows.test.mjs, tests/seeded-diffs.test.mjs.
Fix sketch:
- F2: run-bats:50 uses `bash -c`.
- F3: ci.yml gets `timeout-minutes` per job, a `concurrency` group, `--jobs` in both OS jobs, and the same shellcheck targets as ci-local; pin actions by SHA. Add a test that ci-local's steps match ci.yml's.
- F4: task-done.bats:231 becomes `run ! grep ...`, and run-bats refuses a mid-test `! cmd` line with no `|| false`.
- F5: each node test removes its temp dirs (`t.after(() => rmSync(...))`).
- F6: hook-shape.sh unsets `CLAUDE_CONFIG_DIR`.
- F13: run-bats prints `# INFRA: fork failures in <file>` when a failed file's log holds `fork: Resource temporarily unavailable`; the default `--jobs` is min(6, cores - 1); task-done.bats setup keeps wt-new's stderr.
Tests to add: nested bats under `--jobs`, the INFRA line, the `! cmd` guard, the ci-local and ci.yml parity test.
Run: `bash tests/run-bats tests/scripts/run-bats.bats`, `tests/scripts/task-done.bats`; `node --test tests/lint-rules.test.mjs tests/route-eval.test.mjs tests/route-eval-rows.test.mjs tests/seeded-diffs.test.mjs`; `tests/run-bats tests/scripts/run-bats.bats` in the `kern-ci:task17` Ubuntu image.
Size M. before-release: no shipped behaviour changes.

### P16. Resume and wave integration (M3)

Findings: C-I3, C-I4, C-M14.
Files: skills/execute-plan/references/resume.md, skills/execute-plan/SKILL.md (step 11), scripts/wt-apply, tests/scripts/wt-fork-apply.bats, tests/skills/execute-plan.test.mjs.
Fix sketch:
- C-I3: a task on a `Wave:` line whose snapshot still equals `tree-before` in the same session waits for that worker's notification. Re-dispatch only in a new session, or after the worker returned with no `Status:` line (pstack orchestrate's zombie rule).
- C-I4: step 11 rebuilds each patch from the ledger, `wt-diff <fork> <start tree> <complete tree> --out reviews/task-N-final.diff`; `wt-apply --expect-tree <tree>` checks each patched path's blob after applying.
- C-M14: resume adopts an existing `<worktree.dir>/<plan-slug>` or wave fork after `wt-check`.
Tests to add: wt-apply `--expect-tree` mismatch exits non-zero; execute-plan pins.
Run: `bash tests/run-bats tests/scripts/wt-fork-apply.bats`; `node --test tests/skills/execute-plan.test.mjs`.
Size M. M3: both Importants are PLAUSIBLE and need a compaction mid-wave. Move it to before-run if 0.4.0 should ship safe wave integration.

### P17. Lint soundness (M3)

Findings: F7, F8, F9, F10, F12, F14; tests for F-L3, F-L4, F-L5 and F-RE1.
Files: scripts/lib/lint-rules.mjs, scripts/lib/frontmatter.mjs, scripts/lint-exemptions.json, tests/lint-rules.test.mjs, tests/helpers/md.mjs, tests/route-eval.test.mjs.
Fix sketch: port addy's `frontmatterYamlErrors`; tie each exemption to a message pattern and report stale ones; extend rule 4 to references files, modes and `{KERN}` paths in kernel prose, with anchor checks; strip comment lines before rule 13's match; widen rule 8 and rule 11's patterns and kebab-check agent names; reuse `scanMarkdown` in md.mjs.
Run: `node --test tests/lint-rules.test.mjs tests/route-eval.test.mjs tests/skills/*.test.mjs`; `node scripts/lint-skills.mjs`.
Size M. After P11 and P15.

### P18. Control and help text (M3)

Findings: E6, E7, E8, E9, E10, E11, E12, E13.
Files: skills/help/references/map.md, skills/help/references/fix-a-run.md, skills/autopilot/SKILL.md, skills/mode/SKILL.md, skills/unslop/SKILL.md, skills/technical-writing/SKILL.md, skills/recall/SKILL.md, tests/skills-help.test.mjs, tests/skills-control.test.mjs, tests/skills/recall.test.mjs.
Fix sketch: fix the stale map cells and lint each Tier; limit unslop's "Add soul" to explanation docs and its parentheses ban to dash replacement; autopilot points at settings.md's table and covers a bare `/kern:autopilot`; mode status uses `kern-get`; recall reads `WORK/notes/*` as context and says how to read two transcripts; the status-line snippet takes `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`; a parity test between mode's phrase list and the hook's.
Size M. After P12 and P14.

### P19. Diagnose and finish text (M3)

Findings: D13, D14, D17, D18.
Files: skills/diagnose/SKILL.md, skills/diagnose/scripts/hitl-loop.template.sh, skills/finish-branch/SKILL.md, skills/finish-branch/references/branch-ops.md, skills/commit/SKILL.md, tests/skills/diagnose.test.mjs, tests/skills/finish-branch.test.mjs, tests/skills/commit.test.mjs.
Fix sketch: drop the template header's first clause; diagnose says the loop and instrumentation live in implement's `<wt>`, and a still-red loop after a fix goes back to step 5 and counts; an option-1 rebase runs the proven-tree check or reports "rebased tree not proven"; snapshot before and after the proof and report a difference.
Size M. After P9.

### P20. Guard speed: one parse per call (M3)

Findings: A5; lane F's hook-suite speed items.
Files: hooks/pre-tool-use, hooks/lib/gitctx.sh and every guard that calls `git_words`; tests/hooks/aliases.bats (move the 72.7 s corpus test to its own file), tests/hooks/g13-g15.bats and g05-g06-commit.bats (split by guard).
Fix sketch: the dispatcher runs `git_words` once with the end sentinel, and `_cmd_words` once per record, into arrays every guard reads. Add a bats bound: 100 substitutions under 8 s.
Size L. After every other guard package.

### M3 backlog with no package

A8, A10, A15, B12, B13, C-M7, C-M8, C-M10, C-M11, C-M12, C-M13, G6, G8, G12, G14. Each line is in section 4.

## 4. Minor findings

| ID | Finding | Verdict |
|---|---|---|
| A5 | Each guard parses again; about 200 `$( )` in one call hit the 20 s timeout (re-graded from Important) | M3, P20 |
| A6 | `branch -f`, `branch -M`, `update-ref -d` onto a protected branch get no vote | fix-now, P3 |
| A7 | `stash clear` and `stash drop` from a linked worktree get no vote; stash refs are shared | fix-now, P3 |
| A8 | G16's hook-code match is not tied to `KERN_ROOT`; other repos' `hooks/` and kern's own dev edits ask | M3 |
| A9 | A Write to `$CLAUDE_CONFIG_DIR/settings.json` gets no vote | fix-now, P1 |
| A10 | `$'+feat'` hides a force push in an ask reason; autopilot still denies | M3 |
| A13 | An empty `_g16_lower` capture skips the state-dir deny | fix-now, P1 |
| A14 | An empty session id turns an autopilot deny into an ask | drop: Claude Code always sends `session_id`, and under `-p` an ask is a denial |
| A15 | json.sh leaves `\uXXXX` undecoded; G13 and G14 patch it locally | M3 |
| B3 | Subagent kernel ranks the brief above project rules, lets it authorise merge and messaging, and has no place for the agent's own definition | fix-now, P11 |
| B4 | The routing reminder drops the override clause; technical-writing has no step 0 | fix-now, P12 |
| B5 | "Only policy keys may set auto or deny" contradicts tighten-only project rules | fix-now, P11 |
| B6 | Unknown keys appear under `Set:`; a typo reads as a policy | fix-now, P13 |
| B7 | The 600-char settings cap does not hold for Routes, Unknown and Overrides | fix-now, P13 |
| B8 | `route.<name>` renders a Routes line no text explains | fix-now, P13 (decision 4) |
| B9 | `prompt_hashes` is quadratic on one long line; a 3 MB paste times out prompt-submit | fix-now, P12 |
| B10 | A failed `/kern:autopilot on` state write prints no notice | fix-now, P12 |
| B11 = E9 | Autopilot rules are worded three ways and drift: the hook line omits the non-protected branch and reads as "no shell script"; the skill omits the whole-call rule, the `git add` spellings G5 denies and a bare `/kern:autopilot` | fix-now for the hook line, P12; the skill part M3, P18 |
| B12 | Mid-task rows (prove-it, technical-writing, context) sit under a task-start rule | M3: costs kernel bytes; prove-it's description already catches it |
| B13 | "Never add a rule or lesson on your own" collides with Claude Code's auto memory | M3, decision 8 |
| C-M1 | task-brief flips fences on any backtick or tilde run and can lose a task plan-check accepts | fix-now, P7 |
| C-M2 | `Main:` records no HEAD, so a main-checkout commit reads `main: unchanged` | fix-now, P7 |
| C-M3 | `Main:` is recorded before the worktree dir is excluded; this repo gets a false `main: changed` | fix-now, P7 |
| C-M4 | wt-diff's header glob example is wrong; plan-check keeps a glob Files entry literal | fix-now for the comment, P6; the plan-check refusal M3 |
| C-M5 | wt-new fails on a single-branch clone and discards the fetch's stderr | fix-now, P8 |
| C-M6 | A `.worktreeinclude` entry that is a parent of `worktree.dir` copies every worktree | fix-now, P8 |
| C-M7 | parallel-work integrates `wt-fork` workers into a `wt-new` tree, and each `wt-new` fetches on its own | M3 |
| C-M8 | worktrees.md says only `--force` deletes ignored files; plain remove does too | M3 |
| C-M9 | implement step 3's bare `kern-detect` relies on a Scripts line the subagent kernel lacks | fix-now, P11 |
| C-M10 | Scope rules forbid writes the implement scripts make; `generated_artifacts` outside Files stops step 8 | M3 |
| C-M11 | `tree-before` names two trees in step and inline mode | M3 |
| C-M12 | task-done runs the test up to four times; no Bash timeout advice | M3 |
| C-M13 | Review Focus wording contradicts itself and never asks for the pinning test | M3 |
| C-M14 | Resume cannot adopt a worktree or fork made before its ledger line | M3, P16 |
| D9 | `probe --mutate` writes through a tracked symlink or `../` path outside the fork | fix-now, P4 |
| D10 | floor-scan misses a test disabled by a rename | fix-now, P6 |
| D11 | commit eyeballs the convention while G5 checks a regex; a convention deny is a hard stop | fix-now, P9 |
| D12 | G5's attribution regex matches prose such as "generated by Claude" | fix-now, P9 |
| D13 | An option-1 commit plus a rebase leaves an unproven tree, unreported | M3, P19 |
| D14 | The proven tree is snapshotted after the proof, so files the proof wrote count | M3, P19 |
| D15 | claim-check reads Markdown headings and `*` bullets as comments | fix-now, P6 |
| D16 | The `verify.fast` default "`typecheck` then `lint`" has two readings; with no typecheck, autopilot never finishes | fix-now, P10 |
| D17 | The HITL template header says the agent runs it; the body says the user does | M3, P19 |
| D18 | diagnose names no tree for the loop and has no back-edge for a still-red loop | M3, P19 |
| D19 | The trimmed missing-test clause lost "not a finding" and has no Outputs slot | fix-now, P10 |
| D20 | The package's porcelain `git diff` follows `diff.dstPrefix` and textconv | fix-now, P6 |
| E4 | recall finds `WORK` from `--git-common-dir`, which disagrees with kern-dir in submodules and separate git dirs | fix-now, P14 |
| E5 | `--days 0` is accepted, matches nothing and exits 0 | fix-now, P14 |
| E6 | Stale help-map "Reached by" cells; lint checks only that each skill is listed | M3, P18 |
| E7 | technical-writing applies unslop's "Add soul" to every doc; the two disagree on parentheses | M3, P18 |
| E8 | autopilot `off` cannot tell which `parked:` lines came "since" it turned on | M3, P18 |
| E10 | mode status must name each default's source from a block that lists none | M3, P18 |
| E11 | recall reads two transcripts directly against the kernel's hand-off rule | M3, P18 |
| E12 | recall never reads the `WORK/notes` that context.md writes | M3, P18 |
| E13 | The status-line snippet hard-codes `$HOME/.claude/plugins/data/kern-kern` | M3, P18 |
| E14 | recall's tracker detection names no command | fix-now, P14 |
| F3 | ci-local differs from CI in shellcheck targets, timeouts, tool versions and bats mode | fix-now, P15 |
| F4 | `! grep -q` mid-test can never fail it; run-bats's guard misses it | fix-now, P15 |
| F5 | Node tests never remove temp dirs: TMPDIR now holds 9,668 `kern-lint-*`, 1,453 `kern-rows-*`, 473 `kern-eval-*`, 41 `noawk-*` | fix-now, P15 |
| F6 | hook-shape.sh keeps the caller's `CLAUDE_CONFIG_DIR` | fix-now, P15 |
| F7 | The lint frontmatter parser accepts YAML-invalid scalars | M3, P17 |
| F8 | An exemption hides every finding of its rule for its path; stale ones stay silent | M3, P17 |
| F9 | Path checks skip references files, modes and `{KERN}` paths in kernel prose | M3, P17 |
| F10 | Rule 13 reads comments as code | M3, P17 |
| F11 | A fenced `## Steps` satisfies rule 6 | drop: contrived; no kern file has it |
| F12 | Narrow lint patterns: rule 8 paths, U+2012 and U+2015, agent kebab names, the dormant Skill-tool half of rule 5 | M3, P17 |
| F13 | Under process-limit load a fork failure reads as a test failure; wall-clock asserts flake next | fix-now, P15 |
| F14 | md.mjs `stripFences` disagrees with lint's `scanMarkdown` | M3, P17 |
| G5 | Adherence counts invalid runs as failures; differs from `caseResult` at runs other than 3 | fix-now, P5 |
| G6 | Four scripted checks accept weaker evidence than their expectation | M3: the known-fail rows lane G wrote |
| G7 | commit-work-file's `-F` check reads failed and denied commits | fix-now, P5 |
| G8 | stubMissed voids gh calls with `$( )`, variables or multi-line arguments | M3: false INVALID only |
| G9 | Heldout tests run model-written code with the runner's whole environment; floor-scan's status is unchecked | fix-now, P5 |
| G10 | No run checks that the plugin under test loaded | fix-now, P5 |
| G11 | Snapshots do not pin the measured tree; the copy includes dirty files | fix-now, P5 |
| G12 | `promptResult` excludes only `task-notification` | M3: not observed |
| G13 | One arm's git failure ends the whole h2h run | fix-now, P5 |
| G14 | pilot review scores a grader run without `runProblem` | M3 |

## 5. Source adopt list

| kern | Source | Take | When |
|---|---|---|---|
| hooks/guards/g02-pr.sh, spec 8.1 D2 and D3 | .upstream/pstack/pstack/skills/correct/SKILL.md:30 | Pair each rule with its enforcer: a bats table of D2 and D3 write verbs that fails when one gets no vote | now, P3 |
| scripts/probe | .upstream/superpowers/skills/verification-before-completion/SKILL.md ("Revert fix, run, MUST FAIL"); test-driven-development ("fails, not errors") | Show the reversed run's output and accept only an assertion failure | now, P4 |
| scripts/claim-check | .upstream/addy/skills/constraint-driven-development/references/floor-guard.md | "Never let a 2 read as a 0" | now, P6 |
| skills/self-review/references/smells.md, SKILL.md step 9 | .upstream/pocock/skills/engineering/code-review/SKILL.md:38-41; .upstream/superpowers/skills/requesting-code-review/code-reviewer.md (verdict shape) | Smells are judgement calls that never block; say which classes block | now, P10 |
| kernel/kernel.md:17-32 | .upstream/superpowers/skills/using-superpowers/SKILL.md | A question has a defined path: answer it when it changes nothing | now, P11 |
| hooks/subagent-start, kernel/kernel-subagent.md | .upstream/caveman-4.0.1/src/hooks/caveman-activate.js:295-308 | An agent's own contract wins over kern's Return format | now, P11 |
| scripts/recall-sessions | .upstream/pstack/pstack/skills/recall/SKILL.md:19 | Skip the current chat, here by `CLAUDE_CODE_SESSION_ID` | now, P14 |
| scripts/wt-new | .upstream/superpowers/skills/using-git-worktrees/SKILL.md (Step 0) | Never leave local work out silently: detect local ahead of origin | now, P8 |
| scripts/task-brief | scripts/plan-check:96-112 (kern's own `fence_run`) | The CommonMark fence rule | now, P7 |
| scripts/lib/h2h.mjs:219-227 | .upstream/addy/scripts/run-evals.js:453-502 | Type-check every grader field, bind ids, derive counters from the validated set | now, P5 |
| scripts/behave.mjs, scripts/h2h.mjs | .upstream/caveman-4.0.1/evals/llm_run.py:241-268 | A partial run writes a partial file and leaves the snapshot alone | now, P5 |
| scripts/behave.mjs, h2h.mjs, kernel-adherence.mjs | scripts/lib/exec-run.mjs:141-156 (kern's own `parseArgs`) | Reject unknown or valueless flags before any paid call | now, P5 |
| .github/workflows/ci.yml | .upstream/caveman-4.0.1/.github/workflows/ci.yml | Per-job `timeout-minutes`, a `concurrency` group, SHA-pinned actions | now, P15 |
| skills/execute-plan/references/resume.md, skills/parallel-work/SKILL.md step 5 | .upstream/pstack/pstack/skills/poteto-mode/playbooks/orchestrate.md | Reconcile a late worker against the ledger before accepting it; re-paste standing orders on every resume | M3, P16 |
| execute-plan integration, step 11 | .upstream/pocock/skills/engineering/implement-spec/SKILL.md | Check the integrated result against the reviewed tree | M3, P16 |
| scripts/lib/frontmatter.mjs, lint rule 1 | .upstream/addy/scripts/lib/skill-lint.js:229-320 | `frontmatterYamlErrors` | M3, P17 |
| lint rule 4 | .upstream/addy/scripts/validate-reference-links.js | Scan references files and check `#fragment` anchors | M3, P17 |
| skills/help/references/fix-a-run.md | .upstream/caveman-4.0.1/src/hooks/caveman-statusline.sh:11-40 | Config-dir fallback, spaced JSON keys, a stdin timeout | M3, P18 |
| skills/help/references/map.md | .upstream/pocock/.agents/writing-docs.md | A trigger boundary against the nearest sibling skill | M3, P18 |
| skills/diagnose/SKILL.md | .upstream/pocock/skills/engineering/diagnosing-bugs/SKILL.md; .upstream/superpowers/skills/systematic-debugging/SKILL.md (Phase 4.4) | Tighten the loop; a perf baseline first; a failed fix goes back with its count | M3, P19 |
| diagnose step 5 `[kern-dbg]` | .upstream/pocock/skills/engineering/diagnosing-bugs/SKILL.md | A per-run debug tag | M3 |
| hooks/lib/json.sh | .upstream/caveman-4.0.1/src/hooks/caveman-mode-tracker.js | Decode `\u0000` to `\u007f` once | M3 |
| hooks/lib/state.sh `state_get` | .upstream/caveman-4.0.1/src/hooks/caveman-config.js:108-240 | A size cap on the state read | M3 |
| agents/implementer.md rules 4 and 6 | .upstream/superpowers/skills/subagent-driven-development/implementer-prompt.md; .upstream/pstack/harness/pstack/claude-code/agents/poteto-agent.md | Concrete escalation triggers; a missing skill path returns BLOCKED | M3 |
| agents/task-reviewer.md | .upstream/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md:85-95, 104-109; .upstream/superpowers/skills/requesting-code-review/code-reviewer.md | Unseen evidence is a gap, not a failure; a listed file the diff never touches is Missing; a spec's silence is not permission | M3 |
| skills/prove-it/SKILL.md:21, kernel Evidence line | .upstream/superpowers/skills/verification-before-completion/SKILL.md | The gate covers any word that implies done, fixed or passing | M3 (kernel bytes) |
| skills/prove-it/SKILL.md step 7 | .upstream/pstack/pstack/skills/poteto-mode/SKILL.md:115 | Never hand the user a check you can run | M3 |
| skills/self-review/references/doubt-cycle.md | .upstream/pstack/pstack/skills/blast-radius/SKILL.md step 6 | Name the same-model limit; offer `opus` when the session runs on Sonnet | M3 |
| skills/finish-branch/SKILL.md step 3 | .upstream/superpowers/skills/finishing-a-development-branch/SKILL.md (Step 3) | Ask once which base when the branch's upstream, plan or ledger names another | M3 |
| execute-plan fix loop, resume.md | .upstream/superpowers/skills/subagent-driven-development/SKILL.md ("The fix loop") | Check the fix report holds tests, command and output before re-review; carry parked-finding pointers | M3 |
| scripts/ledger-open | .upstream/superpowers/skills/subagent-driven-development/scripts/sdd-workspace | Disambiguate two plans with one basename | M3 |
| plan step 7, plan-check | .upstream/addy/skills/planning-and-task-breakdown/SKILL.md | Warn when one task's Files exceed `scope_threshold` | M3 |
| skills/plan/references/plan-template.md | .upstream/superpowers/skills/writing-plans/SKILL.md (Self-Review item 4) | Each Review Focus line gets its pinning test | M3 |
| skills/recall/SKILL.md step 6 | .upstream/pstack/pstack/skills/recall/SKILL.md:20, 24-33 | Sweep the tracker when a file or subsystem is named too | M3 |
| scripts/lib/behave.mjs `CHECKS` | .upstream/caveman-4.0.1/tests/test_eval_fidelity.py:143-160 | Known-pass and known-fail rows for every scripted check | M3 |

## 6. Decisions for the user

1. **Which packages land before the confirming run and 0.4.0?** All of P1 to P14 touch what the run loads, so whatever ships in 0.4.0 must land first.
   - (a) All of P1 to P14, then one run. About 30 to 35 implementer hours plus reviews.
   - (b) P1 to P10 before the run; P11 to P14 go to 0.4.1 with their own measurement.
   - (c) P1 to P5 only.
   - Recommend (b). It closes every fail-open path and makes the run trustworthy, and it keeps the kernel and routing text out of a cycle that already looped for days.
2. **GitHub CI is blocked by billing.** Runs since 0.3.0 stop with "recent account payments have failed or your spending limit needs to be increased" (F1).
   - (a) Fix the payment or raise the limit, and move the macOS job to manual or weekly.
   - (b) Keep GitHub CI off and rely on ci-local plus the `kern-ci:task17` Ubuntu image for 0.4.0.
   - (c) Fix billing and keep both jobs on every push.
   - Recommend (a). Ubuntu has had no hosted run since 2026-10-16, and macOS minutes cost the most.
3. **Kernel budget when P11 lands.** The standing cost is 6,345 of 6,345.
   - (a) Take the lossless cuts (about 250 chars), spend about 35 on B2, and lower rule 7's limit to the new measured value.
   - (b) The same, but keep the freed bytes as headroom.
   - (c) Also cut the route cells (about 670 chars), after an inline-rows adherence run.
   - Recommend (a). Locking the limit stops creep; (c) needs a paid measurement first. The `Scripts:` line stays: 103 bare script names depend on it.
4. **What `overrides.<job>: off` means, and `route.<name>`** (B1, B8; documented behaviour).
   - (a) `off` means no override for the job: kern's route stays and the same-name detection is off. Drop `route.<name>`.
   - (b) `off` turns kern's route for the job off.
   - (c) Keep `route.<name>` and render it into the Overrides line.
   - Recommend (a). It is the likeliest meaning beside "project skill name", and `route.<name>` has no reader.
5. **gh writes in interactive mode** (A1).
   - (a) Every gh verb outside a closed read list asks interactively and is denied under autopilot, as spec D2 says.
   - (b) Deny only under autopilot; no new interactive prompts.
   - Recommend (a). gh writes are rare in normal work, and D2 covers both modes.
6. **wt-new when the local base is ahead of origin** (C-I1).
   - (a) Exit 2 with the count; `--base <sha>` works with `--plan`.
   - (b) Base on the local branch when it is ahead, which changes design X7.
   - (c) Warn and build on origin.
   - Recommend (a). It keeps X7's fresh-origin rule and ends the silent stale worktree. This repo, 200 commits ahead, then needs a push over HTTPS or `--base`.
7. **self-review verdict rules** (D3, D4; documented behaviour).
   - (a) Smells are `nit`; `split` needs a blocking finding on a line the previous round asked to change.
   - (b) Smells stay `should-fix` but never trigger `fix first`; `split` keeps only the size rule.
   - Recommend (a). It is the shortest text and matches pocock's "never a hard violation" and the spec's "a round fixes the previous round's fixes".
8. **Learning line against Claude Code's auto memory** (B13).
   - (a) Scope "Never add a rule or lesson on your own" to CLAUDE.md, rules and skills, so memory writes are allowed. About 35 chars.
   - (b) Keep it: kern forbids memory writes too.
   - (c) Memory writes need the user's word.
   - Recommend (a). You rely on auto memory, and today the two collide on every correction.
9. **Exit rule for the confirming run** (MEMORY: agree it before any measure-fix cycle).
   - (a) One run. Release 0.4.0 when every gate passes. On a failure, fix only a harness defect and rerun once; otherwise release with the failure written down.
   - (b) Iterate until green.
   - Recommend (a). Task 16 looped for days.
10. **Leftover audit data.** The session scratchpad holds 807 MB in 159 entries (lane dirs, mutation copies, older task dirs); TMPDIR holds about 11,600 kern test temp dirs; `/tmp/x` is lane E's stray copy of skills/mode/SKILL.md.
    - (a) Delete them once the fix packages are dispatched.
    - (b) Keep them until 0.4.0 ships.
    - Recommend (a). The lane reports hold every repro.

## 7. Process notes

- Lane E read-only breach. At 18:24:28 a failed zsh `cd` let `bash scripts/kern-dir ledgers` run in the main checkout. It made `.kern/` and `.kern/ledgers/` and appended `/.kern/` to `.git/info/exclude`. No tracked file, index entry, ref or HEAD changed. The controller undid all three; at this consolidation `.kern` is absent and `.git/info/exclude` holds no `/.kern/` line. Lane E's `cp` stray, `/tmp/x`, is still there.
- Machine load. During lane A's run about 3,300 short-lived `node -e ... SubagentStart` processes from another lane put the uid at 3,900 of 4,000 processes (kern.maxprocperuid). Lane A saw G1 bats flakes (tests 29, 31, 50) that passed on rerun. Lane C saw task-done.bats fail in setup in 4 of 6 parallel runs of an unmutated copy. Lane D saw one claim-probe fork failure. Lane F saw 7 failures across 4 heavy hook files and recounted two kills on an idle machine. No fork failure is counted as a defect; F13 records the lesson. During this consolidation the uid held 460 to 490 processes, at a load average near 5.
- A5 timing ran under that lighter load: 0.33 s at 1 substitution, 4.0 s at 40, 7.75 s at 80.
- Leftover temp dirs: TMPDIR holds 9,668 `kern-lint-*`, 1,453 `kern-rows-*`, 473 `kern-eval-*` and 41 `noawk-*` (F5; the counts grew during the audit). Lane F's 17 `lp-*` dirs are gone from TMPDIR and `/tmp`. The shared scratchpad holds laneA 48 MB, laneC 113 MB, laneD 8.3 MB, laneE 6.0 MB, mut 329 MB, and older task dirs (rr16l*, rv16l, rv16m, fix16l-*, t16m, trace.txt 25 MB). This consolidation's own `cons` dir was removed.
- Reruns for this consolidation ran on a `git archive HEAD` copy with an isolated HOME and plugin data dir. No `claude` run, no eval runner, no bats suite. Lint on the copy: `lint: clean`.
- GitHub CI runs are pushes to `backup/m1-wip`. main is 200 commits ahead of origin/main, which also drives C-I1 in this repo.
- `evals/snapshots/` holds 23 untracked snapshots from 2026-10-18 to 2026-10-22. Until P5's G3 fix lands, a filtered behave or h2h run on a past date's name can overwrite one; commit or copy them before any run.
