---
name: help
description: "Map of kern: which skill fits, fixes for a run that went wrong, and help setup to write this project's settings."
disable-model-invocation: true
argument-hint: "[setup|check|<question>]"
allowed-tools: Read, Bash(git remote *), Bash(git symbolic-ref *), Bash(git log *), Bash(git for-each-ref *), Bash(git worktree list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *), Bash(git rev-parse *), Bash(git check-ignore *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *)
---

# Help

The human-facing map of kern and the project setup. A message that asks for work is not a help question. Hand it back to the kernel's routing.

## Steps
1. Pick the mode from the argument: `setup`, `check`, or a question. With no argument and an unclear need, ask one multiple-choice question whose options are set up this project, pick a skill, fix a run, and change kern itself.
2. In question mode, check the state that changes the answer, and mention it only when it does:
   - whether this session holds the kernel, and its version
   - which settings files exist
   - whether superpowers' SessionStart hook is still enabled, which makes two routers answer
   - whether a second voice plugin injects rules
   - the `kern mode:` line, with the mode and autopilot.
3. Read the target skill before quoting it.
4. Answer from one section of `references/map.md` or `references/fix-a-run.md`. Give at most one example prompt and do not start the work.
5. `setup` and `check` follow their sections below.

## Setup
1. Explore read-only:
   - `git remote -v`
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect base_branch`, and the same script for `branch.pattern`, `commit.convention`, `test.full`, `test.focused`, `typecheck`, `lint`, `build`, `tracker` and `pr.template`
   - CLAUDE.md and `.claude/rules/**`
   - `.claude/skills/*` and `.claude/commands/*`, which name the jobs a project skill owns
   - connected tracker MCP tools
   - existing kern settings.
2. Present two lists: what detection settled, and what needs a decision. Write a detected value only where detection guessed wrong.
3. Ask about one key group at a time, recommended answer first, and skip the groups detection settled. The groups are tracker, conventions, check commands, review, risk and `worktree.setup`. Risk covers `autopilot`, `protected_targets`, `deploy.envs`, `never_commit`, `scope_threshold` and `shared_services`.
4. Map project skills to kern jobs and show the map, for example `overrides.commit: commit`. Say that kern's guards still apply to project skills.
5. Show the full commented draft of `.claude/kern.local.yml`, built from `templates/kern.local.yml`. Let the user edit it. Write it only after an explicit yes, as one file at the main worktree root. A re-run updates it in place.
6. On the same yes, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir notes`. It reads `work_dir`, creates that directory and adds its exclude line. Then append to `$(git rev-parse --git-common-dir)/info/exclude` the line `/.claude/kern.local.yml`, and `worktree.dir` when it is inside the repo and `git check-ignore -q` fails for it. Never edit `.gitignore` or any tracked file.
7. Offer the shared, committed `.claude/kern.yml` only if the user wants team settings. Committing it follows the normal commit rules. Offer user defaults for `mode.voice`, `mode.surface` and `kern_repo` in `~/.claude/kern.yml` as a separate yes.
8. Print the status-line snippet from `references/fix-a-run.md`. Never write `settings.json`.

Under autopilot, setup refuses, because nobody can confirm the draft. Setup makes no tracker writes.

## Check
Validate without writing anything. Read each settings file that exists: `.claude/kern.local.yml` and `.claude/kern.yml` at the main worktree root, and `~/.claude/kern.yml`. Compare its keys and values with the Key and Values columns of the first table in `${CLAUDE_PLUGIN_ROOT}/kernel/settings.md`. A key with `<...>` stands for a family. Do not rely on the kernel's Project settings block, which is capped and may be cut. Report:
- floor-action keys, which the hooks ignore. `kernel/settings.md` names the floor actions: merge, production deploy, data deletion, force-push to a shared branch, messaging people. The ignored keys are `merge.policy`, `deploy.policy`, `production.policy`, `force_push.policy`, `delete.policy`, `message.policy` and `messaging.policy`;
- any other key that is not in the table, as unknown;
- a value outside its row's Values column, when that column lists fixed words. The hooks read a misspelt policy value such as `atuo` as `ask`, so name the key and the words it takes;
- `overrides.<job>` values that name a missing project skill;
- settings files in a linked worktree, which `git worktree list` shows, that the main worktree root lacks;
- missing exclude lines for `.claude/kern.local.yml` and the `work_dir` directory, `.kern` by default.
