# kern M0 to M2: shared plan contract

Every plan file (m0, m1, m2a, m2b; the superseded m2 plan is kept for history) uses these names, signatures, paths and exit codes exactly. A plan that needs something not listed here adds it to its own Interfaces block and to this file's "Additions" list. Lint rule 16 (M2a) reads this file: every script, `WORK/` folder and ledger line a shipped skill or agent names must appear here.

## Locations

- kern repo on disk (`kern_repo`): `~/Code/projects/kern`. GitHub: private repo `kern` under the account `gh` is logged in as (`gh repo create kern --private --source . --remote origin`, run only after the user says yes).
- Upstream sources for port tasks: `.upstream/<source>/` inside the kern repo, gitignored, filled by `scripts/fetch-upstream`. Source keys: `superpowers` (obra/superpowers tag v6.4.1; fallback copy from `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1`), `pstack` (cursor/plugins @ 11713c6, path `pstack/`), `pocock` (mattpocock/skills @ 49dd158), `addy` (addyosmani/agent-skills @ 1be8e34), `caveman` (copy from `~/.claude/plugins/cache/caveman/caveman/<version dir>`; ideas only, never copied into shipped files), `local` (copy of `~/.claude/skills/{recall,unslop,no-comments}` and `~/.claude/agents/comment-sicko.md`).
- Spec and plans move into the repo at M0 Task 1: `docs/specs/2026-10-12-kern-design.md`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`, `docs/plans/2026-10-12-kern-m{0,1,2}-plan.md`, `docs/plans/contract.md`, research notes to `docs/research/` (merge-define.md, merge-build.md, merge-ship.md, merge-meta.md, replacement-map.md, modes-research.md, audit-*.md).

## Runtime layout (shipped)

```
.claude-plugin/plugin.json  .claude-plugin/marketplace.json
hooks/hooks.json
hooks/session-start   hooks/subagent-start   hooks/prompt-submit   hooks/pre-tool-use      (bash, executable, no extension)
hooks/lib/json.sh  hooks/lib/settings.sh  hooks/lib/state.sh  hooks/lib/decide.sh  hooks/lib/gitctx.sh  hooks/lib/aliases.sh (M2a)
hooks/guards/g00-unproven.sh g01-git.sh g02-pr.sh g03-review.sh g04-untrusted.sh g05-commit.sh g06-secrets.sh g13-protected.sh g14-tracker.sh g15-deploy.sh g16-state.sh
hooks/guards/g18-readonly-agent.sh g20-approval.sh                                            (M2a)
kernel/kernel.md  kernel/routes.md (M2a)  kernel/kernel-subagent.md  kernel/context.md  kernel/settings.md
modes/terse.md  modes/terse-subagent.md
skills/<name>/SKILL.md (+ references/, templates/, scripts/ per skill)
agents/implementer.md agents/task-reviewer.md agents/investigator.md
scripts/kern-root scripts/kern-get scripts/kern-dir scripts/kern-detect                       (M1)
scripts/wt-new scripts/wt-check scripts/wt-snap scripts/wt-diff scripts/wt-fork scripts/wt-apply scripts/wt-audit  (M2a)
scripts/ledger-open scripts/task-brief scripts/task-start scripts/task-review scripts/task-done (M2a)
scripts/brief-check scripts/plan-check scripts/recall-sessions                                 (M2a)
scripts/floor-scan scripts/claim-check scripts/probe                                           (M2a: G7 script, G9, G10)
scripts/lib/wt-common.sh scripts/lib/test-paths.awk scripts/lib/floor-scan.awk                  (M2a, sourced or loaded)
skills/diagnose/scripts/find-polluter.sh skills/diagnose/scripts/loop-rate.sh skills/diagnose/scripts/hitl-loop.template.sh (M2a)
```

Dev tooling (not called at runtime): `scripts/lint-skills.mjs`, `scripts/lib/lint-rules.mjs`, `scripts/lib/kernel-rows.mjs` (M2a), `scripts/route-eval.mjs`, `scripts/lib/rank.mjs`, `scripts/check-version.mjs`, `scripts/release.mjs`, `scripts/seeded-diffs.mjs` (M2a), `scripts/exec-eval.mjs`, `scripts/lib/claude-run.mjs`, `scripts/lib/exec-grade.mjs` (M2a), `scripts/behave.mjs`, `scripts/lib/behave.mjs`, `scripts/kernel-adherence.mjs`, `scripts/lib/adherence.mjs`, `scripts/h2h.mjs`, `scripts/lib/h2h.mjs`, `scripts/standing-cost.mjs` (M2b), `scripts/fetch-upstream` (bash). Tests: `tests/*.test.mjs` and `tests/skills/*.test.mjs` (node --test), `tests/hooks/*.bats`, `tests/scripts/*.bats`, `tests/helpers/` (bats helpers `common.bash`, `wt.bash`; node helper `md.mjs`), `tests/fixtures/projects/<case>/`, `tests/fixtures/payloads/*.json`, `tests/fixtures/mode-activation/cases.json`. Every `.bats` file lives under `tests/hooks/` or `tests/scripts/`, the two folders CI runs.

## hooks/hooks.json (final shape after M1; M2 adds nothing; M3 adds Stop)

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/session-start"] }] }],
    "SubagentStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/subagent-start"] }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/prompt-submit"], "timeout": 10 }] }],
    "UserPromptExpansion": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/prompt-submit"], "timeout": 10 }] }],
    "PreToolUse": [{ "matcher": "Bash|Monitor|Write|Edit|NotebookEdit|Skill|CronCreate|ScheduleWakeup|RemoteTrigger|SendMessage|mcp__.*", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use"], "timeout": 20, "onFailure": "block" }] }]
  }
}
```

SessionStart uses an empty matcher and branches on `source` inside the script, because `resume` and `fork` need handling too.

## Hook input and output facts (Claude Code 2.1.296 docs)

- stdin is one JSON object. Common fields: `session_id`, `cwd`, `hook_event_name`, `permission_mode`, `transcript_path`; subagent context adds `agent_id`, `agent_type` (plugin agents are `kern:<name>`).
- SessionStart: `source` in `startup|resume|clear|compact|fork`. Plain stdout is added to context. Cap 10,000 chars per string.
- UserPromptSubmit: `prompt`. Plain stdout is added to context. Also fires for scheduled tasks, background subagent reports and cross-session messages.
- UserPromptExpansion: `expansion_type` (`slash_command`), `command_name`, `command_args`, `command_source`, `prompt`. Plain stdout is added to context.
- SubagentStart: must print JSON `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"..."}}`.
- PreToolUse: print `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow|ask|deny","permissionDecisionReason":"..."}}`, exit 0. Claude Code applies deny > defer > ask > allow across hooks. Printing nothing means no opinion (normal permission flow).
- Exec form: `"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/<name>"]`.

## Library API (hooks/lib, sourced by hooks and by scripts/kern-get)

`json.sh` (POSIX awk; no jq dependency, jq unused even when present so behaviour is identical everywhere):
- `json_get KEY` reads JSON from `$KERN_INPUT`; prints the decoded string value of the first `"KEY":` whose value is a string; handles `\" \\ \/ \n \t \r \b \f`; leaves `\uXXXX` as the literal six characters. Exit 0 found, 1 absent, or 1 when the first `"KEY":` holds a value that is not a string (it does not search further).
- `json_get_raw KEY` prints the raw JSON text of the first `"KEY":` value (object, array, string or literal). Exit 0 found, 1 absent.
- `json_escape` reads stdin, prints it escaped for a JSON string body (no surrounding quotes): `\` and `"`, tab, CR and LF as short escapes, every other byte below 0x20 as `\u00XX`. The output is always a valid JSON string body, whatever bytes a reason echoes.
- `json_ok` exit 0 when `$KERN_INPUT` starts with `{` and ends with `}` after trimming whitespace, else 1.

`settings.sh`:
- `kern_main_root [dir]` prints the main worktree root (first `worktree ` line of `git -C <dir> worktree list --porcelain`, `dir` defaults to the hook's `cwd`). Exit 2 not a git repo.
- `settings_get KEY [DEFAULT]` prints the value; `settings_source KEY` reports where it came from. For `protected_targets`, `never_commit`, `branch.protected` and `deploy.envs` the value is the union of every layer, highest first, joined with `, `; items are trimmed and a repeated item is dropped, keeping the first; the default applies only when no layer sets the key, an empty value in a higher layer clears nothing, and `settings_source` lists every file that sets it. Order: `$MAIN/.claude/kern.local.yml`, `$MAIN/.claude/kern.yml`, `$HOME/.claude/kern.yml`. Exit 0 found or defaulted, 3 unset with no default.
- `settings_unknown_keys` prints `file<TAB>key` for every key not listed in `kernel/settings.md`'s key table.
- File format: one `key: value` per line; `#` starts a comment at line start or after whitespace outside quotes; surrounding single or double quotes stripped; lists comma-separated; leading and trailing whitespace trimmed; later duplicate keys in the same file win.
- `policy_for ACTION` where ACTION is `commit|push|pr|tracker|review.post` prints `ask|auto|deny` from `<action>.policy` (`review.post_policy` for review.post). `pr.policy` value `draft-after-approval` is read as `ask`. Unknown value prints `ask`.
- `kern_enabled` exit 0 unless the resolved `kern` key is `off`.

`state.sh` (session state):
- State dir: `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions`. File `<session_id>.state`, mode 0600, flat `key: value` lines: `voice`, `surface`, `autopilot` (`on|off`), `since` (ISO 8601 UTC).
- `state_file SID` prints the path; refuses a session id that is not `[A-Za-z0-9_-]+` (exit 2).
- `state_get SID KEY` prints the value, exit 1 when unset, 2 for a bad session id or a symlinked state file.
- `state_set SID KEY=VALUE...` atomic: writes a temp file in the same dir with umask 077, then `mv`; refuses when the target is a symlink (exit 2).
- `state_reset SID` writes defaults from settings: `voice` from `mode.voice` (default `normal`), `surface` from `mode.surface` (default `auto`), `autopilot: off`, and `since`.
- `autopilot_on SID` exit 0 only when no settings file (local, shared or user) says `autopilot: denied` and `state_get SID autopilot` is `on`.
- `autopilot_denied_by` prints the first settings file, in precedence order, that says `autopilot: denied`; exit 1 when none does. `prompt-submit` and `autopilot_text` name this file in "denied by <file>".
- `prompt_hashes` (M2a) reads text on stdin and prints, space-separated, one decimal hash per non-blank line of up to 500 characters (the first 20 such lines), after lowercasing, folding runs of blanks to one space, trimming, and dropping a final run of `.` and `!`. The hash is djb2 mod 2^32, computed in awk under `LC_ALL=C`. State key `prompt_hashes: <hashes>` (M2a) is rewritten by `prompt-submit` on every user prompt that is not wrapped; G20 compares an `approved:` quote's hash with it.

`decide.sh` (PreToolUse votes):
- `vote allow|ask|deny GUARD REASON` records a vote; keeps the strictest (deny > ask > allow); concatenates reasons as `G<n>: <reason>` joined by `; `.
- `emit_decision` prints the PreToolUse JSON for the strictest vote; prints nothing when no guard voted. Under autopilot a final `ask` becomes `deny` with reason suffix `(autopilot: nobody to ask)`.
- `fail_closed REASON` used on parse failure: votes `ask` (becomes `deny` under autopilot).

`gitctx.sh`:
- `git_words CMD` splits a shell command string into simple commands on `;`, `&`, `&&`, `||`, `|`, newlines and unquoted `( )` and `{ }`, and prints one record per line (quotes respected; the bodies of `$( )`, backticks and `-c` scripts, and the arguments of `eval`, are also emitted as records). It returns 0 when it succeeds, so callers may run it under `pipefail`. A newline inside a record, such as a quoted multi-line commit message, is printed as `\037`; decode it before reading lines of a message. Here-doc bodies are data and are left out, except a here-doc read by an sh-family shell with no `-c`, whose body is records. `_shell_words` keeps a quoted newline as `\037` inside its word.
- `git_sub CMDLINE` for a simple command whose head is git (basename, any case): prints `<dir><TAB><subcommand><TAB><rest>` after consuming git's global options (`-C <dir>`, `-c <k=v>`, `--git-dir=`, `--work-tree=`, `--no-pager` and the others the code lists). `dir` defaults to the hook `cwd`.
- `in_main_checkout DIR` exit 0 when `git -C DIR rev-parse --show-toplevel` equals `kern_main_root DIR`.
- `branch_protected BRANCH` exit 0 when BRANCH is the settings `base_branch`, the origin/HEAD branch, listed in `branch.protected`, or listed in `deploy.envs`; when origin/HEAD is unknown, `main`, `master`, `trunk` and `develop` are protected too. A `base_branch` setting only adds a protected branch.
- `current_branch DIR` prints the branch `git -C DIR symbolic-ref -q HEAD` names, without `refs/heads/` (not `rev-parse --abbrev-ref`, which prints `heads/<name>` when a tag shares the name). Exit 1 and no output on a detached HEAD.
- `git_words` (M2a Task 33): a record whose head word is an alias `aliases.sh` loaded is printed, then its expansion is split again and printed after it; the expansion's own words are not expanded again. The record stays so that no vote the command got without aliases is lost, and so that a guard that allows only a command whose first record starts with git or gh never allows an alias. A quoted or escaped head word is never an alias. Without `aliases.sh` loaded, nothing changes.

`aliases.sh` (M2a Task 33; loaded by `hooks/pre-tool-use` before `gitctx.sh`, and `aliases_load` runs for the Bash tool only):
- `alias_snapshot`: prints the shell snapshot to read, or exits 1. `KERN_SHELL_SNAPSHOT` names one (tests); otherwise the newest `snapshot-*.sh` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/shell-snapshots`.
- `aliases_load`: sets `_KA_<hex of the name>` (two hex digits per byte) to the expansion of each alias whose expansion holds a word that is git or gh (last path part, any case, quotes removed), and `KERN_ALIASES=1` when there is one; it first unsets any `_KA_` variable already set. Nothing from the snapshot is evaluated: awk reads at most its first 4 MB as text. A missing, unreadable or unparseable snapshot sets nothing, and no failure stops the hook.
- `alias_text CMD`: prints the expansion of each record of `git_words CMD` whose head word is such an alias, one per line. `hooks/pre-tool-use` sets `KERN_ALIAS_TEXT` to it for the Bash tool when `KERN_ALIASES` is set, and G2, G3, G4, G13, G14 and G15 match their text prefilter (gh, push, deploy tool and client names) against the command and `KERN_ALIAS_TEXT`.
- `alias_expand SEG`: sets `ALIAS_EXP` to SEG with its head word replaced; exit 1 when that word is not such an alias. The head word is the first word after unquoted `NAME=value` words, redirections (with a separate target word) and zsh's reserved words `if then elif else do while until ! { time nocorrect coproc` and `repeat` with its count, as zsh finds it; not after `command`, `builtin`, `exec`, `noglob` or `-`, where zsh does not expand.
- Parsing: `alias [--] name=value` lines, a CRLF read as LF; value bare, single-quoted with `'\''`, or backslash-escaped. Skipped: `$'...'` and double-quoted values, unclosed quotes, a control byte in the value, names holding a quote, `/`, `$`, a backtick, a backslash or a byte outside printable ASCII, names over 256 bytes, lines over 4096 bytes, and alias lines after the first 1 MB of them. The head-word chain is followed as zsh does: each name at most once, at most 8 times, while the expansion is at most 4096 bytes.
- Accepted limits: the hook input and environment do not name the session's snapshot (measured 2026-10-14: one snapshot per Claude Code process; the Bash tool runs `zsh -c 'source <snapshot> && eval ...'`), so the newest stands in for it. Not followed: zsh's trailing-space rule, aliases inside an expansion other than its head-word chain, global aliases, an alias after an assignment word holding a quote or `$`, and an alias defined in the same Bash call and run through `eval` or `$( )` (G00 denies an alias definition under autopilot).

## Guard dispatcher (hooks/pre-tool-use)

Reads stdin into `KERN_INPUT`; `json_ok` fails: `fail_closed "hook input not parseable"` (before `kern_enabled` runs, the safe direction). Exits silently when `kern_enabled` fails. Sets `TOOL` from `tool_name` (`Monitor` is guarded as `Bash`), `SID` from `session_id`, `CWD` from `cwd`, `AGENT` from `agent_type` (empty when absent), `AUTOPILOT=1` when `autopilot_on SID`. A field that is present but malformed (json exit 2) in `tool_input`, `cwd` or `agent_type` fails closed; a guard whose function did not load fails closed. Sources every `hooks/guards/*.sh`; each defines `guard_<id>` (for example `guard_g01`) that inspects `TOOL` and `TOOL_INPUT` and calls `vote`. `KERN_GUARD_IDS` lists the expected guards; a guard file that fails to source, or an expected id with no function, fails closed with G0 "guard <id> did not load". A guard that does not apply votes nothing. Calls them in file order, then `emit_decision`. `KERN_GUARDS` (comma list such as `g01,g05`) limits which run, and is honoured only when `BATS_TEST_FILENAME` is set.

Guard ids and milestones: g00 g01 g02 g03 g04 g05 g06 g13 g14 g15 g16 (M1); g18 g20 (M2a); g17 g19 (M3). `KERN_GUARD_IDS` in `hooks/pre-tool-use` lists them, and a test checks it against the guard files. G20 (approvals quote the user) has its row in design spec 8.3; its contract is under "Additions from the M2a and M2b plans" below.

A guard that votes `allow` approves the whole Bash call, so it proves the full command shape first and falls back to ask (deny under autopilot) for anything it cannot prove; G1's push allow is the model. `settings.sh` `list_has` accepts `a, b` and `[a, b]`. The `_gh_*` helpers in `hooks/guards/g02-pr.sh` (`_gh_load`, `_gh_args`, `_gh_opts`, `_gh_last`, `_gh_only`, `_gh_pos`, `_gh_literal`, `_gh_proven`, `_gh_file_ok`) parse gh flags against gh 2.100's tables and prove a gh command's shape; G3 and G4 use them, and every guard file is sourced before any guard runs.

`_G01_GIT_CMDS` in `hooks/guards/g01-git.sh` lists git 2.54's own commands (`git --list-cmds=builtins,main`, less `pack-redundant` and `whatchanged`). `_g01_foreign` makes G1, G5 and G6 ask, and deny under autopilot, for any git subcommand outside that list, and for any option word left after G1's global-option loop except those that end git (`-v`, `--version`, `-h`, `--help`, `--exec-path`, `--html-path`, `--man-path`, `--info-path`, `--list-cmds=*`); it reads no config. Every guard git call that can refresh the index (G6's diffs and the check-ignore in `_gh_file_ok`) runs with `-c core.fsmonitor=false`, and every `git log` with `--no-show-signature`. G6 runs its git reads under `with_timeout`; an overrun asks "secret scan did not finish".

`_cmd_words` reads `NAME=value` and `NAME+=value` as assignments, and compares wrapper and shell names in any case. `cw_opt` holds the long options that take a value: env `--chdir --unset --split-string --argv0`; sudo `--user --group --host --prompt --chdir --chroot --role --type --close-from --other-user --command-timeout`; nice `--adjustment`; timeout `--signal --kill-after`. A git or gh that appears later in a command whose head is something else is hidden.
- `_g01_hidden` asks, and denies under autopilot, in either of two cases. The first: the next word after git's global options is in `_G01_GIT_CMDS` and outside `_G01_READ_ONLY`. The second: the hidden git carries `-c` or `--config-env`, whatever word follows. A hidden git with no word after it gets no vote.
- `_g02_hidden` asks when the next gh word is in `_G02_GROUPS`. That list holds gh 2.100's groups and their aliases, less browse, search and status.
Neither ever votes allow.

G13, G14 and G15 (Task 13):
- **G13** proves a read to a `protected_targets` entry and denies anything else in both modes; it fails closed when its awk judge errors. It never unwraps a remote `cmd` or `powershell` wrapper (a wrapper denies), and an SQL statement passes only with plain lexing: no comments, backslashes, dollar-quotes, E-strings, doubled quotes or double-quoted strings.
- **G14** allows only the closed per-family MCP list and the proven gh issue/label shape under `tracker.policy: auto`.
- **G15** never allows. It asks (deny under autopilot) when a deploy tool appears at any word with its verb after it.
- **Shared rules:**
  - Each guard strips quotes from whole command text in one `LC_ALL=C tr` pass. Never with `${var//[...]/}`, which is cubic under bash 3.2 in a UTF-8 locale.
  - `git_words` returns 0 when it succeeds, so callers may run it under `pipefail`.
- **G5 convention:** when `commit.convention` is unset, G5 checks the subject against the convention `scripts/kern-detect commit.convention` finds in git log; an explicit empty `commit.convention:` turns the check off.
- **Vote output:** the dispatcher's JSON is valid for any reason text, because `json_escape` escapes every control byte.
- **Lease push to a protected branch:** G1 denies it unless every commit it carries and every commit it would drop from the remote branch is the user's; otherwise it asks, and the reason names `--force-with-lease`.
- **G00 (`hooks/guards/g00-unproven.sh`), autopilot only:** (label G00, apart from `fail_closed`'s G0) denies a Bash record kern cannot read. That covers a command name built at run time (`$g`, `"$@"`, `$'...'`, `$(...)`, a glob or brace head), an sh-family shell whose options or script kern cannot parse, sh-family `-c` behind xargs, find -exec, setsid or docker exec, a shell reading a pipe, here-string, fd or process substitution, an alias definition, eval of run-time text, and source of stdin, an fd or a process substitution. Non-sh interpreters' inline code and here-docs, script files, and a `$VAR/literal-path` program or script operand are accepted limits. Interactive mode is unchanged.
- **Shell scripts:** `git_words` reads an sh-family `-c` in any flag cluster and either case, after `--`, past value long options such as `--rcfile`, by bash's rules and by zsh's. `env -S` and `--split-string` split their command line with quotes, as env does. A `<<` inside `${ }`, `$[ ]` or a `NAME[ ]` subscript is not a here-doc.
- **Settings precedence:** a committed `.claude/kern.yml` cannot set `kern: off`, loosen a `*.policy` or `review.post_policy` to `auto`, or set `rebase.push: autopilot`; those read as unset. Only the user file and a local `.claude/kern.local.yml` can, and the local file only when it is a regular, untracked, non-symlink file in a real `.claude` directory (no symlink, no submodule, no gitlink) that is physically the main worktree's own.
- **G16 and settings files:** any command that is not a reader, or a redirect, that names a kern settings file or a Claude Code settings file (`.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`), or that writes into a `.claude` directory, asks (deny under autopilot). Git subcommands that write the work tree count as writers. Write, Edit and NotebookEdit on Claude Code settings ask too.
- **gh:** `_gh_canon` maps gh 2.100's aliases (`pr new`, `co` and the rest) to the command they name. A first word outside gh's own command list (`_GH_CMDS`), meaning an alias or an extension, asks, and so do `gh alias set|import|delete` and `gh extension install|upgrade|exec`.
- **G1 and G6, other ways out:** a `-C` push into another repository never allows. `env -C` and `sudo -D` count as a directory change. `git send-pack` and `http-push` are unproven pushes, and G6 cannot scan them. `git send-email` and `imap-send` are floor actions. G6 asks "secret scan may be stale" when the same call changes the index or HEAD before a commit or push.
- **G3:** an unlabelled `gh pr comment` asks (deny under autopilot); under `review.post_policy: auto` only a labelled comment allows.

## Scripts (KERN/scripts, bash, executable, `set -euo pipefail`, run as `bash ${CLAUDE_PLUGIN_ROOT}/scripts/<name>`)

| Script | Signature | Output | Exit |
|---|---|---|---|
| `kern-root` | `kern-root [dir]` | line 1 `MAIN`, line 2 git common dir | 0; 2 not a repo |
| `kern-get` | `kern-get KEY [DEFAULT]` | `value<TAB>source` | 0; 3 unset, no default |
| `kern-dir` | `kern-dir SUB` | absolute `WORK/SUB` path (created); first call appends `/<work_dir>/` to `<common-dir>/info/exclude` and prints `kern: added /.kern/ to .git/info/exclude` on stderr | 0; 2 `git ls-files <work_dir>` non-empty |
| `kern-detect` | `kern-detect KEY` for `base_branch`, `branch.pattern`, `commit.convention`, `test.focused`, `test.full`, `typecheck`, `lint`, `build`, `tracker`, `pr.template` | `value<TAB>evidence` | 0; 3 not detectable |
| `wt-new` | `wt-new SLUG [--detach] [--base REF] [--branch NAME]` | worktree path | 0; 2 error (including a `branch.pattern` placeholder it cannot fill without `--branch`) |
| `wt-check` | `wt-check WT BASE_REF` | `ok` or the first mismatch | 0; 1 mismatch; 2 usage |
| `wt-snap` | `wt-snap WT` | tree id | 0; 2 error |
| `wt-diff` | `wt-diff WT FROM_TREE [TO_TREE] [--out FILE] [--allow PATH]... [--allow-file FILE]` | line 1 package path, line 2 `TO_TREE`, then changed paths; with an allow list, each changed path outside it on stderr as `wt-diff: outside the allowed paths: <path>`. An entry covers the same path, every path under it when it ends in `/`, every path starting with it when it ends in `*`. The package diffs run with `--no-ext-diff --no-color`; `<package>.patch` is `git diff-tree -r -p --binary --full-index` | 0; 3 empty diff; 4 a path outside the allow list (package still written); 2 error |
| `wt-fork` | `wt-fork SRC_WT SLUG` | fork path (the state moves as a `diff-tree` patch) | 0; 3 apply failed; 2 `worktree.setup` failed or other error; on 3 and on a setup failure the fork is removed |
| `wt-apply` | `wt-apply PATCH DST_WT` | `applied` | 0; 3 conflict; 2 usage |
| `wt-audit` | `wt-audit [--days N]` | `bucket<TAB>path<TAB>branch<TAB>evidence` per kern worktree; buckets `merged`, `open-pr`, `closed-pr`, `uncommitted`, `committed`, `empty`, `unknown` (a git call failed or the base ref did not resolve; evidence names which; never proposed for teardown) | 0; 2 usage |
| `ledger-open` | `ledger-open PLAN [DIR]`; `ledger-open --summary DIR` | the ledger dir; with `--summary`, the `Decision:`, `parked:`, `Preflight:` and deferred-minor lines, then `main: unchanged` or `main: changed; ...` | 0; 2 plan not approved with the user's quoted words, or DIR holds another plan's ledger; `--summary` 1 when the main checkout changed |
| `task-brief` | `task-brief PLAN N LEDGER_DIR` | brief path `LEDGER_DIR/briefs/task-N.md` | 0; 2 task not found |
| `task-start` | `task-start LEDGER N TREE` | appends `Task N: start tree=<id> at=<iso>` | 0; 2 bad argument |
| `task-review` | `task-review LEDGER N TREE ROUND SPEC QUALITY [--minor TEXT]...` | appends `Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>` and one `Task N: minor (deferred): <text>` per `--minor` | 0; 2 bad argument |
| `task-done` | `task-done LEDGER N WT TREE (--probe PATCH \| --no-probe REASON) -- CMD...` | runs CMD in WT; on success appends `Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok or skipped (reason)> last=<line>`; an inconclusive probe prints probe's first line and appends nothing | 0; 2 tree changed, no approved review of it, or neither --probe nor --no-probe with a reason; 1 the probe shows the test passes without the change; 3 the probe is inconclusive; else CMD's exit code (stderr `command exited <n>`) |
| `brief-check` | `brief-check FILE` | `brief-check: ok`, or `missing: <FIELD>`, `empty: <FIELD>`, `placeholder: <FIELD>` (text still the brief template's, FORBIDDEN not checked), `VERIFY must start with the wt-check entry check` | 0; 1 problems; 2 usage |
| `plan-check` | `plan-check FILE`; `plan-check --graph PLAN`; `plan-check --files PLAN N` | `FILE:LINE: message` per problem; `--graph`: `overlap<TAB>A<TAB>B<TAB><shared>` and `wave<TAB><n><TAB><tasks>`; `--files`: one path per line, a trailing `/**` or `/*` printed as the directory with a trailing `/` | 0; 1 problems; 2 usage or no such task |
| `recall-sessions` | `recall-sessions [--days N] [--topic TEXT]` | `session<TAB><iso><TAB><id><TAB><bytes><TAB><path>`, newest first; with `--topic`, `prompt<TAB><iso><TAB><id><TAB><text>` lines for this project only | 0; 2 usage |
| `floor-scan` | `floor-scan DIFF_FILE` | one line per hit `path:line<TAB>class<TAB>text`; classes `silenced-checker`, `test-made-easier`, `test-deleted`, `assertion-removed`, `unfinished-work`, `debug-print`, `bar-lowered` | 0 clean; 1 hits; 2 unreadable or no `diff --git` header |
| `claim-check` | `claim-check WT DIFF_FILE` | one line per unreachable SHA or absolute word | 0 clean; 1 hits; 2 usage |
| `probe` | `probe [--exclude-tests] WT PATCH -- CMD...`; `probe --mutate FILE:LINE WT -- CMD...` | `probe: fail-then-pass ok` / `probe: test did not fail with the guard removed` / `probe: mutation caught (<line>)` / `probe: mutation survived (<line>)` / `probe: inconclusive (<why>)` | 0 ok; 1 not covered or mutation survived; 3 inconclusive; 2 usage |

`worktree.dir` default: `MAIN/.claude/worktrees`. Branch for `wt-new` (non-detached): `branch.pattern` with `{slug}` substituted, else `kern/<slug>`. A script that sets `MAIN` exports `KERN_MAIN="$MAIN"` before reading settings.

Skill scripts (run as `bash ${CLAUDE_PLUGIN_ROOT}/skills/diagnose/scripts/<name>`): `find-polluter.sh POLLUTION_PATH TEST_GLOB -- TEST_CMD...` (1 with `polluter: <file> creates <path>`; 0 with `no polluter found among <n> test files`; 2 usage, no matching file, TEST_CMD not found, the path already present, a run that exits 126 or 127, or every run failing with no polluter) and `loop-rate.sh N -- CMD...` (`loop-rate: <red>/<N> red, median <seconds>s`; 0; 2 usage, CMD not found, or a run that exits 126 or 127).

### Working directory

`WORK` is `MAIN/<work_dir>`, default `.kern`, created by `kern-dir SUB`. The folders skills name: `WORK/specs/` (define), `WORK/plans/` (plan), `WORK/ledgers/` (execute-plan, one folder per plan slug), `WORK/reviews/` (wt-diff's default package folder), `WORK/tmp/` (commit messages and PR bodies a guard reads), `WORK/notes/` (kernel/context.md), `WORK/pages/` (M4), `WORK/decisions/` (M3).

### Ledger lines

The lines `ledger-open`, `task-start`, `task-review`, `task-done` and execute-plan write, verbatim as `skills/execute-plan/references/ledger-format.md` gives them:

- `# kern ledger: <plan path>`
- `Main: <root> branch=<name> status=<hash>`
- `Worktree: <path> branch=<name> base-tree=<id>`
- `Preflight: Task A x Task B: <shared file or interface>: <ruling>`
- `Decision: <what>; why: <one line>; cost if wrong: <one line>`
- `Task N: start tree=<id> at=<iso>`
- `Task N: review round=<r> tree=<id> spec=<compliant or issues> quality=<approved or needs-fixes>`
- `Task N: minor (deferred): <text>`
- `Task N: fix round=<r> tree=<id>`
- `Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok or skipped (reason)> last=<line>`
- `Wave: tasks <list> forks=<paths>`
- `Applied: Task N patch=<path>`
- `parked: <question>; default: <choice>; why: <one line>`

Short forms skills name in prose: `Task N: complete`, `Task N: start`, `Main:`, `Worktree:`, `Preflight:`, `Decision:`, `Wave:`, `Applied:`, `parked:`.

## Settings keys owned by M1 (documented in kernel/settings.md)

Every key in spec A5 plus design 5.4, one row each: key, default, values, read by. Lint rule 13 checks hooks and kernel/settings.md agree.

## Kernel rendering

Template placeholders: `{VERSION}` (plugin.json version), `{ROOT_PATH}` (absolute `${CLAUDE_PLUGIN_ROOT}`, printed once in the header), `{ROOT}` and `{KERN}` (left literal in the rendered kernel; the header line defines them as the plugin root and `{ROOT}/skills`, user decision 2026-10-12), `{SETTINGS}` (settings summary), `{MODE}` (one line `kern mode: voice=<v> surface=<s> autopilot=<on|off>`), `{AUTOPILOT}` (`off` or `ON since <iso>`). Rendering uses awk (`hooks/lib/render.sh`), so values may hold any character.

## Commit conventions in the kern repo

Subject `M<n>: <imperative summary>` (72 chars or fewer), body says why. No attribution trailers. Stage named files only (`git add -- <paths>`), never `-A`. Commits happen at each task's last step because the user approved this plan; pushes happen only when the user says so.

## Additions

(Plans append names here when they need one not listed above.)

### Additions from the M2 plan

- Lint and rank APIs: M2 uses "M0 as written (binding)" below. M2 appends rules 5, 9 and 12 to `RULES` in `scripts/lib/lint-rules.mjs`.
- Kernel route row format (M1): a markdown table row in `kernel/kernel.md`: `| <when, observable> | Read {KERN}/<skill>/SKILL.md |`; a row that routes to a kernel file reads `| <when> | Read {ROOT}/kernel/<name>.md |`. M2's `scripts/lib/kernel-rows.mjs` exports `kernelRows(kernelText) -> { when, route }[]` and parses both forms (`route` is the skill name or the kernel file's basename).
- Kernel rows as route-eval owners (M2): `targets()` adds `{ name: 'row-<route>', text: <when>, kind: 'row' }` after the skills and before the distractors; each row has a case file `evals/cases/row-<route>.json` in addy's shape with `skill_name: "row-<route>"`; `evaluate()` treats `row-<x>` and `<x>` as the same owner (helper `ownerOf(name) = name.replace(/^row-/, '')`) for positives, negatives and collisions.
- Help map format (M1): `skills/help/references/map.md` holds one table with header `| Skill | Tier | Reached by | Job |`; one row per installed user-reachable skill, its first cell the skill name in backticks (``| `prove-it` | auto | ... |``), the only form lint rule 6 counts. Each M2a skill task appends its own row.
- `wt-new` gains `--branch NAME` (full signature `wt-new SLUG [--detach] [--base REF] [--branch NAME]`); a SHA-shaped `--base` is used as a commit with no fetch, any other base must fetch from origin or the script exits 2.
- `wt-diff` also writes `<package>.patch` (`git diff --binary FROM TO`); `wt-apply` consumes that file.
- `scripts/lib/wt-common.sh` (sourced by `wt-new` and `wt-fork`): `wt_dir`, `wt_exclude_dir DIR`, `wt_include DST`, `wt_setup WT`, `wt_path_free PATH`. The setup marker is `<worktree git dir>/kern-setup-done`.
- Upstream paths as M0's `fetch-upstream` lays them out: `.upstream/superpowers/skills/...`, `.upstream/pstack/pstack/skills/...` (cursor/plugins clone), `.upstream/pocock/skills/engineering/...`, `.upstream/addy/skills/...`, `.upstream/local/recall/SKILL.md`, `.upstream/local/comment-sicko.md`.
- M1 payload-spike record (M1): `docs/spikes/m1-payloads.md` with a line `agent_type in subagent PreToolUse: <value or absent>`. M2 Task 7 reads it.
- G18 tests drive `hooks/pre-tool-use` with `KERN_GUARDS=g18`, `CLAUDE_PLUGIN_DATA` pointing at a temp dir, and a state file `sessions/<sid>.state` holding `autopilot: on` for autopilot cases; they expect no output when G18 does not vote.
- `kern-dir SUB` (M1) accepts a nested SUB such as `ledgers/<plan-slug>` and creates every level; execute-plan relies on it.
- Lint rule 9 (M2) requires `## Steps` as the first H2 of every slash skill and `## Steps` in every auto skill; M1's `mode`, `autopilot` and `help` should open with `## Steps`, and `unslop` (a rule document) gets a rule-9 exemption with a reason. Path skills are left to M1's rule 6.
- Lint rule 12 (M2) and route-eval need a case file `evals/cases/row-<route>.json` for every kernel row, including M1's `technical-writing` and `context` rows; M2 Task 21 writes them, assuming the row texts "Prose others read: PR body, issue, doc, commit message" and "Phase ends, or context is filling".
- Bats tests run through `tests/run-bats`, which on macOS puts `/bin/bash` 3.2 first on PATH. bash 3.2 ignores a false `[[ ]]` in the middle of a test, so every `[[ ]]` assertion ends with `|| false`, and `tests/run-bats` refuses to run while any `.bats` file has a bare one. Scripts stay bash 3.2 compatible.

### M0 as written (binding; supersedes any differing lint or rank shape above)

- `scripts/lib/frontmatter.mjs`: `parseFrontmatter(src) -> { data, body, error }` (single-line `key: value` only; block scalars are an error).
- `scripts/lib/lint-rules.mjs`: `loadModel(root) -> { root, skills, agents, exemptions, shipped, kernelText, cases }`. Skill: `{ name, dir, file, tier: 'auto'|'path'|'slash', data, body, error }` where `data` is the frontmatter object; tier is `auto` without `disable-model-invocation: true`, `path` when `kernelText` contains `Read {KERN}/<name>/SKILL.md`, else `slash`. Agent: `{ name, base, file, data, body, error }`. `shipped`: absolute paths of every file under `skills/ agents/ kernel/ modes/ hooks/`. `cases`: basename of `evals/cases/*.json` to parsed JSON or `{ parseError }`.
- `RULES`: array of `{ id: number, check(model) -> Finding[] }`; `Finding = { rule: number, path: string (repo-relative), level: 'error'|'warn', message: string }`. Helpers inside the module: `err(rule, path, message)`, `warn(rule, path, message)`, `rel(model, absPath)`. Add a rule by appending to `RULES` and adding tests to `tests/lint-rules.test.mjs` (helpers there: `repo(files)`, `skill(name, fmLines, body)`, `lint(files)`, `rules(findings)`). `runLint(model)` drops findings covered by an exemption with a reason.
- M0 ships rules 1, 2, 3, 4, 8, 10, 11 (lint-rules.mjs) and 14 (scripts/check-version.mjs). M1 adds 6, 7, 13, 15. M2 adds 5, 9, 12.
- `scripts/lib/rank.mjs`: `tokenize(text)`, `termFreq(tokens)`, `vec(tf, idf)`, `cosine(a, b)`, `buildCorpus(docs: {name, text}[]) -> { docs: Map, idf }`, `rank(prompt, corpus) -> {name, score}[]` descending, `similarity(nameA, nameB, corpus)`.
- `scripts/route-eval.mjs`: `targets(root) -> {name, text, kind}[]` with owners first and `kind: 'distractor'` entries last (from `evals/distractors.json`); `evaluate(root, { minRank1 }) -> { errors, warnings, rank1Rate }`; case file per owner at `evals/cases/<name>.json` in addy's shape; minimums 3 positive, 2 negative, 1 eval; `evals/baseline.json` `{ "min_rank1": n }`, raised by `--update-baseline`. M0 owners are auto skills only; agents are not ranked.
- `scripts/ci-local` and `.github/workflows/ci.yml` job `checks`: later milestones append steps to both, in the same order.

### Additions from the M1 plan

- `json.sh`: `json_get` and `json_get_raw` also exit 2 on malformed input (unterminated string). `ti_get KEY` reads `$TOOL_INPUT`, the raw `tool_input` JSON the dispatcher sets.
- `settings.sh` also provides `settings_source KEY` (file or `default`; `settings_get` runs in command substitution, so it cannot set `SETTINGS_SOURCE` for the caller), `settings_keys FILE`, `settings_known_keys`, and `list_has LIST ITEM`.
- New library `hooks/lib/render.sh`: `render_template FILE` (awk literal replacement of `{VERSION}`, `{ROOT_PATH}`, `{MODE}`, `{AUTOPILOT}` from `K_*` variables; a line that is exactly `{SETTINGS}` or `{VOICE}` becomes that value; replaces the contract's sed rendering), `kern_version`, `mode_line SID`, `autopilot_text SID`, `settings_summary`, `KERN_FLOOR_KEYS`.
- New file `modes/terse-subagent.md`: the one-line terse voice for subagents (the full `modes/terse.md` would break the 1,200-character subagent budget).
- `decide.sh`: the reason printed is the winning level's reasons, each `G<n>: <reason>`, joined by `; `, prefixed `kern `. `fail_closed` votes as `G0`.
- `gitctx.sh` also provides `_split_words`, `_subst_bodies`, `_shell_words`, `cmd_head`, `current_branch`, `base_branch_name`, `push_targets DIR REST` (skips redirections; prints `*` for `--all`, `--mirror`, `--branches` or a wildcard refspec, and `branch_protected '*'` is true), `with_timeout SECS CMD...`, `gh_sub CMDLINE` (`<group> <verb>`, or `<group>` alone when only one word follows; matches gh on the lowercased basename and skips `-R <v>`, `--repo <v>` and `--repo=<v>`), `word_value WORDS FLAG...`, `word_has WORDS FLAG...`.
- Dispatcher variables a guard reads: `TOOL`, `TOOL_INPUT`, `AGENT`, `CWD`, `SID`, `KERN_MAIN`, `AUTOPILOT`.
- `kern-dir SUB`: SUB is one or more lowercase segments of letters, digits and dashes joined by `/` (for example `ledgers/plan-a`). `branch.pattern` uses `{id}` and `{slug}`; `test.focused` uses `{file}`, or `{dir}` (go) or `{name}` (cargo) where a file cannot be targeted.
- New settings key `mcp.write_servers` (G14). G14 also covers `gh issue` and `gh label` writes. G16 also denies CronCreate, ScheduleWakeup, RemoteTrigger and SendMessage calls whose prompt or message starts with `/kern:autopilot`, `/kern:mode`, `/autopilot` or `/mode`, and Skill calls for those skills. G16 votes ask on writes to `.claude/kern.yml`, `.claude/kern.local.yml` and `~/.claude/kern.yml` (deny under autopilot), because those files set guard policy.
- `tests/run-bats ARGS...` runs bats with `/bin/bash` first on PATH on macOS. `tests/helpers/common.bash` also provides `kern_env DIR`, `payload EVENT FIELDS`, `bash_payload CMD`, `run_guard PAYLOAD [GUARDS]`, `decision_of OUTPUT`, `set_autopilot on|off`, `fake_gh`, `tool_payload TOOL FIELDS` (use it for a payload whose tool_input has several fields: bash 3.2 brace-expands a literal JSON object inside `"$( )"`).
- Lint rule 6 (M1) also resolves `Read {ROOT}/<path>` rows (the context route), and checks the help map's first column (`` | `<skill>` | ``). M1 consumes the "M0 as written" model (`loadModel`, `RULES` entries `{ id, check(model) }`, findings `{ rule, path, level, message }`), not the earlier `ctx` shape above.
- `scripts/lint-exemptions.json` gains `{ "rule": 6, "path": "skills/hello/SKILL.md", ... }`; M2 removes it with the `hello` skill.

### Additions from the M2a and M2b plans

These supersede the "Additions from the M2 plan" entries above where they differ.

- **Routed file (M2a, pre-flight F3).** M2's eight route rows live in `kernel/routes.md`, a table in the kernel row format (`| <when> | Read {KERN}/<skill>/SKILL.md |`) that the session never loads; the kernel keeps M1's two rows and its Routing rule says: "match the task against the table below, then Read {ROOT}/kernel/routes.md and match its rows when the task builds, fixes, plans, reviews, resumes or claims done", followed by "Several matches: define and diagnose before build. Non-trivial work with no match: plan." `{KERN}` and `{ROOT}` in `routes.md` are resolved by the reader, as the kernel header defines them. A routed task's first two tool calls are therefore the Read of `routes.md` and the Read of the route (the two-hop rule the M2b adherence grader accepts).
- `scripts/lib/kernel-rows.mjs` (M2a): `kernelRows(text) -> { when, route }[]` (both row forms) and `routeText(model) -> string` (the kernel and `routes.md`, joined). `loadModel` gains `routesText` (`''` when the file is absent), and a skill routed from either file is `tier: 'path'`.
- Lint rules as of M2a: rule 5 also reads `routes.md`; rule 6 checks the rows of both files and errors when `routes.md` has rows the kernel never names; rule 7 errors when `kernel/routes.md` exceeds 1,500 chars and when the standing cost (the kernel rendered with no settings, plus every auto skill and agent description) exceeds 4,800 chars, and still warns above 4,000 for the kernel with the longest fixture settings; rule 9 requires `## Red flags` (`| Thought | Reality |`, 2 to 6 rows) in prove-it, implement, diagnose, define, execute-plan, commit and finish-branch; rule 12 needs `evals/cases/row-<route>.json` for every row of both files; rule 16 (contract drift) is described in the header of this file.
- `scripts/route-eval.mjs` (M2a): `targets()` adds `{ name: 'row-<route>', text: <when>, kind: 'row' }` for the rows of both files, after the skills and before the distractors; `ownerOf(name) = name.replace(/^row-/, '')`; `evaluate(root, { minRank1, minHeldout })` also returns `heldoutRate`, the rank-1 rate of `evals/heldout.json` (`[{ "owner": "<route or auto skill>", "prompt": "..." }]`). The CLI applies `max(evals/baseline.json min_rank1, evals/floors.json rank1)` to the case positives and `evals/floors.json heldout_rank1` to the held-out set. `evals/floors.json` is `{ "rank1": 85, "heldout_rank1": 32 }`; `tests/route-eval-rows.test.mjs` pins it and pins `evals/heldout.json` by its sha256, so neither is tuned to pass. The baseline still only rises.
- **G20 (M2a), approvals quote the user.** On a Write or Edit of any Markdown file (`.md`, `.markdown`) whose frontmatter, as the file will be after the call, sets `status: approved` (bare or quoted), unless the file already had that status and the same `approved:` line: deny under autopilot; deny without `approved: <date>, "<quote>"` in that frontmatter. For an Edit, the post-edit text is the file with `old_string` replaced by `new_string` (every match when `replace_all` is true); deny when the quote normalized is on the non-answer list (`sounds good`, `whatever you think`, `whatever`, `up to you`, `your call`, `you decide`, `i guess`, `maybe`, `not sure`, `looks fine i guess`); deny when its `prompt_hashes` hash is not in the session's `prompt_hashes`; deny when the file is newer than the session state file. On Bash: deny when a simple command writes a Markdown file (a redirect; a `.md` argument of `sed -i`, `perl -i`, `awk` or `gawk -i inplace`, `ed`, `ex`, `tee` or `truncate`; `dd of=`; the last argument of `cp`, `mv` or `install`; a `.md` argument of a script interpreter when the command holds `approved`) and the command holds `approved`, or the target is approved now, or a `cp`, `mv` or `install` source is an approved Markdown file. Never votes allow. Accepted limits: a write that hides both the path and the word; an unrelated Markdown file that sets `status: approved` is checked too.
- Approval line format (M2a): `status: approved` and `approved: <YYYY-MM-DD>, "<one whole line of the user's message, verbatim>"`, set in one edit. `ledger-open` and `plan-check` accept an approved file only with both.
- Spec frontmatter (M2a): `status: draft | approved | draft (parked under autopilot)`, `form: full | short`, `date`, `approved`, `issue`. A spec has a `## Constraints` section with `- Always:`, `- Ask first:` and `- Never:` lines that plan copies into Global Constraints. `form: short` keeps only Problem, Constraints, Acceptance criteria and Test seams.
- Plan frontmatter (M2a): `status`, `spec`, `issue`, `base`, `approved`, `execution`, `commits: ask`. A task has `**Files:**`, `**Interfaces:**` (`- Consumes:`, `- Produces:`), `**Blocked by:**` (`none` or `Task K`, earlier tasks only), `**Acceptance:**` and a `Run:`/`Expected:` pair; `plan-check` enforces each.
- Seeded-diff set (M2a): `evals/seeded-diffs/base/`, `evals/seeded-diffs/<id>.diff`, `evals/seeded-diffs/labels.json` (`[{ "id", "expect": ["<class>", ...] }]`, an empty `expect` for a decoy); `node scripts/seeded-diffs.mjs [--compare-addy]`.
- Exec evals (M2a): `evals/exec/cases.json` (`[{ "id", "autopilot", "branch", "pr"?, "settings"?, "setup": [<shell>], "turn" }]`), `evals/exec/bin/gh` (logs to `$KERN_EXEC_LOG`, answers from `$KERN_EXEC_PR`), `evals/exec/fixtures/app/`. `scripts/lib/claude-run.mjs` exports `ISOLATION` (`--setting-sources project --strict-mcp-config --no-session-persistence`), `PERMISSIONS` (`--permission-mode acceptEdits --allowedTools "Bash Edit Write Read Glob Grep Agent Task Skill TodoWrite"`), `workspace`, `runClaude`, `toolUses`, `finalText`, `claudeVersion`.
- Snapshots (M2a and M2b): opt-in runs that spend tokens write `evals/snapshots/<suite>-[<variant>-]<model>-<YYYY-MM-DD>.json` (`exec-<date>.json` and `standing-cost-<date>.json` carry no model in the name) with the model, `claude --version`, `ISOLATION`, `PERMISSIONS` and per-case results; snapshots are committed. Raw runs and head-to-head keys go to `evals/results/` (gitignored), never into a snapshot.
- Fixture layers (M2b): `evals/fixtures/<name>/` holds composable layers (`node-bug`, `approved-spec`, `approved-plan`, `project-skill`, `two-modules`, and M2a's `recall-ledger`); a case's `files` lists them in order, the first one a project with a `package.json` (the M0 eval format's `files`). `stage(root, files)` in `scripts/lib/behave.mjs` copies several into one temp dir; `workspace` (M2a) renames `_kern` and `_claude`.
- Behavioural runner (M2b, coverage gap 13): `scripts/lib/behave.mjs` exports `stage`, `loadCases`, `digest`, `graderPrompt`, `parseVerdict`, `caseResult`. `node scripts/behave.mjs [--case <id>] [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]` runs every `evals[]` entry of `evals/cases/*.json` except `row-*.json`, and every case of `evals/behave/pressure.json` and `evals/behave/workflows.json` (`[{ "id", "files"?, "pressure"?: [...], "origin"?, "branch"?, "setup"?, "max_turns"?, "prompts": [...], "expectations": [...] }]`); an isolated grader call per run returns `{"results":[{"n","pass","evidence"}]}`; a case passes on two of three valid runs with at most one invalid.
- Kernel adherence (M2b, coverage gap 10): `scripts/lib/adherence.mjs` exports `rowPrompt`, `inlineRows`, `TODO_TOOLS`, `readSteps`, `normalize`, `routeCall`, `routesCall`, `grade(events, { route, routeFile, steps, root, kind, projectSkill })` with `kind` `positive` (default), `negative` or `multi-turn`; a route counts only as a Read of `<plugin root>/<route file>` (`skills/<route>/SKILL.md`, or `routeFile` such as `kernel/context.md`) or a Skill call to `kern:<route>`, as the first tool call (todo tools aside) or the second after a Read of `<plugin root>/kernel/routes.md`. `node scripts/kernel-adherence.mjs [--case <id>] [--runs N] [--model <m>] [--variant routed|inline-rows] [--dry-run]`, or `--transcript <jsonl> --route <r> [--root <dir>]`; cases in `evals/adherence/cases.json` (`[{ "id", "kind", "route" | null, "route_file"?, "files", "prompts"? (positives take `evals/cases/row-<route>.json` `evals[0].prompt`), "settings"?, "project_skill"?, "origin"?, "branch"?, "setup"? }]`).
- Head-to-head (M2b): `evals/h2h/arms.json` (`[{ "id", "plugin": "<path>" | null }]`: kern `.`, superpowers `.upstream/superpowers`, pocock `.upstream/pocock`, control `null`); a task is `evals/h2h/<category>/<task>/` with `task.json` (`{ "category", "project"?, "prompts", "rubric", "area", "test"?, "visible"?, "spec"?, "traps"?, "patch"?, "patch_message"?, "origin"?, "branch"?, "setup"?, "max_turns"? }`), `repo/`, and per category `heldout/` plus `reference.patch` (diagnose), `change.patch` plus `labels.json` (`[{ "id", "kind": "bug" | "decoy", "file", "match", "what" }]`, review). `scripts/lib/h2h.mjs` exports `CATEGORIES`, `loadArms`, `loadTasks`, `blindIds`, `redact`, `outOfArea`, `falseAlarms`, `gate`, `graderPrompt`, `parseGrades`. `node scripts/h2h.mjs [--category <c>] [--task <c/id>] [--arms a,b] [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]`; the grader reply is `{"grades":[{"id":"arm-A","score":0-10,"matched","decoys","unmatched","unsupported","why"}]}`; `evals/results/h2h-<date>/key.json` is `{ "<date>:<task>:<run>": { "<arm>": "arm-<letter>" } }`, written after grading.
- Standing cost in tokens (M2b): `scripts/standing-cost.mjs` exports `inputTokens(usage)` and `median(xs)`; `node scripts/standing-cost.mjs [--runs N] [--model <m>] [--dry-run]` prints `standing cost: <delta> input tokens (median of N; with kern <a>, without <b>)`.
- Pilot prompts (M2b): `evals/heldout-pilot.json`, same shape as `evals/heldout.json`, frozen by its sha256 in `tests/route-eval-rows.test.mjs`; `evaluate()` also returns `pilotRate`, reported with no floor.
