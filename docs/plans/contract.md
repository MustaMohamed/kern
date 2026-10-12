# kern M0 to M2: shared plan contract

Every plan file (m0, m1, m2) uses these names, signatures, paths and exit codes exactly. A plan that needs something not listed here adds it to its own Interfaces block and to this file's "Additions" list.

## Locations

- kern repo on disk (`kern_repo`): `~/Code/projects/kern`. GitHub: private repo `kern` under the account `gh` is logged in as (`gh repo create kern --private --source . --remote origin`, run only after the user says yes).
- Upstream sources for port tasks: `.upstream/<source>/` inside the kern repo, gitignored, filled by `scripts/fetch-upstream`. Source keys: `superpowers` (obra/superpowers tag v6.4.1; fallback copy from `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1`), `pstack` (cursor/plugins @ 11713c6, path `pstack/`), `pocock` (mattpocock/skills @ 49dd158), `addy` (addyosmani/agent-skills @ 1be8e34), `caveman` (copy from `~/.claude/plugins/cache/caveman/caveman/<version dir>`; ideas only, never copied into shipped files), `local` (copy of `~/.claude/skills/{recall,unslop,no-comments}` and `~/.claude/agents/comment-sicko.md`).
- Spec and plans move into the repo at M0 Task 1: `docs/specs/2026-10-12-kern-design.md`, `docs/specs/2026-10-12-kern-m1-m2-skills.md`, `docs/plans/2026-10-12-kern-m{0,1,2}-plan.md`, `docs/plans/contract.md`, research notes to `docs/research/` (merge-define.md, merge-build.md, merge-ship.md, merge-meta.md, replacement-map.md, modes-research.md, audit-*.md).

## Runtime layout (shipped)

```
.claude-plugin/plugin.json  .claude-plugin/marketplace.json
hooks/hooks.json
hooks/session-start   hooks/subagent-start   hooks/prompt-submit   hooks/pre-tool-use      (bash, executable, no extension)
hooks/lib/json.sh  hooks/lib/settings.sh  hooks/lib/state.sh  hooks/lib/decide.sh  hooks/lib/gitctx.sh
hooks/guards/g01-git.sh g02-pr.sh g03-review.sh g04-untrusted.sh g05-commit.sh g06-secrets.sh g13-protected.sh g14-tracker.sh g15-deploy.sh g16-state.sh g18-readonly-agent.sh
kernel/kernel.md  kernel/kernel-subagent.md  kernel/context.md  kernel/settings.md
modes/terse.md
skills/<name>/SKILL.md (+ references/, templates/, scripts/ per skill)
agents/implementer.md agents/task-reviewer.md agents/investigator.md
scripts/kern-root scripts/kern-get scripts/kern-dir scripts/kern-detect                       (M1)
scripts/wt-new scripts/wt-check scripts/wt-snap scripts/wt-diff scripts/wt-fork scripts/wt-apply  (M2)
scripts/task-brief scripts/task-start scripts/task-done                                       (M2)
scripts/floor-scan scripts/claim-check scripts/probe                                           (M2: G7 script, G9, G10)
```

Dev tooling (not called at runtime): `scripts/lint-skills.mjs`, `scripts/lib/lint-rules.mjs`, `scripts/route-eval.mjs`, `scripts/lib/rank.mjs`, `scripts/check-version.mjs`, `scripts/release.mjs`, `scripts/kernel-adherence.mjs` (M2), `scripts/fetch-upstream` (bash). Tests: `tests/*.test.mjs` (node --test), `tests/hooks/*.bats`, `tests/scripts/*.bats`, `tests/helpers/` (bats helpers), `tests/fixtures/projects/<case>/`, `tests/fixtures/payloads/*.json`.

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
- `json_get KEY` reads JSON from `$KERN_INPUT`; prints the decoded string value of the first `"KEY":` whose value is a string; handles `\" \\ \/ \n \t \r \b \f`; leaves `\uXXXX` as the literal six characters. Exit 0 found, 1 absent or value not a string.
- `json_get_raw KEY` prints the raw JSON text of the first `"KEY":` value (object, array, string or literal). Exit 0 found, 1 absent.
- `json_escape` reads stdin, prints it escaped for a JSON string body (no surrounding quotes).
- `json_ok` exit 0 when `$KERN_INPUT` starts with `{` and ends with `}` after trimming whitespace, else 1.

`settings.sh`:
- `kern_main_root [dir]` prints the main worktree root (first `worktree ` line of `git -C <dir> worktree list --porcelain`, `dir` defaults to the hook's `cwd`). Exit 2 not a git repo.
- `settings_get KEY [DEFAULT]` prints the value and sets `SETTINGS_SOURCE` to the file path or `default`. Order: `$MAIN/.claude/kern.local.yml`, `$MAIN/.claude/kern.yml`, `$HOME/.claude/kern.yml`. Exit 0 found or defaulted, 3 unset with no default.
- `settings_unknown_keys` prints `file<TAB>key` for every key not listed in `kernel/settings.md`'s key table.
- File format: one `key: value` per line; `#` starts a comment at line start or after whitespace outside quotes; surrounding single or double quotes stripped; lists comma-separated; leading and trailing whitespace trimmed; later duplicate keys in the same file win.
- `policy_for ACTION` where ACTION is `commit|push|pr|tracker|review.post` prints `ask|auto|deny` from `<action>.policy` (`review.post_policy` for review.post). `pr.policy` value `draft-after-approval` is read as `ask`. Unknown value prints `ask`.
- `kern_enabled` exit 0 unless the resolved `kern` key is `off`.

`state.sh` (session state):
- State dir: `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions`. File `<session_id>.state`, mode 0600, flat `key: value` lines: `voice`, `surface`, `autopilot` (`on|off`), `since` (ISO 8601 UTC).
- `state_file SID` prints the path; refuses a session id that is not `[A-Za-z0-9_-]+` (exit 2).
- `state_get SID KEY` prints the value, exit 1 when unset.
- `state_set SID KEY=VALUE...` atomic: writes a temp file in the same dir with umask 077, then `mv`; refuses when the target is a symlink (exit 2).
- `state_reset SID` writes defaults from settings: `voice` from `mode.voice` (default `normal`), `surface` from `mode.surface` (default `auto`), `autopilot: off`.
- `autopilot_on SID` exit 0 only when no settings file (local, shared or user) says `autopilot: denied` and `state_get SID autopilot` is `on`.
- `autopilot_denied_by` prints the first settings file, in precedence order, that says `autopilot: denied`; exit 1 when none does. `prompt-submit` and `autopilot_text` name this file in "denied by <file>".

`decide.sh` (PreToolUse votes):
- `vote allow|ask|deny GUARD REASON` records a vote; keeps the strictest (deny > ask > allow); concatenates reasons as `G<n>: <reason>` joined by `; `.
- `emit_decision` prints the PreToolUse JSON for the strictest vote; prints nothing when no guard voted. Under autopilot a final `ask` becomes `deny` with reason suffix `(autopilot: nobody to ask)`.
- `fail_closed REASON` used on parse failure: votes `ask` (becomes `deny` under autopilot).

`gitctx.sh`:
- `git_words CMD` splits a shell command string into simple commands on `;`, `&&`, `||`, `|`, newlines and unquoted `( )` and `{ }`, and prints one record per line (quotes respected; the bodies of `$( )`, backticks and `-c` scripts are also emitted as records). A newline inside a record, such as a quoted multi-line commit message, is printed as `\037`; decode it before reading lines of a message. Here-doc bodies are data and are left out, except a here-doc read by an sh-family shell with no `-c`, whose body is records. `_shell_words` keeps a quoted newline as `\037` inside its word.
- `git_sub CMDLINE` for a simple command starting with `git`: prints `<dir><TAB><subcommand><TAB><rest>` after consuming global options `-C <dir>`, `-c <k=v>`, `--git-dir=`, `--work-tree=`, `--no-pager`. `dir` defaults to the hook `cwd`.
- `in_main_checkout DIR` exit 0 when `git -C DIR rev-parse --show-toplevel` equals `kern_main_root DIR`.
- `branch_protected BRANCH` exit 0 when BRANCH is `base_branch`, listed in `branch.protected`, or listed in `deploy.envs`.
- `current_branch DIR` prints the branch `git -C DIR symbolic-ref -q HEAD` names, without `refs/heads/` (not `rev-parse --abbrev-ref`, which prints `heads/<name>` when a tag shares the name). Exit 1 and no output on a detached HEAD.

## Guard dispatcher (hooks/pre-tool-use)

Reads stdin into `KERN_INPUT`; `json_ok` fails: `fail_closed "hook input not parseable"`. Exits silently when `kern_enabled` fails. Sets `TOOL` from `tool_name` (`Monitor` is guarded as `Bash`), `SID` from `session_id`, `CWD` from `cwd`, `AGENT` from `agent_type` (empty when absent), `AUTOPILOT=1` when `autopilot_on SID`. A field that is present but malformed (json exit 2) in `tool_input`, `cwd` or `agent_type` fails closed; a guard whose function did not load fails closed. Sources every `hooks/guards/*.sh`; each defines `guard_<id>` (for example `guard_g01`) that inspects `TOOL` and `KERN_INPUT` and calls `vote`. A guard that does not apply votes nothing. Calls them in file order, then `emit_decision`. `KERN_GUARDS` (comma list such as `g01,g05`) limits which run, and is honoured only when `BATS_TEST_FILENAME` is set.

Guard ids and milestones: g01 g02 g03 g04 g05 g06 g13 g14 g15 g16 (M1); g18 (M2); g17 (M3).

A guard that votes `allow` approves the whole Bash call, so it proves the full command shape first and falls back to ask (deny under autopilot) for anything it cannot prove; G1's push allow is the model. `settings.sh` `list_has` accepts `a, b` and `[a, b]`. The `_gh_*` helpers in `hooks/guards/g02-pr.sh` (`_gh_load`, `_gh_args`, `_gh_opts`, `_gh_last`, `_gh_only`, `_gh_pos`, `_gh_literal`, `_gh_proven`, `_gh_file_ok`) parse gh flags against gh 2.100's tables and prove a gh command's shape; G3 and G4 use them, and every guard file is sourced before any guard runs.

## Scripts (KERN/scripts, bash, executable, `set -euo pipefail`, run as `bash ${CLAUDE_PLUGIN_ROOT}/scripts/<name>`)

| Script | Signature | Output | Exit |
|---|---|---|---|
| `kern-root` | `kern-root [dir]` | line 1 `MAIN`, line 2 git common dir | 0; 2 not a repo |
| `kern-get` | `kern-get KEY [DEFAULT]` | `value<TAB>source` | 0; 3 unset, no default |
| `kern-dir` | `kern-dir SUB` | absolute `WORK/SUB` path (created); first call appends `/<work_dir>/` to `<common-dir>/info/exclude` and prints `kern: added /.kern/ to .git/info/exclude` on stderr | 0; 2 `git ls-files <work_dir>` non-empty |
| `kern-detect` | `kern-detect KEY` for `base_branch`, `branch.pattern`, `commit.convention`, `test.focused`, `test.full`, `typecheck`, `lint`, `build`, `tracker`, `pr.template` | `value<TAB>evidence` | 0; 3 not detectable |
| `wt-new` | `wt-new SLUG [--detach] [--base REF]` | worktree path | 0; 2 error |
| `wt-check` | `wt-check WT BASE_REF` | `ok` or the first mismatch | 0; 1 mismatch |
| `wt-snap` | `wt-snap WT` | tree id | 0; 2 error |
| `wt-diff` | `wt-diff WT FROM_TREE [TO_TREE] [--out FILE]` | line 1 package path, line 2 `TO_TREE`, then changed paths | 0; 3 empty diff; 2 error |
| `wt-fork` | `wt-fork SRC_WT SLUG` | fork path | 0; 3 apply failed; 2 error |
| `wt-apply` | `wt-apply PATCH DST_WT` | `applied` | 0; 3 conflict |
| `task-brief` | `task-brief PLAN N LEDGER_DIR` | brief path `LEDGER_DIR/briefs/task-N.md` | 0; 2 task not found |
| `task-start` | `task-start LEDGER N TREE` | appends `Task N: start tree=<id> at=<iso>` | 0 |
| `task-done` | `task-done LEDGER N TREE -- CMD...` | runs CMD; on exit 0 appends `Task N: complete tree=<id> test=<cmd> exit=0 review=approved` | CMD's exit code |
| `floor-scan` | `floor-scan DIFF_FILE` | one line per hit `path:line<TAB>class<TAB>text` | 0 clean; 1 hits |
| `claim-check` | `claim-check WT DIFF_FILE` | one line per unreachable SHA or absolute word | 0 clean; 1 hits |
| `probe` | `probe WT PATCH -- CMD...` | `probe: fail-then-pass ok` / `probe: test did not fail with the guard removed` / `probe: inconclusive (<why>)` | 0 ok; 1 not covered; 3 inconclusive |

`worktree.dir` default: `MAIN/.claude/worktrees`. Branch for `wt-new` (non-detached): `branch.pattern` with `{slug}` substituted, else `kern/<slug>`.

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
- Help map format (M1): `skills/help/references/map.md` holds one table with header `| Skill | Tier | Reached by | Job |`; one row per installed user-reachable skill. Each M2 skill task appends its own row.
- `wt-new` gains `--branch NAME` (full signature `wt-new SLUG [--detach] [--base REF] [--branch NAME]`); a SHA-shaped `--base` is used as a commit with no fetch, any other base must fetch from origin or the script exits 2.
- `wt-diff` also writes `<package>.patch` (`git diff --binary FROM TO`); `wt-apply` consumes that file.
- `scripts/lib/wt-common.sh` (sourced by `wt-new` and `wt-fork`): `wt_dir`, `wt_exclude_dir DIR`, `wt_include DST`, `wt_setup WT`, `wt_path_free PATH`. The setup marker is `<worktree git dir>/kern-setup-done`.
- Upstream paths as M0's `fetch-upstream` lays them out: `.upstream/superpowers/skills/...`, `.upstream/pstack/pstack/skills/...` (cursor/plugins clone), `.upstream/pocock/skills/engineering/...`, `.upstream/addy/skills/...`, `.upstream/local/recall/SKILL.md`, `.upstream/local/comment-sicko.md`.
- M1 payload-spike record (M1): `docs/spikes/m1-payloads.md` with a line `agent_type in subagent PreToolUse: <value or absent>`. M2 Task 7 reads it.
- G18 tests drive `hooks/pre-tool-use` with `KERN_GUARDS=g18`, `CLAUDE_PLUGIN_DATA` pointing at a temp dir, and a state file `sessions/<sid>.state` holding `autopilot: on` for autopilot cases; they expect no output when G18 does not vote.
- `kern-dir SUB` (M1) accepts a nested SUB such as `ledgers/<plan-slug>` and creates every level; execute-plan relies on it.
- Lint rule 9 (M2) requires `## Steps` as the first H2 of every slash skill and `## Steps` in every auto skill; M1's `mode`, `autopilot` and `help` should open with `## Steps`, and `unslop` (a rule document) gets a rule-9 exemption with a reason. Path skills are left to M1's rule 6.
- Lint rule 12 (M2) and route-eval need a case file `evals/cases/row-<route>.json` for every kernel row, including M1's `technical-writing` and `context` rows; M2 Task 21 writes them, assuming the row texts "Prose others read: PR body, issue, doc, commit message" and "Phase ends, or context is filling".
- Bats tests that use `[[ ]]` mid-test need bash 4+ (`tests/helpers/wt.bash` refuses bash 3.2); scripts stay bash 3.2 compatible.

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
- `gitctx.sh` also provides `_split_words`, `_subst_bodies`, `_shell_words`, `cmd_head`, `current_branch`, `base_branch_name`, `push_targets DIR REST` (skips redirections; prints `*` for `--all`, `--mirror`, `--branches` or a wildcard refspec, and `branch_protected '*'` is true), `with_timeout SECS CMD...`, `gh_sub CMDLINE` (`<group> <verb>`; matches gh on the lowercased basename and skips `-R <v>`, `--repo <v>` and `--repo=<v>`), `word_value WORDS FLAG...`, `word_has WORDS FLAG...`.
- Dispatcher variables a guard reads: `TOOL`, `TOOL_INPUT`, `AGENT`, `CWD`, `SID`, `KERN_MAIN`, `AUTOPILOT`.
- `kern-dir SUB`: SUB is one or more lowercase segments of letters, digits and dashes joined by `/` (for example `ledgers/plan-a`). `branch.pattern` uses `{id}` and `{slug}`; `test.focused` uses `{file}`, or `{dir}` (go) or `{name}` (cargo) where a file cannot be targeted.
- New settings key `mcp.write_servers` (G14). G14 also covers `gh issue` and `gh label` writes. G16 also denies CronCreate, ScheduleWakeup, RemoteTrigger and SendMessage calls whose prompt or message starts with `/kern:autopilot`, `/kern:mode`, `/autopilot` or `/mode`, and Skill calls for those skills. G16 votes ask on writes to `.claude/kern.yml`, `.claude/kern.local.yml` and `~/.claude/kern.yml` (deny under autopilot), because those files set guard policy.
- `tests/run-bats ARGS...` runs bats with `/bin/bash` first on PATH on macOS. `tests/helpers/common.bash` also provides `kern_env DIR`, `payload EVENT FIELDS`, `bash_payload CMD`, `run_guard PAYLOAD [GUARDS]`, `decision_of OUTPUT`, `set_autopilot on|off`, `fake_gh`, `tool_payload TOOL FIELDS` (use it for a payload whose tool_input has several fields: bash 3.2 brace-expands a literal JSON object inside `"$( )"`).
- Lint rule 6 (M1) also resolves `Read {ROOT}/<path>` rows (the context route), and checks the help map's first column (`` | `<skill>` | ``). M1 consumes the "M0 as written" model (`loadModel`, `RULES` entries `{ id, check(model) }`, findings `{ rule, path, level, message }`), not the earlier `ctx` shape above.
- `scripts/lint-exemptions.json` gains `{ "rule": 6, "path": "skills/hello/SKILL.md", ... }`; M2 removes it with the `hello` skill.
