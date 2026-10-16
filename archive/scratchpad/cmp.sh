#!/bin/bash
# cmp.sh [-c CWD] CMD...: decision under autopilot for old (8c74bca) and new (HEAD)
SP=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad
cw=(); [ "$1" = -c ] && { cw=(-c "$2"); shift 2; }
for c in "$@"; do
  o=$(KROOT=$SP/kold $SP/probe.sh -a "${cw[@]}" "$c" | cut -c1-5)
  n=$($SP/probe.sh -a "${cw[@]}" "$c" | cut -c1-5)
  printf 'old=%s new=%s | %q\n' "$o" "$n" "$c"
done
