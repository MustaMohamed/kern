#!/usr/bin/env bats
# Replays the payloads recorded in Task 1 through the hooks. A missing fixture means that event never
# fired in the spike, and the test is skipped with that reason.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
  F="$K/tests/fixtures/payloads"
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'voice: normal\nsurface: auto\nautopilot: off\n' >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

st() { sed -n "s/^$1: //p" "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"; }
replay() { sed "s#/tmp/kern-fixture#$R#g" "$F/$2.json" | bash "$K/hooks/$1"; }

@test "recorded typed /kern:mode terse switches the voice" {
  if [ -f "$F/expansion-mode.json" ]; then
    replay prompt-submit expansion-mode >/dev/null
  elif [ -f "$F/submit-slash-mode.json" ]; then
    replay prompt-submit submit-slash-mode >/dev/null
  else
    skip "no recorded /kern:mode payload"
  fi
  [ "$(st voice)" = terse ]
}

@test "recorded typed /kern:autopilot on turns autopilot on" {
  [ -f "$F/expansion-autopilot.json" ] || skip "no recorded /kern:autopilot expansion payload"
  replay prompt-submit expansion-autopilot >/dev/null
  [ "$(st autopilot)" = on ]
}

@test "the recorded background report never switches anything" {
  [ -f "$F/submit-task-notification.json" ] || skip "no recorded background report"
  replay prompt-submit submit-task-notification >/dev/null
  [ "$(st autopilot)" = off ]
  [ "$(st voice)" = normal ]
}

@test "the recorded SubagentStart payload yields SubagentStart JSON" {
  [ -f "$F/subagent-start.json" ] || skip "no recorded SubagentStart payload"
  out=$(replay subagent-start subagent-start)
  [[ "$out" == '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"'* ]] || false
}

@test "the recorded subagent PreToolUse payload parses: the dispatcher prints nothing or JSON" {
  [ -f "$F/pretooluse-subagent.json" ] || skip "no recorded subagent PreToolUse payload"
  [ -f "$K/hooks/pre-tool-use" ] || skip "hooks/pre-tool-use arrives in Task 9"
  out=$(replay pre-tool-use pretooluse-subagent)
  [ -z "$out" ] || [[ "$out" == '{"hookSpecificOutput":{"hookEventName":"PreToolUse"'* ]]
}
