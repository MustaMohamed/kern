# Task 25 re-review, fix round 1 (bdcfad5, HEAD fe8d7cc)

Verdict: APPROVED. All four Important findings are addressed. No new Critical or Important finding in this diff. Two Minor items stay partial.

Paths are under /Users/musta/Code/projects/kern. The repo was not edited; `kern-dir` was not run there.

## 1. Status of the earlier findings

| Finding | Status | Where |
|---|---|---|
| I1 `git rev-list *` in allowed-tools | ADDRESSED | skills/finish-branch/SKILL.md:5. The frontmatter is now status, rev-parse, `gh pr list`, kern-get, kern-detect. The step 3 count command still names `git rev-list --left-right --count`; it now prompts, as intended. |
| I2 rebase of a published branch | ADDRESSED | references/branch-ops.md:7 (detect, author check, warning); references/push-and-pr.md:15 (lease push, explanation of a rejected plain push); SKILL.md:56 (red flag). Replay in section 2. |
| I3 prove-it loop | ADDRESSED | skills/prove-it/SKILL.md:21. Section 3. |
| I4 survivors | ADDRESSED | tests/skills/finish-branch.test.mjs. Section 5. |
| M1 stale `-check` path | ADDRESSED | branch-ops.md:11 (slug with `<sha7>`, remove a stale path with plain remove, also under autopilot); SKILL.md:46 names the exception to "no teardown". |
| M2 discard dead end | ADDRESSED | references/discard.md:7 prints the `--force` remove and the `branch -D` for the user to type with `!`. |
| M3 stray untracked files and commit's own proof | ADDRESSED | SKILL.md:22 ("its proof is its own"), SKILL.md:46 (parks at "no files, no commit"), branch-ops.md:11 ("finish-branch step 4"). |
| M4 kern-get and kern-detect | ADDRESSED | SKILL.md:5. |
| M5 `ls -t` | ADDRESSED | SKILL.md:16: `ls -t <dir>/*/ledger.md`. |
| M6 backtick in a title | ADDRESSED | push-and-pr.md:19: reword the title without them. |
| M7 bad slug and missing setup | PARTIAL | The `worktree.setup` clause is in branch-ops.md:11. A `<wt>` base name with a space still gives `wt-new: bad slug`, exit 2 (verified). It falls into "any other non-zero exit: report its output and ask; no push", so the run stops cleanly. Rare; no fix needed now. |
| M8 fork false match | PARTIAL | push-and-pr.md:7 checks the PR URL against `git remote get-url origin`. A fork PR into this repo has this repo's URL, so the check does not catch it. In the reverse layout (origin is a fork, gh resolves the parent) it would reject a legitimate PR. Fix in one clause: add `isCrossRepository` to `--json` and ignore PRs where it is true. Harmless today because G2 denies on any OPEN PR. |
| M9 autopilot ordering | ADDRESSED | SKILL.md:46: "commit, then the dedup check, then the push and PR". |

## 2. I2 replay (scratch repo, linked worktree from `wt-new`, local bare origin, gh stub)

Scripts: t25/rr.sh. Votes are from the real hooks/pre-tool-use.

- Published, own commits only: a base move, then the skill's check. `git rev-parse --verify --quiet origin/kern/plan` printed a SHA. `git log --format=%ae main..HEAD origin/kern/plan` printed only `me@x.io`, the same as `git config user.email`. The rebase was run.
- Plain `git push -u origin kern/plan` after the rebase: vote ask; git rejected it (verified). The skill's explanation in push-and-pr.md:15 matches what happened.
- `git push --force-with-lease origin kern/plan`: no autopilot ask; autopilot deny. The skill says autopilot never rebases, so never lease-pushes; consistent. The lease push then ran fine.
- Another author's commit on `origin/kern/plan`: the log printed two emails, so no rebase is offered. If the rebase were run anyway, the lease push is denied by G1 (verified). The skill's "else G1 denies that push, so go on stale" is true.
- No `origin/<branch>`: `git log ... origin/<branch>` fails with "unknown revision", but the skill runs it only after `--verify --quiet` printed a SHA, so that path is not reached. An `origin/<branch>` equal to the base gives only the user's own commits.
- The skill's range is the same as G1's `_g01_own` range (commits on HEAD and on `origin/<branch>` past the base, by `%ae`), so the skill offers a rebase exactly when G1 will allow the push after it. Merge commits are read by author, as in G1; a merge by someone else's email means no rebase, the safe side.
- Not a defect, noted: `origin/<branch>` is the local remote-tracking ref; step 3 fetches only the base. A branch published from another clone is not seen. A lease push would then fail on stale info and fall to the fetch-and-stop rule. Safe.

## 3. I3 entry paths (read as a model would)

- prove-it from the kernel row, "about to commit": the Gate fires, the run is not inside commit or finish-branch, so it Reads commit. Plain "about to push or open a PR": it Reads finish-branch, whose step 1 consent stops an unrequested push.
- From commit step 4: the run is inside commit, so the Gate skips the hand-off. No loop.
- From finish-branch step 4: same. finish-branch step 8 then runs commit steps 2 to 6, whose step 4 reaches prove-it again from inside commit: no loop.
- Only commit and finish-branch name prove-it in their steps (grep of skills and kernel), so there is no third entry path to cover. execute-plan runs commit's steps, so it counts as inside commit.

## 4. M1 and M2 mechanics

- `wt-new plan-check-<sha7> --detach --base <HEAD sha>` exits 0 and prints the path. A second run exits 2 with `wt: path exists: <full path>`. Plain `git worktree remove <path>` removes it, and `wt-new` then succeeds again.
- Discard of a dirty worktree: plain remove exits 128 ("contains modified or untracked files, use --force"). The printed `git worktree remove --force <wt>` then works when typed, and `git branch -D kern/plan` follows. Order is right (the branch is checked out until the worktree is gone), and the session is in the main checkout at that point.

## 5. Mutations

Scratch copy of fe8d7cc (t25/kc2). Baseline 11 of 11 pass. 19 mutations, all killed (`# fail 1` each):
- The six I4 survivors: size yes/no swap, stale threshold, option-1 SHA, open PR at an older head without a push, "If so, run", `ready` stops.
- New logic: author check loosened, published test inverted, autopilot lease sentence removed, lease vote changed to allow, discard force run by the agent, stale-path remove made `--force`, slug without the SHA, gate exception removed, autopilot stale-removal exception removed, `ls -t <dir>`, `git rev-list *` back in the frontmatter, rejected-push explanation removed, rebase on another author's commits.
- A 20th "control" edit had a wrong phrase (not applied), so it is not counted.

## 6. New findings in this diff

No Critical or Important. Minor only:
- The rebase check runs `git config user.email` and `git log`, neither in allowed-tools, so each prompts. One extra prompt on a rare path.
- The M7 and M8 remainders above.

## 7. Gates (HEAD fe8d7cc)

- `node --test 'tests/**/*.test.mjs'`: tests 142, pass 142, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `route-eval: passed`.
- Bytes: SKILL.md 6,317 of 6,400; push-and-pr.md 2,394 of 2,400; branch-ops.md 1,924; discard.md 994; prove-it 3,683 of 3,800. No `$(` or curly quotes found (lint clean).
- The repo working tree was clean after the run.

## Commands run
- `bash t25/rr.sh`: published-branch rebase, plain and lease push votes with and without autopilot, another author, absent `origin/<branch>`.
- `wt-new plan-check-<sha7>` twice, `git worktree remove`, dirty-worktree remove with and without `--force`, a space-in-name worktree.
- `bash t25/mut.sh` (mutations through `rep.mjs`; my first attempt used python3, which failed with "Bad CPU type", so the results above are from the node rerun).
- The three gates above.

APPROVED
