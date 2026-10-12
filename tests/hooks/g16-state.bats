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
