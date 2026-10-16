# Task 24 report: commit skill

Status: DONE_WITH_CONCERNS (byte cap raised to 5,200; see Deviations)
SHA: 09ead60 (on main, BASE 64c18f4)
Bytes: skills/commit/SKILL.md = 5,196 (cap 5,200; spec says 4,200)

## Tests
Failing first (`node --test tests/skills/commit.test.mjs`): `# pass 0`, `# fail 2`, both `error: 'skills/commit/SKILL.md exists'`.
Passing after: `# pass 2`, `# fail 0`.

## Gates
- `node --test 'tests/**/*.test.mjs'`: tests 134, pass 134, fail 0
- `node scripts/lint-skills.mjs`: `lint: clean` (first run had rule 6, missing map row; fixed by the map row)
- `node scripts/route-eval.mjs`: `rank-1 rate: 66% (baseline 0%)`, `route-eval: passed`
- `claude plugin validate .`: `Validation passed`
- hooks bats not run, as told.

## Mutations
33 pin removals on a scratch copy, each deleting every occurrence of one pinned string: 33 killed, 0 survived. Pins checked for uniqueness: each occurs exactly once (the brief's `detached HEAD` occurred twice; pin changed to `On a detached HEAD, stop:`). Negative asserts: no `$(`, no `temp file`. Frontmatter equality, step count 8 and h2 list are checked by the other asserts.

## Gaps
1. Package path. A task's final package is `<ledger dir>/reviews/task-<N>-<tree7>.diff`, tree7 = first 7 chars of `tree=` on its `Task N: complete` line. Verified: execute-plan step 8 names `task-N-<tree7>.diff`, step 10 says "after fix rounds, remake `<package>` from `tree-before`" so the complete tree names the whole-task package, ledger-format.md lists `tree=<id>` on the complete line. Fix-round packages (`task-N-fix<r>-...`) hold only the fix diff and are not used. `<ledger dir>` is a dir under `kern-dir ledgers` whose ledger's `Worktree:` line names `<toplevel>`. Missing file: run `git -C <toplevel> diff --name-only <start tree> <complete tree>` with the trees from the task's `start` and `complete` lines (trees are unreferenced objects, kept about two weeks); if that fails too, ask for the files (autopilot: park, commit nothing for that task).
2. Overlap. Step 3 detects tasks whose file lists share a path, says they cannot be split by path, offers one commit naming each, or asks, and never stages a file holding another task's hunks under one task's name. Autopilot default when parked: one commit naming each task. The skill says execute-plan step 10 commits right after each task closes, so overlap only arises in a later `/kern:commit`.
3. Where the commit runs. Every git call is `git -C <toplevel> ...`; `<toplevel>` = `git -C <wt> rev-parse --show-toplevel`, `<wt>` the worktree the caller names (execute-plan: plan worktree), else `.`. Checked against g05-commit.sh: `_g05_split` takes `-C` pairs; `_G05_CROSS` stays 0 when the target's `kern_main_root` equals `KERN_MAIN` (any worktree of the repo); `_G05_PLAIN` stays 1 with only `-C`; `_g05_file_ok` takes the absolute `-F` path, which `_gh_file_ok` accepts under main's `.kern`; branch and protection are read from `_G05_DIR` (the plan worktree), as wanted. So `git -C <wt> commit -F <abs path under main .kern/tmp>` is allowed as its own call. This is a code reading; no bats run. Existing bats line 220 expects the same `-C` shape for `-m`. Pin changed from `git commit -F <dir>/commit-msg` to `git -C <toplevel> commit -F <dir>/commit-msg`. Task 26's ship-commands.bats should pin the `-C <abs worktree>` form.
4. allowed-tools. Every prescribed git call is `git -C`, and `Bash(git status *)` does not match `git -C x status`, so I replaced the unprefixed git patterns with `Bash(git -C * status *)`, `diff`, `log`, `rev-parse` (all read-only). That covers `git rev-parse` too. No `git add` or `git commit`. Test updated.

## Other decisions
- Steps 3 to 6 stay a unit for execute-plan step 10 and finish-branch step 7; the intro says so.
- Proof runs once before the first commit, on the working tree; the HEAD^{tree} check applies after the last commit only (earlier per-task commits cannot equal the whole snapshot).
- Message file: Write needs a Read first if `commit-msg` exists, so step 6 says to Read it first.
- Exits: consent, branch, files, proof (steps 1 to 4), `kern-dir` exit 2, `wt-snap` failure, G5 deny or ask, failed `git add` or `git commit` all stop and report; never `--no-verify`, never another command shape. Autopilot parks as `parked: <question>; default: <choice>; why: <one line>`; a protected branch or detached HEAD never commits. Approvals are typed replies, never AskUserQuestion. Autopilot wording copied from execute-plan.

## Deviations
- Cap: 5,196 bytes, above the spec's 4,200, within the 5,200 you allowed. To fit I dropped two of the brief's five red-flag rows ("git add -A is quicker", "The message does not matter"; step 3 and G5 already carry the first) and shortened others. Say if you want them back.
- Frontmatter allowed-tools differs from the brief (gap 4).
- Pin changed (gap 3); extra pins added for gaps 1 to 4 and the autopilot lines.
- Inputs table has two columns (Key, Default) and merges `commit.attribution` with `commit.policy`, to fit the cap.
- Commit message body mentions `git -C`; no attribution added.
- Added acceptance rows: overlap, missing package, run from main checkout, autopilot on protected or detached.

## NOTICED BUT NOT TOUCHING
- docs/specs/2026-10-12-kern-m1-m2-skills.md C9 still holds the old step 3 and 6 text, the 4.2 KB cap and the old frontmatter; earlier tasks updated the spec in a follow-up commit, so one is due here.
- `kern-dir`, `wt-snap` and `kern-dir ledgers` are not in allowed-tools, so they prompt (kern-dir writes `.git/info/exclude` and creates dirs).
- Batched tasks share one package; its file name's tree7 comes from one task's tree, so for batched tasks the fallback `git diff --name-only` path is what actually applies.
- A started but incomplete task may hold hunks in a file a complete task also lists; step 3 does not detect it (only complete tasks are compared).
- execute-plan step 10 says "steps 3 to 6" but step 2 (`<toplevel>`) is needed first; step 3 onward uses `<toplevel>`. Execute-plan should pass its plan worktree and run step 2's toplevel and branch checks too.

## Fix round 1
Commit message: "M2: commit stages ledger tasks by their exact paths and states what is proven". SHA in the message to the lead.
- I1: the four `git -C * <verb> *` allowed-tools rules are gone; only kern-get and kern-detect remain. The git reads (status, diff, log, rev-parse) will prompt.
- I2: stated in Stops: no kern guard allows `git add`; under autopilot it runs unprompted only where the user's permission settings allow it, else its prompt is a stop.
- I3: intro and execute-plan step 10 (plus its test) say "steps 2 to 6". execute-plan stays 12,229 bytes (cap 12,400).
- I4: step 4 says several commits get one proof on the working tree, commits before the last are not proven alone, and the report says so; the red-flag row reads "Prove the tree you commit; several commits get one proof."
- I5, I6, M3d: in references/ledger-tasks.md (name-status parsing, both paths of a rename, started-task paths from briefs/task-N.files, several ledgers ask, already committed).
- M3a to c: G5 "asks and the user declines"; a failed `rev-parse --show-toplevel` stops; defaults list no files, failed toplevel, protected branch, detached HEAD: commit nothing.
- M1: pins added for each; 53 pin removals across SKILL.md and the reference on a scratch copy, 53 killed, no pinned string twice.
- M4: acceptance bullet reworded; rows added for rename, started-task overlap and two ledgers.
- Bytes: SKILL.md 4,899 (cap 5,200), ledger-tasks.md 1,732 (cap 2,000).
- Gates: 135/135 tests, lint clean, route-eval passed, plugin validate passed.
