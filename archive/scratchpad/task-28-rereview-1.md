# Task 28 re-review, fix round 1 (5aa70ba; ada6462 only touches the spec)

## 1. Status of the earlier findings
- I1 ADDRESSED. skills/recall/SKILL.md:19 (step 7) now needs `tree=` == wt-snap and wt-snap != `git -C <wt> rev-parse HEAD^{tree}`. Pinned.
- I2 ADDRESSED. SKILL.md:17 (step 5): "When the answer hinges on what an agent actually did, read the full transcript region, not a grep line or summary". Pinned.
- I3 ADDRESSED with one wrinkle (N2). SKILL.md:19: "No `Worktree:` line ... rules the tag out: tag from its branch or PR when a branch is known, else [unverified, worktree unavailable]; the next move still comes from the incomplete ledger task."
- I4 ADDRESSED. See section 3.
- I5 ADDRESSED. 31 new pins; 66 sentence deletions on SKILL.md leave 4 survivors, 0 of 17 on chat.md.
- `>` minor: PARTIAL, and the new text is false. See N1 (Important).
- Exit-2 clause ADDRESSED. SKILL.md:15 (see section 4).

## 2. I1 three cases (scratch repo, linked worktree off a main checkout, real wt-snap)
- committed and clean: snap 3be22be... == HEAD^{tree} 3be22be.... Text: equals HEAD^{tree} means committed, tag by branch or PR. Correct.
- uncommitted (untracked file added): snap 755a580... != HEAD^{tree}. If ledger tree == snap: `[verified, uncommitted]`. Correct.
- ledger tree != snap: "tag by its branch or PR, as for a differing tree=". Correct.
Also checked: `git rev-parse --git-common-dir` from the linked worktree returns the main checkout's `.git`, as step 3 says.

## 3. chat.md vs ketchup
Every ketchup rule is present: remembers only last message; notifications and subagent results not user messages; names the user knows; which are running and which could not be checked; action item definition (product choice, approval, irreversible, access); earlier item still waiting counts; self-doable work is not an item, named in one line; count opening sentence; nothing happened, say so and stop; most important first; skip unchanged steps; the five per-item parts; say so instead of guessing; link detail; decide without opening. Lost, acceptable: the voice pointer ("plain voice of /bro"; no equivalent in kern, unslop applies) and "keep this turn read-only", kept as "Read-only." Pins: 17 chat pins hold (test run 180/180). The step 9 pointer "reply with the action-item count first, and stop" is pinned. Bytes: chat.md 1,326 of 2,000; SKILL.md 7,194 of 7,200.

## 4. Fixture and exit 2
- Fixture (ledger with no `Worktree:`): Task 3 is incomplete, next move still named (explicit clause). Tag for the Task 3 thread: "from its branch or PR when a branch is known" and the ledger header line reads `Main: /work/app branch=main`. A literal reader could take `branch=main` as the known branch and tag `[merged #N]` / `[in flight main]`, wrong (see N2).
- Exit 2 "outside a git repository: no live state either, say so and stop": the parenthetical applies to the not-a-repo cause only; a usage-error exit 2 still goes on. Stopping skips no readable WORK files: step 3 runs first and needs `git rev-parse --git-common-dir`, which also fails outside a repo, so WORK cannot be located there (it says "missing WORK is not an error"). The remaining case, `git rev-parse` failing in step 3 outside a repo with no stated action, is Minor (N3).

## 5. Mutations
SKILL.md 66 units, 4 survivors; chat.md 17 units, 0 survivors. Survivors: the intro sentence (scaffolding), "Route." (splitter artifact), and the two halves of the Red-flags row "My work on X means everything this week" / "Keep the topic" (together a ported source red flag; deleting the whole row would likely survive). None else carries load. Minor (N4): pin that row.

## 6. New findings (round authored)
N1 (Important) SKILL.md:17. "G18 denies `>` anywhere in a command, even inside quotes: search with `grep -F`, no redirection" is false as a remedy. Measured through the real hook as kern:investigator: `grep -F -n 'x>y' f | cut -c1-300` DENY, `grep -F -n x\>y f` DENY, while `grep -n 'x.y' f` ALLOW. `-F` has no effect on the guard (it scans the command text). A miner told to use `grep -F` for a `>` topic is denied and stuck. Fix: "a topic with `>` : search the text on one side of it, or replace `>` with `.`" (about same bytes; cap has 6 spare, so swap, do not add), and change the pinned string.
N2 (Minor) SKILL.md:19. "when a branch is known" is not defined for a ledger without `Worktree:`; the header's `Main: ... branch=main` is the only branch there. Fix: "a branch named on the `Worktree:` line or the task" or just drop "when a branch is known" and say: no `Worktree:` line: `[unverified, worktree unavailable]` unless a PR is found by `gh pr list --head`.
N3 (Minor) SKILL.md:13-15. Step 3's `git rev-parse` failing outside a repo has no stated action; step 4's exit-2 clause covers it only later. Optional.
N4 (Minor) tests/skills/recall.test.mjs. Pin the red-flag row "My work on X means everything this week".

Stop rule: no round-0 defect was authored by this round's changes beyond N1, which is an error in new text, not in round 0's code. Round 0's I1 to I5 are all closed. No split signal.

## 7. Gates
- `node --test 'tests/**/*.test.mjs'`: tests 180, pass 180, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: rank-1 83%, passed.
- Repo untouched (`git status --porcelain` empty); scratch HOME used; scratch worktree under the t28 scratchpad.

## Verdict: NEEDS-FIXES (one Important: N1; the rest Minor)
