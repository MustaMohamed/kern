. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
T35O=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35; KERN=/Users/musta/Code/projects/kern
setup_env >/dev/null 2>&1
mk() { local c="$1" i; for i in $(seq 1 "$2"); do c="${c}$3$i.md; "; done; printf '%s' "$c"; }
C1=$(mk "nice cd a; nice cd b; nice cd c; nice cd d; " 20 "echo x >> notes")
C2=$(mk "nice cd a; nice cd b; nice cd c; nice cd d; " 60 "echo x >> notes")
C3=$(mk "nice cd a; nice cd b; nice cd c; nice cd d; " 60 "cp docs/plans/ok.md y")
C4=$(mk "nice cd a; nice cd b; nice cd c; nice cd d; " 110 "echo x >> notes")
C5=$(mk "" 60 "echo x >> notes")
for tree in ${TREES:-$T35O/base $T35/p3c $KERN}; do
  for c in C1 C2 C3 C4 C5; do
    s=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
    o=$(run_tree "$tree" "${!c}" "")
    e=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
    printf '%-8s %s %6.2f s  %s\n' "${tree##*/}" "$c" "$(echo "$e - $s" | bc)" "$(dec "$o")"
  done
done
