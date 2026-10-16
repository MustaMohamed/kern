# kern M1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship kern's kernel, mode switching, autopilot grant, settings layer, ten guards and the three M1 skills, all tested on macOS bash 3.2 and Linux bash 5.

**Architecture:** Four bash hooks (`session-start`, `subagent-start`, `prompt-submit`, `pre-tool-use`) share five sourced libraries under `hooks/lib/`. `session-start` renders `kernel/kernel.md` with the project settings summary; `prompt-submit` applies `/kern:mode` and `/kern:autopilot` and writes per-session state; `pre-tool-use` sources every `hooks/guards/g*.sh`, collects votes and prints the strictest. Skills are prose; `scripts/kern-*` give skills the same settings and repo facts the hooks use.

**Tech Stack:** bash 3.2+ and POSIX tools (awk, sed, grep, git), optional `gh` and `gitleaks`; bats-core for hook tests; Node 22 `node:test` for lint rules; shellcheck; Claude Code 2.1.296.

**Spec:** `docs/specs/2026-10-12-kern-design.md` (sections 4 to 8, 11.2, 14) and `docs/specs/2026-10-12-kern-m1-m2-skills.md` (sections A, B, E). Shared names: `docs/plans/contract.md`. M0 must be complete: this plan extends M0's `scripts/lib/lint-rules.mjs`, `tests/lint-rules.test.mjs`, `scripts/ci-local` and `.github/workflows/ci.yml`.

Every command runs from the repo root, `~/Code/projects/kern`, unless a step says otherwise.

## Global Constraints

- Kernel delivery: SessionStart target 4,000 chars (lint warning), lint error at 9,000, Claude Code's cap 10,000 per string. SubagentStart at most 1,200 chars.
- Kernel section budgets (design 4.2): header 100, precedence 420, routing 1,100, autonomy 650, evidence 330, context 125, reply 225, learning 160, paths 250, settings summary 600; total 3,960.
- M1 routing rows: technical-writing and context only. Every other row ships with its route (M2, M3, M6).
- Hooks use bash, POSIX tools and git only. `gh`, `jq` and `gitleaks` are used when present, never required. jq is never used, so behaviour does not change with it.
- Hooks are bash 3.2 compatible (macOS `/bin/bash`): no associative arrays, no `${var,,}`, no `mapfile`, no `;&`. A function that votes must never run in a pipeline subshell; loops read from here-documents instead.
- Plugin hooks use exec form: `"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/<name>"]`.
- PreToolUse decisions are `hookSpecificOutput.permissionDecision` (`allow`, `ask`, `deny`) with `permissionDecisionReason`. A hook that cannot parse its input returns `ask`, or `deny` under autopilot. It never allows on a parse failure. The dispatcher entry uses `"onFailure": "block"`.
- Policy keys: `commit.policy`, `push.policy`, `pr.policy`, `tracker.policy`, `review.post_policy`, each `ask` (default), `auto` or `deny`. Floor actions have no key and never loosen: merge, production deploy, data deletion, force-push to a shared branch, messaging people.
- Autopilot is on only when no settings layer says `autopilot: denied` and the session state says `autopilot: on`, which only the hook writes from a command the user typed.
- Session state: `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>.state`, flat `key: value`, mode 0600, atomic write, symlinks refused. (Skills spec B1 wins over the design's `.json`.)
- `startup`, `clear` and `fork` reset the mode to settings defaults with autopilot off; `compact` and `resume` keep it.
- Settings and `.kern/` resolve from the main worktree root, the first `worktree` line of `git worktree list --porcelain`, never from the current directory.
- Description limits: path and slash skills at most 120 chars. A frontmatter value that contains `: ` is quoted, so YAML parsers read it.
- Shipped files (`skills/`, `agents/`, `kernel/`, `modes/`, `hooks/`): no machine paths, no personal names (lint rule 8), no long dashes or curly quotes (lint rule 11), and never the words caveman, ultracave or megacave as a name.
- `modes/terse.md` is written for kern. Caveman 3.2.0 (Apache-2.0) is credited in NOTICE as the source of the idea; no caveman text is copied.
- Commits: subject `M1: <imperative summary>`, 72 chars or fewer; body says why; no attribution trailers; `git add -- <paths>` only. Pushes happen only when the user says so.
- Port tasks follow the port-task convention in the M0 plan: source file and lines under `.upstream/<source>/`, required headings, adaptation rules, full text of every contract part, and a check command.

## Spec reconciliations made here

| Topic | Spec text | This plan | Why |
|---|---|---|---|
| State file | design 6.1 `<session_id>.json` | `<session_id>.state`, flat lines | Skills spec B1 is later and hooks read it with awk |
| Mode default key | design 5.4 `mode.default` | `mode.voice` and `mode.surface` | Skills spec A5; two axes need two keys |
| `review.taxonomy` default | design `blocker,suggestion,nit` | `blocker,should-fix,nit,pre-existing` | Skills spec A5 |
| `scope_threshold` default | design "unset" | `4` | Skills spec A5 |
| G13 protected targets | in the guard table, in no milestone | M1, Task 13 | A guard with no milestone would never ship |
| G14 | MCP writes | MCP writes plus `gh issue` and `gh label` writes | D2 covers tracker writes however they are made |
| G16 | state-file writes | also CronCreate, ScheduleWakeup, RemoteTrigger, SendMessage and Skill calls that carry `/kern:autopilot` or `/kern:mode` | A scheduled or relayed prompt must not switch state |
| `help check` table | `KERN/kernel/config.md` | `kernel/settings.md` | One key table, checked by lint rule 13 |
| `help` description | unquoted, contains `: ` | quoted | A YAML parser rejects the unquoted form |
| New key | none | `mcp.write_servers` (G14) | Lets a project name a tracker server kern does not know |
| Kernel rendering | contract: `sed` | `awk` literal replacement | Values may hold `|`, `&` and `/` without escaping |

- Expected bats counts in this plan are written in the pretty format (`N tests, 0 failures`), which prints only on a terminal. When output is piped, the same result is `1..N` followed by N `ok` lines and no `not ok`.

## Review Focus

1. **A git command hidden in a chain, a `$( )`, backticks or `bash -c '...'`.** The user expects G1 to see `cd x && git stash` and `bash -c 'git switch main'` the same as a bare command. Pinned: Task 10 test `a chained or substituted main-checkout command is still seen`; Task 9 `gitctx.bats` tests the splitter.
2. **A session running inside a linked worktree.** Settings, `.kern/` and the main-checkout test must resolve from the main worktree root, or a worktree session sees no settings and every guard misjudges "main checkout". Pinned: Task 3 test `a linked worktree reads the main checkout's untracked settings`; Task 4 test `kern-dir creates WORK/sub at the main root`; Task 10 test `the same commands in a linked worktree: no vote`.
3. **A prompt Claude Code starts itself that contains `/kern:autopilot on`:** a background subagent report, a cross-session message, a scheduled task, or a CronCreate Claude writes. None may switch autopilot on. Pinned: Task 8 test `wrapped prompts never switch`; Task 9 test `a scheduled prompt or relayed message carrying /kern:autopilot is denied`.
4. **A very large tool input, such as a 200 KB Write.** The guard dispatcher parses every Write; a quadratic parser would stall each one. Pinned: Task 2 test `a 200 KB value parses in under 5 seconds`.
5. **`gh` missing, offline or slow during the PR duplicate check.** The guard must not allow a PR it could not check, and must not hang the session. Pinned: Task 11 test `gh failing means dedup unknown`; Task 9 test `with_timeout returns promptly when the command finishes`.

## File map

| Path | Task | Responsibility |
|---|---|---|
| `docs/spikes/m1-payloads.md`, `tests/fixtures/payloads/*.json` | 1 | Real hook payloads and the decisions they drive |
| `tests/helpers/common.bash`, `tests/run-bats`, `hooks/lib/json.sh`, `tests/hooks/json.bats` | 2 | Test helpers; JSON reading without jq |
| `hooks/lib/settings.sh`, `kernel/settings.md`, `scripts/kern-get`, `tests/hooks/settings.bats` | 3 | Layered settings and the key table |
| `scripts/kern-root`, `scripts/kern-dir`, `scripts/kern-detect`, `tests/scripts/kern-dir.bats`, `tests/scripts/kern-detect.bats` | 4 | Repo facts for skills |
| `hooks/lib/state.sh`, `tests/hooks/state.bats` | 5 | Per-session mode and autopilot state |
| `kernel/kernel.md`, `kernel/context.md`, `modes/terse.md`, `hooks/lib/render.sh`, `hooks/session-start`, `tests/hooks/session-start.bats` | 6 | Kernel rendering at session start |
| `kernel/kernel-subagent.md`, `modes/terse-subagent.md`, `hooks/subagent-start`, `tests/hooks/subagent-start.bats` | 7 | Subagent kernel |
| `hooks/prompt-submit`, `tests/hooks/prompt-submit.bats` | 8 | Mode and autopilot switching, reminders |
| `hooks/lib/decide.sh`, `hooks/lib/gitctx.sh`, `hooks/pre-tool-use`, `hooks/guards/g16-state.sh`, `hooks/hooks.json`, `tests/hooks/gitctx.bats`, `tests/hooks/g16-state.bats`, `tests/hooks-json.test.mjs` | 9 | Guard dispatcher, G16, hook wiring |
| `hooks/guards/g01-git.sh`, `tests/hooks/g01-git.bats` | 10 | G1 git safety |
| `hooks/guards/g02-pr.sh`, `g03-review.sh`, `g04-untrusted.sh`, `tests/hooks/g02-g04-gh.bats` | 11 | G2, G3, G4 |
| `hooks/guards/g05-commit.sh`, `g06-secrets.sh`, `tests/hooks/g05-g06-commit.bats` | 12 | G5, G6 |
| `hooks/guards/g13-protected.sh`, `g14-tracker.sh`, `g15-deploy.sh`, `tests/hooks/g13-g15.bats` | 13 | G13, G14, G15 |
| `skills/mode/SKILL.md`, `skills/autopilot/SKILL.md` | 14 | Mode and autopilot skills |
| `skills/unslop/SKILL.md`, `skills/technical-writing/SKILL.md` | 15 | Writing skills (ports) |
| `skills/help/**`, lint rule 6, `scripts/lint-exemptions.json` | 16 | Help skill, map, setup, check |
| lint rules 7, 13, 15, `tests/fixtures/projects/*`, `tests/hook-shape.sh`, CI | 17 | Size, key and hook-shape checks in CI |
| `NOTICE`, `CHANGELOG.md`, manifests | 18 | Acceptance, live checks, release 0.2.0 |

## Interfaces M2 relies on

- Kernel route row (contract): `| <when, observable> | Read {KERN}/<skill>/SKILL.md |` in `kernel/kernel.md` under `## Routing`; a kernel file route reads `Read {ROOT}/kernel/<file>.md`. Lint rule 6 resolves both and requires the target's first H2 to be `## Steps` followed by a numbered list. M2 also replaces the routing sentence "Non-trivial work with no match: write a short plan as a todo list first." with "Several matches: define and diagnose before build. Non-trivial work with no match: plan."
- Settings summary (`settings_summary` in `hooks/lib/render.sh`), at most 600 chars, lines in this order, each present only when non-empty except `Settings files:`, which is always printed: `Main worktree: <path>` (or `Not a git repository: user settings only.`), `Settings files: <list>`, `Set: key=value; ...`, `Overrides (follow the project skill, say so in one line): <job> -> project skill <name>; ...`, `Routes: <name> -> <value>; ...`, `Ignored, floor actions have no key: <keys>`, `Unknown keys, ignored: <keys>`. Overrides cover every directory under `skills/` except `mode`, `autopilot`, `help` and `hello`, so each M2 skill gets defer detection with no hook change.
- Mode line: `kern mode: voice=<normal|terse> surface=<chat|auto|html> autopilot=<on|off>`, printed by `mode_line SID` in `hooks/lib/render.sh`. `session-start` prints it in the kernel header; `prompt-submit` prints it on every `/kern:mode` or `/kern:autopilot` turn, outside the default preset, and under autopilot.
- Votes (`hooks/lib/decide.sh`): `vote allow|ask|deny G<n> "<reason>"`; strictest wins (deny, ask, allow); the reason shown is the winning level's reasons joined by `; ` with the prefix `kern `. `fail_closed "<reason>"` votes `ask` as `G0`. Under autopilot a final `ask` becomes `deny`.
- Adding a guard (M2 adds `g18`): create `hooks/guards/g18-<name>.sh` defining `guard_g18()`; the dispatcher sources every `hooks/guards/g*.sh` and calls `guard_<id>` where `<id>` is the file name up to the first `-`. Variables a guard reads: `TOOL`, `TOOL_INPUT` (raw JSON of `tool_input`), `AGENT` (`agent_type`, empty in the main session), `CWD`, `SID`, `KERN_MAIN`, `AUTOPILOT` (`1` or `0`). Helpers: `ti_get KEY`, `git_words`, `git_sub`, `gh_sub`, `cmd_head`, `_shell_words`, `word_has`, `word_value`, `in_main_checkout`, `current_branch`, `branch_protected`, `base_branch_name`, `push_targets`, `with_timeout`, `settings_get`, `policy_for`, `list_has`. Test it with `run_guard "<payload>" g18` from `tests/helpers/common.bash`.
- Test helpers (`tests/helpers/common.bash`): `kern_root`, `make_repo DIR`, `kern_env DIR`, `payload EVENT FIELDS`, `bash_payload CMD`, `run_guard PAYLOAD [GUARDS]`, `decision_of OUTPUT`, `set_autopilot on|off`, `fake_gh`. Run bats through `tests/run-bats`.
- Spike record: `docs/spikes/m1-payloads.md` holds the line `agent_type in subagent PreToolUse: <value or absent>`.

---

