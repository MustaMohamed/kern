. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
setup_env >/dev/null 2>&1
for c in 'nice cd a; nice cd b; nice cd c; echo x >> notes.md' 'nice cd a; nice cd b; nice cd c; nice cd d; nice cd e; echo x >> notes.md' 'nice cd /tmp; nice cd /tmp; nice cd /tmp; nice cd /tmp; nice cd /tmp; nice cd /tmp; echo x >> notes.md'; do
  s=$(date +%s); o=$(run_tree "$T35/r2" "$c" ""); e=$(date +%s)
  printf '%-5s %ss | %s\n      %s\n' "$(dec "$o")" $((e-s)) "$c" "$(why "$o")"
done
