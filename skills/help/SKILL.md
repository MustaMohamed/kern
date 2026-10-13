---
name: help
description: "Map of kern: which skill fits, fixes for a run that went wrong, and help setup to write this project's settings."
disable-model-invocation: true
argument-hint: "[setup|check|<question>]"
allowed-tools: Read, Bash(git remote *), Bash(git symbolic-ref *), Bash(git log *), Bash(git for-each-ref *), Bash(git worktree list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# Help

The human-facing map of kern and the project setup. A message that asks for work is not a help question: hand it back to the kernel's routing.

## Steps
1. Pick the mode from the argument: `setup`, `check`, or a question. No argument and an unclear need: ask one multiple-choice question: set up this project, pick a skill, fix a run, or change kern itself.
2. Question mode: check the state that changes the answer and mention it only when it does: the kernel was injected this session and its version; which settings files exist; superpowers' SessionStart hook is still enabled (two routers); a second voice plugin injects rules; the mode and autopilot line.
3. Read the target skill before quoting it.
4. Answer from one section of `references/map.md` or `references/fix-a-run.md`. Give at most one example prompt and do not start the work.
5. `setup` and `check` follow their sections below.

## Setup
1. Explore read-only: `git remote -v`; `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect base_branch`; the same script for `branch.pattern`, `commit.convention`, `test.full`, `test.focused`, `typecheck`, `lint`, `build`, `tracker` and `pr.template`; CLAUDE.md and `.claude/rules/**`; `.claude/skills/*` and `.claude/commands/*` (jobs a project skill owns); connected tracker MCP tools; existing kern settings.
2. Present two lists: settled by detection (written only where detection guessed wrong) and needs a decision.
3. Ask one key group at a time, recommended answer first, skipping groups detection settled: tracker; conventions; check commands; review; risk (`autopilot`, `protected_targets`, `deploy.envs`, `never_commit`, `scope_threshold`, `shared_services`); `worktree.setup`.
4. Map project skills to kern jobs and show the map, for example `overrides.commit: commit`. Say that kern's guards still apply to project skills.
5. Show the full commented draft of `.claude/kern.local.yml`, built from `templates/kern.local.yml`. Let the user edit it. Write it only after an explicit yes, as one file at the main worktree root; a re-run updates it in place.
6. On the same yes, append to `$(git rev-parse --git-common-dir)/info/exclude` the lines `/.claude/kern.local.yml`, `/.kern/`, and `worktree.dir` when it is inside the repo and `git check-ignore -q` fails for it. Never edit `.gitignore` or any tracked file.
7. Offer `.claude/kern.yml` (shared, committed) only if the user wants team settings; committing it follows the normal commit rules. Offer user defaults (`mode.voice`, `mode.surface`, `kern_repo`) for `~/.claude/kern.yml` as a separate yes.
8. Print the status-line snippet from `references/fix-a-run.md`. Never write `settings.json`.

Under autopilot, setup refuses: nobody can confirm the draft. Setup makes no tracker writes.

## Check
Validate without writing anything: unknown keys and floor-action keys (the kernel's Project settings block lists both); `overrides.<job>` values that name a missing project skill; settings files that exist in a linked worktree but not at the main worktree root (`git worktree list`); missing exclude lines for `.claude/kern.local.yml` and `.kern/`. The key table is `${CLAUDE_PLUGIN_ROOT}/kernel/settings.md`.
