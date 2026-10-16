. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
setup_env >/dev/null 2>&1
K=/Users/musta/Code/projects/kern
c="nice cd a; nice cd b; nice cd c; nice cd d; "; for i in $(seq 1 60); do c="${c}echo x >> notes$i.md; "; done
p=$(payload_of "$c")
for g in g20 g16 g00 g01 g05 g06 g13 g15; do
  s=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
  env -u KERN_SHELL_SNAPSHOT BATS_TEST_FILENAME=x KERN_GUARDS=$g /bin/bash $K/hooks/pre-tool-use <<<"$p" >/dev/null 2>&1
  e=$(perl -MTime::HiRes=time -e 'printf "%.2f", time')
  echo "$g $(echo "$e - $s" | bc)"
done
