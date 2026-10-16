# Task 22 review: execute-plan (d664a4b, scope 9ed34e1..d664a4b)

Reviewer: opus, read-only. Kern repo untouched (`git status --short` empty before and after). All repro work is under this scratchpad: `walk/` (bare origin + clone, plans `sum-guard.md` step mode and `wave.md` delegate wave), `hk/run.sh` (feeds tool JSON to the real `hooks/pre-tool-use`, all guards, session state with autopilot on or off), `mut/` + `mut.py` (removal mutations).

Checks run: `node --test 'tests/**/*.test.mjs'` 126/126 pass; `node scripts/lint-skills.mjs` `lint: clean`; `node scripts/route-eval.mjs` `route-eval: passed` (rank-1 66%). Every script run with no arguments prints its usage. Every ledger line written in both walks matches the contract formats by regex: 15 of 15 (step walk) and 11 of 11 (wave walk).

```
Spec: compliant
Cannot verify: /kern:commit steps 3-6 and finish-branch (Tasks 24/25 not shipped), so the autopilot commit is checked only for its G5 shape; real subagent behaviour (SendMessage to a finished agent after compaction, background spawn notifications) was simulated by hand; Claude Code's own Edit matching vs G20's model (only the hook input was tested); ci-local not rerun.
Declined to judge: G1 allowing plain `git worktree remove` under autopilot (pre-existing guard, the skill's "teardown never runs" is prose); task-done's `last=` capturing node's `# duration_ms` line (pre-existing); route-eval ranking quality; Task 24/25/30 artifacts.
```

## Findings

### Critical 1: an inconclusive probe closes the task with no RED evidence, and the skill says it cannot

`skills/execute-plan/SKILL.md:29` (step 10) says task-done "writes the complete line only when an approved review saw this tree, the command passes, and the test fails with the change reversed (`probe=ok`)", and that `probe=inconclusive` "stands only for a change with nothing to reverse ...; any other reason: ask". Both are false against `scripts/task-done:76-85`: probe exit 3 for any reason sets `probe=inconclusive` and writes `Task N: complete`. The "ask" comes after the line exists, and the resume rule (`references/ledger-format.md:27`, "A task is done only when its `Task N: complete` line exists ... Never re-dispatch a completed task") makes that closure final. There is no ledger line that reopens a task. Under autopilot the task is also committed straight after.

Probe 1, a setup reason (`walk/p1`): the test reads a gitignored `config.local.json` that exists in the plan worktree but not in probe's fork. task-done exit 0, `probe: inconclusive (the command fails in the fork before any change is reversed; missing ignored files or setup?)`, and the ledger gets `Task 1: complete ... review=approved probe=inconclusive`.

Probe 2, a skill-order mistake (`walk/st`): after fix rounds, step 10's literal command `--probe <package>.patch` with `<package>` as step 8 defined it (the round-1 package `task-2-e91a92b.diff.patch`) gives task-done exit 0, `probe: inconclusive (the patch does not reverse-apply: error: patch failed: src/sum.js:2)`, and a complete line. The "after fix rounds, remake `<package>` from `tree-before`" clause is the only thing between a controller and this, and getting it wrong is silent.

Expected: no complete line without fail-then-pass, except for the named new-module case. Smallest fix in the skill: before task-done, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <package>.patch -- <cmd>`, as implement step 8 already does, and call task-done `--probe` only on `probe: fail-then-pass ok` or the new-module inconclusive (`Cannot find module`, a missing export, `the patch changes only test files`). Any other inconclusive: stop and ask before closing. Correct the "only when ... probe=ok" sentence. Follow-up script change: task-done refuses exit 3 unless given an explicit flag with a reason, as `--no-probe` already works.

### Important 1: resume skips wave patches that were never applied

`references/ledger-format.md:27` says: "Resume at the first task without one; when every task has one, go to the final review." No resume rule reads `Applied:` lines. Wave tasks get their complete lines in their forks (step 10) before step 11 applies them. An interruption between those two steps therefore loses integration.

Probe (`walk/repo`, plan `wave.md`): a 2-task wave. Both tasks closed in forks `wave-task-1` and `wave-task-2`, then only Task 1 was applied (`Applied: Task 1 ...`) and the run stopped. Following the resume rule leads to step 12. `wt-diff <plan-wt> <base-tree> --out reviews/final.diff` lists `src/a.js` only, so Task 2's `src/b.js` is missing, and `ledger-open --summary` still prints `main: unchanged`, exit 0. A later serial task would also run on the plan worktree without the wave. The same gap shows under autopilot after a wt-apply conflict, where the task "stays open" yet its complete line exists.

Expected: before the final review or the next serial task, any task on a `Wave:` line whose complete line has no matching `Applied:` line resumes at step 11. Pin it.

### Important 2: a fix loop cannot be resumed from the ledger

Step 9 (`SKILL.md:28`) resumes round 2 "with the findings verbatim (SendMessage to its agent id ...)". Step 1 (`SKILL.md:17`) says "After compaction, trust the ledger and the worktree over memory". Nothing on disk holds the reviewer's findings or the implementer's agent id. task-review stores only verdicts and `--minor` text, the reviewer returns in chat (`agents/task-reviewer.md` Output), and `reviews/` holds only `.diff` and `.patch` files.

Probe: `ls walk/repo/.kern/ledgers/sum-guard/reviews` shows only packages. The ledger after the round-1 needs-fixes review holds no finding text.

Two cases have no instruction. (a) The last line is `review round=1 ... needs-fixes` with no `fix round` line yet. The resume rule covers only "last line is a fix round". (b) The implementer is unreachable in a new session. Upstream SDD:371-375 kept a fallback: "dispatch a fresh implementer carrying the brief path, the report-file path, and the findings — the report file is the persistent memory either way". The port dropped it. A started task whose snapshot differs from its start tree (partial work, no report) is also undefined: `ledger-format.md:27` gives only the "still equal: dispatch again" side.

Expected: write each reviewer return to `<ledger dir>/reviews/task-N-r<r>.txt` before task-review. Rounds 2 and 3 pass that file. An unreachable implementer gets a fresh dispatch with the brief, the report and that file. Resume cases: last line a needs-fixes review means write the fix round line and continue; a changed start tree means review it as round 1.

### Important 3: the ledger reference sanctions hand-written lines that forge the review and RED gates

`references/ledger-format.md:23` says: "one holding the word approved goes in with the Edit tool, as G20 denies that shell write". The brief puts the review stamp and RED evidence "in code, not prose", but nothing guards a ledger line. G20 judges only frontmatter on an Edit.

Probe (`hk/run.sh`, real hooks, interactive and autopilot): an Edit appending `Task 3: complete tree=<id> test=true exit=0 review=approved probe=ok last=x`, or `Task 3: review round=1 tree=<id> spec=compliant quality=approved`, gets no vote in both modes. The same line through printf is denied by G20, and the deny text ("set or change an approval with the Edit or Write tool") points the controller to the Edit path. A plausible trigger: after compaction a controller "restores" a complete line it believes is missing.

Expected: ledger-format.md says that only the scripts write `Task N: start`, `review`, `minor` and `complete` lines, and that a free-text line avoids the word (or uses Edit) for the script-free formats only. A guard that denies hand-written `Task N: (review|complete)` lines in a ledger.md is a follow-up.

### Minor

1. Concern 3 is reproduced (`SKILL.md:21`). With a test script writing an unignored `test-output.log`, `wt-diff <wt> <base-tree>` after the baseline lists `test-output.log`, exit 0, so the final package shows a file no task wrote. Snapshot `base-tree` after the baseline run. A non-deterministic artifact will still show in task packages as exit 4, which is surfaced, not silent.
2. The round cap is a label, not a count (`SKILL.md:28`, "task-review refuses one"). Probe: task-review accepts rounds 1, 1, 2, 3 for one task, giving 4 review lines and exit 0 each time. On resume, r must come from the ledger. Say "r = 1 + the task's review lines".
3. Exit 4 has no follow-up (`SKILL.md:27`). Nothing says what a yes or a no does next. A yes is asked again: remaking the package from `tree-before` (step 10) re-raises exit 4 for the approved file (repro in `walk/c`). On a yes, append the path to `briefs/task-N.files` with a Decision line. On a no, return the task to the implementer.
4. `SKILL.md:29` routes every `command exited <n>` to the implementer "as the next round". Exit 126/127 (command not found, measured: task-done exits 127) is a controller or plan fault, and after an approved round 3 there is no next round. Route 126/127 to a stop, and a post-round-3 failure to the split proposal.
5. Steps 2 and 3 (`SKILL.md:18-19`) have no "once" guard like step 5, so every step-mode invocation appends the `Preflight:` and `Decision:` lines again, and the summary lists them twice.
6. A compound `Run:` has no instruction (`SKILL.md:29`, "one command"). Under autopilot G00 denies `-- sh -c` (measured). `-- bash <kern-dir tmp>/run-task-N.sh` gets no vote (measured). G00's own advice, "a file in the repo", would change the worktree tree if followed there. Report deviation 4's "cannot be wrapped" is inaccurate.
7. Pins: 6 of 6 load-bearing lines left unpinned survive removal, and a pinned control is killed (`mut.py`). The 6 are: the fix-round resume rule in ledger-format.md (the only home of the spec's step 1 sentence); step 9's "(SendMessage to its agent id; inline and step: fix it yourself)"; the Stops line "One commit per closed task ... through `/kern:commit`"; step 12's "Residual findings go to the user in step 13." and "Re-grade findings by effect."; step 10's "A refusal writes nothing and says why."
8. Port of SDD:497 (`SKILL.md:62`): upstream gates dropping a finding with "You adjudicate only at the cap". The row now allows a Decision line at any round, and D5 sends judgment calls to the user. This is brief text, so it is plan-mandated. Suggested Reality: "Put your evidence to the re-review or the user; record the reviewer's verdicts as returned."
9. Step 12 (`SKILL.md:31`) does not name the fix subagent's agent (presumably `kern:implementer`) or the final re-review's model, and does not say that the fix diff's FROM tree is `final.diff`'s second line.

## Deviations (report numbering; the lead's message numbers them differently)

| # | Verdict | Note |
|---|---|---|
| 1 | ruled | cap 12,000 |
| 2 | ruled | round r = r-th review |
| 3 | correct, necessary | Each branch prints a fixed phrase (`command exited <n>`, `passes with the change reversed`, `changed after the review`, `has no review line`, `did not approve`, `probe exited`), so reading text is robust. Both exit-1 meanings go to the implementer, so the overlap at 1 is harmless. The real overlap is at 2 (a CMD exit 2, measured, against a refusal), and the skill branches on text there too. A dedicated CMD-failure code is a nice-to-have follow-up. See Minor 4. |
| 4 | partly drift | "One command" is right. "Cannot be wrapped" is wrong: a WORK/tmp script passes G00. Minor 6. |
| 5 | correct, necessary | Walk (b): the remade TB2..R3 package holds every round, and the round-1 package does not. Its stale use is Critical 1, probe 2. |
| 6 | correct | fix<r> and final.diff names avoid overwrites. |
| 7 | correct | Step mode has no status line. |
| 8 | correct | The reviewer reads briefs/task-N.md, which holds Global Constraints (task-brief:26-37). |
| 9 | correct | `wt-check` is `ok` with base `kern/wave` in the plan worktree and in a fork. `origin/<base>` breaks once a fetch moves it. |
| 10 | correct | wt-new fills `{slug}` itself and exits 2 on `{id}` without --branch. |
| 11 | correct | No cross-plan slug collision. |
| 12 | correct, necessary | parallel-work step 6 integrates before review. Lost with it: parallel-work's drain and timebox rules (step 5). |
| 13 | correct | |
| 14 | correct | G5 denies a detached fork commit under autopilot ("HEAD is detached", measured). |
| 15 | drift in two parts | The Edit route (Important 3); "all complete: final review" ignores Applied (Important 1); the started-task rule is one-sided (Important 2). |
| 16 | correct | wt-diff accepts repeated --allow-file. |
| 17 | correct | Autopilot `git -C <wt> add -- <paths>` gets no vote and `git -C <wt> commit -m` is allowed by G5. Interactive commit: G5 asks. `add -A` and `commit -a` are denied under autopilot. |
| 18 | correct | |

## Dry walk notes

- (a) Step mode, Task 1 approved on round 1: ledger-open, plan-check, `--graph` (`overlap 1 2 src/sum.js`), Preflight, wt-new `sum-guard --base main` (branch `kern/sum-guard`), Worktree line, baseline, `--files`, task-brief, wt-snap, task-start, implement, wt-snap, wt-diff (exit 0), task-review with `--minor`, then task-done `--probe`: `fail-then-pass ok` and the complete line. Each step said what to do.
- (b) Task 2: needs-fixes on round 1, fix round=2 line, fix2 package, needs-fixes on round 2, fix round=3 line, fix3 package, approved on round 3. Round 4 is refused (exit 2). The remade package goes to task-done, which gives `probe=inconclusive` (missing export `mul`, the accepted new-function case).
- (c) wt-diff exit 4 names the file and the package is still written. See Minor 3.
- (d) See Important 1 and Important 2.
- The final step: `ledger-open --summary` printed the Preflight line, the deferred minor and `main: unchanged`. `git -C <wt> log` shows only `init`. The main checkout is clean.

## Guards (real hooks/pre-tool-use, interactive and autopilot)

No vote in either mode: ledger-open (plain and --summary), plan-check (plain, --graph, `--files > briefs/task-N.files`), task-brief, wt-new, wt-fork, wt-snap, task-start, wt-diff with --allow-file, brief-check, task-review holding `approved` with `--minor`, task-done --probe and --no-probe, wt-apply, kern-get, and a printf ledger line without the word.
Denied: a printf ledger line holding "approved" (G20, both modes); `task-done ... -- bash -c` and `-- sh -c` (G00, autopilot only).
Not caught: an Edit-tool forged complete line or review line (Important 3).
No legitimate append was denied that lacks a sanctioned route.
