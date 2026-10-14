# Changelog

All notable changes to kern. Format: Keep a Changelog. Versioning: semver, as defined in docs/specs/2026-10-12-kern-design.md section 12.

## [Unreleased]

- Agents implementer, task-reviewer and investigator.
- floor-scan: the G7 check as a script, with a lowered-bar class and ratchet.<metric> settings keys.
- Guard G18: kern's read-only investigator may run only allowlisted read commands.
- Guard G20: a Markdown spec or plan becomes approved, or changes its approved: line, only with a quote of the user's last message, judged on the file as the edit leaves it; never under autopilot.

## [0.2.1] - 2026-10-14

- PreToolUse asks, or denies under `bypassPermissions`, when a hook library cannot load or lacks a function it defines. In 0.2.0 a missing `settings.sh` or `decide.sh` gave no decision at all. session-start says when kern did not load.
- pre-tool-use and session-start leave POSIX mode first, so `POSIXLY_CORRECT` cannot skip that check.
- A natural-language voice switch fires only when the phrase stands alone on the first line, such as `go terse`, `turn off terse mode` or `back to normal`, with a leading `please` or `ok` and a trailing `please`, `now`, `.` or `!` allowed. More phrases switch, and prompts such as `use terse variable names` no longer do. A 200-case corpus tests the hook.
- No mode line or terse reminder on scheduled-task prompts.
- session-start removes session state files untouched for 30 days.

## [0.2.0] - 2026-10-13

- Kernel and subagent kernel, rendered at session start and subagent start, with the project settings summary.
- Mode switching (`/kern:mode`, natural phrases) and the per-session autopilot grant (`/kern:autopilot`), which only a typed command turns on.
- Settings layer (`.claude/kern.local.yml`, `.claude/kern.yml`, `~/.claude/kern.yml`) and `scripts/kern-root`, `kern-get`, `kern-dir`, `kern-detect`. Safety lists (`protected_targets`, `never_commit`, `branch.protected`, `deploy.envs`) are the union of every layer.
- Guards G1 to G6 and G13 to G16 through one PreToolUse dispatcher. A guard allows only a proven command shape and asks for anything else; under autopilot every ask is a deny.
- Git write commands and gh commands behind a wrapper (`env`, `sudo`, `xargs`, `caffeinate`), git aliases and git extensions ask, because kern cannot see what they run.
- G13 treats `protected_targets` as read-only: it lets through only proven reads (ssh read commands, plain SELECT and similar, copies from the target) and denies everything else in both modes. A remote `cmd` or PowerShell wrapper denies, and so does SQL that needs more than plain lexing (comments, backslashes, dollar-quotes, E-strings, doubled quotes). Entries may be a host, a host:port such as an SSH tunnel, or an sqlite path.
- G14 allows tracker writes under `tracker.policy: auto` only for a closed list of Linear and Notion tools and proven `gh issue` and `gh label` shapes. GitHub MCP writes and every delete always ask.
- G15 asks before deploys and publishes, from a table of 76 command names, named anywhere in a command.
- Under autopilot, G00 denies commands kern cannot read: command names built at run time, shell scripts it cannot parse, and code piped into a shell. Interpreter code in files and here-docs still runs.
- gh aliases and extensions ask, and so does any write to Claude Code's own settings files (`.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`).
- A committed `.claude/kern.yml`, or a `kern.local.yml` that git tracks, cannot turn kern off or loosen a policy; a committed `base_branch` cannot unprotect the default branch.
- Skills `mode`, `autopilot`, `help`, `unslop`, `technical-writing`; the terse voice.
- Lint rules 6, 7, 13 and 15; hook tests on bash 3.2 and 5; CI runs the hook suite.
- Known limits: shell aliases from the Claude Code shell snapshot (such as `gpf!`), `GIT_CONFIG*` environment settings, ANSI-C quoting, package scripts, interpreters and variables can hide a command from the guards. A command over about 40 KB times out in the hook and is blocked.

## [0.1.0] - 2026-10-12

- Repo, manifests, licences, lint, routing evals and CI with a placeholder skill.
- M0 accepted: plugin validates, CI green, marketplace install works.
