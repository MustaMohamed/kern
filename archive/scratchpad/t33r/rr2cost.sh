#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
export CWD="$W/wt"
autopilot off
c16="noglob cd a; noglob cd b; noglob cd c; noglob cd d"
for n in 20 60; do
  body=""; for i in $(seq $n); do body="$body; echo x >> notes$i.md"; done
  for spec in "plain|cd a; cd b; cd c; cd d$body" "maybe16|$c16$body"; do
    c=${spec#*|}; p=$(payload_of "$c")
    for tree in b35 h35c; do
      s=$(/usr/bin/python3 -c 'import time;print(time.time())')
      out=$(env KERN_SHELL_SNAPSHOT=/nonexistent KERN_GUARDS= /bin/bash "$T33/$tree/hooks/pre-tool-use" <<<"$p")
      e=$(/usr/bin/python3 -c 'import time;print(time.time())')
      printf '%-7s n=%-3s %-5s %6.2f s  %s\n' "${spec%%|*}" "$n" "$tree" "$(/usr/bin/python3 -c "print($e-$s)")" "$(dec "$out")"
    done
  done
done
