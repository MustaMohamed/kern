# Changelog

All notable changes to kern. Format: Keep a Changelog. Versioning: semver, as defined in docs/specs/2026-10-12-kern-design.md section 12.

## [Unreleased]

- Guards judge a Bash command whose head word is a shell alias from the Claude Code shell snapshot, such as `gpf! origin main`, as the git or gh command it expands to, as well as itself. With aliases loaded, the guards read the command's own simple commands exactly as without aliases, in the same order and context, then every expansion after all of them, so an alias can only add votes: it never removes a deny or an ask, and never gets an allow, which kern gives only to a command that starts with git or gh. The head word is found after assignments (quoted ones included), redirections and zsh's reserved words (`if`, `!`, `time` and the like), in each simple command, `$( )` and `eval`. An alias whose value ends in a space, such as `_='sudo '`, also expands the word after it, as zsh's trailing-space rule does, so `_ gpf! origin main` is judged as `sudo git push --force origin main`; past 8 such words, a word that is still an alias is denied under autopilot. G2, G3, G4, G13, G14 and G15, which skip a command whose text names no gh, push, deploy tool or network client, read the expansion's text too, so `prc` for `gh pr create`, `gp origin production` as a push to a deploy branch, and an alias that runs psql against a protected target are judged. kern reads the snapshot as text and never runs it; a missing, unreadable or unparseable snapshot changes nothing. It caches the parsed table in its state dir, keyed by the snapshot's path, size and modification time, and reads the cache as data the same way; a forged cache, like a forged snapshot, can only add votes. This removes the 0.2.0 known limit on shell aliases. Known limits, left for M3: the newest snapshot stands in for the session's, which the hook input does not name; an alias defined and used in one Bash call through `eval`, `$( )` or a backtick is not judged interactively (G00 denies the definition under autopilot); nor is an alias past another alias's head word, a global alias, a `$'...'` or double-quoted alias value, a chain of aliases deeper than 8, or interactively an alias past 8 trailing-space words; an expansion no longer sets context for the command's later records, so `gaa && git commit -m x` loses G6's stale-index reason (its decision stays); a snapshot with thousands of aliases slows every Bash call, by about 0.6 s for 10,000; G16 and G20 match only the command's own text, not an alias's expansion; and the shell-snapshots folder is writable, so kern reads a newer snapshot written there, though that can only add votes, never remove a deny or an ask or add an allow.
- help: allows only the exact git commands it prescribes (`git remote -v`, `git rev-parse --git-common-dir`, `git check-ignore -q *`, `git worktree list`); `git remote *`, `git symbolic-ref *` and `git log *` could write config, move HEAD or run a program with no prompt.
- Mode switches: "terse voice" and "terse mode on" switch; extra spaces are folded; a first line over 200 characters never switches.
- Kernel: no is an acceptable answer, and chat in either voice skips the main AI tells; terse keeps existing comments and shows only changed code.
- prove-it: evidence before any done, fixed or passing claim. Removes the M0 placeholder skill.
- Agents implementer, task-reviewer and investigator.
- floor-scan: the G7 check as a script, with a lowered-bar class and ratchet.<metric> settings keys.
- Guard G18: kern's read-only investigator may run only allowlisted read commands.
- Guard G16 asks, and under autopilot denies, any command whose text names kern's hook code or its state functions, reads included; hook files stay readable through the Read and Grep tools. Running prompt-submit with a made-up prompt could forge the user's message or turn autopilot on.
- Guard G20: a Markdown spec or plan becomes approved, or changes its approved: line, only with a quote of the user's last message, judged on the file as the edit leaves it; never under autopilot.
- implement: thin slices, failing test first, mutation and fail-then-pass probes, full suite.
- diagnose: red-capable loop before hypotheses, fix with a regression test proven by probe; loop-rate for flaky bugs.
- define: clarify, classify and get an explicit, quoted approval before code; specs carry a Constraints section.
- plan: approved spec to ordered tasks with exact files and verify commands, checked by plan-check.
- parallel-work: fan out with one worktree per writer, checked briefs and serial integration.
- execute-plan: ledger, per-task worktree snapshots and two-verdict review without commits; approval, review and RED checked by scripts.
- self-review: deterministic checks, built-in code-review at low effort, a spec lane, blast radius, probes, verdict.
- commit: named files, convention-checked message from a file under .kern/tmp, one commit per reviewed task run as `git -C <worktree> commit`, no attribution by default.
- finish-branch: verify, self-review and size gate before the commit, push or draft PR menu; the PR has a title, a body under .kern/tmp and a dedup on the head commit. prove-it hands commits and PRs to these skills.
- recall: rebuild state from kern working files, this project's transcripts and live state; replaces the user-level recall skill.
- Kernel: M2's routes live in kernel/routes.md, which the Routing rule points to, for define, plan, execute-plan, implement, diagnose, prove-it, self-review and recall; routing evals with fixed floors and a frozen held-out set; lint rule 12 and a standing-cost budget.
- Hooks run git with no fsmonitor program and no repo hooks (git 2.31 or later). With an older git, or one whose version cannot be read, session-start says so in one line.

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
