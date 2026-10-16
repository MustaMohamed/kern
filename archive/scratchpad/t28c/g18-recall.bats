#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  export KERN_GUARDS=g18 KERN_ROOT=/Users/musta/Code/projects/kern
}
payload() {
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"},"agent_id":"a1","agent_type":"kern:investigator"}' "$REPO" "$1"
}
vote() { run bash "$KERN_ROOT/hooks/pre-tool-use" <<< "$(payload "$1")"; echo "CMD: $1 => ${output:-none}" >&3; }

@test "the miner commands recall prescribes pass G18" {
  F=/tmp/h/.claude/projects/-x/abc.jsonl
  for c in "grep -n x.y $F | cut -c1-300" "grep -n 'x.y' $F | cut -c1-300" "grep -n x $F | cut -c1-300" "wc -c $F" "sed -n 3,9p $F" "sed -n 4p $F | wc -c"; do
    vote "$c"
    [ -z "$output" ]
  done
}
@test "the forbidden forms are still denied" {
  F=/tmp/h/x.jsonl
  vote "grep -n 'x>y' $F"
  [[ "$output" == *deny* ]]
}
