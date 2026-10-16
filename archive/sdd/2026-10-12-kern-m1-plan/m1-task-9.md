### Task 9: Guard dispatcher, G16 and hook wiring

**Files:**
- Create: `hooks/lib/decide.sh`, `hooks/lib/gitctx.sh`, `hooks/pre-tool-use`, `hooks/guards/g16-state.sh`, `hooks/hooks.json`
- Test: `tests/hooks/gitctx.bats`, `tests/hooks/g16-state.bats`, `tests/hooks-json.test.mjs`

**Interfaces:**
- Consumes: `json.sh` (Task 2), `settings.sh` (Task 3), `state.sh` (Task 5); all four hook scripts exist after this task.
- Produces: the vote API and the guard contract listed under "Interfaces M2 relies on"; `hooks/hooks.json` exactly as in `docs/plans/contract.md`. `gitctx.sh` functions: `git_words CMD`, `_split_words`, `_subst_bodies`, `_shell_words STR`, `git_sub CMDLINE` (`<dir>\t<sub>\t<rest>`, exit 1 not git), `cmd_head CMDLINE`, `in_main_checkout DIR`, `current_branch DIR`, `base_branch_name`, `branch_protected BRANCH`, `push_targets DIR REST`, `with_timeout SECS CMD...`, `gh_sub CMDLINE` (`<group> <verb>`), `word_value WORDS FLAG...`, `word_has WORDS FLAG...`.

- [ ] **Step 1: Write the failing tests**

`tests/hooks/gitctx.bats`:
```bash
#!/usr/bin/env bats
# hooks/lib/gitctx.sh: command splitting and git parsing that every guard relies on.

load ../helpers/common

setup() {
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  for lib in settings gitctx; do
    # shellcheck source=/dev/null
    . "$KERN_ROOT/hooks/lib/$lib.sh"
  done
  export CWD=/tmp
}

@test "git_words splits chains and keeps quoted separators" {
  run git_words 'cd x && git push origin main; echo "a;b" | grep q || git status'
  [ "${lines[0]}" = "cd x" ]
  [ "${lines[1]}" = "git push origin main" ]
  [ "${lines[2]}" = 'echo "a;b"' ]
  [ "${lines[3]}" = "grep q" ]
  [ "${lines[4]}" = "git status" ]
}

@test "git_words also prints the bodies of bash -c, eval, \$( ) and backticks" {
  run git_words "bash -c 'git stash && git switch main'"
  [[ "$output" == *$'\n'"git stash"$'\n'"git switch main"* ]] || false
  run git_words 'echo $(git push -f) && x=`git reset --hard`'
  [[ "$output" == *$'\n'"git push -f"* ]] || false
  [[ "$output" == *$'\n'"git reset --hard"* ]] || false
}

@test "git_sub reads -C, skips env and global options" {
  run git_sub 'FOO=1 git -C /repo -c a=b --no-pager push -u origin "my branch"'
  [ "$output" = "/repo	push	-u origin my branch" ]
  run git_sub "ls -la"
  [ "$status" -eq 1 ]
}

@test "gh_sub, word_value and word_has" {
  [ "$(gh_sub 'GH_TOKEN=x gh pr create --draft')" = "pr create" ]
  w=$(_shell_words "gh pr create --head feat --title 'a b'")
  [ "$(word_value "$w" --head -H)" = feat ]
  [ "$(word_value "$w" --title)" = "a b" ]
  word_has "$w" --title
  run word_has "$w" --draft
  [ "$status" -eq 1 ]
}

@test "push_targets: refspecs, deletes and the current branch" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  run push_targets "$R" "origin +HEAD:refs/heads/rel :old"
  [ "${lines[0]}" = rel ]
  [ "${lines[1]}" = old ]
  run push_targets "$R" "-u origin"
  [ "$output" = feat ]
}

@test "with_timeout returns promptly when the command finishes" {
  start=$(date +%s)
  out=$(with_timeout 10 echo done)
  [ "$out" = done ]
  [ $(($(date +%s) - start)) -lt 3 ]
}
```

`tests/hooks/g16-state.bats`:
```bash
#!/usr/bin/env bats
# G16: Claude cannot write kern session state or relay a mode or autopilot command.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
}

@test "Write under the sessions dir is denied in both modes" {
  p=$(payload PreToolUse "\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$CLAUDE_PLUGIN_DATA/sessions/test-session.state\",\"content\":\"autopilot: on\"}")
  run_guard "$p" g16
  [ "$(decision_of "$output")" = deny ]
  set_autopilot on
  run_guard "$p" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "Edit of another file: no vote" {
  run_guard "$(payload PreToolUse "\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$R/README.md\"}")" g16
  [ "$(decision_of "$output")" = none ]
}

@test "a Bash command naming the sessions dir is denied" {
  run_guard "$(bash_payload "echo autopilot: on >> $CLAUDE_PLUGIN_DATA/sessions/test-session.state")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "a scheduled prompt or relayed message carrying /kern:autopilot is denied" {
  for t in CronCreate ScheduleWakeup RemoteTrigger SendMessage; do
    run_guard "$(payload PreToolUse "\"tool_name\":\"$t\",\"tool_input\":{\"prompt\":\"/kern:autopilot on\"}")" g16
    [ "$(decision_of "$output")" = deny ] || { echo "$t -> $output"; return 1; }
  done
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"/kern:mode terse\"}")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "a scheduled prompt without kern commands: no vote" {
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"check CI\"}")" g16
  [ "$(decision_of "$output")" = none ]
}
```

`tests/hooks-json.test.mjs`:
```js
// hooks/hooks.json: the shape the contract fixes, and every script it names exists and is executable.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const hooks = JSON.parse(readFileSync(join(root, 'hooks', 'hooks.json'), 'utf8')).hooks;

test('every M1 event is wired in exec form', () => {
  assert.deepEqual(Object.keys(hooks).sort(), ['PreToolUse', 'SessionStart', 'SubagentStart', 'UserPromptExpansion', 'UserPromptSubmit']);
  for (const [event, groups] of Object.entries(hooks)) {
    for (const g of groups) for (const h of g.hooks) {
      assert.equal(h.command, 'bash', `${event} uses exec form`);
      const script = h.args[0].replace('${CLAUDE_PLUGIN_ROOT}', root);
      assert.ok(statSync(script).mode & 0o111, `${script} is executable`);
    }
  }
});

test('the guard dispatcher fails closed and sees every guarded tool', () => {
  const pre = hooks.PreToolUse[0];
  assert.equal(pre.hooks[0].onFailure, 'block');
  for (const tool of ['Bash', 'Write', 'Edit', 'NotebookEdit', 'Skill', 'CronCreate', 'ScheduleWakeup', 'RemoteTrigger', 'SendMessage', 'mcp__claude_ai_Linear__save_issue']) {
    assert.match(tool, new RegExp(`^(${pre.matcher})$`), tool);
  }
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats; node --test tests/hooks-json.test.mjs`
Expected: FAIL; `hooks/lib/gitctx.sh: No such file or directory`, `hooks/pre-tool-use: No such file or directory`, and `ENOENT ... hooks/hooks.json`.

- [ ] **Step 3: Write `hooks/lib/decide.sh`**

```bash
# shellcheck shell=bash
# PreToolUse votes. Each guard calls `vote`; the dispatcher calls `emit_decision` once.
# Needs json.sh. Reads AUTOPILOT (1 under autopilot).

_KERN_VOTE=""
_KERN_R_DENY=""
_KERN_R_ASK=""
_KERN_R_ALLOW=""

# vote allow|ask|deny GUARD REASON: keeps the strictest decision (deny > ask > allow).
vote() {
  local d="$1" line="$2: $3"
  case "$d" in
    deny)
      _KERN_VOTE=deny
      _KERN_R_DENY="${_KERN_R_DENY:+$_KERN_R_DENY; }$line"
      ;;
    allow)
      [ -z "$_KERN_VOTE" ] && _KERN_VOTE=allow
      _KERN_R_ALLOW="${_KERN_R_ALLOW:+$_KERN_R_ALLOW; }$line"
      ;;
    *)
      [ "$_KERN_VOTE" != deny ] && _KERN_VOTE=ask
      _KERN_R_ASK="${_KERN_R_ASK:+$_KERN_R_ASK; }$line"
      ;;
  esac
}

# fail_closed REASON: input could not be parsed; never allow.
fail_closed() {
  vote ask G0 "$1"
}

# emit_decision: prints the PreToolUse JSON for the strictest vote, or nothing when nobody voted.
emit_decision() {
  local d="$_KERN_VOTE" r
  [ -n "$d" ] || return 0
  case "$d" in
    deny) r="$_KERN_R_DENY" ;;
    ask) r="$_KERN_R_ASK" ;;
    *) r="$_KERN_R_ALLOW" ;;
  esac
  if [ "$d" = ask ] && [ "${AUTOPILOT:-0}" = 1 ]; then
    d=deny
    r="$r (autopilot: nobody to ask)"
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
    "$d" "$(printf 'kern %s' "$r" | json_escape)"
}
```

- [ ] **Step 4: Write `hooks/lib/gitctx.sh`**

`with_timeout` sends the watchdog's output to `/dev/null` and kills its `sleep` child. Without both, the orphaned `sleep` holds the command substitution's pipe open and every `gh` call waits the full timeout.

```bash
# shellcheck shell=bash
# Shell and git parsing for guards. Needs settings.sh. Reads CWD and KERN_MAIN.

# git_words CMD: one simple command per line. Splits on ; & && || | and newlines outside quotes,
# backticks and $( ). The body of `bash -c '...'`, `sh -c` and `eval '...'` is split again and
# printed after its wrapper, so a chained command inside a string is still seen.
git_words() {
  local seg inner body
  _split_words "$1" | while IFS= read -r seg; do
    printf '%s\n' "$seg"
    _subst_bodies "$seg" | while IFS= read -r body; do
      [ -n "$body" ] && git_words "$body"
    done
    inner=$(printf '%s\n' "$seg" | sed -n -E "s/^(env +([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*)?((ba|z|da)?sh +(-[a-z]+ +)*-c|eval) +//p")
    [ -n "$inner" ] || continue
    inner=$(_shell_words "$inner" | head -n 1)
    [ -n "$inner" ] && git_words "$inner"
  done
}

# _subst_bodies STR: the body of each outermost $( ) and backtick pair, one per line.
_subst_bodies() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? " " : "") $0 }
    END {
      n = length(buf); q = ""; depth = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; continue }
        if (c == "\\") { i++; continue }
        if (depth == 0 && c == "`") {
          e = index(substr(buf, i + 1), "`")
          if (e) { print substr(buf, i + 1, e - 1); i += e }
          continue
        }
        if (c == "$" && substr(buf, i + 1, 1) == "(") {
          if (depth == 0) s = i + 2
          depth++; i++; continue
        }
        if (depth > 0) {
          if (c == "(") depth++
          else if (c == ")") { depth--; if (depth == 0) print substr(buf, s, i - s) }
          continue
        }
        if (c == sq) q = sq
      }
    }'
}

_split_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    function emit(s) { gsub(/^[ \t\n]+|[ \t\n]+$/, "", s); if (s != "") print s }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(buf); q = ""; depth = 0; start = 1; i = 1
      while (i <= n) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; i++; continue }
        if (c == "\\") { i += 2; continue }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i++ }
          else if (c == ")" && depth > 0) depth--
          i++; continue
        }
        if (q == "`") { if (c == "`") q = ""; i++; continue }
        if (c == sq || c == "\"" || c == "`") { q = c; i++; continue }
        if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i += 2; continue }
        if (depth > 0) { if (c == "(") depth++; else if (c == ")") depth--; i++; continue }
        if (c == ";" || c == "\n" || c == "&" || c == "|") {
          emit(substr(buf, start, i - start))
          if ((c == "&" || c == "|") && substr(buf, i + 1, 1) == c) i++
          start = i + 1
        }
        i++
      }
      emit(substr(buf, start))
    }'
}

# _shell_words STR: the words of one simple command, quotes removed, one per line.
_shell_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? " " : "") $0 }
    END {
      n = length(buf); q = ""; w = ""; have = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "\\" && index("\"\\$`", substr(buf, i + 1, 1))) { i++; w = w substr(buf, i, 1) }
          else w = w c
          continue
        }
        if (c == "\\") { i++; w = w substr(buf, i, 1); have = 1; continue }
        if (c == sq || c == "\"") { q = c; have = 1; continue }
        if (c == " " || c == "\t") { if (have) print w; w = ""; have = 0; continue }
        w = w c; have = 1
      }
      if (have) print w
    }'
}

# git_sub CMDLINE: for a simple git command prints `<dir>\t<subcommand>\t<rest>`. Exit 1 when the
# command is not git. Leading VAR=value words and command/exec/time/nohup/sudo are skipped.
git_sub() {
  local w=() t i=0 n dir="${CWD:-$PWD}" rest=""
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_shell_words "$1")
EOT
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      [A-Za-z_]*=*) i=$((i + 1)) ;;
      command | exec | time | nohup | sudo) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 1
  case "${w[$i]}" in git | */git) ;; *) return 1 ;; esac
  i=$((i + 1))
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      -C)
        t="${w[$((i + 1))]-}"
        case "$t" in /*) dir="$t" ;; *) dir="$dir/$t" ;; esac
        i=$((i + 2))
        ;;
      -c) i=$((i + 2)) ;;
      --git-dir=* | --work-tree=* | --namespace=* | --no-pager | --paginate | -p | --bare | --no-replace-objects | --literal-pathspecs | --no-optional-locks) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 1
  t="${w[$i]}"
  i=$((i + 1))
  while [ "$i" -lt "$n" ]; do
    rest="${rest:+$rest }${w[$i]}"
    i=$((i + 1))
  done
  printf '%s\t%s\t%s\n' "$dir" "$t" "$rest"
}

# cmd_head CMDLINE: the first two words of a simple command after env assignments and wrappers.
cmd_head() {
  _shell_words "$1" | awk '
    !started && /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
    !started && /^(command|exec|time|nohup|sudo)$/ { next }
    { started = 1; out = out (n++ ? " " : "") $0; if (n == 2) exit }
    END { print out }'
}

# in_main_checkout DIR: exit 0 when DIR is inside the main worktree (not a linked worktree).
in_main_checkout() {
  local top main
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  main=$(kern_main_root "$1") || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$main" && pwd -P)" ]
}

# current_branch DIR
current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null
}

# base_branch_name: settings base_branch, else origin/HEAD. Exit 1 when neither resolves.
base_branch_name() {
  local b
  if b=$(settings_get base_branch) && [ -n "$b" ]; then
    printf '%s\n' "$b"
    return 0
  fi
  b=$(git -C "${KERN_MAIN:-${CWD:-$PWD}}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || return 1
  printf '%s\n' "${b#origin/}"
}

# branch_protected BRANCH: base branch, branch.protected or deploy.envs. With no resolvable base,
# main, master, trunk and develop count as protected.
branch_protected() {
  local base
  if base=$(base_branch_name); then
    [ "$1" = "$base" ] && return 0
  else
    case "$1" in main | master | trunk | develop) return 0 ;; esac
  fi
  list_has "$(settings_get branch.protected '')" "$1" && return 0
  list_has "$(settings_get deploy.envs '')" "$1" && return 0
  return 1
}

# push_targets DIR REST: remote branch names a `git push` writes, one per line. `:x` and
# --delete targets print as `x`. No refspec means the current branch.
push_targets() {
  local dir="$1" w=() t i=0 n pos=0 any=0
  while IFS= read -r t; do [ -n "$t" ] && w+=("$t"); done <<EOT
$(_shell_words "$2")
EOT
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    t="${w[$i]}"
    i=$((i + 1))
    case "$t" in
      --repo | --push-option | -o | --receive-pack | --exec) i=$((i + 1)); continue ;;
      -*) continue ;;
    esac
    pos=$((pos + 1))
    [ "$pos" -eq 1 ] && continue
    any=1
    t=${t#+}
    case "$t" in
      *:*) t=${t#*:} ;;
    esac
    [ "$t" = HEAD ] && t=$(current_branch "$dir")
    printf '%s\n' "${t#refs/heads/}"
  done
  [ "$any" = 1 ] || current_branch "$dir"
}

# with_timeout SECS CMD...: runs CMD, killing it after SECS seconds. Returns CMD's exit code.
with_timeout() {
  local secs="$1" pid w rc
  shift
  "$@" &
  pid=$!
  (sleep "$secs" && kill "$pid") >/dev/null 2>&1 &
  w=$!
  wait "$pid"
  rc=$?
  pkill -P "$w" >/dev/null 2>&1
  kill "$w" >/dev/null 2>&1
  wait "$w" 2>/dev/null
  return "$rc"
}

# gh_sub CMDLINE: for `gh <group> <verb> ...` prints `<group> <verb>`; exit 1 for anything else.
gh_sub() {
  local out
  out=$(_shell_words "$1" | awk '
    !s && /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
    !s && /^(command|exec|time|nohup|sudo)$/ { next }
    { s = 1; w[++n] = $0; if (n == 3) exit }
    END { if (w[1] == "gh" && n >= 3) print w[2] " " w[3]; else if (w[1] == "gh" && n == 2) print w[2] }')
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# word_value WORDS FLAG...: the value after the first of FLAG in the newline-separated WORDS
# (`--flag value` or `--flag=value`). Exit 1 when absent.
word_value() {
  local words="$1" w prev="" f
  shift
  while IFS= read -r w; do
    for f in "$@"; do
      if [ "$prev" = "$f" ]; then printf '%s\n' "$w"; return 0; fi
      case "$w" in "$f="*) printf '%s\n' "${w#"$f"=}"; return 0 ;; esac
    done
    prev="$w"
  done <<EOT
$words
EOT
  return 1
}

# word_has WORDS FLAG...: exit 0 when any FLAG is one of the newline-separated WORDS.
word_has() {
  local words="$1" w f
  shift
  while IFS= read -r w; do
    for f in "$@"; do [ "$w" = "$f" ] && return 0; done
  done <<EOT
$words
EOT
  return 1
}
```

- [ ] **Step 5: Write `hooks/pre-tool-use`**

```bash
#!/usr/bin/env bash
# kern PreToolUse dispatcher: runs every guard in hooks/guards and prints the strictest vote.
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
# shellcheck source=hooks/lib/json.sh
. "$KERN_ROOT/hooks/lib/json.sh"
# shellcheck source=hooks/lib/settings.sh
. "$KERN_ROOT/hooks/lib/settings.sh"
# shellcheck source=hooks/lib/state.sh
. "$KERN_ROOT/hooks/lib/state.sh"
# shellcheck source=hooks/lib/decide.sh
. "$KERN_ROOT/hooks/lib/decide.sh"
# shellcheck source=hooks/lib/gitctx.sh
. "$KERN_ROOT/hooks/lib/gitctx.sh"

# shellcheck disable=SC2034 # KERN_INPUT, TOOL and AGENT are read by json.sh and the guard files
KERN_INPUT=$(cat)
AUTOPILOT=0
SID=$(json_get session_id 2>/dev/null) || SID=""
# shellcheck disable=SC2034 # TOOL is read by guard files
if ! json_ok || ! TOOL=$(json_get tool_name); then
  [ -n "$SID" ] && autopilot_on "$SID" 2>/dev/null && AUTOPILOT=1
  fail_closed "hook input not parseable"
  emit_decision
  exit 0
fi
CWD=$(json_get cwd) || CWD="$PWD"
# shellcheck disable=SC2034 # read by guard files
AGENT=$(json_get agent_type) || AGENT=""
TOOL_INPUT=$(json_get_raw tool_input) || TOOL_INPUT="{}"
KERN_MAIN=$(kern_main_root "$CWD" 2>/dev/null) || KERN_MAIN=""
export CWD KERN_MAIN
kern_enabled || exit 0
[ -n "$SID" ] && autopilot_on "$SID" && AUTOPILOT=1

for f in "$KERN_ROOT"/hooks/guards/g*.sh; do
  # shellcheck source=/dev/null
  . "$f"
done
for f in "$KERN_ROOT"/hooks/guards/g*.sh; do
  id=$(basename "$f" .sh)
  id=${id%%-*}
  if [ -n "${KERN_GUARDS-}" ]; then
    case ",$KERN_GUARDS," in *",$id,"*) ;; *) continue ;; esac
  fi
  "guard_$id"
done
emit_decision
exit 0
```

- [ ] **Step 6: Write `hooks/guards/g16-state.sh`**

```bash
# shellcheck shell=bash
# G16 mode state: Claude cannot write kern's session state or schedule a prompt that switches it.

guard_g16() {
  local p sd
  sd=$(state_dir)
  case "$TOOL" in
    Write | Edit | NotebookEdit)
      p=$(ti_get file_path) || p=$(ti_get notebook_path) || p=""
      case "$p" in
        "$sd"/* | */plugins/data/kern*/sessions/*) vote deny G16 "kern session state is written only by kern hooks; ask the user to type /kern:mode or /kern:autopilot" ;;
      esac
      ;;
    Bash)
      p=$(ti_get command) || p=""
      case "$p" in
        *"$sd"* | *plugins/data/kern*sessions*) vote deny G16 "commands may not touch kern session state" ;;
      esac
      ;;
    CronCreate | ScheduleWakeup | RemoteTrigger | SendMessage | Skill)
      case "$TOOL_INPUT" in
        *kern:autopilot* | *kern:mode*) vote deny G16 "$TOOL may not carry /kern:autopilot or /kern:mode; only the user types them" ;;
      esac
      ;;
  esac
}
```

- [ ] **Step 7: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/session-start"] }] }],
    "SubagentStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/subagent-start"] }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/prompt-submit"], "timeout": 10 }] }],
    "UserPromptExpansion": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/prompt-submit"], "timeout": 10 }] }],
    "PreToolUse": [{ "matcher": "Bash|Write|Edit|NotebookEdit|Skill|CronCreate|ScheduleWakeup|RemoteTrigger|SendMessage|mcp__.*", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use"], "timeout": 20, "onFailure": "block" }] }]
  }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `chmod +x hooks/pre-tool-use && tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats tests/hooks/payloads.bats && node --test tests/hooks-json.test.mjs && claude plugin validate . --strict`
Expected: `16 tests, 0 failures` (payload tests may skip); `# pass 2`; `Validation passed`.

- [ ] **Step 9: Commit**

```bash
git add -- hooks/lib/decide.sh hooks/lib/gitctx.sh hooks/pre-tool-use hooks/guards/g16-state.sh hooks/hooks.json tests/hooks/gitctx.bats tests/hooks/g16-state.bats tests/hooks-json.test.mjs
git commit -m "M1: add the guard dispatcher, G16 and hook wiring" -m "One process per tool call parses the input once, runs every guard and returns the strictest vote; G16 keeps Claude out of its own mode state."
```

---

