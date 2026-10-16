# M0 pre-flight scan

Method: every code block of the plan was extracted by line range into `scratchpad/preflight-m0/r/` (a scratch copy; `~/Code/projects/kern` untouched) and run there. Run results: `fetch-upstream.bats` 7/7 (under `/bin/bash` 3.2 and bash 5), shellcheck clean, `licensing` 5/5, `lint-rules` 12/12, `versions` 7/7, `route-eval` 6/6, `node scripts/lint-skills.mjs` clean, `check-version` agree, `route-eval` passed (rank-1 100%), `claude plugin validate . --strict` exit 0 (marketplace and plugin.json), full `scripts/ci-local` passes. Real `fetch-upstream` against GitHub worked; all pinned SHAs and versions in UPSTREAM.md match the clones. So the code and tests agree with each other. The findings below are about gaps, traps and conflicts, not red tests.

Line numbers are lines of `kern-spec/plans/2026-10-12-kern-m0-plan.md`.

## 1. Task pairs (shared file or interface)

| # | Pair | Produces vs consumes | Result |
|---|---|---|---|
| P1 | T1 to all | `KR=~/Code/projects/kern`, `.gitignore` (`.upstream/`, `evals/results/`, `.lint-names`) | Agree. But `KR` and `SP` are not defined in the steps that use them (F2), and `KR` already exists (F1). |
| P2 | T1 to contract Locations | docs copied to `docs/specs`, `docs/plans`, `docs/research` | Agree. All 12 research files exist in the scratchpad. Step 2 `ls` checks only 2 of the 6 name groups (merge-*, audit-*), harmless. |
| P3 | T2 to T3 | `.upstream/superpowers/LICENSE`, `pstack/pstack/LICENSE`, `pocock/LICENSE`, `addy/LICENSE`, `caveman/LICENSE`, `caveman/NOTICE` | Agree. All six exist at those paths after the real fetch. |
| P4 | T2 to T7 | `.upstream/addy/scripts/run-evals.js` lines 62-102 and 121-139 | Agree. Line 62 is `const STOP`, 102 closes `termFreq`, 121 opens `vec`, 139 closes `cosine`. `grep -c 'export function'` prints 7; `tokenize('conflicts branching')` gives `['conflict','branch']`. |
| P5 | T2 to T7 | `.upstream/superpowers/skills/<name>/SKILL.md` descriptions for the distractors | Path agrees. Wording differs for 2 of 4 (F10). |
| P6 | T2 to contract Additions | `.upstream/pstack/pstack/skills`, `pocock/skills/engineering`, `addy/skills`, `local/recall/SKILL.md`, `local/comment-sicko.md` | Agree. All exist. |
| P7 | T3 `UPSTREAM.md` columns to `licensing.test.mjs` | destructure `[key,,,,copyright,,url]` over 7 columns | Agree. Copyright cells equal line 3 of each licence file; caveman equals NOTICE line 2. |
| P8 | T3 NOTICE "## File map" to T7 and T8 | T7 appends map lines; T8 says it modifies NOTICE | Mismatch (F5): T8 lists NOTICE under Modify with no step and no `git add`; T7 maps only `distractors.json`, not the two scripts it ports from addy. |
| P9 | T4 to T5 | `skills/hello/SKILL.md`, `.claude-plugin/*.json` | Agree. Lint clean on the real files; no machine paths, no long dashes. |
| P10 | T4 to T6 | version `0.1.0` in plugin.json, marketplace.json, `## [0.1.0] - <date>` | Agree. `check-version` prints `versions: agree`. |
| P11 | T5 `loadModel` to T7 `targets` | `skills[].tier`, `.data.description`, `.name` | Agree. Quoted description is unquoted before ranking. |
| P12 | T5 rule 8 to T1 `.gitignore` | `.lint-names` read by rule 8, ignored by git | Gap (F7): nothing creates `.lint-names`, so the name check never runs in CI or fresh clones. |
| P13 | T5 `SHIPPED_DIRS` to T6 `SHIPPED` | 5 dirs both | Agree with each other. Both are broader than spec 11.2 rule 14 (F11). |
| P14 | T6 CLI to T8 CI | `node scripts/check-version.mjs --pr origin/<base>` | Agree. Works with `fetch-depth: 0`. |
| P15 | T7 CLI to T8 | `node scripts/route-eval.mjs` reads `evals/baseline.json` | Agree. File exists from T7. |
| P16 | T2, T5, T6, T7 tests to T8 `ci-local` | `node --test 'tests/**/*.test.mjs'`, `bats tests/scripts`, shellcheck on 2 scripts | Agree. Node 22 expands the glob; 30 tests run. |
| P17 | T7 to contract "M0 as written" | `tokenize termFreq vec cosine buildCorpus rank similarity`; `targets`, `evaluate`; case shape; minimums 3/2/1 | Agree, exact names and shapes. |
| P18 | T5 to contract "M0 as written" | `parseFrontmatter`, `loadModel`, `RULES`, `err warn rel`, `runLint`; helpers `repo skill lint rules` | Agree. `walk` is not exported, but M1 uses it inside the same module (M1 plan line 5192), so no break. |
| P19 | T5 to M1 plan | M1 inserts rule 6 after rule 11 and replaces "the first two import lines" (the fs and path imports; line 1 is a comment) | Agree. |
| P20 | T7 to M2 | M2 deletes `skills/hello`, `evals/cases/hello.json`, `evals/fixtures/hello` (all created by T7/T4) | Agree on paths. Baseline trap (F6). |
| P21 | T6 `release()` to spec 12 (Keep-a-Changelog) | moves Unreleased "bullets" under the new version | Mismatch (F4): drops `### Added` headings and wrapped lines. |
| P22 | T4 `repository` OWNER to T8 repo creation | `gh api user --jq .login`, then `gh repo create kern` | Agree (`gh` is logged in as MustaMohamed). Task 1 does not check `gh auth status` (F16). |
| P23 | T4 hello reply to T9 | `kern 0.1.0 is installed.` | Agree. |

## 2. Per-task self-consistency

| Task | Tests vs code | Files created vs `git add` | Commands exist at that point | Result |
|---|---|---|---|---|
| T1 | n/a | `.gitignore README.md docs` matches status `?? .gitignore ?? README.md ?? docs/` | `cp`, `git init -b main` fine | `SP` undefined in Step 3, `KR` undefined in Step 6 (F2). `~/Code/projects/kern` already exists with this task's commit (F1). |
| T2 | 7/7 pass on bash 3.2 and 5. Traced: "already at" string, exit 3 on bad SHA, partial clone removed, exit 2 on unknown key. | script + bats = staged | `bats`, `shellcheck` checked in T1 | Expected text `7 tests, 0 failures` is wrong for non-tty (TAP `1..7`) (F12). |
| T3 | 5/5 pass. `sed` on BSD and the `grep -c` check print `0`. | `LICENSE NOTICE UPSTREAM.md licenses tests/licensing.test.mjs` = created set | uses `.upstream` from T2 Step 5 | OK. Informational note I1. |
| T4 | n/a | `.claude-plugin CHANGELOG.md skills/hello/SKILL.md` = created set | `claude plugin validate` fails on empty dir (exit 1), passes with files (exit 0) | OK. |
| T5 | 12/12 pass. Traced rule 10 order `[3,10]`, rule 3 total 1734 over 1500, rule 4 `[4,4]`, rule 8 `[8,8]`. | 5 files = created set | none missing | Rule 8 name list empty by default (F7); no addy source comment though spec says adapted (F14). |
| T6 | 7/7 pass. | 3 files = created set | none missing | `release()` data loss (F4); `SHIPPED` broader than spec (F11). |
| T7 | 6/6 pass, but test 5 passes for the wrong reason (F3). Real run: `hello` 3/3 rank 1, both negatives satisfied, rate 100. | `rank.mjs route-eval.mjs evals tests/route-eval.test.mjs NOTICE` | `evals/fixtures/hello/README.md` created and staged via `evals` | F3, F5, F6, F10. |
| T8 | n/a | `.github/workflows/ci.yml scripts/ci-local`; NOTICE listed under Modify but never edited or staged (F5) | `ci-local` passes locally | `gh run watch` right after push can run before any run exists (F8). |
| T9 | n/a | Step 3 commits with no `git add` (F9) | all commands exist | OK otherwise. |

## 3. Conflicts with Global Constraints and spec

| # | Where | Conflict | Result |
|---|---|---|---|
| C1 | Global line 26 vs session harness | Plan: no attribution trailers. The Claude Code session reminder tells the executor to end commits with a `Claude-Session:` line. | F13. |
| C2 | Global line 19 and spec 2 rule 4 vs `licenses/caveman.*`, UPSTREAM key `caveman` | "Caveman" never a file name in kern. | No real conflict: spec 2 rule 1 and the licensing test require `licenses/<key>.LICENSE`. Informational (I1). |
| C3 | Spec 11.2 rule 14 vs T6 `SHIPPED` | Spec: `skills/`, `kernel/`, `hooks/`; plan also `agents/`, `modes/`. | F11. |
| C4 | Spec 14 M0 "adapted from addy" vs T5/T6 headers | Lint and version scripts carry no source comment; Global line 20 requires one if adapted. | F14. |
| C5 | Global line 22 rule 8 "no personal names" | Not enforced without `.lint-names`. | F7. |
| C6 | Global lines 17-18, 20-23, 25, 26 | Copyright line, pins, description limits, rule 11 chars (none in shipped files, README, CHANGELOG), 72-char subjects (longest is 65), staged named paths. | Agree. |

## Findings

| ID | Task | Plan line | What is wrong | Smallest correction |
|---|---|---|---|---|
| F1 | T1 | 92 | `~/Code/projects/kern` already exists with commit `c8a78b1 "M0: start the kern repo..."`; `docs/` copies equal the scratchpad now. The guard `test ! -e "$KR" \|\| exit 1` stops a fresh run at Step 3. After any plan edit the committed `docs/plans/*` copies go stale. | Mark Task 1 done and start at Task 2, or make the guard `[ -d "$KR/.git" ] && git -C "$KR" log --oneline \| grep -q 'M0: start' && skip`. Re-copy plans into `docs/plans` after the last plan edit. |
| F2 | T1 | 95-97, 136-141 | `SP` is set only in Step 2 (line 83) and used in Step 3; `KR` is set in Step 3 and used in Step 6 (`git -C "$KR"`). Shell state does not persist between tool calls, so `cp "$SP"/...` and `git -C ""` fail. | Put `SP=...` at the top of the Step 3 block and `KR=~/Code/projects/kern` at the top of Step 6. |
| F3 | T7 | 1260, 1265 | Test `a distractor that outranks the skill fails the positive` never reaches the ranking branch. Skill `a` ("greeting kern hello") shares no word with "write a plan for tasks", so the error is `shares no vocabulary`; the assertion's `\|\|` hides it. Verified. | Line 1260 description: `'Use when greeting kern hello or showing a plan'`; line 1265: `assert.ok(...some((e) => /positive prompt ranked #2/.test(e)))`. Verified output: `positive prompt ranked #2 (need top 1)`. |
| F4 | T6 | 1151, 1156 | `release()` keeps only lines starting `- ` and replaces the whole Unreleased block. `### Added` / `### Fixed` headings and wrapped bullet lines are deleted silently (verified). Spec 12 says Keep-a-Changelog, which uses those headings. | Move the Unreleased block text verbatim: capture `m[1].trim()` in `unreleasedBullets`' sibling `unreleasedBody(log)` and write it under the new heading; keep the "empty" check on bullets. Add a test with a `### Added` heading and a wrapped line. |
| F5 | T7, T8 | 1483, 1513, 1586 | T8 lists `Modify: NOTICE (file map lines for everything ported so far)` but no step edits it and the commit omits it. T7 maps only `evals/distractors.json`; `scripts/lib/rank.mjs` and `scripts/route-eval.mjs` (ported from addy) have no map line. | In T7 Step 5 append three lines: `- scripts/lib/rank.mjs: addy scripts/run-evals.js`, `- scripts/route-eval.mjs: addy scripts/run-evals.js`, and the distractors line. Drop NOTICE from T8's Files. |
| F6 | T7 | 1497-1498 | `--update-baseline` sets `min_rank1` to 100 against a one-skill corpus with no real competitors. M2 deletes `hello` and adds real skills; any rank-1 miss then fails `route-eval` and the floor cannot be lowered by the tool. | Do not run `--update-baseline` in M0 (leave `0`), or add a line in T7 saying M2 must reset `evals/baseline.json` when it removes `hello`. |
| F7 | T5 | 106, 921-923 | Rule 8's personal-name check reads `KERN_LINT_NAMES` or the gitignored `.lint-names`. Nothing creates either, so on CI and fresh clones only machine paths are checked. Global Constraint "no personal names" is unenforced. | Add to T5 Step 6: `printf 'Mustafa\nMusta\n' > .lint-names` locally, and for CI set `KERN_LINT_NAMES` as a repo variable or note the limit in README. |
| F8 | T8 | 1595 | `gh run watch "$(gh run list --limit 1 ...)"` runs right after the push; the run may not exist yet, giving an empty id and an interactive picker. | Loop: `until [ -n "$id" ]; do id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId'); sleep 3; done` then watch `$id`. |
| F9 | T9 | 1621 | "Commit as `M0: record acceptance`" has no stage command; Global Constraint requires `git add -- <paths>`. | `git add -- CHANGELOG.md && git commit -m "M0: record acceptance"`. |
| F10 | T7 | 1477, 1479 | Distractors `brainstorming` and `verification-before-completion` are rewritten, not shortened: upstream `brainstorming` starts `You MUST use this before any creative work - ...` and `verification-before-completion` continues `- requires running verification commands ...`. Line 1483 says to keep upstream trigger wording, so the executor will edit them after the fact. | Use the upstream first clause verbatim in the plan text: `"You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior"`. Re-run T7 Step 6 after the change. |
| F11 | T6 | 1085 | `SHIPPED = /^(skills\|agents\|kernel\|modes\|hooks)\//` but spec 11.2 rule 14 names only `skills/`, `kernel/`, `hooks/`. A PR touching only `agents/` or `modes/` fails CI that the spec would pass. | Either narrow the regex to the spec, or add a one-line spec/contract note that `agents/` and `modes/` count. |
| F12 | T2 | 343 | Expected `7 tests, 0 failures` is the pretty formatter; non-tty runs (the executor) print TAP `1..7` and `ok` lines. | Expected: `1..7` followed by seven `ok` lines, exit 0. |
| F13 | Global | 26 | Plan forbids attribution trailers; the session's commit-attribution reminder tells the agent to append `Claude-Session:` to commits and PR text. | Add to Global Constraints: "the executor omits harness attribution lines in kern commits", so the plan, not the reminder, governs. |
| F14 | T5, T6 | 785, 1079 | Spec 14 M0 says lint is "adapted from addy"; addy has `scripts/validate-skills.js` and `validate-versions.js`. `lint-rules.mjs` and `check-version.mjs` carry no source comment, and Global line 20 requires one for adapted scripts. | If written fresh, say so in the plan and spec 14; if borrowed, add `// Adapted from addyosmani/agent-skills scripts/validate-skills.js (MIT)` and NOTICE map lines. |
| F15 | T3 | 503-511 | Informational. caveman's NOTICE (reproduced verbatim) says pre-3.0.0 MIT text is kept in `LICENSE-MIT`, which kern does not copy; the plan says caveman is ideas only. Also `licenses/caveman.*` file names contain the trademark word, as spec 2 rule 1 requires. | No change if nothing pre-3.0.0 is ported. Else copy `LICENSE-MIT` to `licenses/caveman-mit.LICENSE` and add it to the test. |
| F16 | T1 | 75 | `gh auth status` is never checked, but T4 Step 2 (`gh api user`) and T8 Step 5 need a login. (It is logged in now.) | Add `gh auth status` to the Step 1 command. |
