# usage: nat.sh BASH PROMPT-JSON-ESCAPED ; prints voice after
B=$1; K=/Users/musta/Code/projects/kern; HOOKROOT=${3:-$K}
D=$(mktemp -d); R=$D/repo; mkdir -p $R $D/data/sessions; git -C $R init -q 2>/dev/null
printf 'voice: normal\nsurface: auto\nautopilot: off\n' > $D/data/sessions/s.state
printf '{"session_id":"s","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$R" "$2" | CLAUDE_PLUGIN_DATA=$D/data CLAUDE_PLUGIN_ROOT=$HOOKROOT $B $HOOKROOT/hooks/prompt-submit >/dev/null 2>&1
sed -n 's/^voice: //p' $D/data/sessions/s.state; rm -rf $D
