# Task 25 review: finish-branch and the prove-it hand-off (ea78a51)

Spec verdict: compliant, with spec drift to record (listed under Spec drift).
Quality verdict: needs-fixes. No Critical findings. Four Important.

All paths are under /Users/musta/Code/projects/kern. Nothing in the repo was edited; `.kern/` was not created there.

## Critical

None.

## Important

### I1. `Bash(git rev-list *)` in allowed-tools lets a prompt-free call truncate any file
- skills/finish-branch/SKILL.md:5; the pin at tests/skills/finish-branch.test.mjs:27; spec C10 frontmatter.
- Failure: `git rev-list --output=/path/to/file HEAD` matches the rule and runs unprompted. Verified in scratch: it created the file at 0 bytes, and an existing file is truncated the same way. Text injected through a PR body or a repo file could aim this at `~/.zshrc` or a hook script. This is the same class as the `fetch --upload-pack` hole the implementer closed. A `*` after the subcommand does not stop options, and no narrower `rev-list` pattern can, because `--output=` can sit in the middle of the `*`.
- Checked and clean: `git rev-parse *` (no write option; `--output=` is echoed back as text), `git status *` (`--output` is rejected), `gh pr list *` (only `--web` opens a browser).
- Fix: drop `Bash(git rev-list *)`. The one count command then prompts. Update the test pin and spec C10 frontmatter. Apply the same check to help's `git log *` (already in the report's Noticed list).

### I2. Rebasing a branch that is already on origin ends in a rejected push, with the wrong diagnosis
- skills/finish-branch/SKILL.md:17 (step 3), references/branch-ops.md:7 (Rebase), references/push-and-pr.md:15 (Push).
- Failure: the skill's own open-PR-at-an-older-head path (push new commits to an existing PR) combined with a stale base offers a rebase. The user says yes. Step 9 then pushes, and git rejects the push because history was rewritten. Reproduced in scratch: "tip of your current branch is behind". The skill tells the reader "the remote moved", then "never force". The run is stuck, and the user is never told the rebase caused it. Under autopilot there is no rebase, so only the typed path is hit.
- Fix: before proposing a rebase, run `git rev-parse --verify origin/<branch>`. If that ref exists, say in the proposal that the push will then need `--force-with-lease`, and offer the rebase only with that warning. Or state in Push that after a rebase a rejected push means rewritten history, and ask for the lease push as its own G1 prompt. Do not hide it behind "the remote moved".

### I3. prove-it's Gate line makes a loop with its two callers
- skills/prove-it/SKILL.md:21; commit/SKILL.md step 4; finish-branch/SKILL.md:18 (step 4).
- Failure: finish-branch step 4 and commit step 4 both say "follow prove-it". prove-it's Gate then says to Read commit or finish-branch "and follow its steps". A reader inside finish-branch step 4 is sent back to finish-branch step 1, and a reader inside commit step 4 back to commit step 1. The line is verbatim from the brief, so the plan has the defect. A model may notice and skip it, but the text is wrong as written.
- Fix: scope the hand-off to a run not already inside those skills, for example "Then, unless you came here from that skill, for a commit ...". The test at tests/skills/prove-it.test.mjs pins only the two Read strings, so it still passes. The prove-it byte cap is 3,600 and the file is 3,582, so the wording must be 18 bytes or fewer longer, or the cap rises.

### I4. Tests pass under mutations that change load-bearing behaviour
Run on a scratch copy of HEAD (`t25/kc`) with `finish-branch.test.mjs` and `prove-it.test.mjs`. Each mutation replaced one phrase.

| Mutation | Result |
|---|---|
| size gate "stop on yes, go on on no" swapped | survives |
| "behind above 0 is stale" changed to "above 5" | survives |
| "Option 1 ends with the short SHA." deleted | survives |
| open PR at an older head: "push, report its URL, and open no new PR" changed to no push | survives. This is the headline fix of the commit; only "open no new PR" is pinned |
| Dedup "in any state" changed to "if open" | killed |
| proven-tree "If not," changed to "If so," | survives. Only the left half of the sentence is pinned |
| `ready`: go on changed to stop | survives |
| consent "Otherwise stop." changed | killed |
| "Red: no push" changed to "Red: push" | killed |
| "Red, or wt-snap failing: stop." changed to go on | killed |

- Fix: pin whole clauses, each once: `go on on no`, `behind above 0 is stale`, `push, report its URL, and open no new PR`, `If not, run`, `` `ready`: go on ``, `Option 1 ends with the short SHA`. The pr-body test has only 4 pins.

## Minor

- M1. A kept `-check` worktree blocks the next run (branch-ops.md:11; SKILL.md:46). Under autopilot the check worktree is kept with no teardown. The next run's `wt-new <slug>-check` exits 2 "path exists", and the run parks again with no hint. Fix: add the short HEAD SHA to the slug, or say that a path left by an earlier run is removed with plain `git worktree remove` first.
- M2. Discard on a dirty worktree cannot finish (branch-ops.md:3 and :19). The user types `discard` after the listing of what will be lost, then plain `git worktree remove` refuses because of modified or untracked files, and the run stops. The common discard case therefore ends in a manual step. The no-`--force` rule is consistent with worktrees.md, whose five conditions need a `wt-apply` that a discard never has; G1 also asks on `--force`. Fix: when the remove is refused, tell the user the exact `git worktree remove --force <wt>` to run themselves (typed with `!`), or ask for a second typed word. Upstream superpowers says "show and ask" here, not "never".
- M3. "Nothing to commit when `git status --porcelain` prints nothing" (SKILL.md:22). Stray untracked files make it non-empty, so commit's step 3 runs; under autopilot its default is "no files, no commit", which parks the whole finish. This is a safe failure, but a normal autopilot run can end here. Also, commit's step 4 runs `verify.fast` again and records its own wt-snap. branch-ops.md:11 says "the tree from step 4"; say "finish-branch step 4 (`test.full`), not commit's".
- M4. allowed-tools omits `kern-get` and `kern-detect`, which commit allows. The skill reads about ten keys, so a typed run prompts about ten times. Also `git worktree list`, `git remote get-url`, `git merge-base` and `git diff --shortstat` prompt; the report already lists this as the M3 guard-read candidate. Add the two kern scripts, as commit does.
- M5. Step 2 "newest `ledger.md` (`ls -t`)" (SKILL.md:16) has no command. `ls -t <dir>` orders the ledger directories by directory mtime, not by `ledger.md`. Name it: `ls -t <dir>/*/ledger.md`.
- M6. push-and-pr.md:19 forbids a backtick or `$(` in the title but gives no action when `commit.convention` subjects hold backticks (common in conventional commits). Say "reword the title without them". I confirmed all of these titles allow under autopilot: `;`, `|`, `&&`, `#`, `$HOME`, `>`, `*`, `'` as `'\''`, `"`, `\`. A backtick denies.
- M7. `wt-new <slug>-check` takes `<slug>` from the base name of `<wt>` (branch-ops.md:11). A name with a space or a leading dot gives exit 2 "bad slug", and the run asks. A fresh check worktree also has no deps when `worktree.setup` is unset, so a red check can be an environment failure. "Name what the commit left out" would then mislead. Suggest one clause: check `worktree.setup` before blaming the commit.
- M8. Fork false match (the noticed item): `gh pr list --head <branch>` matches by branch name only. A same-named fork PR would make the skill report an unrelated URL and skip the PR, or stop if its head SHA matched. G2 denies on any OPEN PR for the branch anyway, so no outward action is worse. It matters little. One word in the report line ("check the URL is yours") would do.
- M9. SKILL.md:46 says the menu resolves to 3 "after the dedup check", but dedup is step 9, after the step 8 commit. Under autopilot a commit can be made and then the run stops on "PR at this head". Harmless (nothing outward), but the sentence reads as if dedup came first.

## Answers to the specific checks

### 1. Outward-path replay (real hooks/pre-tool-use, linked worktree, local bare origin, gh stub)
Scratch: /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t25/replay.sh. The worktree came from the real `wt-new`; the body file sat under the main `.kern/tmp`, as `kern-dir tmp` prints. Votes below are from the worktree as cwd unless noted.

| Command | no autopilot | autopilot |
|---|---|---|
| `cd <wt>` | none | none |
| `git push -u origin kern/plan` | ask | allow |
| same, with push.policy deny / auto | deny / allow | n/a |
| `git push -u origin main`, from the main checkout and from the worktree | ask | deny |
| `gh pr list --head ... --state all --json ...` | none | none |
| `gh pr create --draft --title 'M2: fix' --base main --body-file <abs>/pr-body.md`, no PR | ask | allow |
| same, title `'M2: don'\''t break'` (apostrophe) | ask | allow |
| same, PR OPEN for the branch | deny | deny |
| same, only a MERGED PR | ask | deny |
| same, gh failing | ask | deny |
| same, pr.policy deny / auto | deny / allow | n/a |
| `gh pr ready 1` | ask | deny |
| `git branch -D kern/plan` (from main) | ask | deny |
| `git worktree remove <wt>` and `<wt>-check` | none | none |

- Autopilot reaches a draft PR with no ask: yes, when no PR exists for the branch. Autopilot never reaches a PR for a branch with a merged or closed PR; the skill says push only (push-and-pr.md:10), which matches this.
- A push of a protected branch is not denied without autopilot: it asks. Under autopilot it is denied.
- The `draft-after-approval` default reads as ask. The skill's lines match the hooks.

### 2. Proven-tree rule
- Verified with the real `wt-snap`. With an untracked `.env.local` left out of the commit, the snapshot differs from `HEAD^{tree}`. With it removed, the two trees match exactly. Ignored files are in neither.
- A mismatch sends the run to `wt-new <slug>-check --detach --base <HEAD sha>`. A 40-hex SHA is taken as a commit with no fetch, so the proof runs on the exact HEAD. A second `wt-new` of the same path exits 2 (see M1).
- Teardown: plain `git worktree remove` refuses on untracked files (exit 128, verified) and succeeds on ignored ones. Both outcomes are covered by the skill. Safe.

### 3. Dedup
Every case in the brief is stated in push-and-pr.md:7-11 and matches the hooks, except the I2 rebase path above. The red flag at SKILL.md:53 repeats it where a reader acts. "Merged or closed only": non-autopilot pushes then asks, and G2's own ask is the second confirmation. Autopilot pushes only, and G2 denies a create anyway. The report's wording ("push and no PR") is right. Fork false match: M8.

### 4. Autopilot defaults
- Going on past a stale base with the PR body's Merge danger recording it: consistent with self-review (`rebase first` is advice; self-review never rebases) and with commit's stops.
- Going on past the size gate with Scope giving the size: consistent. self-review's `split` is a different, later-round condition and still stops.
- Can an autopilot run push an unproven tree? Only through the step 10 compare. A tree changed by self-review fixes, by commit, or by a partial stage differs from the step 4 snapshot, so the check runs. A failed `wt-new` or a red check parks with no push. No path found that pushes unproven. The compare is an instruction, not a hook, so a reader who skips it is not stopped; I1 to I4 aside, that is the design limit.

### 5. Discard
- `--ignored` is right: a plain remove deletes ignored files but refuses on untracked ones (both verified), so the list should name them.
- The no-`--force` rule is consistent with worktrees.md (the first of its five conditions needs a `wt-apply`). Its cost is M2.
- It stops in the main checkout, and the autopilot paragraph says nothing is discarded. G1 denies `branch -D` under autopilot anyway.

### 6. allowed-tools
See I1. `git fetch` was rightly dropped. `rev-parse`, `status` and `gh pr list` hold up; `rev-list` does not.

### 7. Deviations
- Two references, the dropped intro sentence and the dropped Use column: no behaviour lost. The Inputs table still gives every key and default.
- Main-checkout detached HEAD stops: correct. The rule that kern never switches the main checkout's branch wins, and a linked worktree keeps the offer. The stop does not say what the user can do instead; adding "run `/kern:finish-branch` from a worktree" would help.
- Ledger paths are now filtered against `git worktree list`, and "a worktree the user named" comes first: better than the spec text.
- The unported upstream red-flag rows are all outside this skill's scope. The removal-refused row is covered by branch-ops.md; see M2 for the cost.

### 8. Gates
Run on HEAD (655125f):
- `node --test 'tests/**/*.test.mjs'`: tests 141, pass 141, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `rank-1 rate: 66% (baseline 0%)`, `route-eval: passed`.
- No curly quotes, long dashes or arrows in the new files; no `$(` in any skill file.
- Byte counts: SKILL.md 5,970 of 6,000; branch-ops.md 1,990 and push-and-pr.md 1,856 of 2,000; pr-body.md 1,199. SKILL.md has 30 bytes of room, so I2's fix must go in a reference or trade bytes.

## Spec drift to record (docs/specs/2026-10-12-kern-m1-m2-skills.md, C10)
- Step 2 says "else `git worktree list`"; the skill says "a worktree the user named, else a ledger path still in the list, else the toplevel", and stops in the main checkout on a detached HEAD.
- Step 7's discard listing has no `--ignored`.
- Frontmatter still lists `git rev-list *` (I1).
- Step 6 says size is a stop; under autopilot the skill goes on and records it.

## Commands run
- `git rev-parse --abbrev-ref HEAD` in the kern repo: `main`. No git state changed.
- `bash t25/replay.sh` (hooks/pre-tool-use with a gh stub, a real linked worktree from `wt-new`, a local bare origin): the vote table above.
- Title sweep through the hook under autopilot: 10 titles, all allow; a backtick title denied.
- Policy sweep (push.policy deny and auto, pr.policy deny, auto and default): matches the table.
- `git rev-list --output=<file> HEAD` in a scratch repo: wrote a 0-byte file. `git rev-parse --output=...`, `git status --output=...`: no write.
- `wt-snap` before and after a partial commit; `wt-new <slug>-check --detach --base <sha>` twice (exit 0, then 2); `git worktree remove` with an untracked file (exit 128) and with an ignored dir (exit 0).
- Rebase of a pushed branch then `git push -u origin kern/plan`: rejected.
- Mutation sample on a scratch copy of HEAD: 10 mutations, 6 survived (table in I4).
- `node --test 'tests/**/*.test.mjs'`, `node scripts/lint-skills.mjs`, `node scripts/route-eval.mjs`: results above.
