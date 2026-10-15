---
name: commit
description: Commit named files with a message that follows the project's convention, after the checks pass.
disable-model-invocation: true
argument-hint: "[files...]"
allowed-tools: Bash(git -C * status *), Bash(git -C * diff *), Bash(git -C * log *), Bash(git -C * rev-parse *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# commit

One clean commit of the right files. finish-branch and, under autopilot, execute-plan run steps 3 to 6.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Consent: the user typed `/kern:commit` or asked to commit in this session, or autopilot is on. Otherwise stop.
2. Where, in order: `<toplevel>` is what `git -C <wt> rev-parse --show-toplevel` prints; `<wt>` is the worktree the caller names (execute-plan: its plan worktree), else `.`. Run every later git command as `git -C <toplevel> ...`. Branch: `git -C <toplevel> rev-parse --abbrev-ref HEAD` (`HEAD`: detached). On a protected branch, stop and ask: commit locally anyway, or the user moves the work. On a detached HEAD, stop: finish-branch offers to create a branch. Never switch branches.
3. Files: read `git -C <toplevel> status --porcelain`; propose this task's files or those named; list the rest, unstaged. For a `<ledger dir>` under `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers` whose `Worktree:` line names `<toplevel>`, offer one commit per complete task, in ledger order. A task's files are the `## Files changed` list of `<ledger dir>/reviews/task-<N>-<tree7>.diff`, `<tree7>` the first 7 characters of the `tree=` of its `Task <N>: complete` line. If that file is missing, run `git -C <toplevel> diff --name-only <start tree> <complete tree>` on the trees of its start and complete lines; failing that, ask. Tasks that share a path cannot be split (`git add` takes whole files): offer one commit naming each, or ask. Never stage a file that holds another task's hunks under one task's name. Autopilot commits each task as it closes, so overlap arises only in a later run. Stage with `git -C <toplevel> add -- <files>` in its own call, never `-A` or `.`; name and leave out any `never_commit` path. Show `git -C <toplevel> diff --staged --stat`.
4. Before the first commit, follow `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md` once (`verify.fast` and the focused tests). If tracked changes stay unstaged, say the proof ran on the working tree, not the commit. Record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <toplevel>`.
5. Message: use `commit.convention`, or infer it from `git -C <toplevel> log --format=%s -30` and state it; take the ticket id from the branch name by `commit.id_from_branch`; an imperative subject of 72 characters or fewer; a body that says why; one concern per commit (a refactor mixed with a feature: propose two). Prose follows `${CLAUDE_PLUGIN_ROOT}/skills/technical-writing/SKILL.md`. Add attribution only as `commit.attribution` says.
6. Write the message with the Write tool to `<dir>/commit-msg` (Read it first if it exists), `<dir>` being the path `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints. Run `git -C <toplevel> commit -F <dir>/commit-msg` as its own call, with the literal path: no `cd`, no expansion, no other command. G5 reads a message file only inside the main worktree. G5's prompt is the confirmation; under autopilot G5 allows it when the checks pass.
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

Ask at each stop as a typed reply in chat, never through AskUserQuestion. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. Stops: steps 1 to 4, and `kern-dir` exits 2, `wt-snap` fails, G5 denies or asks, `git add` or `git commit` fails. Report its output; never `--no-verify`, never another command shape. Under autopilot a failing convention check is a denial, never a retry with a looser message, and each stop parks as `parked: <question>; default: <choice>; why: <one line>` committing nothing on that path (defaults: overlap, one commit naming each task; no files, no commit); a protected branch or a detached HEAD never commits.

## Red flags

| Thought | Reality |
|---|---|
| "I'll commit when the whole plan is done" | A giant commit cannot be reviewed. |
| "The tests passed earlier" | Prove the tree you commit. |
| "The check failed, so I'll loosen the message" | A failed check is a stop, never a retry. |
