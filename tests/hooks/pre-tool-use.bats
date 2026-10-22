#!/usr/bin/env bats
# hooks/pre-tool-use: fails closed on input it cannot read and on a guard that did not load, keeps the
# strictest vote, and honours KERN_GUARDS only under bats.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
}

# feed N: runs the dispatcher, byte for byte, on the Nth input it cannot read: 1 empty, 2 not JSON,
# 3 no tool_name, 4 truncated tool_input, 5 unterminated cwd, 6 unterminated agent_type.
feed() {
  local in="$BATS_TEST_TMPDIR/in"
  case "$1" in
    1) : >"$in" ;;
    2) printf 'not json' >"$in" ;;
    3) printf '{"session_id":"test-session","cwd":"%s"}' "$CWD" >"$in" ;;
    4) printf '{"session_id":"test-session","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"x","content":"a}' "$CWD" >"$in" ;;
    5) printf '{"session_id":"test-session","tool_name":"Bash","cwd":"/tmp}' >"$in" ;;
    6) printf '{"session_id":"test-session","cwd":"%s","tool_name":"Bash","tool_input":{"command":"ls"},"agent_type":"x}' "$CWD" >"$in" ;;
  esac
  run bash "$K/hooks/pre-tool-use" <"$in"
}

@test "input the dispatcher cannot read gives ask" {
  for n in 1 2 3 4 5 6; do
    feed "$n"
    [ "$status" -eq 0 ] || { echo "$n -> status $status"; return 1; }
    [ "$(decision_of "$output")" = ask ] || { echo "$n -> $output"; return 1; }
  done
  feed 4
  [[ "$output" == *'"needs user approval: kern G0: tool_input not parseable"'* ]] || false
  feed 5
  [[ "$output" == *'"needs user approval: kern G0: cwd not parseable"'* ]] || false
  feed 6
  [[ "$output" == *'"needs user approval: kern G0: agent_type not parseable"'* ]] || false
}

@test "under autopilot, unreadable input that names its session gives deny" {
  set_autopilot on
  for n in 3 4 5 6; do
    feed "$n"
    [ "$status" -eq 0 ] || { echo "$n -> status $status"; return 1; }
    [ "$(decision_of "$output")" = deny ] || { echo "$n -> $output"; return 1; }
    [[ "$output" == *'(autopilot: nobody to ask)"}}' ]] || { echo "$n -> $output"; return 1; }
    [[ "$output" == *'"permissionDecisionReason":"kern G0: '* ]] || { echo "$n -> $output"; return 1; }
  done
}

@test "under autopilot, input with no readable session id still never allows" {
  set_autopilot on
  for n in 1 2; do
    feed "$n"
    [ "$status" -eq 0 ] || { echo "$n -> status $status"; return 1; }
    [ "$(decision_of "$output")" = ask ] || { echo "$n -> $output"; return 1; }
  done
}

# In a headless run (-p, the SDK) Claude Code turns an ask into a denial, and the model reads only the reason
# (task-16-diagnosis X5): "kern G5: commit (message checks pass)" read as a block with no cause.
@test "an ask reason opens with the phrase that the user's approval is needed; a deny reason does not" {
  mkdir -p "$R/.claude" "$CLAUDE_PLUGIN_DATA/sessions"
  run_guard "$(bash_payload "echo push.policy: auto >> $R/.claude/kern.local.yml")"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"permissionDecisionReason":"needs user approval: kern G16: kern settings change guard policy; the user confirms each write"'* ]] || false
  [ "$(printf '%s' "$output" | grep -o 'needs user approval: ' | wc -l | tr -d ' ')" = 1 ]
  run_guard "$(bash_payload "echo autopilot: on >> $CLAUDE_PLUGIN_DATA/sessions/test-session.state")"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"permissionDecisionReason":"kern G16: commands may not write kern session state"'* ]] || false
  [[ "$output" != *'needs user approval'* ]] || false
}

@test "a deny and an ask in one call: deny wins and only deny reasons print" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  run_guard "$(bash_payload "echo push.policy: auto >> $R/.claude/kern.local.yml; echo autopilot: on >> $CLAUDE_PLUGIN_DATA/sessions/test-session.state")"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"kern G16: commands may not write kern session state"'* ]] || false
  [[ "$output" != *"kern settings"* ]] || false
}

@test "an ask beats a later allow, and only ask reasons print" {
  # Opus audit F-H1: no test pinned the dispatcher's ask-over-allow rule. Under push.policy auto, G1
  # allows a push of the worktree's own branch. In a copy of the hooks whose G00, the first guard to run,
  # asks on every call, the same push stays an ask.
  local c="git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt" >/dev/null 2>&1
  mkdir -p "$R/.claude" "$BATS_TEST_TMPDIR/k"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload "$c")"
  [ "$(decision_of "$output")" = allow ]
  [[ "$output" == *'"kern G1: push.policy auto: push feat"'* ]] || false
  printf 'guard_g00() { vote ask G00 "an earlier ask"; }\n' >"$BATS_TEST_TMPDIR/k/hooks/guards/g00-unproven.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload "$c")"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"permissionDecisionReason":"needs user approval: kern G00: an earlier ask"'* ]] || false
}

@test "a reason that echoes control bytes still prints JSON that parses" {
  # Tab, newline and 0x1f split words and json_get reads a raw 0x01 as a backslash, so those never
  # reach this reason; json.bats covers them.
  b=""
  for i in $(seq 2 30); do
    case "$i" in 9 | 10) continue ;; esac
    # shellcheck disable=SC2059 # the format is the octal escape
    printf -v c "\\$(printf '%03o' "$i")"
    b="$b$c"
  done
  printf '{"session_id":"test-session","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git x%sy"}}' \
    "$CWD" "$b" >"$BATS_TEST_TMPDIR/in"
  run bash "$K/hooks/pre-tool-use" <"$BATS_TEST_TMPDIR/in"
  [ "$(parsed_decision "$output")" = ask ]
  [[ "$output" == *"git x"*'\u0002'*'\u001e'*"y is not"* ]] || false
  # A newline inside $( ) reaches a reason as git_words' 0x1f record marker.
  # shellcheck disable=SC2016 # a literal $( in the command
  printf '{"session_id":"test-session","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git push origin \\"$(git \\nbranch --show-current)\\""}}' \
    "$CWD" >"$BATS_TEST_TMPDIR/in"
  run bash "$K/hooks/pre-tool-use" <"$BATS_TEST_TMPDIR/in"
  [ "$(parsed_decision "$output")" = ask ]
  # shellcheck disable=SC2016
  [[ "$output" == *'$(git \u001fbranch'* ]] || false
  # json_get decodes \b, so one appended record used to remove every decision under autopilot.
  set_autopilot on
  printf '{"session_id":"test-session","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git push --force origin main; git x\\by"}}' \
    "$CWD" >"$BATS_TEST_TMPDIR/in"
  run bash "$K/hooks/pre-tool-use" <"$BATS_TEST_TMPDIR/in"
  [ "$(parsed_decision "$output")" = deny ]
}

@test "a 10 KB UTF-8 assignment before a command runs every guard in under 2 s" {
  local blob t0 t1
  # shellcheck disable=SC2046 # one argument per character
  blob=$(printf 'é%.0s' $(seq 5120))
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  run_guard "$(bash_payload "X='$blob' ls")" ""
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
  [ $((t1 - t0)) -lt 2000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
}

@test "a guard file that does not load fails closed" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  printf 'guard_g99() {\n  if then\n}\n' >"$BATS_TEST_TMPDIR/k/hooks/guards/g99-broken.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"needs user approval: kern G0: guard g99 did not load"'* ]] || false
}

@test "a guard file that stops loading partway, or a missing guard file, fails closed" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  printf 'guard_g01() { _g01_missing; }\nif then\n' >"$BATS_TEST_TMPDIR/k/hooks/guards/g01-git.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"needs user approval: kern G0: guard g01 did not load"'* ]] || false
  cp "$K/hooks/guards/g01-git.sh" "$BATS_TEST_TMPDIR/k/hooks/guards/"
  rm "$BATS_TEST_TMPDIR/k/hooks/guards/g13-protected.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"needs user approval: kern G0: guard g13 did not load"'* ]] || false
}

# without_lib LIB: a copy of kern's hooks in $BATS_TEST_TMPDIR/k with hooks/lib/LIB removed.
without_lib() {
  rm -rf "$BATS_TEST_TMPDIR/k"
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/$1"
}

@test "a hook library that does not load gives ask, or deny under bypassPermissions" {
  local lib mode want ask p out
  for lib in json.sh settings.sh state.sh decide.sh gitctx.sh; do
    without_lib "$lib"
    for mode in default bypassPermissions; do
      want=ask ask='needs user approval: '
      [ "$mode" = default ] || want=deny ask=
      p=$(payload PreToolUse "\"permission_mode\":\"$mode\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push --force origin main\"}")
      out=$(bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" 2>/dev/null <<<"$p") || { echo "$lib $mode -> status $?"; return 1; }
      [ "$(parsed_decision "$out")" = "$want" ] || { echo "$lib $mode -> $out"; return 1; }
      [[ "$out" == *"\"${ask}kern G0: hook library $lib did not load; reinstall kern\""* ]] || { echo "$lib $mode -> $out"; return 1; }
    done
  done
  # A space after the colon still reads as bypassPermissions.
  p=$(payload PreToolUse '"permission_mode": "bypassPermissions","tool_name":"Bash","tool_input":{"command":"ls"}')
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" 2>/dev/null <<<"$p")
  [ "$(parsed_decision "$out")" = deny ]
}

@test "with POSIXLY_CORRECT set, a missing hook library still gives the G0 ask" {
  # In POSIX mode a failing "." exits the shell before "|| no_lib" can run.
  without_lib settings.sh
  out=$(POSIXLY_CORRECT=1 bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" 2>/dev/null <<<"$(bash_payload "git push --force origin main")") ||
    { echo "status $?"; return 1; }
  [ "$(parsed_decision "$out")" = ask ] || { echo "$out"; return 1; }
  [[ "$out" == *'"needs user approval: kern G0: hook library settings.sh did not load; reinstall kern"'* ]] || false
}

@test "a hook library that sources but lacks a function the dispatcher calls gives ask" {
  without_lib settings.sh
  { cat "$K/hooks/lib/settings.sh"; printf 'unset -f kern_enabled\n'; } >"$BATS_TEST_TMPDIR/k/hooks/lib/settings.sh"
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" 2>/dev/null <<<"$(bash_payload "git push --force origin main")")
  [ "$(parsed_decision "$out")" = ask ]
  [[ "$out" == *'"needs user approval: kern G0: hook library settings.sh did not load; reinstall kern"'* ]] || false
}

@test "pre-tool-use checks every function each library it loads defines" {
  need_lists_match pre-tool-use
}

@test "a gitctx.sh that sources but lacks git_words gives the G0 ask" {
  without_lib gitctx.sh
  { cat "$K/hooks/lib/gitctx.sh"; printf 'unset -f git_words\n'; } >"$BATS_TEST_TMPDIR/k/hooks/lib/gitctx.sh"
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" 2>/dev/null <<<"$(bash_payload "git push --force origin main")")
  [ "$(parsed_decision "$out")" = ask ] || { echo "$out"; return 1; }
  [[ "$out" == *'"needs user approval: kern G0: hook library gitctx.sh did not load; reinstall kern"'* ]] || { echo "$out"; return 1; }
}

@test "the dispatcher's list of guard ids names every guard file" {
  ids=$(sed -n 's/^KERN_GUARD_IDS="\(.*\)"$/\1/p' "$K/hooks/pre-tool-use")
  files=$(cd "$K/hooks/guards" && for f in g*.sh; do printf '%s ' "${f%%-*}"; done)
  [ -n "$ids" ]
  [ "$ids " = "$files" ]
}

@test "decision_of tells output with no decision from no output" {
  [ "$(decision_of "")" = none ]
  [ "$(decision_of "pre-tool-use: line 9: _g01_x: command not found")" = error ]
  [ "$(decision_of '{"hookSpecificOutput":{"permissionDecision":"ask"}}')" = ask ]
}

@test "KERN_GUARDS limits the guards under bats only" {
  p=$(payload PreToolUse "\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$CLAUDE_PLUGIN_DATA/sessions/test-session.state\"}")
  run_guard "$p" g01
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
  out=$(unset BATS_TEST_FILENAME; KERN_GUARDS=g01 bash "$K/hooks/pre-tool-use" <<<"$p")
  [ "$(decision_of "$out")" = deny ]
}

@test "need_lists_match fails on a library loaded in a form it cannot read" {
  for line in '  . "$KERN_ROOT/hooks/lib/json.sh"' 'source "$KERN_ROOT/hooks/lib/json.sh"' 'for l in json; do . "$KERN_ROOT/hooks/lib/$l.sh"; done'; do
    { printf '%s\n' "$line"; cat "$K/hooks/pre-tool-use"; } > "$BATS_TEST_TMPDIR/pre-tool-use"
    run need_lists_match "$BATS_TEST_TMPDIR/pre-tool-use"
    [ "$status" -eq 1 ] || { echo "accepted: $line"; return 1; }
    [[ "$output" == *"in a form these checks cannot read"* ]] || false
  done
}

# A command substitution whose pipe cannot be made gives status 0 and no output. With no tool name no
# guard runs, so the hook must not stay silent (re-review of 2026-10-21).
@test "a tool name that reads empty asks, is denied under autopilot, and stays silent with kern off" {
  local C="$BATS_TEST_TMPDIR/k"
  mkdir -p "$C"
  cp -R "$K/hooks" "$K/scripts" "$K/kernel" "$K/modes" "$K/.claude-plugin" "$C/"
  # A hook copy whose json_get prints nothing for tool_name stands in for that substitution failing.
  cat >>"$C/hooks/lib/json.sh" <<'EOS'
eval "_kern_real_json_get$(declare -f json_get | sed '1s/^json_get//')"
json_get() { [ "$1" = tool_name ] && return 0; _kern_real_json_get "$@"; }
EOS
  set_autopilot off
  run bash "$C/hooks/pre-tool-use" <<<"$(bash_payload "git push --force origin main")"
  [ "$(decision_of "$output")" = ask ] || { echo "$output"; return 1; }
  [[ "$output" == *"the tool name in the hook input came back empty"* ]] || false
  set_autopilot on
  run bash "$C/hooks/pre-tool-use" <<<"$(bash_payload "git push --force origin main")"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  printf 'kern: off\n' >"$HOME/.claude/kern.yml"
  run bash "$C/hooks/pre-tool-use" <<<"$(bash_payload "git push --force origin main")"
  [ -z "$output" ]
}
