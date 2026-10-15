#!/usr/bin/env bats
# hooks/subagent-start: JSON shape, size, voice.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
}

context_of() {
  printf '%s' "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);if(j.hookSpecificOutput.hookEventName!=="SubagentStart")process.exit(3);process.stdout.write(j.hookSpecificOutput.additionalContext)})'
}

@test "valid SubagentStart JSON under 1,200 characters" {
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"Explore"')"
  [ "$status" -eq 0 ]
  ctx=$(context_of "$output")
  [[ "$ctx" == "# kern "*"(subagent)"* ]] || false
  [ "${#ctx}" -le 1200 ]
  [[ "$ctx" != *"Voice: terse"* ]] || false
}

@test "terse voice reaches the subagent" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'voice: terse\nsurface: auto\nautopilot: off\n' >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"kern:implementer"')"
  ctx=$(context_of "$output")
  [[ "$ctx" == *"Voice: terse"* ]] || false
  [ "${#ctx}" -le 1200 ]
}

@test "with settings.sh missing, subagent-start exits 0 and prints nothing or valid JSON" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/settings.sh"
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/subagent-start" 2>/dev/null <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"Explore"')")
  [ -z "$out" ] || context_of "$out" >/dev/null
}

@test "subagent returns skip preamble, praise and closing offers, and no agent is told to write a bulk file" {
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"kern:investigator"')"
  ctx=$(context_of "$output")
  [[ "$ctx" == *"with no preamble, praise or closing offer"* ]] || false
  [[ "$ctx" != *"Put bulk in a file"* ]] || false
}

@test "normal voice adds no terse line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions" "$R/.claude"
  printf 'voice: normal\nsurface: auto\nautopilot: off\n' >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  # The session's voice wins over the settings voice.
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"kern:implementer"')"
  ctx=$(context_of "$output")
  [[ "$ctx" == "# kern "*"(subagent)"* ]] || false
  [[ "$ctx" != *"Voice: terse"* ]] || false
}

@test "kern: off prints nothing" {
  mkdir -p "$R/.claude"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"Explore"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a bad session id falls back to the settings voice" {
  mkdir -p "$R/.claude" "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  # The state file "../x" would name if the id were not rejected.
  printf 'voice: normal\n' >"$CLAUDE_PLUGIN_DATA/x.state"
  run bash "$K/hooks/subagent-start" <<<"{\"session_id\":\"../x\",\"cwd\":\"$R\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"a1\",\"agent_type\":\"Explore\"}"
  [ "$status" -eq 0 ]
  ctx=$(context_of "$output")
  [[ "$ctx" == *"Voice: terse"* ]] || false
  [ "$(cat "$CLAUDE_PLUGIN_DATA/x.state")" = "voice: normal" ]
}
