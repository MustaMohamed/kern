#!/bin/bash
# probe.sh [-a] [-c CWD] COMMAND : runs dispatcher with only g16, prints decision and reason
SP=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad
K=${KROOT:-/Users/musta/Code/projects/kern}
ap=off; cwd=$SP/env/repo
while :; do case "$1" in -a) ap=on; shift ;; -c) cwd=$2; shift 2 ;; *) break ;; esac; done
export HOME=$SP/env/home CLAUDE_PLUGIN_DATA=$SP/env/data CLAUDE_PLUGIN_ROOT=$K
unset CLAUDE_CODE_ENTRYPOINT
printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$ap" > $SP/env/data/sessions/test-session.state
. $K/hooks/lib/json.sh
j=$(printf '%s' "$1" | json_escape)
p=$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$cwd" "$j")
out=$(printf '%s' "$p" | env BATS_TEST_FILENAME=x KERN_GUARDS=${G:-g16} ${BASH_BIN:-/bin/bash} $K/hooks/pre-tool-use)
d=$(printf '%s' "$out" | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p')
r=$(printf '%s' "$out" | sed -n 's/.*"permissionDecisionReason":"\(kern G[0-9]*\): \(.\{0,40\}\).*/\1 \2/p')
printf '%-5s %-50s | %s\n' "${d:-none}" "$r" "$(printf "%q" "$1")"
