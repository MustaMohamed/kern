# Pre-flight: kern M2 plan

Read-only scan. No plan edited, no repo created.

## Inputs

| File | md5 at end of scan | Note |
|---|---|---|
| `plans/2026-10-12-kern-m2-plan.md` | `ea89b86e...` | unchanged during the scan (mtime 11:09) |
| `plans/2026-10-12-kern-m1-plan.md` | `5a1eb2d2...` | edited by someone else during the scan (11:4x to 11:50). M1 line numbers below are from this latest version |
| `plans/2026-10-12-kern-m0-plan.md` | `4d67d3d4...` | edited during the scan (11:39, 11:47). Every M0 string M2 consumes was re-checked in this latest version |
| `plans/contract.md` | `9a5185dc...` | line 174 changed during the scan (now allows nested `kern-dir` SUB) |

Two items resolved by those concurrent edits are not counted as findings: M2 Task 23 line 4842 assumes ci-local runs `tests/run-bats tests/scripts` (true only since M1 line 5254 was rewritten), and contract line 174 (kern-dir SUB) now agrees with M1 Task 4.

## Method

- Built a synthetic tree at `scratchpad/preflight-m2/t` from the plan text: M0 lint, frontmatter, rank (ported from `~/Code/projects/kern/.upstream/addy/scripts/run-evals.js` lines 62-102 and 121-139 as M0 Task 7 says), route-eval; M1 hooks libs, dispatcher, G16, kernel, settings table, help, mode, autopilot, rule 6/7/13/15; then applied M2 Tasks 1 to 22 in order (ported reference files stubbed with their required headings).
- Ran, measured: `node --test` for agents, lint rules (M0 + M1 + M2 rules 5, 9, 12; rule 7 tests skipped because they `git init`), route-eval, route-eval-rows, all M2 skill tests, adherence; `node scripts/lint-skills.mjs`; `node scripts/route-eval.mjs`; `tests/run-bats` (macOS `/bin/bash` 3.2.57) on `task.bats` and `find-polluter.bats` (10 of 10 pass); G18 through M1's `hooks/pre-tool-use` with real payloads under bash 3.2; `floor-scan` and `claim-check` on hand-built git-style diffs (BSD awk); `shellcheck` 0.11.0 on every M2 script; `/bin/bash -n` on every M2 script; `task-brief` over all 24 tasks of the M2 plan itself; session-start rendering before and after Task 21's rows.
- Not run (they create git repos): `wt-new.bats`, `wt-snap-diff.bats`, `wt-fork-apply.bats`, `claim-probe.bats`, `g18.bats` setup, `no-commit-review.bats`, M1 rule 7 tests. These were traced by hand. mawk is not installed, so the mawk claim in Tasks 5 and 23 is unverified.
- Rule-13 errors in the synthetic tree come from guard files I did not build (G1 to G15); they are excluded from the lint results below.

Labels in the Result column: **measured** (ran it), **traced** (read the code path by hand), **inferred**.

## 1. Interface pairs

| # | Tasks | Producer, then what the consumer uses (exact names) | Result |
|---|---|---|---|
| I1 | M2 T1 -> T2 | `tests/helpers/wt.bash`: `KERN_ROOT`, `wt_test_env`, `make_fixture DIR`; `wt-new SLUG` in setup | consistent (traced) |
| I2 | M2 T1 -> T3 | `scripts/lib/wt-common.sh`: `wt_dir`, `wt_path_free`, `wt_exclude_dir`, `wt_include`, `wt_setup`; marker `<git dir>/kern-setup-done`; `wt-check` in T3 test | consistent (traced); settings source issue F13 |
| I3 | M2 T2 -> T3 | `wt-snap WT` tree; `wt-diff ... --out F` writes `F.patch` (`git diff --binary`); `wt-apply PATCH DST_WT` | consistent (traced) |
| I4 | M2 T3 -> T6 | `probe` runs `cd "$wt" && bash wt-fork "$wt" probe-$$-$RANDOM`, removes it with `worktree remove --force` | consistent (traced) |
| I5 | M2 T2 -> T5 | wt-diff package (`## Diff` with `-U10`) or `.patch` as `floor-scan DIFF_FILE` input | consistent (measured on an equivalent diff: the 7 expected hits, README silent, exit 1) |
| I6 | M2 T2 -> T6/T17 | package as `claim-check WT DIFF_FILE` input | consistent (measured: `notes.js:2 sha-unknown deadbee1cafe`, `notes.js:3 absolute-claim`, exit 1) |
| I7 | M2 T4 -> T14 | `task-brief` needs `## Global Constraints` and `### Task N:`; plan-template and task-template carry both | consistent (measured: task-brief extracts all 24 M2 tasks from the M2 plan itself, fence-aware) |
| I8 | M2 T4 -> T16 | `task-brief PLAN N LEDGER_DIR` -> `LEDGER_DIR/briefs/task-N.md`; `task-start LEDGER N TREE`; `task-done LEDGER N TREE -- CMD` logs to `<ledger dir>/logs/task-N.log`; ledger-format lines | consistent (measured: task.bats 7/7 under bash 3.2) |
| I9 | M2 T7 -> T8 | `G18_AGENTS="kern:investigator"`; investigator `tools` per path A/B; investigator Rule 1 list is inside G18's allowlist | consistent; path B text wrong (F12) |
| I10 | M2 T8 -> T16 | implementer first line `Status: DONE \| DONE_WITH_CONCERNS \| BLOCKED \| NEEDS_CONTEXT`; reviewer `Spec:` / `Task quality:` and modes `task`, `re-review`, `whole-branch` | consistent (traced) |
| I11 | M2 T8 -> T11 | implementer reads the implement SKILL.md by the absolute path in the dispatch | consistent |
| I12 | M2 T9 -> T17 | rule 5 `BUILTIN_SKILLS` has `code-review`; self-review says "Skill tool with `code-review`" | consistent (measured: lint clean) |
| I13 | M2 T9 -> T10..T20 | rule 9: auto has `## Steps`, slash has it first; path skipped | consistent (measured: no rule 9 errors on M2 skills) |
| I14 | M2 T10 -> T17, T18, T19 | `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md` (rule 4 rooted path) | consistent (Task 10 runs first) |
| I15 | M2 T11 -> T12, T16 | `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` | consistent |
| I16 | M2 T15 -> T16 | `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/SKILL.md` and `.../references/brief-template.md`; task order puts T15 first | consistent |
| I17 | M2 T13 -> T14 | spec frontmatter `status: approved`; spec-template headings | consistent |
| I18 | M2 T14 -> T16 | plan frontmatter `status`, `execution:`, `commits: ask` | consistent; approval record incomplete (F17) |
| I19 | M2 T17 -> T19 | verdicts `fix first` / `split` stop finish-branch | consistent |
| I20 | M2 T18 -> T16, T19 | "steps 3 to 6" of commit | T16 consistent; T19 says "the steps" (F19) |
| I21 | M2 T10, T20 -> T21 | `evals/cases/<auto>.json`, `row-<route>.json`, `ownerOf` | recall negatives fail (F6); row-define positives fail (F7) |
| I22 | M2 T21 -> T22 | route names; `readSteps` keeps `0.` lines | consistent (measured: adherence 8/8; dry-run lists 4 cases) |
| I23 | M2 T1, T2, T4 -> T23 | e2e: wt-new, wt-snap, task-start, wt-diff `--out`, task-done from the worktree | consistent (traced) |
| I24 | M2 T7, T12 -> T23 | shellcheck list at 4837-4839 includes `g18-readonly-agent.sh` | fails (F5) |
| I25 | M2 T10..T20 -> M1 help map | each task appends a map row | rows lack backticks (F1) |
| I26 | M2 T11, T13, T15 -> T1 | `wt-new <slug>` with no `--branch`/`--detach` | exits 2 under a `{id}` branch.pattern (F15) |
| I27 | M0 T5 -> M2 T9, T21 | `loadModel`, `RULES`, `err`, `rel`, `join`, `existsSync` in `lint-rules.mjs` | consistent (measured: rules 5, 9, 12 appended, tests pass) |
| I28 | M0 T5 -> M2 T9 Step 1 | agent fixtures at M0 lines 709 and 719 (`...permissionMode: plan\n---\nbody\n`, `${'z'.repeat(151)}\n---\nbody\n`) | exact strings found; replaced; M0 and M1 lint tests still pass (measured) |
| I29 | M0 T5 -> M2 T9, T21 | test helpers `repo`, `skill(name, fm, body)`, `lint`, `rules`; new top-level `manual`, `agentDoc`, `caseJson` | no name clash with M0/M1 (`kernel`) (measured) |
| I30 | M0 T7 -> M2 T21 | `targets`, `evaluate`, the four comparison lines Step 4 rewrites | all four anchors present in latest M0 (M0's 11:47 edit only swapped in `isMain`); measured tests pass |
| I31 | M0 T7 -> M2 T10, T20, T21 | rank tokenizer: drops tokens of 2 chars or fewer ("pr", "ci", "up") and STOP words, light stemming | explains F6 and F7 |
| I32 | M0 T4, T7 -> M2 T10 | `skills/hello`, `evals/cases/hello.json`, `evals/fixtures/hello`, `evals/baseline.json` | removal consistent; prove-it alone ranks 66%, below a hello-era 100%, and Step 7's one-time reset covers it (measured) |
| I33 | M0 T5 -> M2 T20 | `parseFrontmatter` strips surrounding single quotes | consistent (measured: recall frontmatter test passes) |
| I34 | M0 T5 -> M2 T8 | rule 2 `AGENT_KEYS`; rule 3 agent limit 150 | consistent (measured: 149, 144, 130 chars; lint clean) |
| I35 | M0 T6, T8 -> M2 T23 | `scripts/release.mjs minor`; ci-local; ci.yml job `checks` | consistent |
| I36 | M0 T5, T7 -> M2 T22 | loaders read only `evals/cases/` | `evals/adherence/` is not picked up as cases (consistent) |
| I37 | M1 T3 -> M2 T1, T3 | `kern_main_root [dir]`; `settings_get KEY [DEFAULT]` resolves from `KERN_MAIN`, else `CWD`, else `PWD` (M1 697) | works in tests; scripts set `MAIN`, not `KERN_MAIN` (F13) |
| I38 | M1 T4 -> M2 T1 | `kern-detect base_branch` prints `value<TAB>evidence`, exit 3 | consistent (pipefail carries exit 3 to `\|\|`) |
| I39 | M1 T4 -> M2 T2 | `kern-dir reviews` run from WT resolves MAIN | consistent |
| I40 | M1 T4 -> M2 T16 | `kern-dir ledgers/<plan-slug>`; M1 line 1134 allows `/`, lowercase only | uppercase slugs exit 2 (F14) |
| I41 | M1 T9 -> M2 T7 | dispatcher sets `TOOL`, `AGENT`, `KERN_INPUT`, `TOOL_INPUT`; `KERN_GUARDS`; `guard_<id>` from file name up to the first `-` | consistent (measured); G18 uses `json_get command` on the whole payload instead of `ti_get command` (works) |
| I42 | M1 T9 -> M2 T7 | `git_words` -> `_split_words` splits on `&` (M1 2707) | `2>&1` is split before `g18_allowed` sees it (F4) |
| I43 | M1 T9 -> M2 T7 | `git_sub` prints `<dir>\t<sub>\t<rest>` after consuming `-C`, `-c` | consistent; G18 never checks `-c` (F9) |
| I44 | M1 T9 -> M2 T7 | `vote allow\|ask\|deny G<n> "<reason>"` (M1 89, decide.sh 2593) | G18 votes `g18` (F10) |
| I45 | M1 T1 -> M2 T7 | spike line `agent_type in subagent PreToolUse: <value or absent>` | consistent |
| I46 | M1 T17 -> M2 T7 | CI and ci-local `shellcheck -x -S warning hooks/guards/*.sh` | G18 has warning-level SC2221/SC2222 (F5) |
| I47 | M1 T14, T15, T16 -> M2 T9 | mode, autopilot, help open with `## Steps`; unslop has none | only unslop needs the rule 9 exemption Step 5 names (measured) |
| I48 | M1 T16 -> M2 T21 | rule 6: route file body must match `/^## Steps\n+1\. /m` (M1 4979) | every M2 route opens with `0. Defer` (F2) |
| I49 | M1 T16 -> M2 T10..T20 | rule 6 map check: a skill counts as listed only when the row's first cell is its name in backticks (regex at M1 4983) | M2 rows have no backticks (F1) |
| I50 | M1 T6 -> M2 T21 | row texts "Prose others read: PR body, issue, doc, commit message" and "Phase ends, or context is filling" | match exactly; row-technical-writing and row-context cases pass (measured) |
| I51 | M1 T6 -> M2 T21 | routing sentence "Non-trivial work with no match: write a short plan as a todo list first." (M1 1619); M1 interface line 86 expects "...: plan." | Step 7 wording ambiguous and differs (F11) |
| I52 | M1 T6, T17 -> M2 T21 | `tests/hooks/session-start.bats` asserts `[ "${#norm}" -le 4000 ]` (M1 1551); rule 7 warn at 4,000 | M2 rows push the kernel to 4,549 chars (F3) |
| I53 | M1 T10 -> M2 T15, T16 | G1 asks on `git worktree remove --force`, denies under autopilot (M1 3036) | consistent with parallel-work step 9 and Stops |
| I54 | M1 T10, T11 -> M2 T19 | G1 asks on push; G2 drafts and dedups PRs | consistent |
| I55 | M1 T16 -> M2 T10 | `lint-exemptions.json` entry `{rule 6, skills/hello/SKILL.md}` | removed in Task 10 Step 6 (consistent) |
| I56 | M1 T6 -> M2 T22 | kernel: "open a todo list whose first items are its `## Steps`, copied verbatim" | grader checks the same (consistent) |
| I57 | M1 T17 -> M2 T7, T23 | ci-local `tests/run-bats tests/hooks` picks up `tests/hooks/g18.bats` | consistent |
| I58 | M1 T16 -> M2 T24 | `/kern:help setup` writes only after a yes; pilot project has `.claude/skills/commit` and `.claude/skills/self-review` | consistent (checked on disk) |

## 2. Per-task self-consistency

| Task | Tests vs code | Files created vs staged | Commands at that point | Result |
|---|---|---|---|---|
| T1 (84) | 16 tests traced against wt-new/wt-check; bash 3.2 `${pattern//\{slug\}/$slug}` measured OK | 5 created, 5 staged | run-bats (M1), shellcheck | consistent; shellcheck clean (measured); F13 |
| T2 (484) | 10 tests traced; "real index untouched" holds (status rewrites a byte-identical index) | 3, 3 | kern-dir (M1) | consistent; shellcheck clean |
| T3 (704) | 8 tests traced (deletion, binary, conflict message names `a.txt`) | 3, 3 | ci-local checkpoint | consistent; shellcheck clean |
| T4 (897) | 7/7 pass under bash 3.2 (measured) | 4, 4 | | consistent |
| T5 (1138) | 4 tests; equivalent diff gives exactly the asserted hits (measured, BSD awk) | 2, 2 | mawk claim at 1281 unverified | consistent |
| T6 (1292) | 7 tests traced; claim-check measured; probe traced for all 5 cases | 3, 3 | ci-local checkpoint | consistent; shellcheck clean |
| T7 (1529) | 6 of 7 tests pass; "pipes and stderr" fails on `cat a.txt 2>&1 \| wc -l` (measured deny) | 2 created; 4 staged (spike doc, CHANGELOG not in Files) | shellcheck | F4, F5, F9, F10, F22 |
| T8 (1717) | 3/3 pass; 2,651 / 2,350 / 1,793 bytes (limits 4,500 / 5,000 / 3,000) | 5 created + CHANGELOG, all staged | lint | consistent; F12 (path B only) |
| T9 (2012) | lint tests pass (measured); real-tree lint reports only unslop rule 9, as Step 5 expects | 3 modified, staged | ci-local checkpoint | checkpoint red because of F5 |
| T10 (2163) | 4/4 pass; 2,499 / 1,436 bytes | staged incl. deletions via `git rm` | lint, route-eval | lint fails (F1); route-eval passes after the baseline reset Step 7 allows |
| T11 (2363) | 3/3 pass; 3,256 bytes | staged | lint | F1, F8 |
| T12 (2509) | 3/3 node, 3/3 bats under bash 3.2 (measured) | staged | shellcheck clean; ci-local checkpoint | F1, F8; checkpoint red (F1) |
| T13 (2779) | 3/3 pass; 4,314 bytes | staged | lint | F1, F8 |
| T14 (3004) | 3/3 pass; 3,620 bytes | staged | lint | F1, F8, F17 |
| T15 (3221) | 3/3 pass; 3,265 bytes | staged | lint | F1, F8, F15 |
| T16 (3387) | 3/3 pass; 6,873 bytes (limit 9,500) | staged | ci-local checkpoint | F1, F14; checkpoint red (F1) |
| T17 (3598) | 3/3 pass; 3,472 bytes | staged | lint | F1, F8 |
| T18 (3771) | 2/2 pass; 2,589 bytes | staged | lint | F1, F19 |
| T19 (3894) | 3/3 pass; 2,716 bytes | staged | lint | F1 |
| T20 (4053) | 3/3 pass; 3,533 bytes; descriptions 257 + 265 = 522 | staged | lint, route-eval, ci-local checkpoint | F1, F6, F8; route-eval FAILED (measured) |
| T21 (4225) | rows and rule 12 tests pass (33 measured) | staged | lint, route-eval, `node --test` | F2, F3, F7, F10 (rule 6: 8 errors; route-eval: 4 errors, measured) |
| T22 (4501) | 8/8 pass; dry-run prints the 4 ids (measured) | all staged incl. `.gitignore` | | consistent |
| T23 (4777) | e2e traced; inherits F5 at 4837-4839 | 1 created; staged | release.mjs | F5, F20, F21, F22 |
| T24 (4883) | manual pilot | `docs/pilot.md` staged | `/kern:help setup` | consistent |

## 3. Conflicts with the Global Constraints, the spec or the contract

| # | Rule (source) | M2 text | Finding |
|---|---|---|---|
| X1 | Design 4.3 "Every route file opens with a numbered `## Steps` list"; skills spec A6 step 0; M2 Global (line 28) | M1 rule 6 enforces `1.` first; M2 steps start at `0.` | F2 |
| X2 | Design 4.1 target 4,000 chars; 4.2 routing budget 1,100; design 14 M1 acceptance "under 4,000" | Task 21 rows render 4,549 chars with no settings (routing section about 2,000) | F3 |
| X3 | Design 4.3 rule text "Non-trivial work with no match: plan."; M1 line 86 | Task 21 writes "Read {KERN}/plan/SKILL.md." | F11 |
| X4 | Design 8.3 G18: Bash outside a read-only allowlist is denied | allowlist passes five write-capable commands | F9 |
| X5 | M2 Global line 31: every dispatch names its model | define, plan, diagnose dispatch `kern:investigator` with no model | F16 |
| X6 | M2 Global line 25: approval recorded with the date and the user's words | plan step 12 and plan-template omit both | F17 |
| X7 | M2 Global line 27 and skills spec A9: page-when-installed check | no skill states the check | F18 |
| X8 | Contract lines 143 and 177: help map first cell `` `<skill>` `` | M2 map rows unquoted | F1 |
| X9 | Contract line 82 (reasons as `G<n>: <reason>`); M1 line 89 | G18 votes `g18` | F10 |
| X10 | Contract line 153: "`[[ ]]` mid-test need bash 4+ (`tests/helpers/wt.bash` refuses bash 3.2)" | M2 line 33 and wt.bash use `\|\| false` on bash 3.2 | F23 |
| X11 | Skills spec agent `implementer` description 155 chars | M2 shortens to 149 (documented at 1733) | none: documented deviation within lint rule 3 |

## Findings

Severity: High means a check the plan states will fail as written; Medium means wrong behaviour or a step an executor is likely to misapply; Low means a contract or wording mismatch.

| ID | Sev | Task, plan line | What is wrong | Smallest correction |
|---|---|---|---|---|
| F1 | High | T10 2344, T11 2492, T12 2757, T13 2987, T14 3204, T15 3370, T16 3576, T17 3754, T18 3877, T19 4036, T20 4201 | Map rows start `\| prove-it \|`. M1 rule 6 only counts backticked first cells (M1 4983), so lint reports "prove-it is missing from skills/help/references/map.md" (measured) and every later lint, checkpoint and ci-local run is red. | Write each first cell in backticks, for example ``\| `prove-it` \| auto \| ...``; add "first cell in backticks" to contract line 143. |
| F2 | High | T21 4437-4448, expectation at 4488 | M1 rule 6 requires `## Steps` followed by `1. ` (M1 4979). Every M2 route opens with `0. Defer`, so the eight new rows give 8 rule 6 errors (define, plan, execute-plan, implement, diagnose, prove-it, self-review, recall; measured). | In Task 21, change the regex to `/^## Steps\n+\d+\. /m` in `scripts/lib/lint-rules.mjs` (already staged) and add a rule 6 test with a `0.` route. Verified: lint clean after the change. |
| F3 | High | T21 Step 7 4435, Step 9 4488 | The 8 rows grow the rendered kernel from 3,443 to 4,549 chars (50-char root, no settings, measured) and to about 5,060 with long-settings. M1 `tests/hooks/session-start.bats` asserts `-le 4000` (M1 1551), so `tests/run-bats tests/hooks` and ci-local go red; rule 7 warns. Shortening the When text cannot fix it: 8 rows with absolute paths need about 700 chars against 557 of headroom. | A user decision. Smallest: in Task 21, raise the M1 bats bound and rule 7's warn threshold (and design 4.1's target) to the measured size plus margin, recorded in CHANGELOG. Alternative: render routes relative to the root printed in the header. |
| F4 | High | T7 test 1588, code 1693 | M1's `_split_words` splits on `&` (M1 2707), so `cat a.txt 2>&1 \| wc -l` reaches `g18_allowed` as `cat a.txt 2>` and `1` and is denied (measured). The test "pipes and stderr to /dev/null stay allowed" fails. | Before the `git_words` loop in `guard_g18`: `cmd=$(printf '%s' "$cmd" \| sed 's/[0-9]*>&[0-9-]//g')`. Verified: allowed, other denies unchanged. |
| F5 | High | T7 1647, 1666; Step 4 1700; T23 4839 | shellcheck: SC2221/SC2222 (warning) because `*' -exec'*` already covers `*' -execdir'*`; SC2016 (info) on `*'$('*`. Step 4's "prints nothing" fails, M1's `shellcheck -x -S warning hooks/guards/*.sh` fails from Task 7 on (Task 9 checkpoint), and Task 23's line fails. | Drop `\|*' -execdir'*`; write the pattern as `*\$\(*`. Verified: shellcheck clean. |
| F6 | High | T20 4178-4179 | Both recall negatives rank recall first: "What does recall mean in machine learning metrics?" (0.18; shares `recal`, `what`) and "Explain what this regex does" (0.06; shares `what` from "what remains"). route-eval FAILED at Task 20 Step 7, Task 21 Step 9 and every ci-local after (measured). | Use negatives that share no token with the description, for example "Add a CSV export to the reports page" and "Rename the config loader to settings loader". Verified: route-eval passed. |
| F7 | Medium | T21 4460 | Two row-define positives share no vocabulary with "New behaviour and no agreed spec": "Add a CSV export to the reports page" and "Build a feature that lets users invite teammates" (measured "shares no vocabulary"). Step 9's escape only names "ranks outside the top 3". | Reword to the row's words, for example "New behaviour: a CSV export on the reports page, no spec yet" and "We want new behaviour for team invites and there is no agreed spec". Verified: rank-1 rate 88%, passed. |
| F8 | Medium | T11 2468, 2475; T12 2651, 2657, 2663; T13 2960, 2966, 2972; T14 3189; T15 3356; T17 3708, 3714; T20 4164 | Each port check starts with `node scripts/lint-skills.mjs`, but the task's map row is added in a later step and sibling references may not exist yet, so the check fails with rule 6 (and rule 4) errors. Measured at T11 Step 4: `rule 4: referenced file missing: references/slicing.md`, `rule 6: implement is missing from ...map.md`. | Drop `node scripts/lint-skills.mjs &&` from these per-file checks; each task's final test step already runs lint. Or move the map-row step before the SKILL.md step. |
| F9 | Medium | T7 1653-1670 | G18 lets write-capable commands through with no vote (measured): `uniq a.txt out.txt`, `sed -n 1w/tmp/out.txt a.txt`, `git -c core.pager=<cmd> log`, `git -c diff.external=<cmd> diff`, `git grep -O<cmd> foo`. Conflicts with design 8.3 G18. | In `g18_allowed`: deny git when a word is `-c`, `--config-env*`, `-O*` or `--open-files-in-pager*`; drop `uniq`; accept `sed -n` only with scripts matching `^[0-9,$]*p$`; add the five commands to the deny test. |
| F10 | Low | T7 1683, 1689 | `vote deny g18 ...` renders `kern g18:`; the contract and M1 use `G<n>` (M1 89), and M1's fix-a-run tells users to look for `kern G<n>:` (M1 4894). | `vote deny G18 ...` in both places. |
| F11 | Medium | T21 Step 7 4450 | "replacing any shorter version M1 wrote" does not name M1's sentence ("Non-trivial work with no match: write a short plan as a todo list first.", M1 1619), which is not a shorter version; an executor can keep both. The check counts only "Several matches". The new wording also differs from design 4.3 and M1 line 86 ("...: plan.") and adds about 70 rendered chars. | Name the exact M1 sentence to replace, use the spec text "Several matches: define and diagnose before build. Non-trivial work with no match: plan.", and add `grep -c 'Non-trivial work with no match' kernel/kernel.md` (expect 1). |
| F12 | Low | T8 Step 6 1959 | Path B says "replace Rule 2", but the Bash rule is Rule 1; Rule 2 is "Never write files...". | "replace Rule 1". |
| F13 | Low | T1 389, 91; T3 830 | wt-new and wt-fork set `MAIN`, but M1 `settings_get` reads `KERN_MAIN`, else `CWD`, else `PWD` (M1 697). wt-fork takes MAIN from SRC_WT while `worktree.dir` and `worktree.setup` come from the caller's cwd. Task 1's Interfaces claims settings are read from `$MAIN`. | `export KERN_MAIN="$MAIN"` right after each `MAIN=` line. |
| F14 | Low | T16 step 2 3464 | `kern-dir` accepts lowercase only (M1 1134); a plan slug such as `CDS-2465-export` exits 2. | Say "the plan file's basename, lowercased", or make define and plan write lowercase slugs. |
| F15 | Low | T11 2431, T13 2862, T15 3292 | `wt-new <slug>` with no `--branch` or `--detach` exits 2 when `branch.pattern` holds `{id}` (the pilot uses `{id}/{slug}`). | Workers and spikes use `--detach`; implement passes `--branch <name>` when the pattern has `{id}`. |
| F16 | Low | T12 2620, T13 2856, T14 3080 | Global line 31 says every dispatch names its model; these dispatch `kern:investigator` without one. | Add "on `model.investigator` (default `sonnet`)" to each. |
| F17 | Low | T14 3089, template 3120-3127 | Global line 25 wants the date and the user's words; plan step 12 sets only `status: approved` and `execution:`, and plan-template has no `approved:` field. | Add `approved: (date and the user's words)` to plan-template and "with the date and the user's words" to step 12. |
| F18 | Low | Global 27; T13 2860, 2882; T14 3089, 3104; T17 3695; T20 4152 | The "page when installed" check is not stated in any skill. Writing `${CLAUDE_PLUGIN_ROOT}/skills/visual/SKILL.md` in a SKILL.md would fail rule 4 in M2 (file absent). | One line per skill (or in the kernel Reply section): "A page only if kern's `visual` skill is installed; otherwise stay in chat and say once 'visual pages not installed'." |
| F19 | Low | T18 3780; T19 3968 | Commit's interface says finish-branch runs its steps 3 to 6; finish-branch step 7 says "the steps of" commit, which includes the consent and branch steps. | "Commit by running steps 3 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`." |
| F20 | Low | 473, 693, 881, 1127, 1281, 1513, 1701, 2763, 4830 | Expected lines use bats' pretty `N tests, 0 failures`, which prints only on a terminal; piped runs print TAP (`1..N`, `ok` lines). M1 added a note for this (M1 51); M2 has none. | Copy M1's note into M2's Global Constraints. |
| F21 | Low | T23 Step 6 4865 | A token-spending run is preceded only by "tell the user"; the kernel's Autonomy section lists spend as ask-first. | "Ask the user and run it only on yes." |
| F22 | Low | T7 Files 1531-1534 vs 1711; file map 76, 77 | Task 7's Files block omits the spike doc and CHANGELOG it stages; the file map omits `.gitignore` (T22) and `tests/scripts/no-commit-review.bats`, CHANGELOG and manifests (T23). | List them. |
| F23 | Low | contract.md 153 | Says `[[ ]]` mid-test needs bash 4+ and wt.bash refuses bash 3.2; the M2 plan (line 33, wt.bash 100-131) uses `\|\| false` under `tests/run-bats` on bash 3.2. | Replace line 153 with M2 line 33's rule. |

Row counts: 58 interface rows, 24 per-task rows, 11 conflict rows (93 in all); 23 findings.
