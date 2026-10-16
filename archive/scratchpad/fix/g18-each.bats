#!/usr/bin/env bats
load ../helpers/wt
setup() { wt_test_env; REPO="$TMP/repo"; make_fixture "$REPO"; mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"; export KERN_GUARDS=g18; }
payload() { printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"},"agent_id":"a1","agent_type":"kern:investigator"}' "$REPO" "$1"; }
d() { run bash "$KERN_ROOT/hooks/pre-tool-use" <<< "$(payload "$1")"; [[ "$output" == *'"deny"'* ]]; }
@test "deny: sed -n 1p -i a.txt" { d 'sed -n 1p -i a.txt'; }
@test "deny: sed -n 1p a.txt -i" { d 'sed -n 1p a.txt -i'; }
@test "deny: sed -n 1p --in-place=.bak a.txt" { d 'sed -n 1p --in-place=.bak a.txt'; }
@test "deny: sed -n 1p -e 'w /tmp/x' a.txt" { d "sed -n 1p -e 'w /tmp/x' a.txt"; }
@test "deny: rg -nz foo" { d 'rg -nz foo'; }
@test "allow: sed -n 1,5p a.txt" { ! d 'sed -n 1,5p a.txt'; }
@test "allow: sed -n '\$p' a.txt" { ! d "sed -n '\$p' a.txt"; }
