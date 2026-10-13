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
  [[ "$output" == *'"kern G0: tool_input not parseable"'* ]] || false
  feed 5
  [[ "$output" == *'"kern G0: cwd not parseable"'* ]] || false
  feed 6
  [[ "$output" == *'"kern G0: agent_type not parseable"'* ]] || false
}

@test "under autopilot, unreadable input that names its session gives deny" {
  set_autopilot on
  for n in 3 4 5 6; do
    feed "$n"
    [ "$status" -eq 0 ] || { echo "$n -> status $status"; return 1; }
    [ "$(decision_of "$output")" = deny ] || { echo "$n -> $output"; return 1; }
    [[ "$output" == *'(autopilot: nobody to ask)"}}' ]] || { echo "$n -> $output"; return 1; }
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

@test "a deny and an ask in one call: deny wins and only deny reasons print" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  run_guard "$(bash_payload "echo push.policy: auto >> $R/.claude/kern.local.yml; echo autopilot: on >> $CLAUDE_PLUGIN_DATA/sessions/test-session.state")"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"kern G16: commands may not write kern session state"'* ]] || false
  [[ "$output" != *"kern settings"* ]] || false
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
  [[ "$output" == *'"kern G0: guard g99 did not load"'* ]] || false
}

@test "a guard file that stops loading partway, or a missing guard file, fails closed" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  printf 'guard_g01() { _g01_missing; }\nif then\n' >"$BATS_TEST_TMPDIR/k/hooks/guards/g01-git.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"kern G0: guard g01 did not load"'* ]] || false
  cp "$K/hooks/guards/g01-git.sh" "$BATS_TEST_TMPDIR/k/hooks/guards/"
  rm "$BATS_TEST_TMPDIR/k/hooks/guards/g13-protected.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"kern G0: guard g13 did not load"'* ]] || false
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
