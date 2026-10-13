---
name: autopilot
description: Turn this session's autopilot grant on or off, or show what it allows. Only a prompt you type can turn it on.
disable-model-invocation: true
argument-hint: "[on|off|status]"
allowed-tools: Read, Glob, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *)
---

# Autopilot

A per-session grant for unattended runs. kern's prompt hook turns it on only from a command the user typed. This skill reports the result.

## Steps
1. Read the `kern mode:` line the hook injected this turn. No such line: reply "the hook did not run; autopilot is off". Never write the state file and never report "on" without the hook line.
2. `on`, and the line says `autopilot=on`: list what is allowed, what is denied and the floor. Say how to stop: `/kern:autopilot off`, "stop autopilot" or `/clear`. Then ask for, or propose, a checkable stop predicate for the run, such as "stop when every task in the plan has a complete ledger line or one is parked".
3. `on`, and the hook reported "autopilot denied by <file>": name the file and the `autopilot: denied` key. Do not suggest changing it unless the user asks.
4. `status`: on or off, the settings source of `autopilot`, and the `rebase.push` value.
5. `off`: confirm, then list the `parked:` lines written since autopilot turned on in `WORK/ledgers/*/ledger.md`. Find the directory without creating anything: line 1 of `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root` is the main root, and the text before the tab in `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get work_dir .kern` is the work dir. Read `<main root>/<work_dir>/ledgers` only when it already exists. If it does not, say nothing was parked. Never run `kern-dir` here: it creates the directory and edits `.git/info/exclude`.

## What autopilot allows
- Commit on a branch that is not protected, with exactly one `-m` or `-F` and no other option except `-q` or `-v`, when the message passes the convention and attribution checks. kern denies `--amend`, `-a`, `--no-verify`, a pathspec and `git add -A`.
- Write the commit message with `-m '<text>'`, or write it to a file in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir msg` prints and pass that file's absolute path to `git commit -F`. kern cannot check a `$( )` or here-doc message, so it denies one.
- Run git and gh directly, with no wrapper such as env, sudo, xargs or caffeinate, and no `cd` first. kern denies what it cannot prove.
- Push the current branch with `git push [-u] <remote> <current-branch>`, naming both, when the branch is not protected. kern denies a bare `git push`.
- Push with `git push --force-with-lease <remote> <current-branch>` only when settings say `rebase.push: autopilot`, the branch is not protected, and every commit on it past the base branch is the user's. kern denies a lease push of any other branch.
- Open a draft PR from the current branch with `gh pr create --draft` plus `--title`, `--base`, `--fill` or `--body-file` with a file in the repo, after the duplicate check. kern denies it when the head already has an open, merged or closed PR.

kern denies every other action that would ask, because nobody is there to answer. Merge, deploy, review posting and tracker writes always need the user. Park each judgment call with the default chosen, and continue the work that does not depend on it.

## Who can turn it on
Only the user, by typing `/kern:autopilot on`. Claude, a subagent, a skill, a background report, a scheduled task and another session cannot.
