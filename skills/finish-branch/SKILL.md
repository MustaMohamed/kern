---
name: finish-branch
description: "Finish a branch: verify, self-review, check base and size, then offer commit, push, draft PR or keep."
disable-model-invocation: true
allowed-tools: Bash(git rev-parse *), Bash(git symbolic-ref -q --short HEAD), Bash(gh pr list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# finish-branch

Integrate finished work the user's way. A failure no step handles stops the run: report its output.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Consent: the user typed `/kern:finish-branch` or asked for a push, PR, release, tag or version bump in this session, or autopilot is on. Otherwise stop. Asked to tag a merged release: `references/release.md`, section After the merge, instead of steps 2 to 11.
2. Find the work: a worktree the user named, else the newest ledger whose `Worktree:` path is in `git worktree list` (`ls -t <dir>/*/ledger.md`, `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers` prints), else `git rev-parse --show-toplevel`; say which. Run `cd <wt>` as its own call: G1 and G2 judge by the session's directory. `git rev-parse --path-format=absolute --git-dir --git-common-dir` printing one path twice is the main checkout. `git symbolic-ref -q --short HEAD` prints the branch; exit 1 means detached: in a linked worktree, offer "create branch <name from branch.pattern> here" (`git switch -c <name>`) and go on only after it; in the main checkout, stop: kern never switches its branch. A protected branch: stop; ask which worktree; for a release, offer a release branch per `references/branch-ops.md`.
3. Base: `<base>` is `base_branch`. `git remote get-url origin` failing means no remote: `<baseref>` is local `<base>`. Else `<baseref>` is `origin/<base>` after `git fetch origin <base>`; if that fails, report "base not refreshed" and ask to use the last fetched one. `git rev-list --left-right --count <baseref>...HEAD` prints behind, then ahead; behind above 0 is stale: offer a rebase per `references/branch-ops.md`.
4. Prove `test.full` here by following `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`, then record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`. Red, or `wt-snap` failing: stop.
5. Read `${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md` and run it on `<wt>`. Comment hygiene: `skip: no-comments ships in M3`. `fix first`, `split` or no verdict: stop with its report. `rebase first`: handle it as step 3's stale base. `ready`: go on.
6. Size gate: `git merge-base HEAD <baseref>`, then `git diff --shortstat <merge-base> <tree>` (step 4's tree, so untracked files count). Always run it, even after self-review listed the files: `pr.max_lines` reads its line count. The count is insertions plus deletions in every changed file, tests included; with `pr.size_command` set, run it in `<wt>` with `{base}` as `<merge-base>` and `{tree}` as `<tree>`, and the last number it prints is the count instead (it fails or prints none: say so, keep the shortstat count). Name the count you compare, as `lines: <n> (<measure>)`. Files changed above `scope_threshold`, or a count above `pr.max_lines`: propose a split alone, no menu before it is answered; stop on yes, go on on no. A `Decision:` line in the work's ledger whose what opens with size and that quotes the user's one-PR answer settles it: name that answer and both counts, and go on. Never `git add` to count, not even `-N`.
7. Show the menu, then wait: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is. Leave out 2 and 3 with no remote or `push.policy: deny`, and 3 with `pr.policy: deny`. Option 4: report the branch and `<wt>`; stop. Discard only on the typed word `discard`, per `references/discard.md`.
8. Commit, for options 1 to 3: nothing to commit when `git status --porcelain` prints nothing; else run steps 2 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md` on `<wt>`; its stops stop this skill, and its proof is its own, apart from step 4's. Then offer a rebase step 3 put off. A release, if asked: `references/release.md`. Option 1 ends with the short SHA.
9. Dedup, before any push or PR: `references/push-and-pr.md`, section Dedup.
10. Push, for options 2 and 3: `references/branch-ops.md`, section Proven tree, then `references/push-and-pr.md`, section Push.
11. Draft PR, for option 3: `references/push-and-pr.md`, section PR. Report the URL; the worktree stays.

## Inputs

Each key: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get <key>` (exit 3: the default), a detected one then `kern-detect <key>` (both exit 3: ask).

| Key | Default |
|---|---|
| `base_branch`, `branch.pattern`, `test.full`, `pr.template`, `commit.convention`, `tracker` | detected |
| `branch.protected`, `deploy.envs` | base plus deploy branches; none |
| `scope_threshold`, `pr.max_lines`, `pr.size_command` | 4 files; 300 lines; none |
| `push.policy`, `pr.policy`, `pr.dedup` | `ask`; `draft-after-approval`, read as `ask`; `on` |

## Outputs

A commit, push or draft PR, per the choice, or a release; a chat report: SHA, branch, PR URL, `<wt>`, the tag or its wait.

## Stops and autopilot

Ask at each stop as a typed reply in chat, never through AskUserQuestion. A G1 or G2 prompt is the confirmation; a declined prompt or a denial stops, reported. `references/push-and-pr.md` says how the policies meet them.

Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. Under autopilot every kern ask is a denial, nothing is rebased or discarded, no teardown runs but the stale-check removal in `references/branch-ops.md`, and the menu resolves to option 3, or the highest option step 7 left: commit, then the dedup check, then the push and PR. A stop parks as `parked: <question>; default: <choice>; why: <one line>`. Defaults: a stale base or `rebase first`: no rebase; go on, the PR body's Merge danger saying so (why: a draft cannot merge; a rebase changes what was proven). A failed fetch: the last fetched ref. The size gate: go on, Scope giving the size (why: a split is the user's scope call; a draft can be closed). Dedup: per its section. Stray untracked files can park the finish at commit's "no files, no commit" default. Any other stop ends the run, `fix first`, `split` and a failed or unrunnable proven-tree check included.

## Red flags

| Thought | Reality |
|---|---|
| "Tests passed earlier this session" | A run proves only the tree it ran on. Push the proven tree. |
| "A PR exists, so there is nothing to push" | A PR at an older head gets the new commits. Only a PR at this head stops. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` deletes work. |
| "The PR is up, so the worktree is clutter" | Review fixes happen there. It stays until the work lands. |
| "The push was rejected; force will fix it" | The remote moved, unless this run rebased. Investigate; never a plain force. |
