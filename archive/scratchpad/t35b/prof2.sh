. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
setup_env >/dev/null 2>&1
K=/Users/musta/Code/projects/kern
c="nice cd a; nice cd b; nice cd c; nice cd d; "; for i in $(seq 1 60); do c="${c}echo x >> notes$i.md; "; done
p=$(payload_of "$c")
env -u KERN_SHELL_SNAPSHOT BATS_TEST_FILENAME=x KERN_GUARDS=g20 PS4='+${EPOCHREALTIME} ${FUNCNAME[0]:-main} ' $BASHX -x $K/hooks/pre-tool-use <<<"$p" 2>$T35/xtrace.log >/dev/null
awk '{ split($1, a, "+"); t = substr($1, 2) + 0; if (pt) d[pf] += t - pt; pt = t; pf = $2 } END { for (f in d) printf "%8.3f %s\n", d[f], f }' $T35/xtrace.log | sort -rn | head -15
