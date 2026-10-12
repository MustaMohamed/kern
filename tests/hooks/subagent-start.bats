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
