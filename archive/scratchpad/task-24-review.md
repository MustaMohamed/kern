# Task 24 review: commit skill (09ead60)

Spec verdict: issues (C9 and the controller rulings hold; the cross-skill contract and two ported gates are incomplete).
Quality verdict: needs-fixes (no Critical; 6 Important, 4 Minor).

Repo untouched. Scratch: /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t24/ (g5.bats, mutation copy in m/).

## Controller gaps, judged

1. Ledger task files: right source, incomplete instruction. See I6.
2. Overlap, one commit naming each or ask: correct for two complete tasks. Misses an incomplete task. See I5.
3. `git -C <toplevel>` and G5 allowing `git -C <wt> commit -F <abs path>`: correct and verified (G5 table below).
4. allowed-tools `git -C * ...`: pattern syntax is supported, but it is unsafe and inert on the Read path. See I1.

## G5 trace (real hook, scratch repo with linked worktree, KERN_MAIN = main root, branch CDS-2466/plan in the worktree, message file under main .kern/tmp, convention `^CDS-[0-9]+: `)

| Command | cwd | Autopilot | Vote |
|---|---|---|---|
| `git -C <wt> commit -F <main>/.kern/tmp/commit-msg` | main | on | allow ("autopilot commit: message checks pass") |
| same | wt | on | allow |
| same | main | off | ask ("commit (message checks pass)") |
| `git -C <main> commit -F <main>/.kern/tmp/m2` and `git commit -F ...` | main | on | allow |
| same on `main` branch | main | on | deny (protected branch) |
| same, wt detached | main | on | deny (HEAD is detached) |
| subject lacks the branch's ticket id | main | on | deny (convention) |
| `git -C <wt> add -- a.txt b.txt`, all guards loaded | main | on | no vote |
| `git -C <wt> status --porcelain`, `rev-parse HEAD^{tree}`, all guards | main | on | no vote |

Protected branch and detached HEAD never commit under autopilot: confirmed. `_g05_proven` accepts the shape from both checkouts (`_G05_CROSS` is 0 because `kern_main_root` of the worktree is KERN_MAIN; `_g05_file_ok` passes because the file sits under main `.kern/`).

## Important

I1. `allowed-tools` pattern is an unprompted-execution hole, and inert where it matters. skills/commit/SKILL.md:6
- Docs (code.claude.com/docs/en/permissions): "A `*` can go anywhere in the rule: at the start, in the middle, or at the end." So the syntax is valid. But: "In `Bash(git * main)`, it stands in for the subcommand, so Claude Code matches every git subcommand and every option before it. That includes `-c`, which makes git run a program you name." Same for `git -C * status *`: `*` swallows `<dir> -c core.fsmonitor=<script>`. Docs also say to "Put the `*` after the subcommand" and that startup warns on a `*` before the subcommand.
- Verified: with all guards loaded, `git -C <wt> -c core.fsmonitor=evil status --porcelain` and `git -C <wt> diff --output=/tmp/x HEAD` get no hook vote, so the allowed-tools rule would pass them unprompted.
- Also inert on the path that matters: spec X15 says `allowed-tools` does nothing for a skill reached by Read, and execute-plan and finish-branch reach commit by Read. There, every status/diff/log/rev-parse prompts. Graded by effect: slash use has a hole; autopilot use gets no benefit.
- Fix: drop the `git -C *` rules (the user's own settings or a G-guard allow, not a frontmatter wildcard before the subcommand), or accept the prompts and say so in the report. A guard-side allow for a narrow read (status/diff/log/rev-parse with -C only) would be the safe route; that is a hooks task, not this one.

I2. Autopilot still stops at `git add`. skills/commit/SKILL.md:18, hooks/guards/g05-commit.sh:192
- `_g05_add` only denies or asks on broad staging; a narrow `git -C <wt> add -- <files>` gets no vote, and `add` is not in allowed-tools (inert on the Read path anyway). Result: every autopilot task commit prompts the user at the add, so "autopilot commits each task as it closes" is not unattended unless the user's own settings allow add. Step 6's design (G5 allows the commit) is only half of the pair.
- Fix: either a G5 allow for a proven narrow `git -C <this repo> add -- <literal files>` under autopilot (reuse `_g05_wide`), or state the precondition in the skill and execute-plan. Needs a controller ruling; do not paper over it in SKILL.md.

I3. Cross-skill contract is incomplete. skills/commit/SKILL.md:11, skills/execute-plan/SKILL.md:29, tests/skills/execute-plan.test.mjs:98
- execute-plan step 10 and commit's intro run "steps 3 to 6". `<toplevel>`, the branch read and the protected-branch and detached-HEAD stops are all in step 2, so a caller that skips step 2 has no `<toplevel>` and skips the stop. G5 denies as backstop (verified), but that is a deny, not the parked line. Step 4 also reruns prove-it on a tree `task-done` already proved (cost, not a bug).
- Smallest fix: "steps 2 to 6" in commit/SKILL.md:11 and execute-plan/SKILL.md:29, with execute-plan naming `<wt>` as its plan worktree (it already says "plan worktree"); update execute-plan.test.mjs:98, and finish-branch (Task 19/25, its test and traceability F19) to the same wording. Check the byte cap of execute-plan after the one-character change.

I4. "Proven tree" is false for every commit but the last in a multi-commit run. skills/commit/SKILL.md:19, 24
- Proof and `wt-snap` run once on the whole working tree. Commit 1 stages only task 1's files, so its tree (HEAD + task 1) was never run; the HEAD^{tree} check runs only after the last commit and only when nothing stayed unstaged (a `never_commit` file skips it). Red flag "Prove the tree you commit" is therefore not true for commits 1..n-1 on the finish-branch path. (On the execute-plan path each task is proved by `task-done` at its own tree, so that path is fine.)
- Fix: say in step 4/7 that a multi-commit run is proven as a sequence, only the final tree is checked, and the report says so; or require a proof per commit. Choose; do not leave the claim implicit.

I5. A started, incomplete task sharing a file is not detected. skills/commit/SKILL.md:18
- The overlap rule compares complete tasks only. A task with a `Task N: start` line and no complete line (stopped and parked, with disjoint tasks continuing) can leave hunks in a file a complete task also touched; `git add` stages them under the complete task's name, which the same step forbids. No step looks for them.
- Fix: for each task with a start and no complete line, `git -C <toplevel> diff --name-only <its start tree> <wt-snap tree>`; any path shared with a complete task is overlap (one commit naming each, or ask). Needs about 150 bytes; the file is at 5,196, so this needs a cap decision, not a trimmed behaviour.

I6. The `## Files changed` list is name-status, not paths. skills/commit/SKILL.md:18, scripts/wt-diff:47-48
- wt-diff writes `git diff --name-status` there: `M\tpath`, `D\tpath`, `R100\told\tnew`. The skill says "the list" of files and the fallback `--name-only` gives bare paths, so the two sources differ and the skill never says to drop the status letter or to stage both sides of a rename. Fed literally to `git add --`, a status line fails or stages nothing.
- Fix: say "the paths in each line, both for a rename" or use `git diff-tree --name-only` for both sources and skip the package. A test pinning this wording.

## Minor

M1. Tests pin few load-bearing lines. Removal mutations on a scratch copy (`node --test tests/skills/commit.test.mjs`): removing each of these still passes 2/2: `(HEAD: detached)`, `Never switch branches.`, `; no files, no commit`, `name and leave out any never_commit path`, the "proof ran on the working tree" sentence, `Read it first if it exists`, the HEAD^{tree} mismatch sentence, `take the ticket id from the branch name by commit.id_from_branch`, `If that file is missing, run` (the command itself is pinned). Pinned (fail when removed): `never -A or .`, the looser-message denial, `never --no-verify`. Pin at least never-switch, no-files default, never_commit, mismatch, and `kern-dir ledgers`.

M2. Dropped red-flag rows ("git add -A is quicker", "The message does not matter"): not a lost gate. Step 3 states `never -A or .` (test-pinned) and G5 broad-add guard enforces it; step 5 requires the convention, a why-body and one concern, and G5 checks subject and ticket id. They were motivational. Spec allows 2 to 6 rows and 3 remain, so this passes the porting rule. Restore the `-A` row if a later byte raise allows it.

M3. Stop wording. (a) "G5 denies or asks" is a stop, but step 6 says G5's prompt is the confirmation; without autopilot an ask is the normal prompt, so read it as "G5 asks and the user declines". (b) The parked line needs `default:`; protected branch and detached HEAD are covered only by "never commits", not listed beside the other defaults. (c) `rev-parse --show-toplevel` failing (not a repo) has no named action. (d) Several ledgers naming the same `Worktree:` path, or a complete task already committed earlier, have no rule: the latter ends in `git commit` "nothing to commit", a stop with no cause given.

M4. Acceptance bullet "Run from the main checkout for a plan worktree" cannot happen with a typed `/kern:commit`: `<wt>` is only "the worktree the caller names", so toplevel is main. Reword the bullet to "called by execute-plan with the plan worktree".

## Checks passed

- Exits: steps 1 to 4, `kern-dir` exit 2, `wt-snap` failure, G5 deny or ask, `git add`/`git commit` failure all stop and report; autopilot parks with the stated line and commits nothing.
- No `$(...)` in a prescribed command; the test asserts it. No long dashes, curly quotes or source tags. No lint exemptions. Cap 5,196 of 5,200 (spec at 66d0d44).
- Files-from-ledger naming `reviews/task-<N>-<tree7>.diff` matches execute-plan step 8; `tree=` of the complete line is the last reviewed tree.

## Commands run

- `bats scratch/t24/g5.bats`: 16 cases, results in the G5 table above and the I1 hole checks.
- `node --test 'tests/**/*.test.mjs'`: 134 pass, 0 fail.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `route-eval: passed` (rank-1 rate 66%, baseline 0%).
- 12 removal mutations on a scratch copy of the repo, results in M1.
- WebFetch https://code.claude.com/docs/en/permissions (docs.claude.com redirects there).
- `git status --short` in the kern repo after: clean.
