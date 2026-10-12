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

@test "a guard file that does not load fails closed" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  printf 'guard_g99() {\n  if then\n}\n' >"$BATS_TEST_TMPDIR/k/hooks/guards/g99-broken.sh"
  run bash "$BATS_TEST_TMPDIR/k/hooks/pre-tool-use" <<<"$(bash_payload ls)"
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"kern G0: guard g99 did not load"'* ]] || false
}

@test "KERN_GUARDS limits the guards under bats only" {
  p=$(payload PreToolUse "\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$CLAUDE_PLUGIN_DATA/sessions/test-session.state\"}")
  run_guard "$p" g01
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
  out=$(unset BATS_TEST_FILENAME; KERN_GUARDS=g01 bash "$K/hooks/pre-tool-use" <<<"$p")
  [ "$(decision_of "$out")" = deny ]
}
