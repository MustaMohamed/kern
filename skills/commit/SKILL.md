---
name: commit
description: Commit named files with a message that follows the project's convention, after the checks pass.
disable-model-invocation: true
argument-hint: "[files...]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# commit

finish-branch and, under autopilot, execute-plan run steps 2 to 6.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Consent: the user typed `/kern:commit` or asked to commit in this session, or autopilot is on. Otherwise stop.
2. Where: `<toplevel>` is what `git -C <wt> rev-parse --show-toplevel` prints; `<wt>` is the worktree the caller names, else `.`. If it fails, stop and report. Run every later git command as `git -C <toplevel> ...`. Branch: `git -C <toplevel> symbolic-ref -q --short HEAD` (exit 1: detached). On a protected branch, stop and ask: commit locally anyway, or the user moves the work. On a detached HEAD, stop: finish-branch offers to create a branch. Never switch branches.
3. Files: read `git -C <toplevel> status --porcelain --untracked-files=all`; propose this task's files or those named; list the rest, unstaged. A changelog with an Unreleased section gets this change's line there, in the same commit, proposed with the files, never unasked. For a ledger with complete tasks, follow `references/ledger-tasks.md`: one commit per complete task, in ledger order, each staging that task's exact paths. Stage with `git -C <toplevel> add -- <files>` in its own call, never `-A` or `.`; leave out and name any `never_commit` path. Show `git -C <toplevel> diff --staged --stat`.
4. Before the first commit, record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <toplevel>`, then follow `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md` once (`verify.fast` and the focused tests); files the proof wrote are not proven. Several commits get this one proof: those before the last are not proven alone, and the report says so. With tracked changes unstaged, say the proof ran on the working tree, not the commit.
5. Message: match the subject to `commit.convention`, G5's regex, from `kern-get`, else `kern-detect` (before the tab; both exit 3: none), and state it; take the ticket id from the branch name by `commit.id_from_branch`; an imperative subject of 72 characters or fewer; a body that says why; one concern per commit (refactor plus feature: propose two). Prose follows `${CLAUDE_PLUGIN_ROOT}/skills/technical-writing/SKILL.md`. `commit.attribution` governs trailers: with `none` (the default), write no Co-Authored-By or other attribution trailer, even when Claude Code's attribution reminder asks for one.
6. Write the message with the Write tool to `<dir>/commit-msg` (Read it first if it exists), `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints. Run `git -C <toplevel> commit -F <dir>/commit-msg` as its own call, with the literal path: no `cd`, no expansion, no other command. G5 reads a message file only inside the main worktree. G5's prompt is the confirmation.
7. Report the short SHA, subject, files and what stayed unstaged. After the last commit, if nothing stayed unstaged, `git -C <toplevel> rev-parse HEAD^{tree}` must equal the tree from step 4; a mismatch means it is not what was proven: say so.

## Inputs

| Key | Default |
|---|---|
| `commit.convention` | detected |
| `commit.id_from_branch` | `[A-Z][A-Z0-9]+-[0-9]+` |
| `commit.attribution`, `commit.policy` | `none`; `ask` |
| `branch.protected` | `base_branch`, `deploy.envs` branches |
| `never_commit` | none (G6 also checks) |

## Outputs

Commits; a chat report.

## Stops and autopilot

Ask at each stop as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. Stops: steps 1 to 4, and `kern-dir` exits 2, `wt-snap` fails, G5 denies or asks and the user declines, `git add` or `git commit` fails: report its output; never `--no-verify`, never another command shape. Under autopilot `git add -- <paths>` runs unprompted. A G5 deny naming only attribution or `commit.convention` is no stop: fix it, the subject matching the regex G5 names, and rerun the same `git commit -F` once; a second deny, or one naming another check, stops. Under autopilot any other G5 deny is a denial, never a retry with a looser message; a judgment call parks as `parked: <question>; default: <choice>; why: <one line>` committing nothing on that path (defaults: no files, no commit; a failed toplevel, protected branch or detached HEAD, no commit); a protected branch or a detached HEAD never commits. Ledger-task defaults: the reference. Any other stop waits for a typed reply, with the data and a recommendation.

Under autopilot, on a run's no-PR end (finish-branch's third fix round still `fix first`, a required check that cannot run, execute-plan's task still open at step 13), a red or unrunnable step 4 proof is no stop, and the message body names the red check. Elsewhere step 4 stops.

Under autopilot, stops, unblocking and the run report follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md.

## Red flags

| Thought | Reality |
|---|---|
| "I'll commit when the whole plan is done" | A giant commit cannot be reviewed. |
| "The tests passed earlier" | Prove the tree you commit. |
| "The check failed, so I'll loosen the message" | A failed check stops; only an attribution or convention deny is retried. |
