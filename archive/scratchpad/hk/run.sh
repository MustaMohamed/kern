#!/usr/bin/env bash
# run.sh MODE TOOL CWD JSON_TOOL_INPUT  -> prints hook decision (or "no vote")
K=/Users/musta/Code/projects/kern
S=$(cd "$(dirname "$0")" && pwd)
export CLAUDE_PLUGIN_DATA=$S/data
mode=$1 tool=$2 cwd=$3 ti=$4
sid=sess-$mode
( export KERN_ROOT=$K; . $K/hooks/lib/settings.sh; . $K/hooks/lib/state.sh; if [ "$mode" = auto ]; then state_set $sid autopilot=on; else state_set $sid autopilot=off; fi )
input=$(printf '{"session_id":"%s","cwd":"%s","tool_name":"%s","tool_input":%s,"permission_mode":"default"}' "$sid" "$cwd" "$tool" "$ti")
out=$(printf '%s' "$input" | bash $K/hooks/pre-tool-use)
[ -n "$out" ] && printf '%s\n' "$out" | sed -n 's/.*"permissionDecision":"\([a-z]*\)","permissionDecisionReason":"\(.*\)"}}/\1: \2/p' || echo "no vote"
