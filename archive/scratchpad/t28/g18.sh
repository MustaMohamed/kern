#!/usr/bin/env bash
S=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t28
export HOME=$S/home CLAUDE_PLUGIN_DATA=$S/data CLAUDE_PLUGIN_ROOT=/Users/musta/Code/projects/kern KERN_GUARDS=g18
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  esc=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
  out=$(printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"},"agent_id":"a1","agent_type":"kern:investigator"}' "$S/repo" "$esc" | bash $CLAUDE_PLUGIN_ROOT/hooks/pre-tool-use 2>&1)
  if [ -z "$out" ]; then echo "ALLOW  $cmd"; else echo "DENY   $cmd"; fi
done
