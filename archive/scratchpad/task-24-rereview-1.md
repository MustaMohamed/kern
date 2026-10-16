# Task 24 re-review, fix round 1 (300128c)

Scope: diff 66d0d44..300128c (plus ffd5da3 spec line). Repo untouched; scratch under .../scratchpad/t24/ (walk.sh, run.sh, g5.bats).

## 1. Prior findings

| Item | Status | Where |
|---|---|---|
| I1 allowed-tools hole | ADDRESSED | skills/commit/SKILL.md:6 holds only kern-get and kern-detect; test pins it (tests/skills/commit.test.mjs:15) |
| I2 `git add` prompt | ADDRESSED (as ruled) | SKILL.md Stops paragraph ("No kern guard allows `git add`..."). True: G5 gives no vote on a narrow add (replay below), so it prompts unless the user's settings allow it |
| I3 steps 2 to 6 | ADDRESSED | SKILL.md:11; skills/execute-plan/SKILL.md:29; tests/skills/execute-plan.test.mjs:98. No "steps 3 to 6" left in skills/ or tests/. Open follow-up: docs/specs/...skills.md:735 and the plan's finish-branch step 7 (docs/plans/2026-10-14-kern-m2a-plan.md:6618, traceability F19) still say "steps 3 to 6"; finish-branch is not built yet, so fix them when it is, or it will lack step 2 |
| I4 what a multi-commit run proves | ADDRESSED | SKILL.md:19 and the red-flag row. Walkthrough B/C below agree |
| I5 started-incomplete task | ADDRESSED (as ruled) | references/ledger-tasks.md:17-19; case C below. Residue is Minor N3 |
| I6 name-status paths | PARTIAL | ledger-tasks.md:11 correct for the package (case D). The name-only fallback at :13 still loses a rename's old path: see N1 |
| M1 pins | PARTIAL | many pins added; survivors in section 6 |
| M3 stops | ADDRESSED | SKILL.md:17 (toplevel failure), Stops (G5 decline, defaults), ledger-tasks.md:7-9 (several ledgers: ask), :21 (already committed) |
| M4 acceptance wording | ADDRESSED | tests/skills/commit.acceptance.md:9 |

## 2. Ledger walkthrough (real wt-snap and wt-diff packages, plan worktree, `git -C <wt>` throughout, paths read from the package as ledger-tasks.md says)

| Case | `git add` paths | Commit outcome | HEAD^{tree} vs step-4 snapshot |
|---|---|---|---|
| A. two complete tasks, disjoint (a.txt, b.txt) | `a.txt`; then `b.txt` | two commits, in order; b.txt stayed unstaged after the first | EQUAL |
| B. two complete tasks share shared.txt | `a.txt shared.txt b.txt` (one commit naming both) | one commit, nothing left | EQUAL |
| C. parked started task 3, `.files` = `shared.txt`, `src/`; complete task 1 (a.txt, shared.txt), complete task 2 (b.txt) | task 1 not staged (ask, default uncommitted); `b.txt` for task 2 | task 2 committed; a.txt and shared.txt stay modified | check skipped (files stayed unstaged), mismatch expected; step 7 says so |
| D. rename old.txt to new.txt, package present | `old.txt new.txt` (package line `R100<TAB>old<TAB>new`) | one commit, clean | EQUAL |
| E. same rename, package deleted (name-only fallback) | `new.txt` only | commit succeeds, `D old.txt` stays unstaged | MISMATCH (see N1) |
| E2. package deleted, modify plus delete | `a.txt b.txt` | clean | EQUAL |
| F. task 1 already committed, task 2 pending | task 1: status clean, reported committed; task 2: `b.txt` | one commit | EQUAL |
| F2. task 1 committed, then task 2 also edits a.txt | task 1 paths look dirty | see N2 | n/a |

## 3. G5 replay (hook, all guards, scratch repo with linked worktree)

- `git -C <wt> add -- old.txt new.txt`: no vote with autopilot on, with G5 only, and with autopilot off from the worktree cwd. The skill's precondition statement is true.
- `git -C <wt> add -- src/`: no vote. `git -C <wt> add -- .`: deny.
- `git -C <wt> commit -F <main>/.kern/tmp/commit-msg`: allow under autopilot (unchanged from round 0).

## 4. execute-plan

The diff is one line, "steps 3 to 6" to "steps 2 to 6", at SKILL.md:29, plus its pin. Size 12,229 bytes against the 12,400 cap (test:33); execute-plan tests pass.

## 5. New findings

Important

N1. Name-only fallback drops a rename's old path. skills/commit/references/ledger-tasks.md:13 (and its pin, tests/skills/commit.test.mjs `git -C <toplevel> diff --name-only <start tree> <complete tree>`).
- `git diff --name-only` detects renames and prints only the new path. Reproduced (case E): staging `new.txt` alone leaves `D old.txt` unstaged; the commit holds new.txt while HEAD still has old.txt, a broken intermediate commit, and the unstaged deletion is reported as "stayed unstaged" although it belongs to the task. The package path is right (case D); only the "missing package" path is wrong, and it is the path the acceptance file tests.
- Fix: `git -C <toplevel> diff --no-renames --name-only <start tree> <complete tree>`; update the pin; add a rename-with-missing-package line to commit.acceptance.md. About 13 bytes; reference is at 1,732 of 2,000.

Minor

N2. "Already committed" is judged by clean paths. ledger-tasks.md:21. Case F2: task 1 was committed by autopilot, task 2 (parked, uncommitted) later edits the same file; task 1's path is dirty, so task 1 reads as uncommitted, overlaps task 2, and the rule offers one commit naming both, staging only task 2's hunks under task 1's name too. Content is right, the message is wrong. Cheaper test: compare the path at the complete tree with HEAD (`git diff --quiet <complete tree> HEAD -- <paths>` at the time of the check is also fooled by later edits; a real fix is to check that the package patch is already in HEAD). Leave, or note the limit.

N3. `.files` is the allow-list, not what the task dirtied. ledger-tasks.md:17. A parked task that wrote outside its `.files` (wt-diff catches that at review, which a parked task never reached) is not seen; a `dir/` entry such as `src/` blocks every complete task under it (conservative, safe). Accepted by the ruling; keep it in the PR notes.

No new Critical.

## 6. Gates and mutations

- `node --test 'tests/**/*.test.mjs'`: 135 pass, 0 fail.
- `node scripts/lint-skills.mjs`: `lint: clean`. `node scripts/route-eval.mjs`: `route-eval: passed`.
- Sizes: commit/SKILL.md 4,899 (cap 5,200), ledger-tasks.md 1,732 (cap 2,000), execute-plan 12,229 (cap 12,400).
- 12 removal mutations on a scratch copy (commit.test.mjs). Fail when removed (pinned): the rename sentence, the started-task sentence, the already-committed sentence, `If it fails, stop and report.`, the one-proof sentence, `Ledger-task defaults are in the reference.`, the ledger-reference sentence, `wt-snap fails`, the per-task-paths clause. Survive: ` (a dir/ entry covers what is under it)`, `keep ledger order.`, `Every default below is what autopilot parks with.` (the first matters: add a pin).
- `git status --short` in kern after: clean.

Verdict: NEEDS-FIXES (one Important: N1, a one-flag fix; everything else addressed).
