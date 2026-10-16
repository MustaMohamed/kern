#!/bin/bash
# rr1probe.sh: Task 35 round-1 probes, pairs b35->h35b and h35->h35b; commands from $T33/rr1probe.txt.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
export CWD="$W/wt"; ln -s "$R" "$W/wt/repeat"
SD=$CLAUDE_PLUGIN_DATA/sessions; mkdir -p "$SD"; HC=$HOME/.claude; mkdir -p "$HC/agents"; echo '{}' >"$HC/settings.json"
printf -- '---\nstatus: approved\n---\n' >"$W/wt/src.md"
for mode in ${MODES:-on}; do
  autopilot "$mode"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    c=${c//@SD@/$SD}; c=${c//@HC@/$HC}; c=${c//@R@/$R}; c=${c//@NL@/$'\n'}
    for pair in "b35 h35b" "h35 h35b"; do
      set -- $pair; BASE=$T33/$1; HEAD=$T33/$2
      printf '%s %-3s %-4s->%-5s ' "$mode" "" "$1" "$2"; cmp2 "$c" | head -1 | sed "s#$W#W#g" | cut -c1-140
    done
  done <"${PROBES:-$T33/rr1probe.txt}"
done
