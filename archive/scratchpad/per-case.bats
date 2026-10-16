load /Users/musta/Code/projects/kern/tests/helpers/common
setup() { R="$BATS_TEST_TMPDIR/repo"; make_repo "$R"; kern_env "$R"; mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"; }
fp() { payload PreToolUse "\"tool_name\":\"$1\",\"tool_input\":{\"file_path\":\"$2\",\"content\":\"x\"}"; }
@test "per case" {
  local s=$'\305\277' k=$'\342\204\252' c
  for c in "echo x > .claude/${s}ettings.json" "echo x > .claude/${k}ern.yml" "echo x > .claude/${s}ettings.local.json" "echo on > $CLAUDE_PLUGIN_DATA/${s}essions/a.state"; do
    run env KERN_GUARDS=g16 bash "$KROOT/hooks/pre-tool-use" <<<"$(bash_payload "$c")"; echo "Bash $c => $(decision_of "$output")" >&3
  done
  for c in "$R/.claude/${s}ettings.json" "$R/.claude/${k}ern.local.yml" "$CLAUDE_PLUGIN_DATA/${s}essions/a.state"; do
    run env KERN_GUARDS=g16 bash "$KROOT/hooks/pre-tool-use" <<<"$(fp Write "$c")"; echo "Write ${c##*/repo/} => $(decision_of "$output")" >&3
  done
}
