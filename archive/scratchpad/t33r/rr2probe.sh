#!/bin/bash
# rr2probe.sh: probes from $PROBES, pairs from $PAIRS (base:head ...), modes from $MODES.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
export CWD="$W/wt"
SD=$CLAUDE_PLUGIN_DATA/sessions; mkdir -p "$SD"; HC=$HOME/.claude; mkdir -p "$HC/agents"; echo '{}' >"$HC/settings.json"
printf -- '---\nstatus: approved\n---\n' >"$W/wt/src.md"
XD="$W/xdir"; mkdir -p "$XD"; printf -- '---\nstatus: approved\n---\n' >"$XD/src.md"
ln -s "$R" "$W/wt/repeat"
printf -- "---\nstatus: approved\n---\n" >"$W/wt/t.md"; YD="$W/ydir"; mkdir -p "$YD"; printf -- "# plain\n" >"$YD/src.md"
for mode in ${MODES:-on}; do
  autopilot "$mode"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    c=${c//@SD@/$SD}; c=${c//@HCU@/$(printf %s "$HC" | tr a-z A-Z)}; c=${c//@HC@/$HC}; c=${c//@R@/$R}; c=${c//@XD@/$XD}; c=${c//@YD@/$YD}; c=${c//@NL@/$'\n'}
    for pair in ${PAIRS:-b35:h35c h35b:h35c}; do
      BASE=$T33/${pair%%:*}; HEAD=$T33/${pair#*:}
      printf '%s %-4s->%-5s ' "$mode" "${pair%%:*}" "${pair#*:}"; cmp2 "$c" | head -1 | sed "s#$W#W#g" | cut -c1-150
    done
  done <"$PROBES"
done
