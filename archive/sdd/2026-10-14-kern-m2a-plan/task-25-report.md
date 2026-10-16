Status: DONE_WITH_CONCERNS (all gates green; spec C10 needs a controller docs commit for the new caps, step numbers, consent step, references, allowed-tools and title quoting)

# Task 25 report: finish-branch and the prove-it hand-off

SHA: `ea78a51` (`M2: add the finish-branch skill`), on `main`, parent `f436c98`. Branch checked first: `main`. Working tree clean after the commit. No attribution trailer.

## Files

- `skills/finish-branch/SKILL.md` (new)
- `skills/finish-branch/references/push-and-pr.md` (new): Dedup, Push, PR, and how `push.policy` and `pr.policy` meet G1 and G2
- `skills/finish-branch/references/branch-ops.md` (new): Rebase, Proven tree (the `-check` worktree), Discard
- `skills/finish-branch/references/pr-body.md` (new, the brief's full text)
- `skills/prove-it/SKILL.md` (Gate line)
- `tests/skills/finish-branch.test.mjs` (new), `tests/skills/prove-it.test.mjs` (appended test)
- `tests/skills/finish-branch.acceptance.md` (new), `skills/help/references/map.md` (row), `CHANGELOG.md` (line)

## Byte counts

| File | Bytes | Cap (in test) |
|---|---|---|
| `skills/finish-branch/SKILL.md` | 5,970 | 6,000 |
| `references/push-and-pr.md` | 1,856 | 2,000 |
| `references/branch-ops.md` | 1,990 | 2,000 |
| `references/pr-body.md` | 1,199 | 2,000 |
| `skills/prove-it/SKILL.md` | 3,582 | 3,600 (unchanged; no raise needed) |

## Tests: failing, then passing

Run: `node --test tests/skills/finish-branch.test.mjs tests/skills/prove-it.test.mjs`

Before the skill existed (expected reasons: files missing, hand-off missing):
```
not ok 1 - finish-branch frontmatter
  error: 'skills/finish-branch/SKILL.md exists'
not ok 2 - finish-branch sections, steps and red flags
  error: 'skills/finish-branch/SKILL.md exists'
not ok 3 - push and PR reference
  error: 'skills/finish-branch/references/push-and-pr.md exists'
not ok 4 - PR body template
  error: 'skills/finish-branch/references/pr-body.md exists'
ok 5 - prove-it frontmatter is the spec text
ok 6 - prove-it sections, steps, gate and red flags
ok 7 - evidence reference
ok 8 - the M0 placeholder is gone
not ok 9 - the gate hands a commit to commit and a push or PR to finish-branch
  error: 'skills/prove-it/SKILL.md must contain: for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`'
# tests 9
# pass 4
# fail 5
```
(The first red run had one test for a single reference; the branch-ops reference test was added when the content was split, so the green run has 10.)

After:
```
ok 1 - finish-branch frontmatter
ok 2 - finish-branch sections, steps and red flags
ok 3 - branch-ops reference: rebase, proven-tree check, discard
ok 4 - push-and-pr reference: dedup, push, PR
ok 5 - PR body template
ok 6 - prove-it frontmatter is the spec text
ok 7 - prove-it sections, steps, gate and red flags
ok 8 - evidence reference
ok 9 - the M0 placeholder is gone
ok 10 - the gate hands a commit to commit and a push or PR to finish-branch
# tests 10
# pass 10
# fail 0
```

## Gates

- `node --test 'tests/**/*.test.mjs'`: `# tests 141`, `# pass 141`, `# fail 0` (baseline before the task: 135 of 135).
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `rank-1 rate: 66% (baseline 0%)`, `route-eval: passed`.
- `claude plugin validate .`: `✔ Validation passed`.
- ci-local not run (Task 26).

## Mutations

Run on a scratch copy of the repo. `assertContains` was instrumented there to log every pin the two test files check; each pin was then removed (first occurrence) and the owning test file run.
- 117 pins logged. All 109 pins this task added were killed: 52 in SKILL.md, 23 in branch-ops.md, 28 in push-and-pr.md, 4 in pr-body.md, and the 2 new prove-it Gate pins.
- Uniqueness: the finish-branch test asserts that each pin occurs exactly once (`assertOnce`), so no pin of mine occurs twice.
- The 3 survivors are pre-existing prove-it pins that occur 2 or 3 times (listed under Noticed).
- 10 structural mutations, all killed: `Bash(git fetch *)` added to allowed-tools, a step deleted, step 1's "Otherwise stop." removed, `$(` added to SKILL.md and to each reference, a reference heading renamed or removed, a red-flag pin doubled, and `## Outputs` renamed.

## Gap answers

### 1. Consent

Step 1 is now: "Consent: the user typed `/kern:finish-branch` or asked to push or open a PR in this session, or autopilot is on. Otherwise stop." The steps run 0 to 11 (12 lines). The test asserts 12 steps and step 1's exact text.

### 2. Commit call

Step 8 reads: "run steps 2 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md` on `<wt>`; its stops stop this skill." Commit's step 2 takes `<wt>` as "the worktree the caller names". When `git status --porcelain` prints nothing, there is nothing to commit, and the run goes on to the push. Both strings are pinned.

### 3. Every exit and outcome

- **Fetch fails, no remote.** `git remote get-url origin` failing means there is no remote. `<baseref>` is then local `<base>`, and the menu drops options 2 and 3. Under autopilot it resolves to option 1.
- **Fetch fails, remote exists.** The run reports "base not refreshed" and asks whether to go on with the last fetched ref. A no ends the run. Under autopilot the run goes on with the last fetched ref. Self-review then returns `rebase first`, which is handled as a stale base.
- **Stale base.** The run proposes `git rebase <baseref>` and runs it only on yes. A no goes on. git refuses a rebase over uncommitted changes; the rebase is then offered again after step 8's commit, and a second refusal goes on. A conflict runs `git rebase --abort`, reports the conflicting paths and stops. After a rebase in step 3 or 5, the run starts again from step 4. After a rebase in step 8, the proven-tree check re-proves the tree. These rules are in `branch-ops.md`, section Rebase.
- **prove-it red, or wt-snap fails:** stop (step 4).
- **Self-review verdicts.** `ready` goes on. `fix first`, `split` and no verdict stop with self-review's report; no verdict covers its empty-diff and merge-base stops. `rebase first` is handled as step 3's stale base.
- **Size gate.** The command is `git merge-base HEAD <baseref>`. Its printed SHA is then passed to `git diff --shortstat <merge-base> <tree>`, where `<tree>` is step 4's wt-snap tree, so untracked files count. Neither command uses `$(...)`. "Files changed" is compared with `scope_threshold`, and insertions plus deletions with `pr.max_lines`. Over either, the run proposes a split: yes stops, no goes on. I checked in a scratch repo that `git diff --shortstat <commit> <snapshot tree>` counts an untracked file.
- **gh missing, logged out or failing in dedup:** report its output. The push may go on; no PR opens. G2 would ask on create anyway, and that is a deny under autopilot.
- **`pr.dedup: off`.** `kernel/settings.md` lists `on` as its only value ("G2 always checks"). The dedup runs whatever the key says.
- **wt-new.** Exit 0 prints the path. Any non-zero exit means: report its output and ask, and do not push. Exit 2 covers a bad slug, an existing `-check` path from an earlier run, an unknown commit or a failed setup; a raw git failure gives another code. After the check, the run proposes a plain `git worktree remove <check>` and runs it on yes. A refusal keeps the worktree, and the path is reported. `--force` never runs. Under autopilot the check worktree is kept and reported, because no teardown runs.
- **Rejected push.** Run `git fetch origin <branch>`, show `git log --oneline HEAD..origin/<branch>`, and stop. Never force. A failing pre-push hook is reported, never bypassed with `--no-verify`.
- **G1 and G2 votes.** A prompt is the confirmation. A declined prompt or a denial stops, and is reported. I replayed `hooks/pre-tool-use` with the bats helpers from a linked worktree:

  | Command | Normal | Policy deny | Autopilot |
  |---|---|---|---|
  | `cd <wt>` | none | | |
  | `git push -u origin kern/plan` | ask | deny | allow |
  | `gh pr create --draft --title 'M2: f' --base main --body-file <MAIN>/.kern/tmp/pr-body.md` | ask | deny | allow |
  | same, with a merged PR on the branch | | | deny |
  | same, with gh failing | | | deny |
  | `gh pr ready 1` | | | deny |
  | `git branch -D kern/plan` | ask | | deny |
  | `git rebase origin/main`, `git switch -c kern/x`, plain `git worktree remove` (linked worktree) | none | | |

- **`gh pr create` failing:** report its output, say that the branch is pushed, and stop. Never retry another shape.
- **`kern-dir tmp` exits 2:** stop.
- **A failure no step names:** stop and report its output. The intro states this rule.
- **The title under G2.** I replayed G2 on a set of titles; results:
  - Double quotes with `$` or a backtick fail `_gh_literal`, so G2 asks, and denies under autopilot.
  - Single quotes keep `$` literal. A `'` written as `'\''` passes and parses back to the right title.
  - A backtick or `$(` anywhere in the command fails `_gh_proven`'s whole-command check, even inside single quotes. Under autopilot that is a deny.

  So the title is single-quoted: `gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md`. Each `'` in it is written as `'\''`, and it holds no backtick and no `$` before `(`.

### 4. Discard (branch-ops.md, section Discard)

1. List what discard destroys:
   - `git status --porcelain -uall --ignored`. Ignored files are added because I checked that a plain `git worktree remove` deletes them without refusing, while untracked files make it refuse.
   - `git log --oneline <baseref>..HEAD`.
   - `<wt>`.
2. Wait for the typed word `discard`.
3. `cd` to the main checkout (the first `git worktree list` line) as its own call.
4. Run `git worktree remove <wt>`, then `git branch -D <branch>` (G1 asks), then `git worktree prune`, each as its own call.
5. Report what was removed, and that remote branches and PRs stay.

Rules around it:
- In the main checkout, discard stops: it would need a reset or a clean there.
- `--force` never runs. worktrees.md allows it only when five conditions hold, and the first needs a `wt-apply`, which a discard never has. A refused remove therefore stops and reports the files that blocked it; the worktree and the branch stay.
- Discard never runs under autopilot. The autopilot paragraph says "nothing is rebased or discarded", and G1 denies `branch -D` under autopilot anyway.

### 5. Autopilot, stop by stop

Every kern ask is a deny under autopilot (`emit_decision` in `decide.sh`). The menu resolves to option 3 after the dedup check, or to the highest option step 7 left: 2 under `pr.policy: deny`, 1 with no remote or under `push.policy: deny`. Each stop and its parked default:

| Stop | Parked default | Why |
|---|---|---|
| Stale base or `rebase first` | No rebase; go on. The PR body's Merge danger names the stale base. | A draft cannot merge, and a rebase changes what was proven. Stopping would block every autopilot PR whenever the base moved. |
| Failed fetch | Go on with the last fetched ref | Matches self-review. |
| Size gate | Go on. The PR body's Scope gives the size. | A split is the user's scope call, and a draft can be closed. Plan branches often exceed `scope_threshold` by design. |
| `fix first`, `split` or no verdict | Park; the run ends with nothing committed or pushed | |
| Proven-tree mismatch | Not a judgment: the check runs on a detached copy. A red check or a failed `wt-new` parks, and the run ends with no push; the check worktree is kept. | |
| Dedup: PR at this head | Report its URL and stop | |
| Dedup: open PR at an older head | Push; no new PR | |
| Dedup: only merged or closed PRs | Park; push, no PR | A second PR for a branch is the user's call. |
| Dedup: gh failing | Push, no PR | |
| Detached HEAD or protected branch | Park; the run ends | |

How the policies meet G1 and G2:
- **`push.policy`:**
  - `ask`: G1 asks, and that prompt is the confirmation.
  - `auto` or autopilot: G1 allows `git push -u origin <branch>` to an unprotected branch.
  - `deny`: G1 denies every push, and the menu drops options 2 and 3.
- **`pr.policy`:** the default `draft-after-approval` reads as `ask`.
  - `ask`: G2 asks.
  - `auto` or autopilot: G2 allows only the draft shape, for a branch with no PR.
  - `deny`: G2 denies, and the menu drops option 3.
  - G2 denies any PR that is not a draft. Under autopilot a merged or closed PR, or gh failing, also turns G2's ask into a deny. `gh pr ready` is never run.

### 6. prove-it Gate line

The brief's line is in place verbatim. prove-it is 3,582 bytes, under its 3,600 cap, so the cap was not raised.

## Deviations

1. **allowed-tools drops `Bash(git fetch *)`.** `git fetch --upload-pack=<cmd>` runs a local command. I verified it in scratch: the option created a file. A `*` after the subcommand does not stop an option. The fetch now prompts on a typed run. The list is `Bash(git status *), Bash(git rev-list *), Bash(git rev-parse *), Bash(gh pr list *)`, pinned in the test.
2. **The title is single-quoted**, not double-quoted as in the brief's pin (gap 3). The pin changed with it.
3. **Two references instead of one.** One 2,000-byte file could not hold dedup, proven tree, push and PR plus the rebase and discard mechanics while SKILL.md stays at or under 6,000. `push-and-pr.md` holds Dedup, Push and PR with the policy votes; `branch-ops.md` holds Rebase, Proven tree and Discard. Each has a cap of 2,000 in the test. Several brief pins moved into these files: the dedup command, `headRefOid`, "open no new PR", the proven-tree line, the `wt-new` line, the `gh pr create` line, `kern-dir tmp` and the status listing.
4. **The discard listing adds `--ignored`** (gap 4). The pin reads `status --porcelain -uall --ignored`.
5. **A detached HEAD in the main checkout stops.** The brief offers `git switch -c` there; kern never switches the main checkout's branch. The offer stays for linked worktrees.
6. **Step 2 adds "a worktree the user named" first.** It also keeps only ledger `Worktree:` paths that `git worktree list` still shows, and says which worktree it chose.
7. **The size gate measures against step 4's wt-snap tree**, so untracked files count.
8. **Bytes:**
   - The Inputs table lost its Use column, and its rows are merged.
   - The brief's intro sentence "Every path ends in an outward choice, so this skill is slash only" is dropped. It describes the skill; no behaviour depends on it.
   - SKILL.md sits at 5,970 of 6,000.
9. **The acceptance file has 3 more lines:** the consent stop, gh logged out, and discard with untracked files.
10. **Spec C10 is not edited**, because it is not in the brief's file list. It still says 5,000 bytes, `Bash(git fetch *)`, the old step numbers, a double-quoted title and no consent step. It needs a controller docs commit, as for Tasks 23 and 24.

## NOTICED BUT NOT TOUCHING

- **prove-it tests pin three strings that occur more than once,** so removing one occurrence survives the test:
  - `${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff` (2 times in SKILL.md)
  - `claim: command, result` (2 times in SKILL.md)
  - `zero tests ran` (3 times in references/evidence.md)
- **help's allowed-tools has write vectors:**
  - `Bash(git remote *)` matches `git remote set-url`, `add` and `remove`.
  - `Bash(git log *)` matches `git log --output=<file>`, which writes a file.
  - The same check as for `git fetch` applies to every `Bash(git <sub> *)` rule.
- **Some reads have no guard allow under autopilot:** `git fetch`, `git merge-base`, `git diff`, `git remote get-url` and `git worktree list`. They run unprompted only where the user's permission settings allow them, the same gap commit notes for `git add`. A guard-side read allow is an M3 candidate, as progress.md I1 says.
- **Shared temp files.** `pr-body.md` and commit's `commit-msg` share one path under `.kern/tmp`, so two finish-branch runs in different worktrees at once would overwrite each other's file.
- **Fork branches.** `gh pr list --head <branch>` matches by branch name only, so a fork PR with the same branch name would count in the dedup. G2's own check has the same limit.
- **Unported red-flag rows.** finishing-a-development-branch rows 217, 218, 221, 222, 223 and 224 are not ported; the brief chose the five rows used. The rule from row 222 ("removal refused, `--force`") is enforced in branch-ops.md instead.

## Fix round 1

Status: DONE. SHA `bdcfad5` ("M2: finish-branch handles a published rebase and prove-it no longer loops"), on `main` after the controller's `655125f`. Branch checked: `main`. Paths staged by name. No attribution. Tree clean after the commit.

### Byte counts

| File | Bytes | Cap (in test) |
|---|---|---|
| `skills/finish-branch/SKILL.md` | 6,317 | 6,400 |
| `references/push-and-pr.md` | 2,394 | 2,400 |
| `references/branch-ops.md` | 1,924 | 2,400 |
| `references/discard.md` (new) | 994 | 2,400 |
| `references/pr-body.md` | 1,199 | 2,000 |
| `skills/prove-it/SKILL.md` | 3,683 | 3,800 (raised from 3,600 in the test) |

### Tests: failing, then passing

The pins were updated first, and the run failed for the expected reasons:
```
not ok 1 - finish-branch frontmatter
not ok 2 - finish-branch sections, steps and red flags
  error: 'skills/finish-branch/SKILL.md must contain: `Worktree:` path'
not ok 3 - branch-ops reference: rebase, proven-tree check, discard
  error: 'skills/finish-branch/references/branch-ops.md must contain: If `git rev-parse --verify --quiet origin/<branch>` prints a SHA, the branch is published'
not ok 4 - push-and-pr reference: dedup, push, PR
  error: "skills/finish-branch/references/push-and-pr.md must contain: A PR counts only if its URL is this repo's, ..."
ok 5 - PR body template
ok 6..9 (prove-it, unchanged)
not ok 10 - the gate hands a commit to commit and a push or PR to finish-branch
  error: 'skills/prove-it/SKILL.md must contain: unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step)'
# tests 10
# pass 5
# fail 5
```
After the fixes: `# tests 11`, `# pass 11`, `# fail 0`. The new discard reference added one test.

### Gates

- `node --test 'tests/**/*.test.mjs'`: tests 142, pass 142, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `rank-1 rate: 66% (baseline 0%)`, `route-eval: passed`.
- `claude plugin validate .`: `✔ Validation passed`.

### Mutations

Run on a scratch copy of the repo.
- **Pin removal.** 134 pins were logged. All 126 pins this task owns were killed: 57 in SKILL.md, 18 in branch-ops, 11 in discard, 33 in push-and-pr, 4 in pr-body and 3 for the prove-it gate. The test asserts that each pin occurs exactly once. The same 3 pre-existing prove-it pins survive, because each occurs 2 or 3 times.
- **Swap and removal, 27 of 27 killed.** For each I4 clause:
  - Size gate: removed, and yes/no swapped.
  - "behind above 0 is stale": removed, and 0 changed to 5.
  - "Option 1 ends with the short SHA.": removed, and changed to "goes on to step 9".
  - "An open PR at an older head: push, ...": removed, the push dropped, and "open no new PR" changed to "open a new PR".
  - "If not, run": removed, and changed to "If so".
  - "`ready`: go on.": removed, and changed to "stop".

  Also killed:
  - The rebase "on no, go on" changed to stop.
  - "else G1 denies that push, so go on stale" changed to rebase anyway.
  - The G1 lease clause changed to "allows it".
  - "use the lease push" changed to stop.
  - "Never a plain force." changed in the reference, and in the red flag.
  - "Red: no push." changed to "push anyway".
  - The stale-check removal changed to stop.
  - Discard "never under autopilot" changed to "also".
  - The `!` prefix changed to "run them".
  - gh failing changed to open a PR anyway.
  - The autopilot order reverted to the old sentence.
  - The prove-it "unless" clause removed.
  - `Bash(git rev-list *)` re-added.
- **Structural, 10 of 10 killed.**

### Rulings applied

- **I1.** `Bash(git rev-list *)` is out of allowed-tools, and the test pin is updated. The count command now prompts.
- **I2.** Rebase of a branch already on origin (`branch-ops.md`, section Rebase; `push-and-pr.md`, section Push):
  - If `git rev-parse --verify --quiet origin/<branch>` prints a SHA, the branch is published. The skill warns that a rebase rewrites published commits and that the push becomes the lease push.
  - It offers the rebase only if `git log --format=%ae <baseref>..HEAD origin/<branch>` prints only `git config user.email`. Otherwise G1 would deny the lease push, so the run goes on stale.
  - After the rebase, the push is `git push --force-with-lease origin <branch>`, as its own call.
  - A plain push rejected right after this run's rebase is explained as that rebase, which rewrote published commits; the skill then uses the lease push. Any other rejection means the remote moved.
  - Plain force is never used. The red flag now reads "The remote moved, unless this run rebased. Investigate; never a plain force."
  - Autopilot never rebases, so it never lease-pushes.
  - Replayed against G1 (g01-git.sh 640-690) on a rebased, published worktree branch:

    | Case | Result |
    |---|---|
    | Plain push after the rebase | git rejects it (non-fast-forward) |
    | Lease push of the user's own branch | ask |
    | Same, under autopilot | deny ("lease push under autopilot needs rebase.push: autopilot") |
    | Lease push with another author's commit on the branch | deny ("may hold commits by other authors") |
    | `git push --force` | deny |
- **I3.** prove-it's Gate now reads: "Then, unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step), for a commit, Read ...". The clause is pinned, and the test cap is 3,800.
- **I4.** The six clauses are pinned whole, each exactly once; the swap mutations are listed above.
- **M1.** The check worktree is `wt-new <slug>-check-<sha7> --detach --base <HEAD sha>`. Exit 2 with `path exists` means an earlier run left that check: plain `git worktree remove <path>`, under autopilot too, then wt-new again. SKILL.md's autopilot line names this removal as the one exception to "no teardown runs".
- **M2.** When the plain remove is refused, discard prints `git worktree remove --force <wt>` and `git branch -D <branch>` for the user to type with the `!` prefix. The skill never runs `--force`.
- **M3.**
  - Proven tree: "the tree from finish-branch step 4; commit's own proof is separate". Step 8 says "its proof is its own, apart from step 4's".
  - Stops: "Stray untracked files can park the finish at commit's "no files, no commit" default."
- **M4.** `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *)` and `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)` are added. Both scripts only read: kern-get takes KEY and an optional DEFAULT, and kern-detect takes a key.
- **M5.** The newest ledger is found with `ls -t <dir>/*/ledger.md`, where `<dir>` is what `kern-dir ledgers` prints. The skill takes the first one whose `Worktree:` path is still in `git worktree list`.
- **M6.** "A subject with a backtick, or a `$` before `(`, is reworded for the title without them". The text holds no literal `$(`, so the no-substitution test still holds.
- **M7.** "If wt-new said `worktree.setup` is unset, a red may be the environment: check that before blaming the commit".
- **M8.** Dedup: "A PR counts only if its URL is this repo's (`git remote get-url origin`); check before reporting it."
- **M9.** Autopilot: "the menu resolves to option 3, or the highest option step 7 left: commit, then the dedup check, then the push and PR."

### Deviations

- **A third reference, `references/discard.md`.** branch-ops reached 2,712 bytes with I2, M1, M2 and M7, against a 2,400 cap. Discard is its own rare path, so it moved out, and step 7 points to it. Each reference is capped at 2,400 in the test. No behaviour was dropped.
- **The acceptance file has one more line,** for the stale base on a published branch.

### Noticed but not touching

- The 3 pre-existing prove-it pins that occur more than once. They are unchanged from the first report.
- **The fork false match is only partly fixed.** A fork's PR into this repo also has a URL in this repo, so M8's check catches a gh default-repo mismatch but not a same-named fork branch. Adding `isCrossRepository` to the dedup's `--json` fields would catch it. That changes the spec's pinned command, so I left it.
