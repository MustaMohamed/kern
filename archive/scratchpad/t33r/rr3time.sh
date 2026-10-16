#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
export CWD="$W/wt"
printf -- '---\nstatus: approved\n---\n' >"$W/wt/src.md"
autopilot on
while IFS= read -r c; do
  p=$(payload_of "$c")
  for tree in ${TREES:-b35 h35d}; do
    s=$(/usr/bin/python3 -c 'import time;print(time.time())')
    out=$(env KERN_SHELL_SNAPSHOT=/nonexistent KERN_GUARDS= /bin/bash "$T33/$tree/hooks/pre-tool-use" <<<"$p")
    e=$(/usr/bin/python3 -c 'import time;print(time.time())')
    printf '%-5s %6.2f s %-5s %s\n' "$tree" "$(/usr/bin/python3 -c "print($e-$s)")" "$(dec "$out")" "${c:0:70}"
  done
done <"$1"
