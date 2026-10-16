# M1 Task 9 report: guard dispatcher, G16 and hook wiring

Status: DONE

Commit: `57ae08f M1: add the guard dispatcher, G16 and hook wiring` (on `main`, parent `6ad61cb`, not pushed, no trailers).

## What I did

1. Wrote the three Step 1 test files with the Write tool, transcribed from the brief.
2. Ran Step 2 and saw RED for the expected reasons.
3. Wrote `hooks/lib/decide.sh`, `hooks/lib/gitctx.sh`, `hooks/pre-tool-use`, `hooks/guards/g16-state.sh` and `hooks/hooks.json` with the Write tool, transcribed from the brief.
4. Checked the transcription. I split the brief's fenced blocks into scratch files and ran `diff` against each written file. All 8 files are byte-identical to the brief. `hooks/hooks.json` is also byte-identical to the block in `docs/plans/contract.md`.
5. Ran Step 8 and saw GREEN. Then ran shellcheck, the whole hook and script suite, all node tests and the skill lint. Then committed exactly as Step 9 says.

No deviations from the brief. No code changes beyond the brief.

## TDD evidence

### RED (Step 2)

Command: `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats; node --test tests/hooks-json.test.mjs`

```
1..11
not ok 1 git_words splits chains and keeps quoted separators
not ok 2 git_words also prints the bodies of bash -c, eval, $( ) and backticks
not ok 3 git_sub reads -C, skips env and global options
not ok 4 gh_sub, word_value and word_has
not ok 5 push_targets: refspecs, deletes and the current branch
not ok 6 with_timeout returns promptly when the command finishes
not ok 7 Write under the sessions dir is denied in both modes
ok 8 Edit of another file: no vote
not ok 9 a Bash command naming the sessions dir is denied
not ok 10 a scheduled prompt or relayed message carrying /kern:autopilot is denied
ok 11 a scheduled prompt without kern commands: no vote
# .../tests/hooks/gitctx.bats: line 11: .../hooks/lib/gitctx.sh: No such file or directory   (x6)
# CronCreate -> bash: .../hooks/pre-tool-use: No such file or directory
# Error: ENOENT: no such file or directory, open '.../hooks/hooks.json'
not ok 1 - tests/hooks-json.test.mjs
# pass 0
# fail 1
```

All three expected reasons appear. Tests 8 and 11 pass before the code exists. They assert "no vote" (`decision_of` prints `none` for empty output), and a missing dispatcher also prints nothing. They become meaningful once the dispatcher runs. They are the brief's tests, and I left them unchanged.

### GREEN (Step 8)

Command: `chmod +x hooks/pre-tool-use && tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats tests/hooks/payloads.bats && node --test tests/hooks-json.test.mjs && claude plugin validate . --strict`

```
1..16
ok 1 git_words splits chains and keeps quoted separators
ok 2 git_words also prints the bodies of bash -c, eval, $( ) and backticks
ok 3 git_sub reads -C, skips env and global options
ok 4 gh_sub, word_value and word_has
ok 5 push_targets: refspecs, deletes and the current branch
ok 6 with_timeout returns promptly when the command finishes
ok 7 Write under the sessions dir is denied in both modes
ok 8 Edit of another file: no vote
ok 9 a Bash command naming the sessions dir is denied
ok 10 a scheduled prompt or relayed message carrying /kern:autopilot is denied
ok 11 a scheduled prompt without kern commands: no vote
ok 12 recorded typed /kern:mode terse switches the voice
ok 13 recorded typed /kern:autopilot on turns autopilot on
ok 14 the recorded background report never switches anything
ok 15 the recorded SubagentStart payload yields SubagentStart JSON
ok 16 the recorded subagent PreToolUse payload parses: the dispatcher prints nothing or JSON
# tests 2
# pass 2
# fail 0
Validating marketplace manifest: .../kern/.claude-plugin/marketplace.json
✔ Validation passed
```

The real count is 16 tests, 0 failures, 0 skips. This matches the brief's `16 tests, 0 failures`. The Task 8 payload test, `the recorded subagent PreToolUse payload parses`, no longer skips: it runs and passes against the recorded fixture. All 5 payload tests run, because every fixture they need is present.

### `claude plugin validate . --strict`

`claude` is Claude Code 2.1.296, and the command passes (rc 0). Its output names only the marketplace manifest, so I checked whether it reads `hooks/hooks.json` at all. I copied `.claude-plugin`, `hooks` and `skills` into a scratch dir and replaced `hooks.json` with an entry of `"type":"bogus"`. On that copy, `claude plugin validate . --strict` printed `Validating hooks: .../hooks/hooks.json` and `Unknown hook type "bogus"`, and failed with rc 1. So the validator does check `hooks.json`, and the real file passes. `claude plugin validate .claude-plugin/plugin.json --strict` also passes, as in `scripts/ci-local`.

## shellcheck (0.11.0)

- `shellcheck -x hooks/pre-tool-use`: clean, rc 0. It follows all five libraries and `g16-state.sh` is sourced dynamically.
- `shellcheck hooks/pre-tool-use hooks/lib/*.sh hooks/guards/*.sh`: no finding in any new file. The only findings are two pre-existing SC2016 infos: `hooks/lib/json.sh:8` (the awk program in single quotes) and `hooks/lib/settings.sh:97` (the sed pattern with backticks). Both are intended and come from Tasks 2 and 3.
- `shellcheck` on only the four new files, without `-x` and without the other libraries as input, gives three things. First, SC1091 infos for the unfollowed `json.sh`, `settings.sh` and `state.sh`. Second, an SC2034 warning: `TOOL_INPUT appears unused` at `hooks/pre-tool-use:30`. The variable is read by `ti_get` in `json.sh` and by `g16-state.sh`. Third, nothing else. The brief's disable comments cover `KERN_INPUT`, `TOOL` and `AGENT`, but not `TOOL_INPUT`. I left the brief's code as written. When the libraries are visible (`-x`, or passed as input), the warning disappears. CI does not run shellcheck on `hooks/` today: `scripts/ci-local` and `ci.yml` check only `scripts/fetch-upstream` and `scripts/ci-local`.

## Whole suites before commit

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..99`, 99 `ok`, 0 `not ok`, 0 skips, rc 0.
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`, rc 0.
- `node scripts/lint-skills.mjs`: `lint: clean`. Rules 8 and 11 cover the new shipped files under `hooks/`.

## Behaviour spot checks (bash 3.2, `/bin/bash`, isolated HOME and CLAUDE_PLUGIN_DATA)

These are outside the brief's tests. I ran them to confirm the contract's fail-closed points.

| Input | Output |
|---|---|
| `not json` | `ask`, `kern G0: hook input not parseable` |
| empty stdin | `ask`, same reason |
| object without `tool_name` | `ask`, same reason |
| object without `tool_name`, state `autopilot: on` | `deny`, `kern G0: hook input not parseable (autopilot: nobody to ask)` |
| Bash `ls` | no output, rc 0 |
| `kern: off` in user settings plus a Bash command naming the sessions dir | no output, rc 0 (the contract says exit silently when kern is off) |
| `Skill` with `"skill":"kern:mode"` | `deny`, `kern G16: Skill may not carry /kern:autopilot or /kern:mode; only the user types them` |
| `NotebookEdit` with `notebook_path` under sessions | `deny`, G16 state reason |

Every row exited 0.

## Files changed

- `hooks/lib/decide.sh` (new)
- `hooks/lib/gitctx.sh` (new)
- `hooks/pre-tool-use` (new, mode 100755 in the index)
- `hooks/guards/g16-state.sh` (new)
- `hooks/hooks.json` (new)
- `tests/hooks/gitctx.bats` (new)
- `tests/hooks/g16-state.bats` (new)
- `tests/hooks-json.test.mjs` (new)

## Concerns

None block this task. Two observations for the controller:

1. **SC2034 on `TOOL_INPUT`.** Running shellcheck on `hooks/pre-tool-use` alone, without `-x`, gives this warning. If Task 17 or CI later adds `shellcheck hooks/...` without `-x`, it will fail on `hooks/pre-tool-use:30`. There are two fixes: add `TOOL_INPUT` to the existing `SC2034` disable comment, or run shellcheck with `-x`. I changed nothing here.
2. **Settings files are not guarded (outside this task).** As the spot check shows, `kern: off` in any settings layer turns off every guard, G16 included. No M1 guard covers Claude writing `.claude/kern.local.yml`, `.claude/kern.yml` or `~/.claude/kern.yml`. The help skill writes `kern.local.yml` on purpose, after an explicit yes. Under autopilot, a Write that sets `kern: off` or loosens `*.policy` goes to Claude Code's normal permission flow only. G16's scope as written covers only session state, so this is a design question, not a Task 9 defect.

---

# Fix round A: dispatcher and G16

Status: DONE_WITH_CONCERNS. One requested assertion cannot hold, and I did not force it (concern 1 below).

Commit: `a59bcb0 M1: fail closed on malformed input; G16 covers paths and settings`, parent `57ae08f`, on `main`, not pushed, no trailers. Files: `hooks/pre-tool-use`, `hooks/guards/g16-state.sh`, `hooks/hooks.json`, `tests/hooks/pre-tool-use.bats` (new), `tests/hooks/g16-state.bats`, `tests/hooks-json.test.mjs`. I did not touch `hooks/lib/gitctx.sh`; G16 only calls `git_words` and `_shell_words` from it.

## Changes

1. **Malformed fields fail closed** (`hooks/pre-tool-use`).
   - The dispatcher reads `cwd` first. Exit 0 uses the value; any other code falls back to `$PWD`. Then it resolves `KERN_MAIN` and computes `AUTOPILOT`. All of this happens before any parse check, so a fail-closed ask becomes deny under autopilot.
   - If cwd returned exit 2, the dispatcher fails closed with `cwd not parseable`.
   - For `tool_input` and `agent_type`, exit 1 keeps today's fallback (`{}` or empty). Any other code fails closed with `<field> not parseable`, emits and exits 0. I treat every non-1 code as malformed, not only 2, so an unexpected awk failure cannot fall through to a default.
   - A new helper, `unparseable WHAT`, does `fail_closed "$WHAT not parseable"`, `emit_decision` and `exit 0`. The top-level failure still reads `hook input not parseable`.
2. **Dispatcher hardening.**
   - `KERN_GUARDS` is honoured only when `BATS_TEST_FILENAME` is also set. I checked that bats exports it to child processes.
   - A guard file that did not load now fails closed: `declare -F "guard_$id" >/dev/null || { fail_closed "guard $id did not load"; continue; }`. On bash 3.2, sourcing a file with a syntax error returns 1 and leaves the function undefined, and the dispatcher keeps running.
   - `TOOL_INPUT` has its own `# shellcheck disable=SC2034 # read by ti_get and the guard files`.
   - `Monitor` is added to the PreToolUse matcher (after `Bash`). The dispatcher maps it with `[ "$TOOL" = Monitor ] && TOOL=Bash`. The Monitor schema in this session has `command`, `description`, `timeout_ms` and `ws`. `tests/hooks-json.test.mjs` now also pins `Monitor`.
   - **For shellcheck to be clean with and without `-x`**, each variable is now assigned in a single command that its directive covers. `AUTOPILOT` sits in a `{ }` group under its directive. `TOOL_INPUT` and `AGENT` use `X=$(...) || case $? in ...` (inside the `||` branch, `$?` is the substitution's status; I checked this on bash 3.2). I also added one file-wide `# shellcheck disable=SC1091 # the libraries are followed under shellcheck -x`. I checked that `-x` still follows the libraries: with the `TOOL_INPUT` directive removed, `-x` reports no SC2034 and plain `shellcheck` reports it.
3. **`tests/hooks/pre-tool-use.bats`** (new, 6 tests). It feeds six unreadable inputs byte for byte: empty, `not json`, no `tool_name`, the truncated Write from the request, an unterminated `cwd` and an unterminated `agent_type`. Each gives `ask`. The last three also pin their reason text.
   - Under `set_autopilot on`, the four inputs that carry `session_id` give `deny` with a reason ending `(autopilot: nobody to ask)"}}`. Empty stdin and `not json` still give `ask` (concern 1).
   - Deny plus ask: one Bash command writes both a settings file and the state file. It gives `deny`, prints only the G16 state reason and no `kern settings` text.
   - Broken guard: the test copies `hooks/` to the test tmpdir and adds `g99-broken.sh` with a syntax error. The result is `ask` with `G0: guard g99 did not load`.
   - `KERN_GUARDS`: with `KERN_GUARDS=g01` under bats, G16 is skipped and there is no vote. In a subshell with `BATS_TEST_FILENAME` unset, G16 runs and the result is `deny`.
4. **G16 session state.**
   - Write, Edit and NotebookEdit: a relative path is taken from `CWD`. G16 compares three forms of the path, each lowercased: as written, normalised (`.`, `..` and `//` resolved as text by a small awk), and physical (`cd` to the normalised parent, `pwd -P`). Each is compared with the lexical sessions dir, the physical sessions dir and the brief's `*/plugins/data/kern*/sessions/*`. Text normalisation is needed because bash 3.2 `cd` fails through a nonexistent directory: `cd data/nope/../sessions` fails, I checked.
   - Bash: G16 denies only write shapes against state. The shapes are an unquoted `>`, `>>`, `>|` or `&>` redirect target, and the first command word (after `VAR=value`, `command`, `exec`, `time`, `nohup`, `sudo`, `env` and flags) being `tee`, `cp`, `mv`, `ln`, `rm`, `truncate`, `dd` or `install`, or `sed` or `perl` with an in-place flag (`--in-place*`, or a short-flag word containing `i`).
   - A Bash target is state when the lowercased word contains the sessions dir, `plugins/data/*sessions`, `claude_plugin_data*sessions` or the session id.
   - Redirects are scanned on the whole line and on every simple command from `git_words`. The whole-line scan is needed because `_split_words` cuts `>|` and `&>` apart from their targets. The per-command scan covers the bodies of `bash -c`, `$( )` and backticks.
   - Reads pass. `/dev/null`, `/dev/stdout`, `/dev/stderr` and single-digit fd targets are ignored.
   - A cheap prefilter returns before any parsing when the command mentions none of the targets.
   - CronCreate, ScheduleWakeup, RemoteTrigger and SendMessage: G16 reads the `prompt` and `message` keys, strips leading whitespace (newlines included), lowercases, and denies when the first word is `/kern:autopilot`, `/kern:mode`, `/autopilot` or `/mode`. A mention later in the text passes, and so does `/models`.
   - Skill: G16 denies when `skill`, lowercased and without a leading `/`, is `kern:autopilot`, `kern:mode`, `autopilot` or `mode`.
5. **G16 settings files.**
   - A Write, Edit or NotebookEdit whose path (any of the three forms) ends in `/.claude/kern.yml` or `/.claude/kern.local.yml` votes `ask`: `kern settings change guard policy; the user confirms each write`. The state check runs first over all three forms. So if a settings-looking path physically resolves into the sessions dir, it is still denied.
   - A Bash write shape whose target ends in `.claude/kern.yml` or `.claude/kern.local.yml` also votes `ask`. Under autopilot, `emit_decision` turns these into `deny`.
6. **Existing "no vote" tests.** `Edit of another file: no vote` first runs Write, Edit and NotebookEdit on the state file (each `deny`), then asserts status 0, empty output and `none`. `a scheduled prompt without kern commands: no vote` first gets `deny` for `/kern:autopilot on`, then asserts status 0, empty output and `none`. I renamed `a Bash command naming the sessions dir is denied` to `a Bash write into the sessions dir is denied`, because reads now pass. Its body is unchanged.

New G16 tests cover each requested case:
- a `..` path, including one through a nonexistent directory
- an upper-cased path
- a symlinked dir
- `echo autopilot: on >> ~/.claude/plugins/data/k*/sessions/*.state`
- ScheduleWakeup `/autopilot on`
- a Monitor command writing state
- `cat` of state passes
- a SendMessage that mentions `/kern:mode` mid-text passes

They also cover 19 Bash write shapes, reads with `2>/dev/null` or `> /tmp/copy`, Skill names, and the settings ask, autopilot deny and read pass.

## A bash 3.2 test trap I hit (worth knowing for later guard tests)

Bash 3.2 brace-expands a literal `{"a":1,"b":2}` inside `"$( )"`, even when the braces sit inside an escaped double-quoted argument:

```
/bin/bash -c 'echo "[$(printf "<%s>" "x{\"a\":1,\"b\":2}")]"'
[<x"a":1>] [<x"b":2>]
```

So `run_guard "$(payload PreToolUse "...{\"skill\":\"x\",\"args\":\"on\"}")"` sends a broken payload, and the "no vote" result looks like a real result. The assignment form `p=$(payload ...)` is not affected, and neither are single-field objects. My first Skill, SendMessage and Monitor tests had this shape and failed for this reason, not because of the guard. `tests/hooks/g16-state.bats` now has `tool_payload TOOL FIELDS`, which adds the braces inside the helper, and its comment says why. Tasks 10 to 13 will build multi-field `tool_input` payloads and should use the same pattern. It may belong in `tests/helpers/common.bash`, but I left that file alone in this round.

## TDD evidence

RED: `tests/run-bats tests/hooks/pre-tool-use.bats tests/hooks/g16-state.bats` against `57ae08f` gives `1..22`. 16 tests are `not ok`:

- 1, input the dispatcher cannot read gives ask (case 4: empty output)
- 2, the autopilot deny version of 1
- 4, deny plus ask
- 5, broken guard
- 6, KERN_GUARDS
- 9, `..` path
- 10, upper-cased path
- 11, symlinked dir
- 13, Bash write shapes (the first failing case is the `~/.claude/plugins/data/k*` glob)
- 14, reads pass (the old G16 denied `cat`)
- 15, Monitor
- 17, relayed text opening with a command
- 18, relayed text with only a mention
- 20, Skill (bare `autopilot`)
- 21, settings ask
- 22, settings read

6 tests are `ok`. They pin behaviour that already held: 3 (no session id gives ask), 7, 8, 12, 16 and 19. `node --test tests/hooks-json.test.mjs` gives `# fail 1` (`Monitor` does not match).

GREEN, same command after the change: `1..22`, 22 `ok`. `node --test tests/hooks-json.test.mjs` gives `# pass 2`, `# fail 0`.

## Whole suite before commit

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..116`, 116 `ok`, 0 `not ok`, 0 skips (99 before, plus 6 in `pre-tool-use.bats` and 11 in `g16-state.bats`).
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `claude plugin validate . --strict` and `claude plugin validate .claude-plugin/plugin.json --strict`: both `Validation passed`.

## shellcheck 0.11.0 on touched hook files

`shellcheck -x hooks/pre-tool-use hooks/guards/g16-state.sh`, `shellcheck hooks/pre-tool-use hooks/guards/g16-state.sh`, and each file alone without `-x`: all rc 0 with no output.

## Probe (outside tests, bash 3.2, isolated HOME and data)

| Case | Decision | Time |
|---|---|---|
| Bash `ls -la` | none | 93 ms |
| Bash `cd x && git status; echo a \| grep q` | none | 52 ms |
| Bash state write | deny | 69 ms |
| Bash state read with `2>/dev/null` | none | 64 ms |
| Write to a repo file | none | 65 ms |
| Write to a relative path | none | 62 ms |
| Write through a symlinked sessions dir | deny | 62 ms |
| Monitor `tee` into state | deny | 65 ms |
| `mcp__x__y` | none | 41 ms |

Stderr was empty for every case.

## Concerns

1. **Deviation: empty stdin and `not json` give ask, not deny, under autopilot.** The request asks for all four inputs to deny under autopilot. Two of them carry no `session_id`, so the dispatcher cannot tell which session's state applies. A deny there would mean either denying whenever the session id is unreadable, which contradicts "these give ask" in interactive mode, or guessing from other sessions' state files, which is a heuristic. I found no session id in the hook environment: the spike record lists payload fields only. The test `under autopilot, input with no readable session id still never allows` pins today's ask. If you want deny for these, tell me which rule to use: always deny when the session id is unreadable, or something else.
2. **Additions beyond the request.** I made these to close bypasses of the narrowed Bash rule. Say if any should go.
   - `$CLAUDE_PLUGIN_DATA/sessions` counts as a state target, because the hook sees the variable unexpanded.
   - A `cd`/`pushd` into the sessions dir makes every later write shape in the same command a state write. The old rule caught `cd <sessions> && echo on > x.state` by naming alone.
   - Redirects are scanned on the whole line, which catches `>|` and `&>`.
   - `cp <state> /tmp/x` counts as a write, because cp is a write shape and any operand that names state counts. A copy out of the sessions dir is therefore denied, which errs on the strict side.
3. **The contract and plan still show the old matcher.** `docs/plans/contract.md` and the Task 9 brief still show `Bash|Write|...` without `Monitor`. I did not edit them, because recording rulings there has been the controller's step.
4. **Limits of the Bash rule.**
   - Lexical matching cannot see writes through interpreters (`python -c`, `node -e`), through variables (`D=...; echo > $D/x`), or through a `cd` into `.claude` followed by `> kern.yml`.
   - The settings rule has no cd tracking.
   - Here-doc bodies are scanned as if they were commands, so a here-doc that mentions a state path after `>` is denied.
5. **The keys G16 reads for RemoteTrigger and ScheduleWakeup are unverified.** It reads `prompt` and `message`. CronCreate (`prompt`) and SendMessage (`message`) are confirmed from their schemas. RemoteTrigger and ScheduleWakeup are not available in this session, so their keys are a guess.

---

# Fix round B: gitctx splitter, push_targets, with_timeout

Status: DONE.

Commit: `1f7c85b M1: see git behind wrappers and groups; tighten push_targets`, parent `a59bcb0`, on `main`, not pushed, no trailers. Files: `hooks/lib/gitctx.sh`, `tests/hooks/gitctx.bats`, `tests/helpers/common.bash`, `tests/hooks/g16-state.bats`. The working tree also has your uncommitted edits to `docs/plans/2026-10-12-kern-m1-plan.md`, `docs/plans/contract.md` and `docs/specs/2026-10-12-kern-design.md`. I left them unstaged and did not touch them.

## Changes

1. **Splitter (I-1).**
   - `_split_words` now splits on unquoted `(` and `)` at depth 0. It also splits on `{` and `}` when either is a whole word: the character before it is the start of input or a separator, and the character after it is the end of input or a separator. So `${x}`, `{}`, `{a,b}` and `--format='{%H}'` stay intact.
   - `emit` drops each backslash-newline (`gsub(/\\\n/, "", s)`) rather than joining with a space, so `git sta\` + newline + `sh` reads as `git stash`.
   - Quoted parentheses stay inside their word.
   - **New `_cmd_words CMDLINE`** prints the words of a simple command from its command name on. It skips leading `VAR=value` words, the keywords `if then elif else do while until ! {`, the wrappers `command exec time nohup sudo env`, and their options (`-u X` and `-g X` take a value; any other `-*` is skipped). `git_sub`, `cmd_head` and `gh_sub` now read from it, which replaces three separate skip lists.
   - **Deviation in approach, same behaviour:** shell-wrapper detection in `git_words` does not use the suggested extended regex. It reads `_cmd_words` and treats the segment as a wrapper when the command name's basename is `sh`, `bash`, `zsh` or `dash`. The script is the word after a flag matching `-[a-z]*c`; other `-*` flags are skipped. `eval` takes all of its arguments, joined with spaces, as bash does. Because detection uses the same skip list, it covers every case the regex would: an optional path, combined flags ending in `c`, and `nohup`, `command`, `exec`, `time` or `sudo` before the shell. It also covers `then bash -c ...`, `sudo -u me bash -c ...` and `env A=1 bash -c ...`, which the regex form would not.
   - The comment above `git_words` says xargs and `find -exec` are out of scope.
   - **`env` is added** to the wrapper list. Before, `env A=1 git stash` was not seen as git by `git_sub`.
2. **push_targets (I-2).**
   - In `_split_words`, `&` is never a separator when the character before it is `>` or `<` or the character after it is `>`. That covers `2>&1`, `>&`, `<&` and `&>`. `|` after `>` (`>|`) is not a separator either. `>|` was not in your list; it is the same class, and I added it.
   - push_targets skips any word that starts with `<`, `>` or `&>`, and any word that starts with a digit and contains `>` or `<`. When that word is only an operator with no target attached (`>`, `2>`, `<`, `>|`), the next word is skipped too.
   - `--all`, `--mirror` and `--branches` print `*`, and so does a refspec that contains `*`. `branch_protected '*'` returns 0 before it reads settings.
   - `heads/` is stripped as well as `refs/heads/`.
   - `--delete X`, `-d X` and `:X` print `X`. These already worked; they are now pinned by tests, including `:refs/heads/old` and `--delete heads/old`.
3. **with_timeout (Minor-2).** The watchdog now runs `command -v pkill >/dev/null && pkill -P "$pid"; kill "$pid"`, so the child's children die first and then the child. The fast-path cleanup is unchanged.
4. **Rider.** `tool_payload` moved to `tests/helpers/common.bash` with its bash 3.2 brace-expansion comment and the same behaviour. `g16-state.bats` now uses the shared one; its 16 tests pass unchanged.

New `gitctx.bats` tests (8, total 14):
- shells, wrappers, groups and keywords: the 13 requested `git stash` forms, each checked with `git_sub` and `cmd_head`, and also as `gh pr create` checked with `gh_sub`, plus `for ... do git push ...`
- backslash-newline, with both the leading-space form and the mid-word form
- quoted parentheses: `git commit -m "fix (x)" && (git status)` gives exactly two lines, and the message survives
- redirections never split: `2>&1 |`, `&>` and `>|`
- push_targets skips six redirection forms; the output of `git_sub` on `git push origin 2>&1` gives `main`
- `*` for `--all`, `--mirror`, `--branches` and wildcard refspecs; `branch_protected '*'`
- `heads/` stripping and six delete forms
- the slow path of with_timeout: `out=$(with_timeout 1 sh -c 'echo partial; sleep 6')` is non-zero, `out` is `partial`, and it takes under 3 s

## TDD evidence

RED: `tests/run-bats tests/hooks/gitctx.bats` against `a59bcb0` with the new tests gives `1..14`. 8 tests are `not ok`, and the run took 7.3 s because the old `with_timeout` waited for the orphaned `sleep 6`:

- 3 (`no git stash in: bash -lc "git stash"`)
- 4 (`no git stash in: git \`)
- 5, quoted parentheses
- 6, redirections never split
- 10 (`origin 2>&1 -> 2>&1`)
- 11 (`--all origin -> main`)
- 12, `heads/` stripping
- 14, with_timeout slow path

The 6 tests that already existed passed.

To show test 3 case by case, I ran a scratch script against the old library (`git show a59bcb0:hooks/lib/gitctx.sh`). Every requested form returned NO except `command`, `exec` and `time`, which the old skip list already handled. Against the new library, every form returns yes, and so do `if true; then bash -c ...`, `sudo -u me bash -c ...`, `env A=1 git stash`, `f() { git stash; }`, `eval git stash` and `cat <(git stash)`. Regression checks with unchanged output: `echo {a,b}`, `--format='{%H}'`, `$( )` and backtick bodies, `git commit -m "a; b (c) {d}"`, and `find -exec` (still one segment, as the comment says).

GREEN, same command: `1..14`, 14 `ok`, in **3.4 s**. The slow-path test accounts for about 1 s of that.

## Whole suite before commit

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..124`, 124 `ok`, 0 `not ok`, 0 skips, 36.6 s.
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- shellcheck 0.11.0 on `hooks/lib/gitctx.sh`, with and without `-x`: rc 0, no output. `hooks/pre-tool-use` and `hooks/guards/g16-state.sh` are still clean both ways.

## Cost

- `git_words` on a 29-segment chain takes 155 ms, against 124 ms before. The extra time is the `_cmd_words` call per segment for wrapper detection, which replaced a `sed` call.
- The dispatcher probe is unchanged: 42 to 96 ms per call, with empty stderr.
- The 200 KB parse budget is not affected, because `git_words` runs only for Bash and only when G16's prefilter matches.
- No guard function runs in a pipeline. The only new pipelines are inside `git_words` and `_cmd_words`, as before, and neither votes.

## Concerns

1. **A comment in G16 is now stale.** `hooks/guards/g16-state.sh` says "The whole line first: the command splitter cuts `>|` and `&>` apart from their targets." The splitter no longer does that. The whole-line redirect scan is now redundant but harmless. That file was outside this round's file list, so I left it. A one-line comment fix, or dropping the whole-line pass, can go in whichever round next touches G16.
2. **G16 still uses its own command-head skip list.** In `_g16_bash` that list does not take `sudo -u X`'s value, so `sudo -u me tee <state>` takes `me` as the command. Switching `_g16_bash` to `_cmd_words` would fix it, but that is a G16 change outside this round's files.
3. **Splitter limits that remain.** A quoted newline inside one simple command still prints that command over two lines, as before. Inside `$( )` at depth > 0, quotes are not tracked, so `$(echo ")")` miscounts. Neither is new.

## Round B rider: RemoteTrigger with a nested body

Commit: **amended into round B**, as instructed. `1f7c85b` is replaced by **`4d94ed6`** (`M1: see git behind wrappers and groups; tighten push_targets`). The parent is still `a59bcb0`. Nothing was pushed, and the body gained one sentence about RemoteTrigger. The amend added `hooks/guards/g16-state.sh` and `tests/hooks/g16-state.bats`; your docs edits are still unstaged.

Change: in `_g16_relay`, for `TOOL = RemoteTrigger` only, G16 denies when the lowercased raw `TOOL_INPUT` contains `/kern:autopilot` or `/kern:mode` anywhere, with the same reason as the other relay tools. CronCreate, ScheduleWakeup and SendMessage keep the opens-with rule. The comment above `_g16_relay` says why RemoteTrigger differs.

**Finding: part of the premise does not hold.** `json_get` matches the first `"prompt":` key at any nesting depth; it is not limited to the top level. So before this change, a RemoteTrigger create with `body.job_config.prompt` = `/kern:autopilot on` was already denied by the opens-with rule. Your requested case passed on the old code. The old code actually missed two shapes:

- a mention that is not at the start: `check CI then /Kern:Mode terse`
- a key other than `prompt` or `message`: `body.routine.instructions`

Tests (one new `@test`, 17 in the file):
- deny for a `create` with `job_config.prompt` = `/kern:autopilot on` (as requested)
- deny for an `update` whose prompt has `/Kern:Mode` mid-text, in mixed case
- deny for a `run` with `routine.instructions` = `/kern:autopilot on`
- `list` gives status 0, empty output and no vote

RED: I temporarily removed the new branch and ran `tests/run-bats -f RemoteTrigger tests/hooks/g16-state.bats`. The result was `not ok`, failing at line 149, the mid-text `update` case. The `create` case at line 147 passed, which confirms the finding above. I then restored the branch.

GREEN: the same command gives `ok`.

**My own test slip, fixed before RED:** my first `update` case text was `check CI, then ...`. That comma sat inside the `{...}` of an inline `"$( )"`, so bash 3.2 brace-expanded the payload. That is the same trap `tool_payload`'s comment warns about: the helper adds only the outer braces, so a nested object with a comma still needs care. I removed the comma.

Whole suite before amending:
- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..125`, 125 `ok`, 0 `not ok`, 0 skips.
- `node --test tests/*.test.mjs`: 46/46.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- shellcheck on `g16-state.sh`: clean with and without `-x`; the dispatcher with `-x` is clean too.

---

# Fix round C: the RemoteTrigger rider in its own commit, plus two G16 cleanups

Status: DONE.

Commit: `fd2c243 M1: G16 reads RemoteTrigger bodies and the shared command head`, parent `1f7c85b`, on `main`, not pushed, no trailers. Files: `hooks/guards/g16-state.sh`, `tests/hooks/g16-state.bats`.

**The amend is undone.** The rider section above says `4d94ed6` replaced `1f7c85b`. That is no longer true. I checked that `4d94ed6` differed from `1f7c85b` only by the rider: the same parent `a59bcb0`, and only `g16-state.sh` and `g16-state.bats` changed. I then ran `git reset --soft 1f7c85b`, which moved `main` back without touching the working tree, so your unstaged docs edits were unaffected. The rider stayed staged, and I committed it here with the two cleanups. History is now `a59bcb0` (round A), then `1f7c85b` (round B, as first committed), then `fd2c243` (round C). `4d94ed6` survives only in the reflog.

## Changes

1. **RemoteTrigger rider.** The code and test are the same as in the rider section above: G16 denies when the lowercased raw input mentions `/kern:autopilot` or `/kern:mode` anywhere.
2. **G16 finds the command name with `_cmd_words`.** `_g16_bash` used its own list of words to skip before the command name. It now reads `_cmd_words`, the shared skipper from `gitctx.sh`. So `sudo -u X` takes its value, and keywords such as `then` and `do` are skipped before the command name.
3. **The stale comment is gone, together with the pass it described.** The whole-line redirect pass existed only because the splitter used to cut `>|` and `&>` apart from their targets. Round B fixed that, so the per-command redirect scan now sees `>|` and `&>`, and the whole-line pass was redundant. I removed it, which also removes the comment that was no longer true. The per-command scan is at least as broad: it also covers the bodies of `bash -c` and `$( )`, and it applies the cd rule.

Three cases are added to `every Bash write shape against session state is denied`:
- `sudo -u me tee <state>`
- `if true; then rm -f <state>; fi`
- `echo on &> <state>`

## TDD evidence

RED: I ran a scratch bats file per case against the guard as it stood before this change.

| Case | Before |
|---|---|
| `sudo -u me tee <state>` | none |
| `if true; then rm -f <state>; fi` | none |
| `echo on &> <state>` | deny, from the whole-line pass |
| `echo on >\| <state>` | deny, from the whole-line pass |

`tests/run-bats -f "every Bash write shape" tests/hooks/g16-state.bats` failed on `sudo -u me tee ... ->`.

GREEN: `tests/run-bats tests/hooks/g16-state.bats tests/hooks/pre-tool-use.bats` gives `1..23`, 23 `ok`. The `&>` and `>|` cases still deny with the whole-line pass removed.

## Whole suite before commit

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..125`, 125 `ok`, 0 `not ok`, 0 skips.
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- shellcheck 0.11.0 on `hooks/guards/g16-state.sh`, with and without `-x`, and on `hooks/pre-tool-use` with `-x`: rc 0, no output.

---

# Fix round D: the session id counts only as the state file name

Status: DONE.

Commit: `7bea993 M1: G16 counts the session id only as the state file name`, parent `f64f898`, on `main`, not pushed, no trailers. Files: `hooks/guards/g16-state.sh`, `tests/hooks/g16-state.bats`.

## Change

Before this round, G16 treated any word that contained the session id as session state. Claude Code's scratchpad and task paths contain the session id, so ordinary Bash writes there were denied in every mode. Now the session id counts only as the state file's name:
- `_g16_names`, the prefilter on the whole command, matches `*<sid>.state*`, not `*<sid>*`.
- `_g16_kind`, the check on each word, matches a word equal to `<sid>.state` or ending in `/<sid>.state`.

The comment above `_g16_kind` now says why the bare session id is not enough. I changed nothing else.

## Tests

New `@test "the session id counts only as the state file name: scratchpad writes pass"`, using the payload's session id `test-session`:
- `echo on > test-session.state` and `echo on > /anywhere/test-session.state` are still denied.
- Writes into `/private/tmp/claude-501/proj/test-session/scratchpad` get no vote: `node build.mjs > $d/out.txt`, `cp report.json $d/` and `git diff > $d/review.diff`.

The existing write-shape case `echo on > /tmp/test-session.state` still denies.

RED: `tests/run-bats -f "session id counts only" tests/hooks/g16-state.bats` failed at the scratchpad case: `node build.mjs > .../scratchpad/out.txt` gave `deny`, `commands may not write kern session state`. The two deny cases passed before the change too.

GREEN: the same command gives `ok 1`.

## Whole suite before commit

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..126`, 126 `ok`, 0 `not ok`, 0 skips.
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- shellcheck on `hooks/guards/g16-state.sh` with and without `-x`, and on `hooks/pre-tool-use` with `-x`: rc 0, no output.
