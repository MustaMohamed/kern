# Task 23 re-review, fix round 1 (60153a9, head 64c18f4)

Scope: `review-f0d684e..60153a9.diff` plus the spec cap commit. Mode: re-review.

## 1. Earlier findings

| Id | Status | Where |
|---|---|---|
| I1 scope_threshold default | ADDRESSED | `skills/self-review/SKILL.md:35` row `scope_threshold | 4 files`; `:30` "exit 3 takes the table default"; pinned. |
| I2 probe exit 3 and skip lines | ADDRESSED | SKILL.md:21 (step 7) "exit 1, 2 and 3 each fail the check; exit 3 reported inconclusive"; step 9 "a failed or unrun check (step 2 or 7)"; "A lane skip line ... does not change the verdict". Matches the ruling. |
| I3 no verdict on stale base | ADDRESSED | SKILL.md:12 (no origin remote: local `<base>`), step 9 `rebase first` "or 'base not refreshed' is reported". Stops section: failed fetch goes on only "(origin exists)". |
| I4 split trigger | ADDRESSED (see N2 for a gap in how counts are taken) | SKILL.md step 9 `split`: later round, package over `scope_threshold` paths and previous not, or a finding in an added line of the since package; "a first round never splits". `references/rounds.md` names packages and the since package. |
| I5 order and hidden rebase need | ADDRESSED | Step 9: "tested in order: `split`, `fix first`, `rebase first`, else `ready`"; "If `fix first` wins, still report a rebase need". |
| M1 `<test>` placeholder | ADDRESSED | Step 7: `{file}` or `{dir}` replaced by the one test file, no shell syntax. |
| M2 whole-branch probe overclaim | ADDRESSED | Step 7 and `references/claim-checks.md:15` reworded to "branch's non-test changes reversed"; points single-guard proof to implement. `skills/implement/SKILL.md:21` does carry a probe step, so the pointer is real. |
| M3 `--mutate` semantics | ADDRESSED | Step 7: file relative to `<wt>`, line from the working file, first operator inverted. |
| M4 wt-diff other exits | ADDRESSED | Step 1 "any other non-zero exit stops and reports"; Stops "any `wt-diff` non-zero exit end the run". |
| M5 taxonomy order, spec-lane mapping | ADDRESSED | Step 9 "(ordered high to low)", "(the spec lane's Critical and Important count)". |
| M6 | closed by ruling, no change | |
| M7 upstream losses | PARTIAL | Restored: "never make up a caller or an API", "Paste what happened" (`blast-radius.md`), adversarial wording incl. "say explicitly when no fault turns up" (`doubt-cycle.md:12`). Still absent: upstream "stop on the user's ship it" and the "what it does" output item. Low impact; accept. |
| M8 doubt theater under autopilot | ADDRESSED | `doubt-cycle.md:25` "under autopilot, park it as a `parked:` line". |
| M9 pins on verdict definitions | ADDRESSED | Test pins now cover split, fix first, rebase first, order, skip rule, Inputs row, probe exits. Of 21 SKILL.md removal mutations, 20 caught; the one miss (`remote get-url origin` with backticks) was my malformed needle: the real pin `git -C <wt> remote get-url origin` exists. |

## 2. rounds.md walked by hand

Scratch repo: `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t23/rounds`, branch `feat/x-y` from `main`, `CLAUDE_PLUGIN_ROOT=/Users/musta/Code/projects/kern`. I scripted the text as written: slug from `rev-parse --abbrev-ref HEAD` with `/` to `-`, `kern-dir reviews` run in the worktree, highest numeric N from `<slug>-<N>.diff`, `wt-diff <wt> <merge-base> --out <reviews>/<slug>-<N>.diff`, previous tree from line 1 after `..`, `wt-diff <wt> <previous-tree> --out <slug>-<N>-since.diff`.

- First run, branch with `/`: slug `feat-x-y`, no previous, package `.kern/reviews/feat-x-y-1.diff` plus `feat-x-y-1.diff.patch`, wt-diff exit 0, no since package. Correct.
- Second run after a fix commit: previous 1, package `feat-x-y-2.diff`. Line 1 of package 1 gave `previous-tree=85e08899d4ae` (12 hex). `git rev-parse --verify 85e08899d4ae^{tree}` resolved to the full tree id. Since package `feat-x-y-2-since.diff` listed only `b.txt` and `c.txt` (what changed after round 1); exit 0. Correct.
- Third run with no change: package 3 written, previous 2, previous tree resolved, since wt-diff exit 3 ("empty diff"), no since file. rounds.md says "exit 3 means nothing did". Correct.
- Detached HEAD: slug `detached`, `detached-1.diff`, independent of the branch files. Correct.
- `-since.diff` never counts as a package: with the listing `feat-x-y-1.diff, -2-since.diff, -2.diff, -3.diff` plus `.patch` files, the pattern `^<slug>-[0-9]+\.diff$` selected only 1, 2, 3 (highest 3). The `.patch` files and since files do not match. Also `kern-dir reviews` holds wt-diff's default-named packages (`<tree7>..<tree7>.diff`), which do not match either.
- Slug collisions: `a/b` and `a-b` both give `a-b`, so they share one counter and one "previous". Detached work on unrelated commits also shares `detached`. A branch `feature` does not collide with `feature-2` (`feature-2-1.diff` fails the all-digits test). Matters only when two such branches are reviewed in one repo: the previous tree then comes from the other branch (it resolves, since trees are in the one object store), the since package is large and unrelated, and `split` can fire or not fire wrongly. Rare, and the damage is a wrong `split`, which finish-branch stops on and the user can read. Minor (N1).
- Snapshot trees are not referenced by any ref (`wt-snap` is a temporary index and `write-tree`). A previous tree built from uncommitted work is a dangling object, kept by default for two weeks. After a prune, the since `wt-diff` exits 2 ("not a tree"); rounds.md gives no action for that (N3).

## 3. Verdict order and base handling

- Order: split, fix first, rebase first, else ready is stated once, in that order, and pinned. The earlier list-order confusion is gone.
- `fix first` winning still reports a rebase need (SKILL.md step 9, pinned).
- No remote: `git -C <wt> remote get-url origin` exits 2 on a repo with no origin (run). `<baseref>` is local `<base>`; `git rev-parse main`, `merge-base HEAD main` and `diff --name-only <merge-base> main` all ran with no `$(...)` in the skill text. Works.
- Caveat on that path: `kern-detect base_branch` exits 3 on a repo with no `origin/HEAD` (run). So with no remote and no `base_branch` setting the skill asks, and under autopilot "A missing base ... end the run". That is the stated behaviour and consistent, but a no-remote repo always needs `base_branch` set (N4, Minor, docs only).

## 4. Exit actions and dropped behaviour

- wt-diff main run: 0, 3, other stated. floor-scan and claim-check: 1 hits, other failed. probe: 1, 2, 3 each fail the check. kern-get exit 3 takes the table default; both exit 3 asks. Fine.
- Gaps (all Minor): the since `wt-diff` in rounds.md has only exit 3 (N3); `kern-dir reviews` exit 2 (tracked work dir) and a failing `rev-parse --abbrev-ref` have no action in rounds.md (N3).
- Dropped to fit 7,000: I compared against the f0d684e version. Gone: the step 6 phrase "push the one fact down to 'ran it'" became "prove the one fact it is safe because of" (the ladder in blast-radius.md still says it); the "a trade-off is kept and listed" autopilot clause (already absent before this round). Neither is a gate. Nothing load-bearing lost. SKILL.md 6,995 of 7,000, rounds.md 1,173 of 1,400, claim-checks.md 1,684 of 1,700, doubt-cycle 2,308 of 2,400, blast-radius 1,927 of 2,600.

## 5. New findings in this diff

No Critical or Important.

- N1 (Minor) `references/rounds.md` Package names: slugs collide for `a/b` vs `a-b` and for every detached run. Suggest `detached-<short HEAD sha>` and accepting the `/` collision, or documenting it.
- N2 (Minor) SKILL.md step 9 `split`: "this package has more than `scope_threshold` paths and the previous one did not" never says how to count the previous package's paths. Its `## Files changed` list or `<slug>-<N>.diff.patch` gives it; one clause fixes it. Also, round 2 growth from continued feature work (not fixes) counts as `split`; acceptable as a size gate, but worth knowing.
- N3 (Minor) rounds.md exits without actions: since `wt-diff` exit 2 or other; `kern-dir reviews` exit 2; detached/rev-parse failure. Suggest "any other non-zero: no since package, say so, `split` cannot use it".
- N4 (Minor) No-remote repos need `base_branch` set because `kern-detect` reads `origin/HEAD`.
- N5 (Minor) Pins on rounds.md are shallow. Removing "with `/` written as `-`", "with N all digits", "The package with the highest N", "exit 3 means nothing did" or the `-since` naming sentence passes the tests (5 of 7 needles missed; `detached` and the first-line `<N+1>` pins hold). The numeric-highest rule is the likeliest to be misread (lexical sort puts 9 above 10).

## 6. Gates and mutation sample

- `node --test 'tests/**/*.test.mjs'`: tests 132, pass 132, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `route-eval: passed` (rank-1 rate 66%, baseline 0%).
- Removal mutations on a `git archive HEAD` copy under `t23/copy2`: 28 needles (21 in SKILL.md, 7 in rounds.md); SKILL.md 21 caught (one my own needle typo, real pin present), rounds.md 2 caught and 5 missed (N5).
- Side effects: the scratch repo's `.kern/` lives under the scratchpad only. In the kern repo I ran no `kern-dir`; `git status --short` is clean and there is no `.kern/`.

## Verdict: APPROVED

All five Important and all nine Minor findings are addressed or accepted. The five new items are Minor and may be fixed in the next touch or left.
