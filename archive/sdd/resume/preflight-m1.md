# M1 plan pre-flight

Plan: `kern-spec/plans/2026-10-12-kern-m1-plan.md` (5,349 lines, mtime 11:09). Line numbers below are that file's. M0 plan was re-read at 11:39 after another agent edited it (now 1,654 lines).

## Method (what was run, in `scratchpad/preflight-m1/`)

- Extracted every fenced file in the plan and diffed it against `m1draft/`: 55 files identical. Differences are only the controller's three edits (`|| false` on 40 bats lines in 8 files; `tests/run-bats` guard; nested `kern-dir`) plus the new kern-dir test. The lint-rules and lint-rules.test snippets (plan 4773, 4954, 5115, 5148, 5157) match the draft line for line.
- Built a tree = draft + plan versions of every changed file. Ran under `/bin/bash` 3.2 via `tests/run-bats` and under bash 5.3 via plain `bats`: 117 tests, **1 failure** (F1). `node --test tests/*.test.mjs`: 28 pass. `lint-skills`: clean. `tests/hook-shape.sh`: 8 cases. `shellcheck -x -S warning` on the exact CI file list: clean.
- Re-ran the port commands (plan 4643, 4657) against `~/.claude/skills/unslop` and `repos/cursor/plugins/pstack` (pin 11713c6): both outputs byte-identical to the draft; sizes 8,747 and 9,526 bytes.
- Assembled M0's real `lint-rules.mjs` and tests (M0 plan 646, 760, 784) plus M1's Task 16 and 17 insertions as the plan says: 17 tests pass; lint clean over the M1 shipped files.
- Probed the guards (24 commands, both modes) against the Task 10 and 12 interface text: all agree. Probed `tests/run-bats` with a bare `[[ ]]` (space and tab indent): refuses, exit 1; with `|| false`: runs and reports the failing assertion.
- Re-ran the prompt-submit, payload and session-start bats with `CLAUDE_CODE_ENTRYPOINT=sdk-cli`, `sdk-ts`, `cli` (F3).

## 1. Interface and shared-file pairs

| # | Pair | Produces against consumes | Result |
|---|---|---|---|
| P1 | T2 `tests/helpers/common.bash` and T3 to T13, T18 bats | `kern_root make_repo kern_env payload bash_payload run_guard decision_of set_autopilot fake_gh`; every helper the tests call exists, identical to draft | OK, except `kern_env` leaks `CLAUDE_CODE_ENTRYPOINT` (F3) |
| P2 | T2 `json.sh` and T3, T4, T6 to T9 | `json_get` 0/1/2, `json_get_raw`, `json_escape`, `json_ok`, `ti_get` | OK |
| P3 | T2 `tests/run-bats` (edit 2) and every `.bats`, and M0 `tests/scripts/fetch-upstream.bats` | Bare `[[ ]]` guard: regex `^[[:space:]]+\[\[ .* \]\][[:space:]]*$`. No bare line left in M1 or M0 plan code. Guard works (probe). Gap: a trailing comment after `]]` is not caught | OK; the guard's first real catch is F1 |
| P4 | T2 `run-bats` and the "N tests, 0 failures" lines | Non-tty bats prints TAP, not that summary | F5 |
| P5 | T1 `save` fixtures and T8 `payloads.bats` | `submit-task-notification.json`, `pretooluse-subagent.json` | F8 |
| P6 | T1 decisions 2, 4, 7 and T8 `hooks/prompt-submit` | Strings to edit exist verbatim: `case "${NAME#/}" in` (2326), `KERN_WRAPPER_TAGS` (2201), 2368, 2377 | OK; `expansion_type` is never recorded or checked (F11) |
| P7 | T1 record lines and T18 Step 4, M2 Task 7 | `ask under bypassPermissions: pending (Task 18)` (line 194) replaced by T18; `agent_type in subagent PreToolUse: <value or absent>` matches contract | OK |
| P8 | T1 Step 7 and T1 Steps 3, 4, 6 | `$SPIKE`, `$L` carried across steps; `rm -rf` on `dirname $SPIKE` | F7 |
| P9 | T3 `settings.sh` and T4 `kern-dir`, `kern-get`, `kern-detect` | `kern_main_root`, `settings_get work_dir .kern`; nested names via edit 3: `ledgers/plan-a` ok, `ledgers//x`, `a/`, `/a`, `a/-b`, `../x` all exit 2 | OK |
| P10 | T3 `kernel/settings.md` and A5 + design 5.4 key lists | All A5 keys present; design 5.4 keys present except `mode.default` (reconciled to `mode.voice`/`mode.surface`, table lines 37 to 49) | OK |
| P11 | T3 `settings.md` rows and T17 rule 13 and every reader | Lint passes both directions on the full tree | OK |
| P12 | T4 `kern-dir` (edit 3), T6 `context.md` (`kern-dir notes`), M2 `kern-dir ledgers/<plan-slug>` | Slug character set (lowercase, digits, dashes) is not stated in M2 at 3464 | OK for M1; contract.md still states the old rule (F13) |
| P13 | T5 `state.sh` and T6 `mode_line`, T7, T8, T9 `autopilot_on` | `state_get/set/reset`, `now_iso`, 0600, atomic, symlink refused | OK |
| P14 | T6 `render.sh` and T7 `subagent-start` | `K_VOICE`, `kern_version`, `render_template`; subagent output 888 chars + terse-subagent line, limit 1,200 | OK |
| P15 | T6 `kernel.md` rows and T15 `technical-writing`, T6 `context.md`, T16 rule 6, M2 `kernelRows` | Row texts equal M2's assumed strings exactly; both route files open `## Steps` + numbered list; row format `\| when \| Read {KERN}/x/SKILL.md \|` and `Read {ROOT}/kernel/context.md` | OK |
| P16 | T6 kernel text and M2 row additions | Rendered 3,488 chars (3,954 with the `long-settings` fixture). M2 adds 8 rows of about 80 chars | F9 |
| P17 | T6 `settings_summary` and the "Interfaces M2 relies on" block (line 85), T17 fixtures | Order matches; "each present only when non-empty" is false for `Settings files` | F14 |
| P18 | T6 `modes/terse.md` and T8 switch output, T17 rule 7 | 1,676 bytes (spec: about 2 KB); rule 7 adds it to the kernel length | OK |
| P19 | T8 `prompt-submit` and T14 skill text | "autopilot denied by <file>", `kern mode:` line, "Never write the state file" strings agree | OK |
| P20 | T8 UserPromptExpansion branch and spec B2 hook contract 1 | `expansion_type` must be `slash_command` | F11 |
| P21 | T9 `decide.sh` and T10 to T13 guards, T18 Step 4 patch | `vote deny G1 "..."` signature; `emit_decision` locals are `d` and `r`, as the patch uses; `CWD=` line exists for `PERMISSION_MODE` | OK |
| P22 | T9 `gitctx.sh` and guards, M2 G18 | All 46 names in the Interfaces text exist; M2 uses only M1-defined helpers | OK |
| P23 | T9 `pre-tool-use` and M2 G18 | `KERN_GUARDS`, `TOOL_INPUT`, `AGENT`, `guard_<id>` from file name up to first `-` | OK |
| P24 | T9 `hooks/hooks.json` and contract.md | JSON equal to the contract block (node deep compare) | OK |
| P25 | T10 `g01-git.bats` and T18 Step 4 appended test | 16 tests, then 17 after the append | OK |
| P26 | T11 G2 and design 8.3 | Merged or closed PR asks; design says duplicates are denied | F12 |
| P27 | T11 `fake_gh` and T2 helpers | Defined, same env names | OK |
| P28 | T12/T13 guards and settings keys | `commit.id_from_branch`, `commit.attribution`, `never_commit`, `protected_targets`, `mcp.write_servers`, `deploy.envs`, `rebase.push` all in table | OK |
| P29 | T14 `autopilot` skill step 5 and spec A2 `WORK` | Path hard-coded `.kern/` | F10 |
| P30 | T15 NOTICE lines and M0 NOTICE `## File map` (last section) and `licensing.test.mjs` | Format `- <kern path>: <key> <upstream path>`, key `local` exists; test only needs the section heading | OK |
| P31 | T15 port commands and M0 `.upstream` layout | `.upstream/local/unslop/SKILL.md`, `.upstream/pstack/pstack/skills/technical-writing/SKILL.md` match M0 `fetch-upstream` | OK (run) |
| P32 | T16 rule 6, T17 rules 7/13/15 and M0 `lint-rules.mjs` | M0 imports are lines 3 to 4 (two comment lines first), so "first two import lines" is read as import lines, not file lines; `join existsSync readFileSync parseFrontmatter err rel walk warn` all in scope when rule 6 lands; exemption match `rule` + `path` equals `skills/hello/SKILL.md` | OK (assembled and run) |
| P33 | T16 `map.md` header and M2 appends | `\| Skill \| Tier \| Reached by \| Job \|`; rule 6 regex `^\| \`name\` \|` | OK |
| P34 | T17 `scripts/ci-local`, `ci.yml` and M0 Task 8 | M0 lines are `bats tests/scripts` (1559, 1608) | F4 |
| P35 | T17 fixtures and `tests/hook-shape.sh` | 8 cases pass; also pass with `sdk-cli` | OK |
| P36 | T18 `release.mjs`, `check-version.mjs`, CHANGELOG and M0 Task 6 | Unreleased bullets non-empty, newest release then 0.2.0 | OK |
| P37 | T8 test "reminder only outside the default preset" and `kern_env` | Hook skips reminder under `sdk*` | F3 |

## 2. Each task against itself

| Task | Tests vs code | Files created vs staged | Commands available at that point | Findings |
|---|---|---|---|---|
| 1 | Spike only | Staged: record + fixtures; ok | `$SPIKE`/`$L` assumed persistent; `rm -rf` on unset var | F7, F8 |
| 2 | 7 of 7 pass; Expected text format | 4 files, all staged | ok | F5 |
| 3 | 8 of 8 pass | 4 files, staged | `chmod +x scripts/kern-get` in Step 6 after Step 5 creates it | F5 |
| 4 | 12 tests (5 + 7), Expected says 11 | 5 files, staged | `kern-detect` run on the CDS repo, read-only | F2 |
| 5 | 5 of 5 pass | ok | ok | none |
| 6 | 1 failing assertion at plan 1576 | 6 files, staged | `modes/terse.md` created before Step 8 | F1, F9 |
| 7 | 2 of 2 pass | ok | ok | none |
| 8 | 16 expected; all 16 pass with entrypoint `cli`; test at 2100 fails with `sdk*` | 3 files, staged | `hooks/pre-tool-use` skipped in payloads.bats until Task 9 | F3, F11 |
| 9 | 6 + 5 + 5 = 16 ok; `# pass 2` ok | 8 files, staged | `claude plugin validate` needs the four hooks; all exist | none |
| 10 | 16 of 16 | ok | ok | none |
| 11 | 12 of 12, 6 s (limit 30 s) | ok | `fake_gh` from Task 2 | F12 |
| 12 | 11 of 11 | ok | ok | none |
| 13 | 10 of 10; timing check 0.41 s vs 0.5 s limit | ok | whole suite 43 s | F15 |
| 14 | 4 of 4; lint clean at this point (rule 4 refs resolve) | ok | ok | F10 |
| 15 | 2 of 2; port outputs reproduce; `3 grep lines` ok | 4 paths staged incl. NOTICE | `licensing.test.mjs` from M0 | none |
| 16 | 3 + rule 6 tests pass; Step 2 expected failures plausible | 7 paths staged | rule 6 uses only M0-imported names | none |
| 17 | rules 7, 13, 15 tests pass; `hook-shape: 8 cases passed` ok | fixtures, runner, lint, CI, ci-local staged | Step 7 replace-string does not exist in M0's ci-local | F4 |
| 18 | `tail -1` check cannot see failures; g01 count 17 ok | CHANGELOG, manifests, spikes staged | `release.mjs minor` ok | F6 |

## 3. Conflicts with Global Constraints and the spec

| # | Constraint or spec text | Plan | Result |
|---|---|---|---|
| G1 | Global line 18: section budgets precedence 420, autonomy 650 | Rendered sections: Precedence 469 (455 without heading), Autonomy 701 (689). Routing 757 of 1,100. Total 3,488 of 3,960 | F9 |
| G2 | SubagentStart at most 1,200 | 888 chars plus terse line | OK |
| G3 | Bash 3.2, no jq, no assoc arrays, no mapfile, no `${v,,}`; votes never in a pipeline | greps clean; guards read from here-documents; 117 tests under 3.2 | OK |
| G4 | Exec-form hooks, `onFailure: block` | hooks.json equals contract | OK |
| G5 | Description limits; quote values with `: ` | mode 104, autopilot 111, help quoted (111), unslop quoted, technical-writing 99 | OK |
| G6 | Shipped files: no names, machine paths, long dashes, curly quotes, caveman words | M0 names list (`Mustafa Mohamed MustaMohamed musta heyinfinito`) and the regexes: none found | OK |
| G7 | Policy keys, floor actions | 24 guard probes agree | OK |
| G8 | State file 0600, atomic, symlink refused | tests pass | OK |
| G9 | `startup`, `clear`, `fork` reset; `compact`, `resume` keep | `session-start` case statement and tests | OK |
| G10 | Commit subjects `M1: ...` at most 72 chars, named paths, no trailers | 19 commits checked | OK |
| G11 | Spec B1/B2/B3 frontmatter verbatim | skills-control test; help differs only by quoting (reconciled row) | OK |
| G12 | Spec 4.3 routing sentence | M1 sentence differs; M2 replaces it as the plan states (line 84) | OK |
| G13 | Spec B2 hook contract 1 | no `expansion_type` check | F11 |
| G14 | Spec 8.3 G2 | merged or closed asks | F12 |
| G15 | Spec A2 `WORK`, `work_dir` | autopilot skill hard-codes `.kern` | F10 |
| G16 | Spec 11.2 rules 6, 7, 13, 15 | Implemented; rule 15 lists 8 fixtures (spec 7 plus `long-settings`) | OK |

## Findings (15)

Each: task, plan line, what is wrong, smallest correction.

**F1. Task 6, plan 1576. A test assertion is false; blocks Task 6 Step 8, Task 13 Step 6, Task 17 Step 8.**
`[[ "$output" == *"Set: push.policy=auto"* ]] || false`. The fixture has `foo.bar: 1`, and `settings_keys` ends in `sort -u`, so the summary reads `Set: foo.bar=1; push.policy=auto`. The draft passed only because bash 3.2 ignores a false mid-test `[[ ]]`; it fails on bash 5 too. The controller's `|| false` edit surfaced it.
Correction: change line 1576 to `*"push.policy=auto"*`.

**F2. Task 4, plan 1306.** Expected `11 tests, 0 failures`; with the new nested test `kern-dir.bats` has 5 and `kern-detect.bats` 7. Correction: `12`.

**F3. Task 2 `kern_env` (plan 285-291) and Task 8 test (plan 2100-2107).** `prompt-submit` prints no reminder when `CLAUDE_CODE_ENTRYPOINT` starts with `sdk` (line 2377). Under `sdk-cli` or `sdk-ts` the test "reminder only outside the default preset" fails (verified). Any executor started through the SDK or `claude -p` hits it; again hidden before the `|| false` edit. Correction: add `unset CLAUDE_CODE_ENTRYPOINT` to `kern_env` (after line 290).

**F4. Task 17 Step 7, plan 5240.** "Replace `tests/run-bats tests/scripts` with `tests/run-bats tests/scripts`" is a no-op, and that string is not in M0's files. M0 `scripts/ci-local` line is `bats tests/scripts` (M0 1559) and `ci.yml` step "Script tests" is `run: bats tests/scripts` (M0 1608), so `fetch-upstream.bats` and `kern-dir.bats` keep running outside `run-bats`. Correction: "replace `bats tests/scripts` with `tests/run-bats tests/scripts` in `scripts/ci-local` and in the `Script tests` step of `ci.yml`".

**F5. Plan 554, 941, 1306, 1488, 1872, 1990, 2389, 3003, 3339, 3708, 4107, 5282, 5317.** "`N tests, 0 failures`" prints only with `--formatter pretty` or on a terminal; piped output (executors, CI) is TAP (`1..N`, `ok`, `not ok`). M0 fixed this at its line 343. Correction: use M0's wording: "`1..N` and no `not ok` line (`N tests, 0 failures` on a terminal)".

**F6. Task 18 Step 1, plan 5278 and 5282.** `tests/run-bats ... | tail -1` shows only the last TAP line, so a failure in the middle of a guard file is invisible, and the pipeline status is `tail`'s. "Each guard file ends with `0 failures`" cannot appear in TAP. Correction: `tests/run-bats tests/hooks/$g*.bats | grep -E '^(1\.\.|not ok)'` and expect `1..N` with no `not ok`.

**F7. Task 1, plan 144, 163, 239.** `$SPIKE` (Step 1) and `$L` (Step 4) are used in Steps 3, 4, 6, 7 as if the shell persisted; in an executor each command block is a fresh shell. In Step 7 an empty `$SPIKE` makes `dirname ""` = `.` and the line becomes `rm -rf .`. Correction: start Steps 3, 4, 6 and 7 with `SPIKE=<path printed in Step 1>` and `L="$SPIKE/plugin/hooks/payloads.log"`, and write Step 7 as `: "${SPIKE:?set SPIKE from Step 1}" && rm -rf "$(dirname "$SPIKE")"`.

**F8. Task 1 Step 6, plan 224 and 226.** `save submit-task-notification UserPromptSubmit 'task-notification\|cross-session\|SPIKE\|git log'` matches the user's own typed prompt (3), which contains `git log` and `SPIKE-MARKER` and comes before the report, so the saved "background report" is a typed prompt. `save pretooluse-subagent PreToolUse 'investigator'` matches the main session's Agent tool call (its input names `kern:investigator`) before the subagent's own call. Both fixtures then replay green without testing what their names say. Correction: patterns `'<task-notification\|<cross-session-message\|<scheduled-task'` and `'"agent_type"'`.

**F9. Global Constraints 18, Task 6 1509, M2 interface.** The kernel text exceeds two section budgets (Precedence 469 vs 420, Autonomy 701 vs 650) while line 1509 says "within the design 4.2 budgets"; only the total (3,488 vs 3,960) holds. M2 adds 8 rows (M2 plan 4440-4447, about 80 chars each): about 4,130 chars with no settings, about 4,600 with the `long-settings` fixture (now 3,954, 46 chars of headroom). Rule 7 then warns, and M2 Step 9 expects it not to and forbids shortening the rule text. Nit: the "50-character root" is 52 characters (`/Users/someone/.claude/plugins/cache/kern/kern/0.1.0`).
Correction: trim M1's `kernel.md` by about 150 chars now (Precedence about 40, Autonomy about 40, Routing rule text about 70) and update 3,489 in line 1509; or state in Global Constraints that only the total and rule 7 are enforced and tell M2 to cut row text.

**F10. Task 14, plan 4560 (autopilot step 5).** `.kern/ledgers/*/ledger.md` hard-codes the default work dir; spec A2 and B2 say `WORK/ledgers/*/ledger.md` and `work_dir` is a setting. Correction: "`ledgers/*/ledger.md` under the work dir (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers` prints it)".

**F11. Task 8, plan 2321-2333.** The `UserPromptExpansion` branch turns autopilot on from any event named `kern:autopilot`; spec B2 hook contract 1 requires `expansion_type` `slash_command`. Task 1 never records the value. Correction: add `expansion_type for /kern:autopilot: <value>` to the Task 1 record, and in the `kern:mode | kern:autopilot)` arm dispatch with allow-on only when `json_get expansion_type` equals `slash_command`.

**F12. Task 11, plan 3358 and 3534.** G2 asks for a merged or closed PR on the same head; design 8.3 says duplicate PRs are denied. The plan's reconciliation table (lines 37 to 49) has no row for it. Correction: add a reconciliation row, or change the vote at 3534 to `deny`.

**F13. contract.md 174.** "`kern-dir SUB`: SUB is lowercase letters, digits and dashes" contradicts contract.md 150 and plan 1128 (nested names). Correction: "SUB is one or more segments of lowercase letters, digits and dashes, joined by `/`".

**F14. Plan 85 (Interfaces M2 relies on).** Says each summary line is "present only when non-empty"; `settings_summary` always prints `Settings files: none; defaults apply` (fixture `no-settings` expects it). Correction: add "`Settings files` is always printed".

**F15. Task 13 Step 7, plan 4433.** "`real` under 0.5 s": measured 0.41 s under `/bin/bash` 3.2 on this machine for `npm test && git status`; M2 adds G18 to the same dispatcher. Correction: "under 1 s".
