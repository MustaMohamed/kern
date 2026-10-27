# kern pilot-fix plan, round 2

**Status: approved on 2026-10-27, with all four recommendations; written 2026-10-27 against main ae1ce58 (M2b, after the first pilot-fix plan and its reruns). Reviewed against the code on 2026-10-27, with two findings folded in: G18 judges a record that reads a variable with it empty too, and Task 1 gives `pr.size_command` a merge-base commit as `{base}`, as finish-branch does. Task 12's dry run and paid round each need their own yes.**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementers and reviewers run on Opus.

**Goal:** Turn the 11 generic fixes from MA-254 round 2 (draft PR MoneyApp#874) into kern changes every project gets, add eval cases for the two new duties, and run one full test round. Round 2 matched the project's usual flow in plan, review and code at 44% of its cost, but lost on ease and time: 385.6 minutes idle on a size question kern could have asked while the user was there, 8 guard asks after the user's "One", 13 needless guard asks and denies in all, and 29% of the cost in one evidence-gathering task. Nothing here is specific to MoneyApp, React Native or emulators. Project knowledge stays in each project's `CLAUDE.md`, `.claude/rules/**` and skills.

**Architecture:** execute-plan sizes the plan worktree after each closed task, from snapshot trees and never from the index, and asks `split` or one PR at the first breach; finish-branch then reads that answer from the ledger instead of asking again. finish-branch's menu asks for its replies in words that `prompt_consent` already reads, so one typed reply covers the commit, push and PR, and its PR report names the reviews that ran and the PR checks. A verification task (Files modify nothing, steps gather evidence) gets a narrow brief, a task-reviewer `evidence` mode that checks rows against files, and a two-round cap. define and plan count re-indented lines as shortstat does and keep the ticket's Out of scope lines in the short form. self-review searches every other reader for moved literals, and `probe --mutate` drops a lone `!`. proof-check fails a `degraded:` evidence row. G18 and G16 lose four false positives, each with its threat model and still-denies tests. G20 keeps both denies, which this plan pins, and the skills route around them. The kernel does not change.

**Spec:** `docs/specs/2026-10-12-kern-design.md` sections 5 (the `pr.max_lines` and `pr.size_command` rows) and 8.3 (the G16, G18 and G20 rows), and `docs/specs/2026-10-12-kern-m1-m2-skills.md` (define, plan, execute-plan, self-review, finish-branch: their steps, settings table and size sentences). Each task edits the spec text its change touches, with the user's word as the reason. Brief: `.superpowers/sdd/2026-10-14-kern-m2b-plan/pilot-fixes-2-plan-brief.md`. Evidence: `.superpowers/sdd/2026-10-14-kern-m2b-plan/pilot-cmp-MA254-r2.md` (sections 1, 3, 5 and 6, and "Kern changes this comparison shows, ranked", items 1 to 11). Round 2's work files: `~/Code/projects/practice/MoneyApp/.kern/` (read only). Shared names: `docs/plans/contract.md`. Style: `docs/plans/2026-10-25-kern-pilot-fixes.md`.

## The user's decision (2026-10-26), verbatim

"start", to "draft the fix plan with items 1 to 11" of the ranked list. Items 12 and 13 (eval cases, records) and the test round come from the brief, as in the last plan.

## Open questions

Answered on 2026-10-27, in the user's words: "Approve the plan with all four recommendations: keep shortstat, keep G20's denies, keep G18's loop and sed denies, and the exit rule. Build it with the SDD loop."

1. **Keep `git diff --shortstat` as the size measure when `pr.size_command` is unset (Task 1).** Round 2's 650 lines were 300 with `-w` and 323 by the project's own counter, so the brief offers two ways for "the project's counter decides": setup offering that counter, or the gate accepting an excess that is whitespace only. Setup already offers `pr.size_command` (the first pilot-fix plan's Task 3); round 2 never reran it. A gate that counts fewer lines by default loosens it, a MAJOR change under design spec section 12. Recommendation: yes, keep shortstat; the size question names the `-w` count beside it, so the user sees a re-indent and answers in one reply. On a no (accept whitespace-only excess): Task 1 adds to execute-plan step 10 and finish-branch step 6 "When the shortstat count is over and `git diff -w --shortstat` is at or under, the gate passes, naming both counts", edits `kernel/settings.md`'s `pr.max_lines` row and design spec section 5 to say so, and Task 11's CHANGELOG bullet marks it breaking, for the next release's MAJOR bump.
2. **G20 keeps both denies; the skills route around them (Task 9).** The brief asks G20 to judge only spec and plan approval lines. A shell command does not show the line it writes (`sed -i 's/draft/approved/' plan.md`), so G20 judges the word `approved` in the command and a destination that may be Markdown. The one narrowing that would pass round 2's review write, a redirect target whose last path part is literal and not Markdown, is unsafe under zsh, the shell the Bash tool runs on this Mac: `D="a.md b"; echo hi > $=D/x.txt` wrote both `a.md` and `b/x.txt` (MULTIOS, reproduced in a scratch directory). The ledger deny would stay anyway: it appends to `ledger.md`, a Markdown file, in a command that holds `approved`. Round 2 lost one retry each. Recommendation: yes. On a no: Task 9 narrows `_g20_target`'s first branch (`hooks/guards/g20-approval.sh:288`) for redirect targets whose last path part is literal and not Markdown, passes a `redirect` flag from `_g20_seg1`, lists zsh's MULTIOS with word splitting (`$=x`, `setopt shwordsplit`) as an accepted limit in the guard header and the section 8.3 row, and its test asserts the review write passes.
3. **G18 keeps denying `for` loops and `sed` scripts other than `-n` with line numbers (Task 7).** Two of round 2's four G18 denies (events 14 and 15) also held `sed 's/^/+129 /'` and a `for` loop; G18 denies both on their own (`g18-readonly-agent.sh:72-89` and `:91`), so Task 7's fix lets events 16 and 17 through and not 14 and 15. GNU sed's `e` and `w` flags run and write, and a loop variable takes values G18 cannot read. Recommendation: yes; Task 7 adds one sentence to the investigator's rules naming the shapes that pass. On a no: a follow-up plan designs a loop rule (literal word list, allowlisted body, the variable substituted per word) with its own threat model; this plan does not.
4. **The exit rule for Task 12.** (1) Every gate passes: stop and report. (2) A gate this package broke (a case or category that passed at the last paid round and fails now), or a new case that fails (`workflow-execute-plan-size-breach`, `finish-menu-consent`): one fix package, focused suites and ci-local, one rerun of only the failed categories, then stop and report whatever it shows. (3) A known limit that failed before (adherence Sonnet multi-diagnose 0/3; the `workflow-self-review-proofs` skip under `fix first`, which passed 2/3) is reported, not fixed. No second fix round without the user's word. Recommendation: yes. On a no, Task 12 stops after the paid round and reports.

## Decisions made in this plan

- Size is asked in execute-plan step 10, after each closed task: the round 2 ledger had the count at 22:40, while the user was there.
- The count runs from the `Worktree:` line's base tree to a fresh `wt-snap` tree: no fetch, no index, and untracked files count, since `wt-snap` uses a temporary index.
- A breach is asked about unless the plan's Size line was already over that limit: such a plan had its split or the user's word at plan step 7. A plan with no Size line is asked about.
- One size answer per plan: finish-branch takes the ledger's `Decision:` line with the user's one-PR answer and does not ask again, naming both counts so growth shows. A second ask at finish brings the overnight wait back.
- Under autopilot the size stop parks with one PR: finish-branch's size default and its reason (a split is the user's scope call; a draft can be closed).
- No new ledger format: the answer is a `Decision:` line whose what opens with "size". Lint rule 16 accepts the short form, and `ledger-format.md` needs no row.
- The split question stays alone, with no menu before it is answered: exec gate `finish-split-nine-files` (`offersSplitToUser` fails on a shown menu) and the skills spec's acceptance line "a split is proposed before the menu" require it. The consent words go on step 7's menu.
- No `prompt_consent` change: it already reads `commit`, `commit and push` and `commit, push and open a draft PR`, and gives nothing for `1` to `4`, `keep`, `One`, `one PR` or `split` (reproduced against `hooks/lib/state.sh:222-256`). The fix is menu text, pinned to the grammar by a new `consent.bats` test.
- The PR report runs `gh pr checks <n>` once, without `--watch`: the brief asks for no wait. Its output is reported whatever the exit.
- A verification task gets a reference file and a reviewer mode, not new steps: execute-plan's SKILL.md is at 12,597 of 12,599 bytes, and the path is rare.
- A verification task gets at most two rounds: each round repeats the whole gathering (round 2: 138 calls, $7.17, over two rounds). Still unproven after round 2: stop and ask, as step 9 does after round 3.
- The verification reviewer checks rows against stored files and never redoes the work: round 2's two Opus reviews cost $1.87 re-deriving it.
- `degraded:` in an evidence cell fails the row, like `none`: `proofs.md` already says never file a proof for a state it does not show. Whether a screenshot shows the state stays a reading duty.
- `probe --mutate` drops a `!` only when the line has no other operator, and never one after a name character or closing bracket: TypeScript's `x!` and Rust's `println!` are not negations.
- self-review never makes a fork of its own: probe makes and removes its fork, and round 2's hand-made fork stayed on disk with a full `node_modules`. Removing one needs `git worktree remove --force`, which G1 asks for.
- The short spec form keeps `## Not doing`, and plan-check does not require it: approved short specs from before this plan lack it, and execute-plan step 2 would stop on them. The plan review checks non-goals.
- define counts a re-indented file's moved lines and names the `-w` count beside it: the gate counts them, and round 2's spec said about 290 against 650 delivered.
- G18 substitutes only one-letter variables: no shell and no allowlisted command reads one from its environment, while `IFS`, `PATH`, `GIT_*` or `RIPGREP_CONFIG_PATH` change what runs.
- G18 denies a variable set twice in one command: after `||` or in a branch, the guard cannot tell which value a later record reads (`T=a.txt || T=-o; sort $T out.txt`).
- G18 judges each record that reads a variable twice, with the value and with the variable empty, and both must pass: after `||`, in a pipeline, in the background, in a subshell or in a branch, the assignment may not reach the record. `test -f /etc/passwd || T=1p; sed -n $T w/tmp/x a.txt` runs `sed -n w/tmp/x a.txt`, a write. Found in plan review on 2026-10-27: the draft's code let four such shapes through, and bash and zsh both wrote the file.
- G18 allows one brace list per word, not in the first word, with no item or word that starts with `-`: `-{-pre=sh,x}` expands to `--pre=sh`.
- G18's raw backtick check moves to `_g18_expands`, which already reads quotes and escapes: an escaped backtick in double quotes is literal.
- G16 skips the operand of a find pattern test only on a line where find acts on nothing it finds: such a pattern only picks paths to print, the reach of the accepted limit `find $K -name prompt-submit`.
- G16's find check does not treat `.` as the `source` builtin: it is find's usual start path, and a sourced file of paths is again the accepted limit.
- G16 reads a `cat > file <<'E'` body as code only when every other record that names the file is an interpreter and every other record is `cd` or a read-only filter: a shell, `./file`, `chmod`, `cp` or `xargs` keeps every rule.
- The finish menu case is an exec case with two turns: the exec harness has the gh stub that takes the draft PR and a scripted grader. The size case is a behaviour case: it needs execute-plan's whole task loop and a model grader for the question.
- The exec gh stub answers `gh pr checks` as gh does for a branch with no checks: finish-branch now calls it in every exec case that opens a PR.
- Byte caps rise only where a task names the cap and why: execute-plan `SKILL.md` 12,599 to 13,550 (Task 1) to 13,850 (Task 3); `ledger-format.md` 2,600 to 2,750 (Task 9); finish-branch `SKILL.md` 6,960 to 7,200 (Task 1) to 7,650 (Task 2); define `SKILL.md` 6,950 to 7,000 and `spec-template.md` 3,100 to 3,450; `plan-review.md` 1,450 to 1,600; self-review `SKILL.md` 8,250 to 8,500, `blast-radius.md` 2,600 to 2,900, `claim-checks.md` 1,939 to 2,000 (Task 5) and `proofs.md` 1,200 to 1,350 (Task 6); new `verification.md` at 1,250. Each number is the measured size of this plan's text, rounded up to the next 50.
- The kernel does not change, so lint rule 7 needs no relock.

## Fix to task

| Brief fix | Task |
|---|---|
| 1. Ask about a size breach when it is first measured | 1 |
| 2. finish-branch's menu asks for a reply typed consent can read | 2 |
| 3. Blast radius treats a moved box's classes and styles as a copy | 5 |
| 4. Verification-task cost | 3 |
| 5. Sizing counts re-indent and reconciles with a size the ticket states | 4 |
| 6. `probe --mutate` inverts a negated condition; no fork left behind | 5 |
| 7. Guard false positives: G18 | 7 |
| 7. Guard false positives: G16 | 8 |
| 7. Guard false positives: G20 | 9 (and Task 3's step 8 sentence) |
| 8. Never stage to count size | 1 |
| 9. The short spec form keeps the ticket's Out of scope lines | 4 |
| 10. `proof-check` and a proof drawn on a degraded state | 6 |
| 11. The PR-open message names the reviews and runs `gh pr checks` | 2 |
| 12. Eval cases | 10 |
| 13. Records | 11 |
| Test round | 12 |

## Global Constraints

- Write plain, short sentences in every file (unslop): answer first, no long dashes, no curly quotes, sentence-case headings.
- Generic only: no MoneyApp, React Native or emulator names in any skill, agent, guard or script. Say "a verification task", "states", "evidence".
- Node: `PATH="$HOME/.volta/tools/image/node/22.23.3/bin:$HOME/.local/bin:$PATH"`. Bats tests that set `HOME` to a temp directory need that node first on `PATH`.
- Lint in every task: `node scripts/lint-skills.mjs` prints `lint: clean`.
- Tests: bats only through `bash tests/run-bats <file>`, one suite at a time; node tests with `node --test <file>`. Each task runs its focused suites; `scripts/ci-local` runs once, in Task 12.
- Standing cost: lint rule 7 is the gate (6,207 rendered chars warn, 6,296 standing cost error). No task edits `kernel/kernel.md`, `kernel/kernel-subagent.md`, an auto skill description or an agent description. Task 1's `kernel/settings.md` edit is in the "read by" column only, which the render does not read.
- A byte cap rises only in the task that names it, with the reason in the test comment and in the skills spec's size sentence.
- Records scripts never use String.replace with a string replacement.
- Commits: `M2: ...`, `git add -- <paths>` with the paths named, no attribution trailers. Never stage `docs/pilot.md` (uncommitted until Task 18 Step 7) or the older untracked `evals/snapshots/*.json` files.
- No paid model run inside any task, and no `claude`, eval runner or other model call before Task 12. Task 12's dry run and paid round run only on the user's yes, under `CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval` after `claude auth status` shows mustafa.mohamed.wd@gmail.com, with `--jobs 6` and `--no-cache`, every runner at once (`scripts/eval-all`). Never the default login, which is a Team account.
- No edits to frozen files: `evals/heldout.json` (its sha in `tests/route-eval-rows.test.mjs:100`), `evals/pilot/tasks.json`, `evals/heldout-pilot.json`.
- Guard changes keep failing closed: each relaxes only the rule that fired, states its threat model in the guard's comment, and adds a still-denies or still-asks case beside its allow case.
- Implementers and reviewers run on Opus. The eval model under test stays Sonnet.
- A failed gate is a finding, not a reason to edit a case: Task 12's exit rule applies.

## Review Focus

1. **G18 or G16 letting a write or a hook run through.** An option hidden in a variable or brace list, a variable set twice or left unset by `||`, a pipe, `&`, a subshell or a branch, a longer variable name, a value with `$`, a glob or a blank, a find that acts on what it finds, a file a shell or a path runs, and a pipe to a runner still deny or ask. Pinned in Task 7 (`g18.bats` test 16) and Task 8 (`g16-state.bats` tests 83 and 84, still-asks halves), beside the 13 and 82 existing tests.
2. **Consent that the menu text no longer gives.** The menu's three action replies must each parse to their consent, and a digit or a size answer to none. Pinned in Task 2 (`consent.bats`, reading the replies from the SKILL.md itself) and graded by `finish-menu-consent` in Task 12.
3. **A size count that stages or misses untracked files.** execute-plan and finish-branch count from `wt-snap` trees and never run `git add`. Pinned in Tasks 1 and 2 (skill pins) and graded by `workflow-execute-plan-size-breach`'s scripted `no-git-add` check.
4. **A verification task that closes on unproven evidence.** Its review checks each row against a stored file, a third round never starts, and task-done still needs an approved review. Pinned in Task 3.
5. **A proof check that passes a degraded proof, or a probe that mutates the wrong `!`.** Pinned in Task 6 (`proof-check.bats` test 9) and Task 5 (`claim-probe.bats` tests 34 and 35).
6. **G20 left as it is.** Both round 2 shapes still deny, and the Write tool and a call of its own pass. Pinned in Task 9 (`g20-probes.bats` test 56).
7. **A skill pin that no longer finds its text.** Every new sentence has a pin in its skill test, and every raised cap names why.

## Baseline (measured 2026-10-27 at ae1ce58)

- `node scripts/lint-skills.mjs`: `lint: clean`. Rule 7 at its lock (6,207 and 6,296).
- Last paid round: 7a230f8 on 2026-10-25, with reruns at 5d6e8be and 09cada4 (CHANGELOG Unreleased, the pilot fixes bullet): exec 8/8, behaviour 22/22 after the reruns, adherence Sonnet 19/20 (multi-diagnose 0/3, the known limit) and Haiku 20/20, head-to-head plan and review PASS.
- Every guard event in the evidence's section 5 table was reproduced against the real hooks (`hooks/pre-tool-use` in a throwaway `HOME` and plugin data dir, with the agent type each event had). The rule that fired is cited in each guard task.
- Pre-flight in a scratch copy of ae1ce58's tracked files: with this plan's G16, G18, probe and proof-check code and new tests applied, `tests/run-bats --jobs 6 tests/hooks` gave no failure, `claim-probe.bats` 35 of 35 and `proof-check.bats` 9 of 9; `shellcheck -x -S warning` passed on the four changed files. With every skill and agent edit below applied (and no test edits), lint was clean, and `node --test tests/*.test.mjs tests/skills/*.test.mjs` failed only the 10 cap and pin assertions the tasks below update (plus one exec test that needs a real git checkout). On the unchanged code, each new allow test fails and each still-denies test passes, as each task's first Expected line says.

## Tasks

### Task 1: Ask about size at the first breach; never stage to count

Round 2's ledger recorded 624 changed lines against `pr.max_lines: 400` after Task 3 at 22:40, with the user present, and left the question to finish-branch, which asked at 00:24 with the user gone: 385.6 minutes idle. kern took that count on its own initiative, with `git -C $W add -N .` (G5 ask, `hooks/guards/g05-commit.sh:184`, "git add . stages every change"), and the intent-to-add entry broke the first commit's lint-staged backup at 06:51. execute-plan now sizes the plan worktree after each closed task, from trees, and asks at the first breach; finish-branch takes that answer from the ledger.

**Files:**
- Modify: `skills/execute-plan/SKILL.md`, `skills/finish-branch/SKILL.md`, `kernel/settings.md`, `tests/skills/execute-plan.test.mjs`, `tests/skills/finish-branch.test.mjs`, `docs/specs/2026-10-12-kern-design.md`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: the `Worktree: <path> branch=<name> base-tree=<id>` ledger line; `wt-snap <wt>` (prints a tree id, untracked files included); `pr.max_lines`, `pr.size_command`, `scope_threshold` through `kern-get`.
- Produces: a `Decision:` ledger line whose what opens with "size", which finish-branch step 6 reads; the size stop's autopilot default. Task 10's `workflow-execute-plan-size-breach` grades both.

- [ ] **Step 1: Write the pins**

In `tests/skills/execute-plan.test.mjs`, replace `  assertMaxBytes(SKILL, 12599);` with:

```js
  // 13,550 since pilot fix plan 2's Task 1 (raised from 12,599): step 10 sizes the plan worktree after each closed task
  // and asks at the first breach; MA-254 round 2 had the count at 22:40 and asked at 00:24, with the user gone.
  assertMaxBytes(SKILL, 13550);
  assertContains(SKILL, ["| `pr.max_lines`, `pr.size_command` | 300 lines; none | step 10's size |"]);
```

In the same file's `PINS`, append to the `10:` list:

```js
    'Then size the plan worktree (a wave: after step 11): `git -C <plan-wt> diff --shortstat <base-tree> <tree>`',
    'so untracked files count; never `git add`, not even `-N`.', "unless the plan's Size line was over that limit: stop and ask `split` or one PR",
    'naming `lines: <n> (<measure>)`, the `-w` count, the limit and its source.', 'Record the answer in a `Decision:` line whose what opens with size; `split` ends the run.',
```

and append to the `stops:` list: `"the size stop takes one PR, why: a split is the user's scope call and a draft can be closed"`.

In `tests/skills/finish-branch.test.mjs`, add to the `assertOnce(SKILL, [...])` list of the "sections, steps and red flags" test: `"whose what opens with size and that quotes the user's one-PR answer settles it: name that answer and both counts, and go on."`, `'Never `git add` to count, not even `-N`.'`. Replace its cap lines with:

```js
  // 6,594 since M2b Task 17 (raised from 6,400): a release on request, the tag-only route and the release branch, coverage AD24.
  // 6,960 since the pilot fix plan's Task 2: the size gate's measure and pr.size_command.
  // 7,200 since pilot fix plan 2's Task 1: step 6 takes execute-plan's ledger answer and never stages to count.
  assertMaxBytes(SKILL, 7200);
```

In that file's settings test (the one with `| \`pr.size_command\` | none |`), add: `assertContains('kernel/settings.md', ['tests included, or `pr.size_command`\'s count | plan, execute-plan, finish-branch, help |', '| execute-plan, finish-branch, help |']);`

Run: `node --test tests/skills/execute-plan.test.mjs tests/skills/finish-branch.test.mjs`
Expected: the cap tests pass, and the new pins fail (the text is not there yet).

- [ ] **Step 2: execute-plan step 10, Inputs and Stops**

In `skills/execute-plan/SKILL.md`, step 10, after `Under autopilot only, then commit the task's files with `/kern:commit` steps 2 to 6 (a wave task: after step 11).` insert (one space before it, same paragraph):

> Then size the plan worktree (a wave: after step 11): `git -C <plan-wt> diff --shortstat <base-tree> <tree>`, `<base-tree>` from the `Worktree:` line and `<tree>` from `wt-snap <plan-wt>`, so untracked files count; never `git add`, not even `-N`. With `pr.size_command`, its last number is the count (`{base}` is `git -C <plan-wt> merge-base HEAD <baseref>`, `<baseref>` as finish-branch step 3 finds it; `{tree}` is `<tree>`). The first time the count passes `pr.max_lines`, or the files pass `scope_threshold`, unless the plan's Size line was over that limit: stop and ask `split` or one PR, naming `lines: <n> (<measure>)`, the `-w` count, the limit and its source. Record the answer in a `Decision:` line whose what opens with size; `split` ends the run.

In the Inputs table, after the `| \`shared_services\`, ...` row, add the row:

```
| `pr.max_lines`, `pr.size_command` | 300 lines; none | step 10's size |
```

In Stops and autopilot, replace `a red baseline goes on, naming red-before tests)` with `a red baseline goes on, naming red-before tests; the size stop takes one PR, why: a split is the user's scope call and a draft can be closed)`.

- [ ] **Step 3: finish-branch step 6**

In `skills/finish-branch/SKILL.md`, step 6, after `propose a split alone, no menu before it is answered; stop on yes, go on on no.` insert: ` A `Decision:` line in the work's ledger whose what opens with size and that quotes the user's one-PR answer settles it: name that answer and both counts, and go on. Never `git add` to count, not even `-N`.`

- [ ] **Step 4: Settings and specs**

In `kernel/settings.md`, the `pr.max_lines` row's last cell becomes `plan, execute-plan, finish-branch, help`, and the `pr.size_command` row's `execute-plan, finish-branch, help`. Make the same reader change in design spec section 5's two rows (`docs/specs/2026-10-12-kern-design.md:266-267`) and the skills spec's settings table (`docs/specs/2026-10-12-kern-m1-m2-skills.md:99-100`).

In the skills spec: execute-plan step 10 (the line starting `10. Close the task:`) gains, before its source brackets, "Then it sizes the plan worktree from the `Worktree:` base tree to a fresh `wt-snap` tree, never staging, and asks `split` or one PR at the first count over a limit, unless the plan's Size line was already over it; the answer is a `Decision:` line (pilot fix plan 2; MA-254 round 2 asked 1 h 44 min later, with the user gone)." Its section 6 Stops list adds "a size breach (autopilot: one PR)". Its section 7 Acceptance adds "- A task that takes the plan worktree over `pr.max_lines` for the first time: the run stops after that task closes and asks `split` or one PR, naming the count, its measure and the limit; no `git add` ran." finish-branch step 6 (`docs/specs/2026-10-12-kern-m1-m2-skills.md:751`) gains "A ledger `Decision:` line with the user's one-PR answer settles the gate; it never stages to count." The size sentences change: execute-plan's (line 451) "SKILL.md at most 12,599 bytes" becomes "SKILL.md at most 13,550 bytes (12,599 until pilot fix plan 2's Task 1: step 10's size check" followed by the existing parenthesis text; finish-branch's (line 772) "SKILL.md at most 6,960 bytes (6,594 until the pilot fix plan's Task 2;" becomes "SKILL.md at most 7,200 bytes (6,960 until pilot fix plan 2's Task 1, which reads execute-plan's size answer; 6,594 until the pilot fix plan's Task 2;".

- [ ] **Step 5: Run the focused checks**

Run: `node --test tests/skills/execute-plan.test.mjs tests/skills/finish-branch.test.mjs tests/kernel.test.mjs && node scripts/lint-skills.mjs`
Expected: all pass; `lint: clean`. `wc -c skills/execute-plan/SKILL.md` prints 13521 and `skills/finish-branch/SKILL.md` 7157.

- [ ] **Step 6: Commit**

```bash
git add -- skills/execute-plan/SKILL.md skills/finish-branch/SKILL.md kernel/settings.md tests/skills/execute-plan.test.mjs tests/skills/finish-branch.test.mjs docs/specs/2026-10-12-kern-design.md docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: execute-plan asks about size at the first breach, from trees, and finish-branch takes that answer"
```

### Task 2: finish-branch's menu in words, and the PR-open report

Round 2's finish asked for `one PR` or `split` and promised the commit, push and PR in the same message; the user's "One" is no consent under `prompt_consent`'s closed grammar (`hooks/lib/state.sh:241`: a part that is not an action exits with no output), and 8 asks followed. The grammar already reads `commit, push and open a draft PR` as `commit push pr`, `commit and push` as `commit push` and `commit` as `commit`, so step 7's menu asks for those words. The user asked "what next" 38 minutes after the PR, then "did you review the PR?": step 11 now names each review that ran and runs `gh pr checks` once.

**Files:**
- Modify: `skills/finish-branch/SKILL.md`, `tests/skills/finish-branch.test.mjs`, `tests/hooks/consent.bats`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: `prompt_consent` (unchanged); the work's ledger (`Task N: review round=...`, the final review lines); self-review's verdict and lanes from step 5; `gh pr checks <n>` (G2 reads it as `pr/checks`, no vote).
- Produces: the menu replies `commit`, `commit and push`, `commit, push and open a draft PR`, `keep`, which Task 10's `finish-menu-consent` types; `Bash(gh pr checks *)` in `allowed-tools`.

- [ ] **Step 1: Write the tests**

Append to `tests/hooks/consent.bats`:

```bash

@test "each reply finish-branch's menu asks for is that option's consent; a digit or a size answer is none" {
  # Pilot fix plan 2, Task 2 (MA-254 round 2): the user's "One" gave no consent, and 8 asks followed.
  . "$(kern_root)/hooks/lib/settings.sh"
  . "$(kern_root)/hooks/lib/state.sh"
  c() { printf '%s\n' "$1" | prompt_consent; }
  menu=$(grep '^7\. Show the menu' "$(kern_root)/skills/finish-branch/SKILL.md")
  for r in 'commit' 'commit and push' 'commit, push and open a draft PR' 'keep'; do
    [[ "$menu" == *"\`$r\`"* ]] || { echo "the menu lacks the reply: $r"; return 1; }
  done
  [ "$(c 'commit')" = "commit" ]
  [ "$(c 'commit and push')" = "commit push" ]
  [ "$(c 'commit, push and open a draft PR')" = "commit push pr" ]
  for p in 1 2 3 4 keep One 'one PR' split; do
    [ -z "$(c "$p")" ] || { echo "consent from: $p"; return 1; }
  done
}
```

In `tests/skills/finish-branch.test.mjs`: in the frontmatter test, `allowed-tools` becomes `'Bash(git rev-parse *), Bash(git symbolic-ref -q --short HEAD), Bash(gh pr list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *), Bash(gh pr checks *)'`. In the `assertOnce` list, replace `'1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is'` with `'1 `commit`; 2 `commit and push`; 3 `commit, push and open a draft PR`; 4 `keep`.'` and add `'Ask for the reply in those words: G5, G1 and G2 read them as this prompt\'s consent, while a digit gives none'`, `'Then report each review that ran and its result'`, `'run `gh pr checks <n>` once, with no wait: report its output, or why it could not run.'`. Replace the cap lines' last two with:

```js
  // 7,200 since pilot fix plan 2's Task 1: step 6 takes execute-plan's ledger answer and never stages to count.
  // 7,650 since pilot fix plan 2's Task 2: step 7's replies in words, step 11's reviews and PR checks.
  assertMaxBytes(SKILL, 7650);
```

At `tests/skills/finish-branch.test.mjs:265`, the Outputs line becomes `'A commit, push or draft PR, per the choice, or a release; a chat report: SHA, branch, PR URL, the reviews that ran, the PR checks, `<wt>`, the tag or its wait.'`.

Run: `bash tests/run-bats tests/hooks/consent.bats` and `node --test tests/skills/finish-branch.test.mjs`
Expected: the new bats test fails on "the menu lacks the reply: commit"; its grammar lines would pass. The finish-branch frontmatter, pin and Outputs tests fail.

- [ ] **Step 2: Change the menu, step 11, Outputs and the frontmatter**

In `skills/finish-branch/SKILL.md`:
- Frontmatter `allowed-tools`: append `, Bash(gh pr checks *)`.
- Step 7: replace `Show the menu, then wait: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is.` with `Show the menu, then wait: 1 `commit`; 2 `commit and push`; 3 `commit, push and open a draft PR`; 4 `keep`. Ask for the reply in those words: G5, G1 and G2 read them as this prompt's consent, while a digit gives none, so each commit, push and PR would ask.`
- Step 11: after `Report the URL; the worktree stays.` insert ` Then report each review that ran and its result (self-review's verdict and lanes; from the work's ledger, the task and whole-branch reviews), and run `gh pr checks <n>` once, with no wait: report its output, or why it could not run.`
- Outputs: replace `SHA, branch, PR URL, `<wt>`, the tag or its wait.` with `SHA, branch, PR URL, the reviews that ran, the PR checks, `<wt>`, the tag or its wait.`

- [ ] **Step 3: Spec**

In the skills spec's finish-branch section: step 7 (line 752) becomes "Show the menu, then wait: 1 `commit`; 2 `commit and push`; 3 `commit, push and open a draft PR`; 4 `keep`, asking for the reply in those words, which `prompt_consent` reads as consent for that prompt (pilot fix plan 2; a digit or "one PR" gives none)." followed by its existing discard sentence and sources. Step 11 gains "The report names each review that ran with its result and the output of one `gh pr checks <n>`, with no wait." Section 5 Outputs becomes "Commit, push or PR per the choice, or a release; chat, with the reviews that ran, the PR checks, and the tag or why it waits." Section 7 Acceptance adds "- The menu asks for replies in words; a typed `commit, push and open a draft PR` commits, pushes and opens the draft with no G5, G1 or G2 ask." The size sentence (line 772): "SKILL.md at most 7,200 bytes (6,960 until pilot fix plan 2's Task 1" becomes "SKILL.md at most 7,650 bytes (7,200 until pilot fix plan 2's Task 2, for the menu replies and the PR report; 6,960 until its Task 1".

- [ ] **Step 4: Run the focused checks**

Run: `bash tests/run-bats tests/hooks/consent.bats && node --test tests/skills/finish-branch.test.mjs && node scripts/lint-skills.mjs`
Expected: all pass; `lint: clean`; `wc -c skills/finish-branch/SKILL.md` prints 7600.

- [ ] **Step 5: Commit**

```bash
git add -- skills/finish-branch/SKILL.md tests/skills/finish-branch.test.mjs tests/hooks/consent.bats docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: finish-branch's menu asks for replies typed consent reads, and its PR report names the reviews and checks"
```

### Task 3: Verification tasks

Round 2's Task 6 gathered evidence and wrote no file: 138 calls, 25.14M tokens, $7.17 over two rounds, plus $1.87 for two Opus reviews, 29% of the run. execute-plan had no path for it: step 8 says `Exit 3 (empty): return the task to the implementer.`, so kern improvised (`Decision: Task 6 is delegated to an implementer with an empty write scope`). Its brief's CONTEXT named five files and three open questions beyond the states. The fix is a reference file that narrows the brief, a task-reviewer `evidence` mode that checks rows against files, and a two-round cap. Step 8 also saves a review with the Write tool, since G20 denied round 2's `cat > $LD/reviews/task-1-r1.txt` (Task 9 keeps that deny).

**Files:**
- Create: `skills/execute-plan/references/verification.md`
- Modify: `skills/execute-plan/SKILL.md`, `agents/task-reviewer.md`, `tests/skills/execute-plan.test.mjs`, `tests/agents.test.mjs`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: `wt-diff` exit 3 (empty); `task-review` and `task-done --no-probe`; the brief template's fields.
- Produces: task-reviewer mode `evidence` (inputs: brief, report, evidence directory); a verification task's report table `| State | Evidence | Result |`.

- [ ] **Step 1: Write the pins**

In `tests/skills/execute-plan.test.mjs`: replace the Task 1 cap lines with:

```js
  // 13,550 since pilot fix plan 2's Task 1 (raised from 12,599): step 10 sizes the plan worktree after each closed task
  // and asks at the first breach; MA-254 round 2 had the count at 22:40 and asked at 00:24, with the user gone.
  // 13,850 since its Task 3: steps 6 and 8 send a verification task to references/verification.md, and step 8 saves a review
  // with the Write tool.
  assertMaxBytes(SKILL, 13850);
  assertHeadings('skills/execute-plan/references/verification.md', ['# Verification tasks', '## Brief', '## Review', '## Close']);
  assertMaxBytes('skills/execute-plan/references/verification.md', 1250);
  assertContains('skills/execute-plan/references/verification.md', ['Its Files modify nothing.', 'a value with no stored output proves nothing',
    'mode `evidence`', 'At most two rounds, the review and one fix round', 'A state still unproven after round 2: stop and ask, naming each one; never start a third round.',
    '--no-probe "verification task: no code"']);
```

Append to `PINS[8]`: `"A verification task's diff is empty by design: review it as `references/verification.md` says."`, `'Use the Write tool: G20 may deny a shell write of text that holds approved.'`. In the `'execute-plan sections, steps, scripts and red flags'` test add `assert.ok(s[6].includes('A verification task, one whose Files modify nothing and whose steps gather evidence, follows `references/verification.md` in every mode.'), s[6]);` after the `steps(body)` line.

In `tests/agents.test.mjs`, the task-reviewer test's `assertContains` list adds ``'`evidence`: a verification task, with no diff.'``, `'never redo the work'`.

Run: `node --test tests/skills/execute-plan.test.mjs tests/agents.test.mjs`
Expected: the headings test fails (no `verification.md`), and the new pins fail.

- [ ] **Step 2: Write the reference**

Create `skills/execute-plan/references/verification.md`:

```markdown
# Verification tasks

A verification task shows that the plan's change reaches the states its spec names. Its Files modify nothing. Its evidence (scripts, reads, screenshots) goes under `kern-dir tmp`, never in the repository.

## Brief

- CONTEXT: only the spec lines and states its steps name, the evidence rows to fill and the project's method file for them. Not the earlier tasks' reports or reviews.
- ACCEPTANCE: one line per state, saying what its evidence must show.
- REPORT: a `| State | Evidence | Result |` table. Each Evidence cell names a stored file: a value with no stored output proves nothing.

## Review

`wt-diff` exits 3 by design: record that line and go on. Dispatch `kern:task-reviewer` in mode `evidence` with the brief, the report and the evidence directory, saved and recorded as step 8 says. At most two rounds, the review and one fix round: each round repeats the whole gathering. A state still unproven after round 2: stop and ask, naming each one; never start a third round.

## Close

`task-done <ledger> <N> <wt> <tree-after> --no-probe "verification task: no code" -- bash <script>`, where `<script>` is a `kern-dir tmp` file that runs `test -s` on each evidence file the report names.
```

- [ ] **Step 3: Point execute-plan at it**

In `skills/execute-plan/SKILL.md`:
- Step 6: before ` Then by mode:` insert ` A verification task, one whose Files modify nothing and whose steps gather evidence, follows `references/verification.md` in every mode.`
- Step 8: after `Exit 3 (empty): return the task to the implementer.` insert ` A verification task's diff is empty by design: review it as `references/verification.md` says.` After `Save its return as `<ledger dir>/reviews/task-N-r<r>.txt`, r = 1 + the task's review lines.` insert ` Use the Write tool: G20 may deny a shell write of text that holds approved.`

- [ ] **Step 4: The reviewer's evidence mode**

In `agents/task-reviewer.md`:
- Inputs: replace `the diff package path, the worktree path` with `the diff package path (in mode `evidence`, the evidence directory), the worktree path`, and `the mode: `task`, `re-review` or `whole-branch`.` with `the mode: `task`, `re-review`, `whole-branch` or `evidence`.`
- Modes: after the `whole-branch` bullet add `- `evidence`: a verification task, with no diff. Check each report row against the file it names: a value with no stored output, or a file that does not show the row's state, is a finding. Read the brief, the report and the files its rows name, plus one check per named risk; never redo the work.`

- [ ] **Step 5: Spec**

In the skills spec's execute-plan section: step 6 gains "A verification task, whose Files modify nothing, follows `references/verification.md`: a brief limited to the states and evidence rows its steps name, a report table of stored files, a task-reviewer `evidence` review, at most two rounds, and a `--no-probe` close (pilot fix plan 2: MA-254 round 2's evidence task cost 29% of the run)." Step 8 gains "A review's return is saved with the Write tool." Section 7 Acceptance adds "- A verification task: its empty diff goes to an `evidence` review, not back to the implementer, and a state unproven after round 2 stops the run." The size sentence (line 451) reads "SKILL.md at most 13,850 bytes (13,550 until pilot fix plan 2's Task 3, for the verification path; 12,599 until its Task 1: step 10's size check" and gains "`references/verification.md` 1,250" in its reference list.

- [ ] **Step 6: Run the focused checks**

Run: `node --test tests/skills/execute-plan.test.mjs tests/agents.test.mjs && node scripts/lint-skills.mjs`
Expected: all pass; `lint: clean`; `wc -c skills/execute-plan/SKILL.md` prints 13829 and `skills/execute-plan/references/verification.md` 1220.

- [ ] **Step 7: Commit**

```bash
git add -- skills/execute-plan/SKILL.md skills/execute-plan/references/verification.md agents/task-reviewer.md tests/skills/execute-plan.test.mjs tests/agents.test.mjs docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: execute-plan gives a verification task a narrow brief, an evidence review and two rounds"
```

### Task 4: Sizing counts re-indent; the short form keeps Not doing

Round 2's spec said about 290 lines by shortstat. The ticket said about 332 added outside tests, another measure, and one file's re-indent made 396 changed lines, 58 ignoring whitespace; 650 were delivered. The plan review checked size and wrote "No split is needed". MA-255 and MA-256, the ticket's Out of scope items, appeared only in chat, so the plan review had no Not doing lines to check.

**Files:**
- Modify: `skills/define/SKILL.md`, `skills/define/references/spec-template.md`, `skills/plan/references/plan-review.md`, `tests/skills/define.test.mjs`, `tests/skills/plan.test.mjs`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: the spec template's `## Size` and `## Not doing`; plan-review's Size and Non-goals checks.
- Produces: a short-form spec with `## Not doing`; a Size line that counts re-indented lines and names `-w` and the ticket's measure. plan-check is unchanged.

- [ ] **Step 1: Write the pins**

In `tests/skills/define.test.mjs`: replace `assertMaxBytes(SKILL, 6950);` with

```js
  // 7,000 since pilot fix plan 2's Task 4: step 6 counts a re-indented file's moved lines.
  assertMaxBytes(SKILL, 7000);
```

In the refs table, the `spec-template.md` entry's cap becomes `3450`, with its comment line followed by `    // 3,450 since pilot fix plan 2's Task 4: the re-indent and ticket-measure sentences, and the short form's Not doing.`. In the "define reads the ticket by default" test, replace `'keep only Problem, Size, Constraints, Acceptance criteria and Test seams'` with `'keep only Problem, Size, Constraints, Acceptance criteria, Test seams and Not doing'`, and add to that `assertContains` list `'A re-indented or re-wrapped file counts every line it moves; give its `git diff -w` count beside it.'`, `'A size the ticket states in another measure is named next to this one, each with its measure.'`, `"The ticket's Out of scope lines, each with any ticket it names"` (the test at `tests/skills/define.test.mjs:126`, its `assertContains` at `:136`). In the same test, line 131's string `'First count the files and the changed lines from your reads, tests included, and say both'` becomes `"First count the files and the changed lines from your reads, tests included, a re-indented file's moved lines too, and say both"`.

In `tests/skills/plan.test.mjs`, replace the plan-review cap lines with:

```js
  // 1,450 since the pilot fix plan's Task 5 (raised from 1,400): the States, Size, Non-goals and spike checks.
  // 1,600 since pilot fix plan 2's Task 4: the Size check reads the gate's own measure, re-indented lines included.
  assertMaxBytes('skills/plan/references/plan-review.md', 1600);
  assertContains('skills/plan/references/plan-review.md', ["Check its line estimate in the gate's own measure against the file map, re-indented lines included"]);
```

Run: `node --test tests/skills/define.test.mjs tests/skills/plan.test.mjs`
Expected: the new pins fail.

- [ ] **Step 2: Edit the skills**

- `skills/define/SKILL.md` step 6: replace `First count the files and the changed lines from your reads, tests included, and say both;` with `First count the files and the changed lines from your reads, tests included, a re-indented file's moved lines too, and say both;`.
- `skills/define/references/spec-template.md`: after `as `git diff --shortstat` counts (or `pr.size_command`'s measure, named).` insert ` A re-indented or re-wrapped file counts every line it moves; give its `git diff -w` count beside it. A size the ticket states in another measure is named next to this one, each with its measure.` Replace `keep only Problem, Size, Constraints, Acceptance criteria and Test seams` with `keep only Problem, Size, Constraints, Acceptance criteria, Test seams and Not doing`. Under `## Not doing` add the line `The ticket's Out of scope lines, each with any ticket it names, then what else this change leaves alone; `none` when nothing.` (a blank line before it).
- `skills/plan/references/plan-review.md`: after `- Size: the Size line over `scope_threshold` or `pr.max_lines` with no split or user's word.` insert ` Check its line estimate in the gate's own measure against the file map, re-indented lines included; a ticket's size in another measure does not stand in for it.`

- [ ] **Step 3: Spec**

In the skills spec: line 325's short-form text says the short form keeps "Problem, Size, Constraints, Acceptance criteria, Test seams and Not doing (the ticket's Out of scope lines; pilot fix plan 2, Task 4)", and its Size item adds "a re-indented file counts every moved line, with its `-w` count beside it; a ticket's size in another measure is named next to it". The size sentences: define (line 346) "SKILL.md at most 7,000 bytes (6,950 until pilot fix plan 2's Task 4; 6,500 until" and "`references/spec-template.md` at most 3,450 bytes (3,100 until pilot fix plan 2's Task 4; 3,000 until that task)"; plan (line 395) "`plan-review.md` 1,600 (1,450 until pilot fix plan 2's Task 4; 1,400 until that task)".

- [ ] **Step 4: Run the focused checks**

Run: `node --test tests/skills/define.test.mjs tests/skills/plan.test.mjs && bash tests/run-bats tests/scripts/plan-check.bats && node scripts/lint-skills.mjs`
Expected: all pass (plan-check's short-form tests still pass: it does not require `## Not doing`); `lint: clean`; sizes 6977, 3401 and 1585.

- [ ] **Step 5: Commit**

```bash
git add -- skills/define/SKILL.md skills/define/references/spec-template.md skills/plan/references/plan-review.md tests/skills/define.test.mjs tests/skills/plan.test.mjs docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: sizing counts re-indented lines and names the ticket's measure; the short spec form keeps Not doing"
```

### Task 5: Moved literals are copies; probe drops a lone `!`; no hand-made fork

Round 2's blast-radius check cleared a loading skeleton because it "copies none of the tab or support-line code", while it repeats the shared piece's class lists and style strings. `probe --mutate` printed `inconclusive (no condition to invert ...)` on `if (!wraps)`: its operator list has no `!` (`scripts/probe:146-164`). kern then made a fork by hand and left it with a full `node_modules`.

**Files:**
- Modify: `skills/self-review/SKILL.md`, `skills/self-review/references/blast-radius.md`, `skills/self-review/references/claim-checks.md`, `skills/implement/references/test-design.md`, `scripts/probe`, `tests/scripts/claim-probe.bats`, `tests/skills/self-review.test.mjs`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: `probe --mutate FILE:LINE WT -- CMD` (unchanged usage and outputs).
- Produces: probe's mutation also drops the first `!` that is not before `=` and not after a name character or closing bracket, when the line has no operator from its list.

- [ ] **Step 1: Write the tests**

Append to `tests/scripts/claim-probe.bats`:

```bash

@test "--mutate: a negation with no other operator is dropped, and the test catches it" {
  printf '[ ! "$1" = bad ]\n' > "$WT/gate.sh"
  printf 'bash gate.sh bad && exit 1\nbash gate.sh good || exit 1\nexit 0\n' > "$WT/test-gate.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate gate.sh:1 "$WT" -- sh test-gate.sh
  [ "$status" -eq 0 ]
  [ "$output" = 'probe: mutation caught ([  "$1" = bad ])' ]
  [ "$(cat "$WT/gate.sh")" = '[ ! "$1" = bad ]' ]
}

@test "--mutate: an operator on the line wins over a negation, and a ! after a name or before = is never dropped" {
  printf 'if (!ok && x) f()\n' > "$WT/a.js"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate a.js:1 "$WT" -- sh test-always.sh
  [ "$status" -eq 1 ]
  [[ "$output" == "probe: mutation survived (if (!ok || x) f())"* ]] || false
  printf 'y = x!.z\n' > "$WT/b.ts"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate b.ts:1 "$WT" -- sh test-always.sh
  [ "$status" -eq 3 ]
  [ "$output" = "probe: inconclusive (no condition to invert on b.ts:1)" ]
}
```

In `tests/skills/self-review.test.mjs`: replace `assertMaxBytes(SKILL, 8250);` with a comment line `// 8,500 since pilot fix plan 2's Task 5: step 6 searches readers for moved literals, step 7 makes no fork of its own.` and `assertMaxBytes(SKILL, 8500);`. In the references table, `blast-radius.md` becomes `2900` and `claim-checks.md` `2000`, with the comment `// pilot fix plan 2's Task 5: blast-radius.md 2,600 to 2,900 (moved literals), claim-checks.md 1,939 to 2,000 (probe drops a lone !).` Add to the self-review tests: `assert.ok(s[6].includes("Search them for the moved elements' class lists, style values and literal props (`references/blast-radius.md`)."), s[6]);`, `assert.ok(s[7].includes('Never mutate in a fork you make yourself: probe makes and removes its own'), s[7]);`, and `assert.ok(section(readDoc(`${REF}/blast-radius.md`).body, '## Where grep stops').includes('is a copy and a finding, even when it imports nothing from the piece.'));`, `assertContains(`${REF}/claim-checks.md`, ['or drops a `!` when it has none, in a throwaway fork']);`.

Run: `bash tests/run-bats tests/scripts/claim-probe.bats` and `node --test tests/skills/self-review.test.mjs`
Expected: test 34 fails (inconclusive, exit 3); test 35 and the 33 existing tests pass. The new self-review pins fail.

- [ ] **Step 2: probe**

In `scripts/probe`, replace the comment `  # Invert the first operator found on the line, in this order; a word must stand alone.` with:

```bash
  # Invert the first operator found on the line, in this order; a word must stand alone. With none, drop
  # the first negation: a ! not before = and not after a name character or a closing bracket, so
  # if (!ok) becomes if (ok) while x!.y and != stay.
```

and, in the same awk program, after the operator loop's closing `      }` (the line after `if (i) { $0 = substr(...); done = 1; print > "/dev/stderr"; break }`), insert:

```awk
      for (i = 1; !done && i <= length($0); i++) {
        if (substr($0, i, 1) != "!") continue
        a = substr($0, i + 1, 1); b = (i == 1) ? "" : substr($0, i - 1, 1)
        if (a == "=" || a == "" || b ~ /[A-Za-z0-9_)\]}]/) continue
        $0 = substr($0, 1, i - 1) substr($0, i + 1); done = 1; print > "/dev/stderr"
      }
```

Line 3 of the header ("Mutate mode: CMD passes in WT; on a fork with one condition inverted at FILE:LINE, CMD fails.") stays true.

- [ ] **Step 3: The skill text**

- `skills/self-review/SKILL.md` step 6: after `Code moved into a shared piece: read every other reader of the old code; a copy left behind is a finding.` insert ` Search them for the moved elements' class lists, style values and literal props (`references/blast-radius.md`).` Step 7: after `probe inverts the first operator on that line in a throwaway fork, never the worktree.` insert ` Never mutate in a fork you make yourself: probe makes and removes its own, and its inconclusive exit fails the check as below.`
- `skills/self-review/references/blast-radius.md`, `## Where grep stops`: after the manifest bullet add `- Markup or code moved into a shared piece: `rg -F` each moved element's class list, style object and literal props or strings in every other reader of the old code. A reader that repeats one, a loading skeleton or fallback included, is a copy and a finding, even when it imports nothing from the piece.`
- `skills/self-review/references/claim-checks.md`: replace `inverts the first operator on that line in a throwaway fork` with `inverts the first operator on that line, or drops a `!` when it has none, in a throwaway fork`.
- `skills/implement/references/test-design.md`: replace `it inverts one operator on that line, the first in probe's fixed order, in a throwaway fork;` with `it inverts one operator on that line, the first in probe's fixed order, or drops a `!` when the line has none, in a throwaway fork;`.

- [ ] **Step 4: Spec**

In the skills spec's self-review section: step 6 gains "the moved elements' class lists, style values and literal props are searched for in every other reader; a reader that repeats one is a copy (pilot fix plan 2)"; step 7 gains "`probe --mutate` drops a lone `!`, and self-review never makes a fork of its own". The size sentence (line 679): "SKILL.md at most 8,250 bytes" becomes "SKILL.md at most 8,500 bytes (8,250 until pilot fix plan 2's Task 5", and "`blast-radius.md` 2,600" becomes "`blast-radius.md` 2,900 (2,600 until that task)"; the claim-checks cap reads 2,000.

- [ ] **Step 5: Run the focused checks**

Run: `bash tests/run-bats tests/scripts/claim-probe.bats && node --test tests/skills/self-review.test.mjs tests/skills/implement.test.mjs && node scripts/lint-skills.mjs`
Expected: 35 of 35; all node tests pass; `lint: clean`; sizes 8455, 2869, 1973 and 4237.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/probe tests/scripts/claim-probe.bats skills/self-review/SKILL.md skills/self-review/references/blast-radius.md skills/self-review/references/claim-checks.md skills/implement/references/test-design.md tests/skills/self-review.test.mjs docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: blast radius treats moved literals as copies; probe drops a lone !; self-review makes no fork of its own"
```

### Task 6: proof-check fails a degraded proof

Round 2's `edit commitment` row was filed with "(form drew empty, on main too)": proof-check passed it, since its evidence cell had a backticked file that existed. Only the spec lane caught it, as "Cannot verify". A script cannot tell what a screenshot shows; it can read a marker the author writes. `proofs.md` already says never file a proof for a state it does not show, so a `degraded:` row fails like `none`.

**Files:**
- Modify: `scripts/proof-check`, `skills/self-review/references/proofs.md`, `tests/scripts/proof-check.bats`, `tests/skills/self-review.test.mjs`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: the proofs table format (unchanged).
- Produces: output line `degraded: PROOFS:<row>: line <N> state <state>`, exit 1; the row's state stays unproven.

- [ ] **Step 1: Write the test**

Append to `tests/scripts/proof-check.bats`:

```bash

@test "evidence marked degraded: fails and leaves its state unproven" {
  proofs '| 1 | add | `./add.png` |' '| 1 | edit | `./edit.png` Degraded: the form drew empty |' '| 2 | rows reached by scrolling | `npm test -- rows`: 3 passed, not degraded |' '| 3 | - | `npm test`: 12 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "degraded: proofs.md:4: line 1 state edit" ]
  [ "${lines[1]}" = "unproven: 1 edit" ]
  [ "${#lines[@]}" -eq 2 ]
}
```

In `tests/skills/self-review.test.mjs`, the references table's `proofs.md` cap becomes `1350` (comment: `// proofs.md 1,200 to 1,350 since pilot fix plan 2's Task 6: the degraded: marker.`), and the proofs `assertContains` adds ``'is written `degraded: <what differs>`, and proof-check fails it.'``.

Run: `bash tests/run-bats tests/scripts/proof-check.bats`
Expected: test 9 fails (exit 0, no output); tests 1 to 8 pass.

- [ ] **Step 2: proof-check**

In `scripts/proof-check`, in the rows awk, replace `? "empty" : "ok"` with `? "empty" : (e ~ /(^|[^a-z])degraded:/) ? "degraded" : "ok"`. In the shell loop, after `    empty) echo "no evidence: $proofs:$row"; bad=1; continue ;;` add `    degraded) echo "degraded: $proofs:$row: line $ln state $st"; bad=1; continue ;;`. In the header comment, after the `missing file:` sentence add: "An evidence cell that holds `degraded:`, in any case, marks evidence taken on another or a degraded state: `degraded: PROOFS:<row>: line <N> state <state>`, and the state stays unproven." and add the `degraded:` line to the Output list.

- [ ] **Step 3: proofs.md and spec**

In `skills/self-review/references/proofs.md`, `## Evidence`, after `the rows after the scroll for rows reached by scrolling.` insert ` Evidence taken on another or a degraded state (an empty form, a fallback, the add form for `edit`) is written `degraded: <what differs>`, and proof-check fails it.` In the skills spec's self-review section, the proof-check description gains "a `degraded:` evidence row fails and leaves its state unproven", and the size sentence's "`proofs.md` 1,200" becomes "`proofs.md` 1,350 (1,200 until pilot fix plan 2's Task 6)".

- [ ] **Step 4: Run the focused checks**

Run: `bash tests/run-bats tests/scripts/proof-check.bats && node --test tests/skills/self-review.test.mjs && node scripts/lint-skills.mjs`
Expected: 9 of 9; pass; `lint: clean`; `proofs.md` 1336 bytes.

- [ ] **Step 5: Commit**

```bash
git add -- scripts/proof-check skills/self-review/references/proofs.md tests/scripts/proof-check.bats tests/skills/self-review.test.mjs docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: proof-check fails evidence marked degraded:"
```

### Task 7: G18: one-letter variables, brace lists of files, an escaped backtick

Round 2's four investigator denies, reproduced against `hooks/pre-tool-use` with `agent_type` `kern:investigator`:

| Event | Command shape | Rule that fired | After this task |
|---|---|---|---|
| 14 (22:17:09) | `T=src/...; cat -n $T/...; ...; sed -n 130,230p $T/... \| cat -n \| sed 's/^/+129 /'; C=...` | the record `T=src/...` is not on the allowlist (`g18-readonly-agent.sh:91`) | still denied: `sed 's/^/+129 /'` is not `sed -n` with line numbers (`:72-89`) |
| 15 (22:17:19) | `f=.../bie0lxquu.txt; grep -n ... $f \| head -40; ...; for x in ...; do ...; done` | the record `f=...` (`:91`) | still denied: the `for` record (`:91`) |
| 16 (22:17:32) | `grep -n -o "category-picker[^']*" .../{add_commitment,budget}.md` | `_g18_expands` reads `{` (`:113-114`) | allowed |
| 17 (22:17:35) | `rg -n -o "category-picker[^'\`]*" .../add_commitment.md .../budget.md` | the raw backtick check (`:17`), on an escaped backtick inside double quotes; there is no brace | allowed |

Threat model: the investigator is read-only, and a prompt-injected investigator controls only its command text. A one-letter variable set once to a plain value is substituted into the records after it, and the result goes through every existing check, so `T=-o; sort $T out.txt` is judged as `sort -o out.txt` and denied. Only one-letter names: no shell and no allowlisted command reads one from its environment, while `IFS`, `PATH`, `GIT_*`, `RIPGREP_CONFIG_PATH` or zsh's `path` would change what runs. A variable set twice is denied, since `T=a || T=-o` leaves G18 unable to tell which value a later record reads. An assignment may also not reach a later record at all: after `||`, in a pipeline, in the background, in a subshell or in a branch the variable stays unset, and `test -f /etc/passwd || T=1p; sed -n $T w/tmp/x a.txt` runs `sed -n w/tmp/x a.txt`, which writes. So a record that reads a variable is judged twice, with the value and with the variable empty, and both readings must pass. A value with `$`, a glob, a blank or a quote inside stays an unknown record. A brace list passes only in a word that is not the record's first and does not start with `-`, with one group, a comma, no `..`, and items of name characters, none empty or starting with `-`: the shell then makes only file-name words, never an option or a command name. An unescaped backtick outside single quotes still denies through `_g18_expands`.

**Files:**
- Modify: `hooks/guards/g18-readonly-agent.sh`, `tests/hooks/g18.bats`, `agents/investigator.md`, `tests/agents.test.mjs`, `docs/specs/2026-10-12-kern-design.md`

**Interfaces:**
- Consumes: `git_words`, `_shell_words`, `vote`.
- Produces: `_g18_assign RECORD` (sets `_G18_N`, `_G18_V`), `_g18_subst TEXT NAME VALUE`; `_g18_expands` with the brace-list exception.

- [ ] **Step 1: Write the tests**

Append to `tests/hooks/g18.bats`:

```bash

@test "a one-letter variable set once to a plain path is read as that path" {
  # Pilot fix plan 2, Task 7 (MA-254 round 2, events 14 and 15): T=src/...; cat -n $T/... was denied for the assignment.
  for cmd in 'T=src/a; cat -n $T/a.txt' 'T=src; grep -n foo ${T}/a.txt | head -5' "f='/tmp/x.txt'; grep -n foo \$f" \
    'cd src; T=src/a; cat -n $T/b.txt; git grep -n foo' 'T=src && C=docs; cat $T/a.txt $C/b.md'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "a brace list of file names and an escaped backtick in double quotes pass" {
  # Events 16 and 17: grep -n -o "...[^']*" .../{a,b}.md, and rg -n -o "...[^'\`]*" with the backtick escaped.
  bt='rg -n -o \"foo[^'"'"'\\`]*\" a.md'
  for cmd in 'grep -n -o foo src/{a,b}.md' 'rg -n foo docs/{x,y}.md | head' 'ls {src,docs}' "$bt" 'git log -1 HEAD@{1}'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "variables, brace lists and backticks that could hide an option or run code are still denied" {
  for cmd in 'IFS=/; cat -n a.txt' 'PATH=/tmp; cat a.txt' 'T=$HOME; cat $T/a.txt' 'T=-o; sort $T out.txt a.txt' \
    'T=a.txt || T=-o; sort $T out.txt' 'T=a.txt cat $T' "T='a b'; cat \$T" 'T=*.txt; cat $T' 'sort $T out.txt; T=-o' \
    'T=a; sort ${T:--o} out.txt' 'T=a; sort $Tx out.txt' \
    '{cat,a.txt}' 'rg -n foo x{,--pre=sh}' 'rg -n foo -{-pre=sh,x}' 'rg -n foo \"-\"{-pre=sh,x}' 'sed -n {1w/tmp/x,p} a.txt' 'cat a{1..3}.txt' 'cat {a,{b,c}}.txt' \
    'cat \"$(id)\"' 'rg -n \"foo`id`\" a.md' 'T=src; for x in a b; do cat $T/$x; done' \
    'test -f /etc/passwd || T=1p; sed -n $T w/tmp/x a.txt' 'T=1p | sed -n $T w/tmp/x a.txt' 'T=1p & sed -n $T w/tmp/x a.txt' \
    '( T=1p ); sed -n $T w/tmp/x a.txt'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}
```

Run: `bash tests/run-bats tests/hooks/g18.bats`
Expected: tests 14 and 15 fail (the first command of each is denied); test 16 and tests 1 to 13 pass.

- [ ] **Step 2: Change the guard**

In `hooks/guards/g18-readonly-agent.sh`:

1. Line 17: replace `  case "$c" in *'>'* | *'<('* | *\$\(* | *'`'*) return 1 ;; esac` with `  case "$c" in *'>'* | *'<('* | *\$\(*) return 1 ;; esac` (an active backtick still denies in `_g18_expands`, which reads quotes and escapes).

2. Replace the whole `_g18_expands` function and its comment with:

```bash
# _g18_expands TEXT: exit 0 when the shell may turn TEXT into words it does not show: a $ or a
# backtick outside single quotes ($_, ${x:--o}, $'-o'), or a brace expansion ({-o,out.txt}). A brace
# pair after @ with no comma or .. inside, such as git's HEAD@{1} or @{u}, does not expand. One brace
# list of file names in a word passes (list below): the shell makes only file-name words of it.
_g18_expands() {
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" '
    # list W K: 1 when word W, the Kth, is not the first, does not start with -, holds one { before one },
    # and the group holds a comma, no .., and items of name characters, none empty or starting with -.
    function list(w, k,   g, a, m, i) {
      if (k == 1 || substr(w, 1, 1) == "-") return 0
      if (gsub(/[{]/, "{", w) != 1 || gsub(/[}]/, "}", w) != 1) return 0
      g = substr(w, index(w, "{") + 1); if (!index(g, "}")) return 0
      g = substr(g, 1, index(g, "}") - 1)
      if (!index(g, ",") || index(g, "..")) return 0
      m = split(g, a, ",")
      for (i = 1; i <= m; i++) if (a[i] !~ /^[A-Za-z0-9_.\/+][A-Za-z0-9_.\/+-]*$/) return 0
      return 1
    }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      # s keeps every character; a quoted or escaped brace, comma or blank becomes _, so it neither
      # expands nor splits a word, and a quoted - still starts its word.
      n = split(buf, C, ""); q = ""; s = ""
      for (i = 1; i <= n; i++) {
        c = C[i]
        if (q == sq) { if (c == sq) q = ""; else s = s (c ~ /[{},[:space:]]/ ? "_" : c); continue }
        if (c == "\\") { i++; s = s (C[i] ~ /[{},[:space:]]/ ? "_" : C[i]); continue }
        if (c == "$" || c == "`") exit 0
        if (q == "\"") { if (c == "\"") q = ""; else s = s (c ~ /[{},[:space:]]/ ? "_" : c); continue }
        if (c == sq || c == "\"") { q = c; continue }
        s = s c
      }
      gsub(/@[{][^,.{}]*[}]/, "@", s)
      m = split(s, W, /[[:space:]]+/); k = 0
      for (i = 1; i <= m; i++) {
        if (W[i] == "") continue
        k++
        if (index(W[i], "{") && !list(W[i], k)) exit 0
      }
      exit 1
    }'
}

# _g18_assign RECORD: exit 0 when RECORD is only NAME=VALUE with a one-letter NAME and a plain VALUE
# (letters, digits and _ . / : @ + -, in one pair of quotes or none); sets _G18_N and _G18_V. No shell and
# no allowlisted command reads a one-letter variable from its environment, while IFS, PATH, GIT_* or
# RIPGREP_CONFIG_PATH would change what runs, so any longer name stays denied.
_g18_assign() {
  local r=$1
  r=${r#"${r%%[![:space:]]*}"}
  r=${r%"${r##*[![:space:]]}"}
  case "$r" in [A-Za-z]=*) ;; *) return 1 ;; esac
  _G18_N=${r%%=*}
  _G18_V=${r#?=}
  case "$_G18_V" in
    \'*\') _G18_V=${_G18_V#\'} && _G18_V=${_G18_V%\'} ;;
    \"*\") _G18_V=${_G18_V#\"} && _G18_V=${_G18_V%\"} ;;
  esac
  case "$_G18_V" in '' | *[!A-Za-z0-9_./:@+-]*) return 1 ;; esac
  return 0
}

# _g18_subst TEXT NAME VALUE: TEXT with each $NAME and ${NAME} replaced by VALUE, so G18 judges the words
# the shell would run. $NAMEx names another variable and stays, and any $ left is denied as before.
_g18_subst() {
  printf '%s' "$1" | N=$2 V=$3 env LC_ALL=C awk '
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = ENVIRON["N"]; v = ENVIRON["V"]; out = ""
      while ((i = index(buf, "$")) > 0) {
        out = out substr(buf, 1, i - 1); buf = substr(buf, i + 1)
        if (substr(buf, 1, 3) == "{" n "}") { out = out v; buf = substr(buf, 4); continue }
        if (substr(buf, 1, 1) == n && substr(buf, 2, 1) !~ /[A-Za-z0-9_]/) { out = out v; buf = substr(buf, 2); continue }
        out = out "$"
      }
      printf "%s", out buf
    }'
}
```

3. In `guard_g18`, replace `  local cmd line` with `  local cmd line bare seen=' ' asg='' n v nl=$'\n'`, and replace the loop's first two lines (`  while IFS= read -r line; do` / `    [ -n "$line" ] || continue`) with:

```bash
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # A one-letter variable set once to a plain value is read as that value in the records after it.
    # One set twice is denied: after || or in a branch, G18 cannot tell which value a later record reads.
    if _g18_assign "$line"; then
      case "$seen" in
        *" $_G18_N "*)
          vote deny G18 "$AGENT is read-only; $_G18_N is set twice in one command, so G18 cannot tell which value a later command reads. Set each variable once."
          return 0
          ;;
      esac
      seen="$seen$_G18_N "
      asg="$asg$_G18_N=$_G18_V$nl"
      continue
    fi
    bare=$line
    while IFS='=' read -r n v; do
      [ -n "$n" ] && line=$(_g18_subst "$line" "$n" "$v") && bare=$(_g18_subst "$bare" "$n" "")
    done <<EOF
$asg
EOF
    # The assignment may not reach this record (after ||, in a pipeline, in the background, a subshell or
    # a branch), so the record must also pass with each variable empty.
    if [ "$bare" != "$line" ] && ! g18_allowed "$bare"; then
      vote deny G18 "$AGENT is read-only; with a variable unset, as it may be when this command runs, '${bare%%[[:space:]]*}' with these arguments is not on its allowlist. Write the value out."
      return 0
    fi
```

The `g18_allowed` call and deny message after it stay as they are.

- [ ] **Step 3: The investigator's rule and the spec**

In `agents/investigator.md`, rule 1, after `when you need more, say which command and why, and the controller runs it.` add ` A one-letter variable set once to a plain path, and a brace list of file names, pass; a loop, a longer variable name and a sed script other than line numbers and p do not.` In `tests/agents.test.mjs`, the investigator test's `assertContains` adds `'a loop, a longer variable name and a sed script other than line numbers and p do not'`. The G18 row of design spec section 8.3 (`docs/specs/2026-10-12-kern-design.md:429`) gains, before its last cell: "A one-letter variable set once to a plain value is read as that value and as empty, and both readings must pass; one brace list of file names in a word that is not the first passes (pilot fix plan 2); a longer name, a value with `$`, a glob or a blank, a variable set twice, and a brace list holding an option stay denied."

- [ ] **Step 4: Run the focused checks**

Run: `bash tests/run-bats tests/hooks/g18.bats && bash tests/run-bats tests/hooks/g18-parity.bats && bash tests/run-bats tests/hooks/pre-tool-use.bats && node --test tests/agents.test.mjs && shellcheck -x -S warning hooks/guards/g18-readonly-agent.sh && node scripts/lint-skills.mjs`
Expected: 16 of 16, 3 of 3, pre-tool-use all ok, agents pass, no shellcheck output, `lint: clean`.

- [ ] **Step 5: Commit**

```bash
git add -- hooks/guards/g18-readonly-agent.sh tests/hooks/g18.bats agents/investigator.md tests/agents.test.mjs docs/specs/2026-10-12-kern-design.md
git commit -m "M2: G18 reads a one-letter variable and a brace list of files, and an escaped backtick is literal"
```

### Task 8: G16: find patterns, and cat-written scripts an interpreter runs

Round 2's two G16 asks, reproduced against `hooks/pre-tool-use` with `agent_type` `kern:implementer`:

- Event 10 (22:49:06): `... find / -name "*.db" -path "*seed*" -not -path "*/node_modules/*" 2>/dev/null | head`. In `_g16_hooks_read`, the word `*/node_modules/*` has the directory part `*`, which `_g16_glob hooks "*"` matches (`hooks/guards/g16-state.sh:909`), so it is read as inside a hooks directory, and its last part `*` matches every hook name (`:921`). The evidence cited `:779-800`, the glob helper; the vote comes from these two lines.
- Event 11 (23:08:21): `cd <scratch> && cat > cellfit.py <<'E'` with a Python body, then `python3 cellfit.py ... | cut -c1-210` (the brief's `; python3 cellfit.py` dropped the pipe). The body word `image.open(f{tag}/{name}_p{n}.png` has a zsh group `(` in its directory part (`:909`) and a `{` in its last part (`:918`). The shell view did not apply: `_g16_inert` rule 1 fails on the `|` (`:967`), and `cat` is not one of the interpreter heads (`:941`).

Threat model: G16 asks before a command that names kern's hook code, so the model cannot run `prompt-submit` to forge the user's message or edit a guard unseen. (1) A find pattern operand (`-name`, `-iname`, `-path`, `-ipath`, `-wholename`, `-iwholename`, `-regex`, `-iregex`, `-lname`, `-ilname`) only picks paths to print, so it is skipped on a line that runs `find` and holds no `-exec`, `-execdir`, `-ok`, `-okdir`, `-delete`, `-fprint`, `-fprint0`, `-fprintf`, `-fls`, no `xargs`, `parallel` or shell word, and no `$` or backtick. Reaching a hook path that way is the accepted limit `find $K -name prompt-submit`. A literal `hooks/<hook>` still hits, since the literal rule runs before the words. (2) A `cat > file <<'E'` body is code for the interpreter that runs the file, as `python3 - <<'E'` is: the body counts as code only when every record that holds `<<` is that `cat` with one quoted here-doc and one `>` or `>>` to a literal file; every other record naming the file is an interpreter; every other record is `cd` or a read-only filter (`cut`, `head`, `tail`, `grep`, `wc`, `uniq`, `tr`, `nl`, `column`, `ls`, `echo`, `printf`, `true`, `mkdir`); and `_g16_inert`'s rules 2 to 5 and its shell-word rule hold. A pipe can then feed only a filter or an interpreter, so rule 1 is not needed. A file a shell, a path (`./x.sh`), `chmod`, `cp` or `xargs` touches keeps every rule, and so does `sort` (its `--compress-program` runs a program).

**Files:**
- Modify: `hooks/guards/g16-state.sh`, `tests/hooks/g16-state.bats`, `docs/specs/2026-10-12-kern-design.md`

**Interfaces:**
- Consumes: `_G16_HOOK_AWK`, `_g16_shell_view`, `_g16_inert VIEW CMD HEADS EXEMPT`, `git_words`.
- Produces: `_g16_inert VIEW CMD HEADS EXEMPT [pipes]` (with `pipes`, rule 1 is skipped); `_g16_cat_file VIEW CMD`.

- [ ] **Step 1: Write the tests**

Append to `tests/hooks/g16-state.bats`:

```bash

@test "a find whose patterns only pick paths to print gets no vote; a find that acts on what it finds, or names a hook, still asks" {
  # Pilot fix plan 2 (MA-254 round 2, event 10): -not -path "*/node_modules/*" read as a glob for a hooks path
  # (_g16_hooks_read: a * directory part matches hooks, and a * last part matches every hook name).
  expect_cmd none 'find / -name "*.db" -path "*seed*" -not -path "*/node_modules/*" 2>/dev/null | head' \
    'find . -path "*/dist/*" -prune -o -name "*.ts" -print | wc -l'
  # shellcheck disable=SC2016 # a literal $( )
  expect_hook 'find / -path "*/h*/*" -exec bash {} \;' 'find / -path "*/h*/*" -execdir cat {} +' 'find / -path "*/h*/*" -delete' \
    'find / -path "*/h*/*" -fprint /tmp/x' 'find / -path "*/h*/*" | xargs bash' 'find / -path "*/h*/prompt-submit" | sh' \
    'bash $(find / -path "*/h*/prompt-submit")' 'find / -path "*/hooks/prompt-submit"' 'cat /x/*/h*/prompt-submit; find . -name "*.ts"'
}

@test "a script cat writes to a file that only an interpreter runs gets no vote; a file a shell or a path runs still asks" {
  # Pilot fix plan 2 (MA-254 round 2, event 11): cat > cellfit.py <<'E' ... E, then python3 cellfit.py | cut. Its body's
  # f'{tag}/{name}_p{n}.png' read as a brace group after a paren directory part, and the pipe failed _g16_inert's rule 1.
  B="im=Image.open(f'{tag}/{name}_p{n}.png')"
  expect_cmd none "$(printf '%s\n' "cd /tmp/w && cat > cellfit.py <<'E'" "$B" 'E' 'python3 cellfit.py head:a:0 | cut -c1-210')" \
    "$(printf '%s\n' "cat >> d/x.py <<'E'" "$B" 'E' 'python3 d/x.py && echo done')"
  expect_hook "$(printf '%s\n' "cat > x.sh <<'E'" "$B" 'E' 'bash x.sh')" "$(printf '%s\n' "cat > x.sh <<'E'" "$B" 'E' './x.sh')" \
    "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'chmod +x x.py; ./x.py')" "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'cp x.py /tmp/y; sh /tmp/y')" \
    "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'python3 x.py | xargs -I{} {}')" "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'python3 x.py > o.sh; ./o.sh')" \
    "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'python3 x.py | sort --compress-program=sh')" "$(printf '%s\n' "cat > x.py <<E" "$B" 'E' 'python3 x.py')" \
    "$(printf '%s\n' "cat <<'E' | sh" "$B" 'E')" "$(printf '%s\n' "cat > x.py > y.sh <<'E'" "$B" 'E' 'python3 x.py; sh y.sh')" \
    "$(printf '%s\n' "cat > x.py <<'E'" "open('/k/hooks/prompt-submit').read()" 'E' 'python3 x.py')" \
    "$(printf '%s\n' "cat > x.py <<'E'" "$B" 'E' 'python3 x.py; cat /x/h*/prompt-submit')"
}
```

Run: `bash tests/run-bats tests/hooks/g16-state.bats`
Expected: tests 83 and 84 fail at their `expect_cmd none` line (each first command asks); tests 1 to 82 pass.

- [ ] **Step 2: Change the guard**

In `hooks/guards/g16-state.sh`:

1. In `_G16_HOOK_AWK`, replace the line `{ n = split($0, w, /[ \t\r;|&<>)=]+/); for (i = 1; i <= n; i++) if (w[i] != "") words = words w[i] "\n" }` with:

```awk
{
  n = split($0, w, /[ \t\r;|&<>)=]+/)
  # fp: the line runs find and nothing that acts on what it finds, so a find pattern only picks paths
  # to print (see _g16_hooks).
  fp = 0
  for (i = 1; i <= n; i++) { b = w[i]; sub(/^.*\//, "", b); if (b == "find") fp = 1 }
  for (i = 1; i <= n && fp; i++) {
    b = w[i]; sub(/^.*\//, "", b)
    if (w[i] ~ /^-(exec|execdir|ok|okdir|delete|fprint|fprint0|fprintf|fls)$/ || index(w[i], "$") || index(w[i], "`")) fp = 0
    if (b ~ /^(xargs|parallel|sh|bash|zsh|dash|ksh|mksh|yash|fish|csh|tcsh|busybox|eval|source)$/) fp = 0
  }
  for (i = 1; i <= n; i++) {
    if (w[i] == "") continue
    if (fp && i > 1 && w[i - 1] ~ /^-(name|iname|path|ipath|wholename|iwholename|regex|iregex|lname|ilname)$/) continue
    words = words w[i] "\n"
  }
}
```

and add to the `_G16_HOOK_AWK` comment: "A word right after a find pattern test (-name, -path and the like) is left out on a line that runs find and nothing that acts on what it finds: no -exec, -execdir, -ok, -okdir, -delete, -fprint, -fprint0, -fprintf or -fls, no xargs, parallel or shell word, and no $ or backtick. Such a pattern only picks paths to print, the reach of the accepted limit find $K -name prompt-submit. `.` is not read as a shell there: it is find's usual start path."

2. In `_g16_shell_view`, replace `  _g16_inert "$_G16_SV" "$1" '^(python[0-9.]*|node|nodejs|ruby|perl|php)$' ''` with `  _g16_inert "$_G16_SV" "$1" '^(python[0-9.]*|node|nodejs|ruby|perl|php)$' '' || _g16_cat_file "$_G16_SV" "$1"`, and in its comment replace "A cat body could be piped to a shell, so cat bodies keep every rule." with "A cat body could be piped to a shell, so a cat body keeps every rule unless _g16_cat_file passes: cat writes it to a file that only an interpreter runs."

3. After `_g16_shell_view`, add:

```bash
# _g16_cat_file VIEW CMD: exit 0 when every here-doc in CMD is a script that cat writes to a file for an
# interpreter to run. It needs all of these: each record of VIEW that holds << is cat (any path, no
# NAME=value before it) with one here-doc and one > or >> to a file named by letters, digits and _ . / -,
# and nothing else; each other record whose head is python (python[0-9.]*), node, nodejs, ruby, perl or
# php may name that file; every other record has the head cd, cut, head, tail, grep, wc, uniq, tr, nl,
# column, ls, echo, printf, true or mkdir and names no such file (by path or last path part); and
# _g16_inert holds with cat among its heads, except its rule 1. A pipe can then feed only a filter or an
# interpreter, so rule 1 is not needed. A file a non-interpreter record names (./x.sh, chmod, cp, mv)
# keeps every rule.
_g16_cat_file() {
  _g16_inert "$1" "$2" '^(cat|python[0-9.]*|node|nodejs|ruby|perl|php)$' '' pipes || return 1
  printf '%s\n' "$1" | env LC_ALL=C awk '
    { rec[NR] = $0 }
    END {
      nf = 0
      for (r = 1; r <= NR; r++) {
        $0 = rec[r]
        if (!index($0, "<<")) continue
        h = tolower($1); sub(/^.*\//, "", h)
        if (h != "cat") exit 1
        f = ""; hd = 0
        for (j = 2; j <= NF; j++) {
          if ($j ~ /^<<-?$/) { j++; hd++; continue }
          if ($j ~ /^<<-?./) { hd++; continue }
          if ($j ~ /^>>?$/) { if (f != "") exit 1; j++; f = $j; continue }
          if ($j ~ /^>>?[^>&|]/) { if (f != "") exit 1; f = $j; sub(/^>>?/, "", f); continue }
          exit 1
        }
        if (hd != 1 || f !~ /^[A-Za-z0-9_.\/-]+$/) exit 1
        cat[r] = 1; file[++nf] = f
      }
      if (!nf) exit 1
      for (r = 1; r <= NR; r++) {
        if (r in cat) continue
        $0 = rec[r]
        for (i = 1; i <= NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/; i++) ;
        h = tolower($i); gsub(/["\047\\]/, "", h); sub(/^.*\//, "", h)
        if (h ~ /^(python[0-9.]*|node|nodejs|ruby|perl|php)$/) continue
        if (h !~ /^(cd|cut|head|tail|grep|wc|uniq|tr|nl|column|ls|echo|printf|true|mkdir)$/) exit 1
        for (j = i; j <= NF; j++) {
          w = $j; gsub(/["\047\\]/, "", w); b = w; sub(/^.*\//, "", b)
          for (k = 1; k <= nf; k++) { fb = file[k]; sub(/^.*\//, "", fb); if (w == file[k] || b == fb) exit 1 }
        }
      }
    }'
}
```

4. In `_g16_inert`, replace `  case "$2" in *'|'*) return 1 ;; esac` with `  case "$2" in *'|'*) [ "${5-}" = pipes ] || return 1 ;; esac`, and its usage comment's first line becomes `# _g16_inert VIEW CMD HEADS EXEMPT [pipes]: ...`, with "Rule 1 is skipped when the fifth argument is pipes (_g16_cat_file)." added after the rule 1 paragraph.

- [ ] **Step 3: Spec**

The G16 row of design spec section 8.3 (`docs/specs/2026-10-12-kern-design.md:427`) gains, before its last cell: "the same reading applies to a `cat > file <<'E'` body when only an interpreter runs that file and every other command is `cd` or a read-only filter, where a pipe may feed a filter; and a find pattern operand (`-name`, `-path` and the like) is not read as a hooks path on a line where find acts on nothing it finds (pilot fix plan 2)".

- [ ] **Step 4: Run the focused checks**

Run: `bash tests/run-bats tests/hooks/g16-state.bats && bash tests/run-bats tests/hooks/pre-tool-use.bats && bash tests/run-bats tests/hooks/g20.bats && shellcheck -x -S warning hooks/guards/g16-state.sh`
Expected: 84 of 84; the other two suites all ok; no shellcheck output.

- [ ] **Step 5: Commit**

```bash
git add -- hooks/guards/g16-state.sh tests/hooks/g16-state.bats docs/specs/2026-10-12-kern-design.md
git commit -m "M2: G16 skips find patterns that only pick paths, and reads a cat-written script an interpreter runs as code"
```

### Task 9: G20 keeps both denies; the skills route around them

Both round 2 denies came from `_g20_target`'s first branch (`hooks/guards/g20-approval.sh:288-289`): the command holds the word `approved` (`_G20_W=1`, `:750`) and writes `$LD/...`, a destination built at run time. Event 12 wrote a review `.txt` through `cat > $LD/reviews/task-1-r1.txt <<'EOF'`. Event 13 appended to `$LD/ledger.md` in the same command as `bash $S/task-review ... compliant approved`; with a literal path it is still denied, as a Markdown write in a command that holds the word (`_G20_WRITES`). G20 cannot see what line a shell write makes, and narrowing to a literal last path part is unsafe under zsh's MULTIOS (open question 2). This task pins both denies, shows the two routes that pass, and tells execute-plan's ledger format to append in a call of its own. Task 3 already made step 8 save a review with the Write tool.

**Files:**
- Modify: `tests/hooks/g20-probes.bats`, `skills/execute-plan/references/ledger-format.md`, `tests/skills/execute-plan.test.mjs`, `hooks/guards/g20-approval.sh` (comment only), `docs/specs/2026-10-12-kern-design.md`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`

**Interfaces:**
- Consumes: G20 unchanged.
- Produces: the ledger-format rule that a line is appended in a call of its own when the command would hold `approved`.

- [ ] **Step 1: Write the test**

Append to `tests/hooks/g20-probes.bats`:

```bash

@test "review and ledger text that holds approved stays denied in a shell write from a variable or beside a task-review call; a literal path, a call of its own and the Write tool pass" {
  # Pilot fix plan 2, Task 9 (MA-254 round 2, events 12 and 13). Narrowing the first deny to a literal last path part is
  # unsafe under zsh: MULTIOS writes a split redirect word ($=D/x.txt) to every file it names.
  mkdir -p "$R/.kern/ledgers/x/reviews"
  printf '# kern ledger\n' > "$R/.kern/ledgers/x/ledger.md"
  b "LD=$R/.kern/ledgers/x
cat > \$LD/reviews/task-1-r1.txt <<'EOF'
Task quality: approved
EOF"
  deny
  b "LD=$R/.kern/ledgers/x; printf '%s\n' 'Decision: a; why: b; cost if wrong: c' >> \$LD/ledger.md; bash task-review \$LD/ledger.md 1 abc 1 compliant approved"
  deny
  b "cat > $R/.kern/ledgers/x/reviews/task-1-r1.txt <<'EOF'
Task quality: approved
EOF"
  none
  b "printf '%s\n' 'Decision: a; why: b; cost if wrong: c' >> $R/.kern/ledgers/x/ledger.md"
  none
  write "$R/.kern/ledgers/x/reviews/task-1-r2.txt" 'Task quality: approved'
  none
}
```

Run: `bash tests/run-bats tests/hooks/g20-probes.bats`
Expected: 56 of 56: this test pins current behaviour.

- [ ] **Step 2: Ledger format, guard comment, specs**

In `skills/execute-plan/references/ledger-format.md`, after `one holding the word approved goes in with the Edit tool, as G20 denies that shell write to a Markdown file.` insert ` So does a line appended in a command that holds the word anywhere else, a `task-review ... approved` call included: append it in a call of its own.` In `tests/skills/execute-plan.test.mjs`, the LEDGER cap becomes `2750` with the comment `// 2,750 since pilot fix plan 2's Task 9 (raised from 2,600): append in a call of its own beside a task-review approved call.`, and `assertContains(LEDGER, [...])` adds `'a `task-review ... approved` call included: append it in a call of its own.'`.

In `hooks/guards/g20-approval.sh`, the comment above `_g20_target` gains: "# With approved in the command, a write to a destination built at run time is denied whatever its last part: zsh's MULTIOS writes a split redirect word ($=x, or with shwordsplit) to each file it names, so x/notes.txt can also reach a spec. kern writes review and ledger text with the Write tool or in a call of its own (pilot fix plan 2)."

The G20 row of design spec section 8.3 (`:431`) gains: "A shell write of text that holds the word to a destination built at run time stays denied whatever its file name, since zsh's MULTIOS can split it onto a spec; kern writes reviews with the Write tool and appends ledger lines in a call of their own (pilot fix plan 2)." The skills spec's execute-plan size sentence (line 451) reads "`references/ledger-format.md` at most 2,750 bytes (2,600 until pilot fix plan 2's Task 9)".

- [ ] **Step 3: Run the focused checks**

Run: `bash tests/run-bats tests/hooks/g20-probes.bats && bash tests/run-bats tests/hooks/g20.bats && node --test tests/skills/execute-plan.test.mjs && shellcheck -x -S warning hooks/guards/g20-approval.sh && node scripts/lint-skills.mjs`
Expected: 56 of 56, g20 all ok, pass, no shellcheck output, `lint: clean`; `ledger-format.md` 2741 bytes.

- [ ] **Step 4: Commit**

```bash
git add -- tests/hooks/g20-probes.bats skills/execute-plan/references/ledger-format.md tests/skills/execute-plan.test.mjs hooks/guards/g20-approval.sh docs/specs/2026-10-12-kern-design.md docs/specs/2026-10-12-kern-m1-m2-skills.md
git commit -m "M2: pin G20's two pilot denies and append ledger lines in a call of their own"
```

### Task 10: Eval cases

Two cases for the new duties, gating like the others (two of three valid runs, at most one invalid): the size question at the first breach (behaviour), and the finish menu's typed reply with no guard ask (exec, two turns). The exec harness gains `turns`, and its gh stub answers `gh pr checks`.

**Files:**
- Modify: `evals/behave/workflows.json`, `scripts/lib/behave.mjs`, `tests/behave.test.mjs`, `evals/exec/cases.json`, `scripts/lib/exec-run.mjs`, `scripts/lib/exec-grade.mjs`, `evals/exec/bin/gh`, `tests/exec-eval.test.mjs`

**Interfaces:**
- Consumes: fixture layers `node-bug`, `sum-fixed`, `approved-spec`, `approved-plan`; `runsGit`, `steps`, `argOf`; exec's `MENU`, `guardAsked`, `CONSENT_ASK`, `pushedTip`, `check`.
- Produces: behaviour case `workflow-execute-plan-size-breach` with scripted check `no-git-add`; exec case `finish-menu-consent` and grader; `casePrompts(c)` reading `c.turns` (a list) in place of `c.turn`.

- [ ] **Step 1: Write the tests**

In `tests/behave.test.mjs`, the sorted `CHECKS` key list gains `'no-git-add'` (between `'next-move-task-3'` and `'no-recall-skill'`), and append:

```js
test('no-git-add fails on any git add, -N included, and passes with none (pilot fix plan 2, Task 10)', () => {
  const check = CHECKS['no-git-add'];
  assert.equal(check([...ran('git -C /w/app diff --shortstat 1a2b 3c4d', ' 2 files changed, 14 insertions(+)'), ...reply('Split or one PR?')]).pass, true);
  assert.equal(check([...ran('git -C /w/app add -N . ; git -C /w/app diff --shortstat'), ...reply('x')]).pass, false);
  assert.equal(check([...ran('cd /w/app && git add src/export.js'), ...reply('x')]).pass, false);
  const c = loadCases(ROOT).find((x) => x.id === 'workflow-execute-plan-size-breach');
  assert.deepEqual(c.checks, { 2: 'no-git-add' });
  assert.deepEqual(c.setup, ["mkdir -p .claude && printf 'pr.max_lines: 10\\n' > .claude/kern.local.yml"]);
});
```

In `tests/exec-eval.test.mjs`, the dry-run test's id list adds `'finish-menu-consent'`, and append:

```js
test('finish-menu-consent: two turns; the menu in words, then no guard ask, one commit pushed and one draft PR (pilot fix plan 2, Task 10)', () => {
  assert.deepEqual(casePrompts({ autopilot: false, turns: ['/kern:finish-branch', 'commit, push and open a draft PR'] }), ['/kern:finish-branch', 'commit, push and open a draft PR']);
  assert.deepEqual(casePrompts({ autopilot: false, turn: 'commit' }), ['commit']);
  const menu = { type: 'result', subtype: 'success', result: 'Reply with one: 1 `commit`; 2 `commit and push`; 3 `commit, push and open a draft PR`; 4 `keep`.' };
  const done = { type: 'result', subtype: 'success', result: 'Draft PR: file:///o/pull/8' };
  const pushed = git({ 'ls-remote origin refs/heads/feat/sum': 'abc\trefs/heads/feat/sum', 'rev-parse feat/sum': 'abc', 'rev-list --count main..feat/sum': '1', 'status --porcelain': '' });
  const grade = (events, ghLog = ['pr create --draft --title fix --body-file b.md'], g = pushed) => GRADERS['finish-menu-consent']({ events, ghLog, git: g, branch: 'feat/sum' });
  assert.equal(grade([menu, done]).pass, true);
  assert.equal(grade([done, done]).pass, false, 'no menu in the first reply');
  assert.equal(grade([menu, done], []).pass, false, 'no draft PR');
  const asked = { type: 'user', message: { content: [{ type: 'tool_result', is_error: true, content: 'needs user approval: kern G5: commit (message checks pass)' }] } };
  assert.equal(grade([menu, asked, done]).pass, false, 'G5 asked');
});
```

Add `casePrompts` to the import from `../scripts/lib/exec-run.mjs` at `tests/exec-eval.test.mjs:13`.

Run: `node --test tests/behave.test.mjs tests/exec-eval.test.mjs`
Expected: the new tests fail (no `no-git-add`, no case, no grader, `casePrompts` ignores `turns`).

- [ ] **Step 2: The behaviour case and its check**

Append to `evals/behave/workflows.json`:

```json
  { "id": "workflow-execute-plan-size-breach", "skills": ["execute-plan"], "files": ["node-bug", "sum-fixed", "approved-spec", "approved-plan"], "max_turns": 60, "origin": true,
    "setup": ["mkdir -p .claude && printf 'pr.max_lines: 10\\n' > .claude/kern.local.yml"],
    "prompts": ["Execute the approved plan in .kern/plans/export.md in inline mode."],
    "expectations": [
      "After Task 1 is closed (its task-done line) and before any edit for Task 2, stops and asks whether to split or keep one PR",
      "The question names the changed-line count with its measure, such as lines: 18 (git diff --shortstat), and the limit pr.max_lines 10 with its source",
      "No Bash call runs git add, git add -N included",
      "Does not push or open a PR"],
    "checks": { "2": "no-git-add" } }
```

In `scripts/lib/behave.mjs`, add to `CHECKS`:

```js
  // workflow-execute-plan-size-breach (pilot fix plan 2, Task 10; MA-254 round 2's `git add -N .` raised a G5 ask and broke a
  // commit's lint-staged backup): no Bash call, the main session's or a subagent's, runs git add (runsGit), -N included.
  'no-git-add': (events) => {
    const adds = steps(events).filter((s) => s.call?.name === 'Bash' && runsGit(s.call.input.command ?? '', 'add'));
    return adds.length ? { pass: false, evidence: `git add ran: Bash ${argOf(adds[0].call)}` } : { pass: true, evidence: 'no Bash call runs git add' };
  },
```

- [ ] **Step 3: The exec case, harness, grader and stub**

- `scripts/lib/exec-run.mjs`: `export const casePrompts = (c) => [...(c.autopilot ? ['/kern:autopilot on'] : []), ...(c.turns ?? [c.turn])];`
- `evals/exec/cases.json`, after `finish-menu-first`: `{ "id": "finish-menu-consent", "autopilot": false, "branch": "feat/sum", "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"], "turns": ["/kern:finish-branch", "commit, push and open a draft PR"] },`
- `scripts/lib/exec-grade.mjs`, after `MENU`: `const replies = (events) => events.filter((e) => e?.type === 'result' && typeof e.result === 'string').map((e) => e.result);` and in `GRADERS`, after `finish-menu-first`:

```js
  // finish-menu-consent (pilot fix plan 2, Task 10; MA-254 round 2 asked 8 times after the user's "One"): the first reply shows
  // the menu with option 3 in words, and the typed option 3 is G5's, G1's and G2's consent: the commit, the push and one
  // draft PR land with no consent ask.
  'finish-menu-consent': ({ events, ghLog, git, branch }) => {
    const first = replies(events)[0] ?? '';
    const creates = ghLog.filter((l) => l.startsWith('pr create'));
    return check([
      [MENU.test(first) && /commit, push and open a draft PR/i.test(first), 'the first reply does not show the menu with option 3 as "commit, push and open a draft PR"'],
      [!guardAsked(events, 'G5', CONSENT_ASK), 'G5 asked for the commit the user typed'],
      [!guardAsked(events, 'G1'), 'G1 asked for the push the user typed'],
      [!guardAsked(events, 'G2'), 'G2 asked for the PR the user typed'],
      [creates.length === 1 && /--draft/.test(creates[0]), 'not exactly one draft PR'],
      ...pushedTip(git, branch, 1),
    ]);
  },
```

- `evals/exec/bin/gh`, before the `*)` arm: `  "pr checks") echo "no checks reported on the '$(git branch --show-current 2>/dev/null)' branch"; exit 1 ;;` (gh's own reply for a branch with no CI).

- [ ] **Step 4: Run the focused checks**

Run: `node --test tests/behave.test.mjs tests/exec-eval.test.mjs tests/behave-fixtures.test.mjs tests/eval-all.test.mjs && shellcheck evals/exec/bin/gh && node scripts/lint-skills.mjs`
Expected: all pass; `node scripts/behave.mjs --dry-run` would list 23 cases and `node scripts/exec-eval.mjs --dry-run` 9 (both are run in Task 12, not here); `lint: clean`.

- [ ] **Step 5: Commit**

```bash
git add -- evals/behave/workflows.json scripts/lib/behave.mjs tests/behave.test.mjs evals/exec/cases.json scripts/lib/exec-run.mjs scripts/lib/exec-grade.mjs evals/exec/bin/gh tests/exec-eval.test.mjs
git commit -m "M2: eval cases for the size question at the first breach and the finish menu's typed consent"
```

### Task 11: Records

**Files:**
- Modify: `docs/plans/contract.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: Tasks 1 to 10 as committed.
- Produces: the contract entry and the CHANGELOG bullets Task 12 extends.

- [ ] **Step 1: Contract**

Append one entry to `docs/plans/contract.md`'s decisions list, in the existing format: **"Size at the first breach, consent replies in words, verification tasks, and four guard false positives (pilot fix plan 2 `docs/plans/2026-10-26-kern-pilot-fixes-2.md`; the user's "start"; supersedes the pilot fix plan entry's short-form list and the Spec frontmatter entry's `form: short` list)."** Sub-bullets, one each:
- execute-plan step 10's size check (the command, `wt-snap`, never `git add`, the `Decision:` line whose what opens with size, the autopilot default) and finish-branch step 6 reading it; `pr.max_lines` and `pr.size_command` are read by execute-plan.
- finish-branch step 7's replies `commit`, `commit and push`, `commit, push and open a draft PR`, `keep`, read by `prompt_consent` unchanged; step 11's reviews and one `gh pr checks <n>`; `Bash(gh pr checks *)` in `allowed-tools`.
- `skills/execute-plan/references/verification.md` and task-reviewer mode `evidence` (inputs, checks, two rounds, the `--no-probe` close); step 8 saves a review with the Write tool.
- `form: short` keeps Problem, Size, Constraints, Acceptance criteria, Test seams and Not doing; plan-check still requires only Problem, Constraints, Acceptance criteria and Test seams for it.
- The Scripts table's `probe` row: `--mutate` drops the first `!` not before `=` and not after a name character or closing bracket when the line has no listed operator. The `proof-check` row: `degraded: PROOFS:<row>: line <N> state <state>`.
- G18 `_g18_assign`, `_g18_subst` and `_g18_expands`' brace-list rule; G16 `_g16_cat_file` and `_g16_inert`'s fifth argument `pipes`, and the find-pattern skip in `_G16_HOOK_AWK`; G20 unchanged, with its two pinned denies.
- Exec case format: `"turn"` or `"turns": [...]`; `casePrompts` reads `turns` first. The gh stub answers `pr checks`. Behaviour `workflow-execute-plan-size-breach` (checks `{ "2": "no-git-add" }`) joins the workflow list at line 342; exec `finish-menu-consent` joins the exec cases.

Edit the exec format line (`docs/plans/contract.md:339`, `[{ "id", "autopilot", "branch", "pr"?, "settings"?, "setup": [<shell>], "turn" }]`) to `[{ "id", "autopilot", "branch", "pr"?, "settings"?, "setup": [<shell>], "turn" or "turns": [...] }]`, and add `workflow-execute-plan-size-breach` to line 342's workflow list ("and, since pilot fix plan 2's Task 10, `workflow-execute-plan-size-breach`").

- [ ] **Step 2: CHANGELOG**

Under `## [Unreleased]`, before the pilot fixes bullet, add a bullet "The second pilot fixes (pilot fix plan 2 `docs/plans/2026-10-26-kern-pilot-fixes-2.md`, 2026-10-26; the user's "start"). MA-254 round 2 matched the project's usual flow in plan, review and code at 44% of its cost, but lost on ease and time. These are the generic fixes; none is specific to that project." with one sub-bullet per area: size at the first breach and never staging; the menu in words and the PR report; verification tasks; sizing and Not doing; blast radius, probe and forks; `degraded:`; G18; G16; G20 pinned; the eval cases; the caps (each old and new number from the Decisions list). If open question 1 got a no, the size sub-bullet starts "Breaking:".

- [ ] **Step 3: Check and commit**

Run: `node scripts/lint-skills.mjs && node --test tests/coverage.test.mjs`
Expected: `lint: clean` (rule 16 finds every new ledger and script name in the contract); pass.

```bash
git add -- docs/plans/contract.md CHANGELOG.md
git commit -m "M2: record the second pilot fixes"
```

### Task 12: Final test round

ci-local green, a free dry run over every runner and case, one paid full round, and at most one fix and one rerun of only what this package broke. Exit rule, agreed at approval (open question 4): (1) every gate passes: stop and report; (2) a gate this package broke, or a new case that fails (`workflow-execute-plan-size-breach`, `finish-menu-consent`): one fix package for those failures, focused suites and ci-local, one rerun of only the failed categories, then stop and report whatever it shows; (3) a known limit that failed before (adherence Sonnet multi-diagnose 0/3; the `workflow-self-review-proofs` skip under `fix first`) is reported, not fixed. No second fix round without the user's word.

**Files:**
- Create: the snapshots the round writes under `evals/snapshots/` (named by each runner's log)
- Modify: `CHANGELOG.md`; on a fix, the files that cause the failure

**Interfaces:**
- Consumes: `scripts/ci-local`; `scripts/eval-all [--jobs N] [--no-cache] [--only a,b] [--dry-run]` (runners exec, behave, adherence-sonnet, adherence-haiku, h2h-plan, h2h-review); each runner's `--case <id>`.
- Produces: committed snapshots and a CHANGELOG sub-bullet with the results.

- [ ] **Step 1: Run ci-local**

Run: `PATH="$HOME/.volta/tools/image/node/22.23.3/bin:$HOME/.local/bin:$PATH" scripts/ci-local`
Expected: `ci-local: all steps passed`. A red step is fixed in the task that owns the file, with that task's focused suite, before anything else here.

- [ ] **Step 2: Ask for the dry run, then run it**

Ask the user: "ci-local is green. May I run the free dry run of every runner and case? It makes no model call." On yes:

```bash
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval claude auth status
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval scripts/eval-all --jobs 6 --no-cache --dry-run
```

Expected: `claude auth status` names mustafa.mohamed.wd@gmail.com (any other account: stop and tell the user). Each runner lists its cases with no model call: exec 9 cases, behaviour 23, adherence Sonnet and Haiku 20 each, head-to-head plan and review. Every runner exits 0. Report the session counts.

- [ ] **Step 3: Ask for the paid round, then run it**

Ask the user, with the dry run's session counts, the models (Sonnet under test; Opus for kern's reviewer and investigator subagents; the graders the runners name) and the last full round's wall time (9m20s at 7a230f8): "May I run the paid full round?" On yes:

```bash
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval claude auth status
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval scripts/eval-all --jobs 6 --no-cache
```

Expected: one line per runner, exit 0 only when every runner exits 0. Gates: each behaviour case passes on at least two of three valid runs with at most one invalid, the new one included; exec 9 of 9; adherence Sonnet 19 of 20 or better (multi-diagnose is the known limit), Haiku reported; head-to-head plan and review PASS.

- [ ] **Step 4: Apply the exit rule**

All gates pass: go to step 5. A gate this package broke, or a new case that fails: read the failing runs' logs under `evals/results/eval-all-<stamp>/`, write one fix package on the files that cause it, run their focused suites and `scripts/ci-local`, commit it (`git add -- <the fixed paths>`, `git commit -m "M2: <what the fix does>"`), then ask the user before one rerun of only the failed categories, every command started at once:

```bash
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval scripts/eval-all --jobs 6 --no-cache --only <failed runners>
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval node scripts/behave.mjs --case <failed id> --jobs 6 --no-cache
CLAUDE_CONFIG_DIR=$HOME/.claude-kern-eval node scripts/exec-eval.mjs --case <failed id> --jobs 6 --no-cache
```

Then stop, whatever the rerun shows. A known limit is reported and not fixed.

- [ ] **Step 5: Record and commit**

Add one sub-bullet to this plan's CHANGELOG bullet: the head, the date, the user's yes, `--jobs 6`, no cache, sessions and wall time, and each gate's result, then the fix and rerun if there was one, and the snapshot names. Commit:

```bash
git add -- CHANGELOG.md evals/snapshots/<each snapshot this round wrote>
git commit -m "M2: record the second pilot-fix test round" -m "<each gate's result, one clause each>"
```

Never add the older untracked snapshots or `docs/pilot.md`. Report to the user what passed, what failed and what is left. Stop.

## After this plan

Task 18, the solo pilot, follows on the user's word, then Task 19. A third MA-254 round is the user's call; it would measure fixes 1, 2 and 4 directly (idle time, guard asks, the evidence task's cost).
