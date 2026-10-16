#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/wt
setup() { wt_test_env; REPO="$TMP/repo"; make_fixture "$REPO"; mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"; export KERN_GUARDS=g18; }
payload() { printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"},"agent_id":"a1","agent_type":"kern:investigator"}' "$REPO" "$1"; }
@test "mining commands" {
  for cmd in 'grep -n floci /abs/a.jsonl | cut -c1-300' 'wc -c /abs/a.jsonl' 'sed -n 12,40p /abs/a.jsonl' 'sed -n 12p /abs/a.jsonl | wc -c' 'sed -n 12p /abs/a.jsonl | cut -c1-500' 'grep -c floci /abs/a.jsonl'; do
    run bash /Users/musta/Code/projects/kern/hooks/pre-tool-use <<< "$(payload "$cmd")"
    [ -z "$output" ] || { echo "VOTE for: $cmd: $output"; false; }
  done
}
