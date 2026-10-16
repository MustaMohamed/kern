#!/bin/bash
# run.sh SNAPKIND CWDKIND MODE OUT TREE...: each command of the files in $CORPORA, for each tree; TSV to OUT.
. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
snapk=$1; cwdk=$2; mode=$3; out=$4; shift 4
T35O=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35
case $snapk in none) SNAP="" ;; real) SNAP=$T35O/../t33r/real-snap.sh ;; hostile) SNAP=$T35O/../t33r/hostile-snap.sh ;; esac
setup_env
case $cwdk in main) export CWD="$R" ;; wt) export CWD="$W/wt" ;; esac
: >"$out"
autopilot "$mode"
n=0
# shellcheck disable=SC2086 # CORPORA is a list of files
cat $CORPORA | while IFS= read -r line; do
  [ -n "$line" ] || continue
  n=$((n + 1))
  agent=""
  case "$line" in "["*"] "*) agent=${line%%] *}; agent=${agent#[}; line=${line#*] } ;; esac
  c=${line//@NL@/$'\n'}; c=${c//@HC@/$HOME/.claude}; c=${c//@SD@/$SD}; c=${c//@WT@/$W/wt}; c=${c//@R@/$R}
  for tree in "$@"; do
    if [ -n "$agent" ]; then
      p=$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","agent_id":"a1","agent_type":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$CWD" "$agent" "$(json_str "$c")")
    else
      p=$(payload_of "$c")
    fi
    if [ -n "$SNAP" ]; then
      o=$(env KERN_SHELL_SNAPSHOT="$SNAP" KERN_GUARDS= "$BASH_BIN" "$tree/hooks/pre-tool-use" <<<"$p" 2>&1)
    else
      o=$(env -u KERN_SHELL_SNAPSHOT KERN_GUARDS= "$BASH_BIN" "$tree/hooks/pre-tool-use" <<<"$p" 2>&1)
    fi
    d=$(dec "$o"); [ -z "$d" ] && [ -n "$o" ] && d=ERROR
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${tree##*/}" "$snapk" "$cwdk" "$mode" "$n" "${d:-none}" "$(why "$o" | tr '\t' ' ')" "${line}${agent:+ [$agent]}" >>"$out"
  done
done
