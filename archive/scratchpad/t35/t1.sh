. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35/h.sh
setup_env
time (for i in 1 2 3 4 5; do run_tree "$BASE" "git status" "" >/dev/null; done)
time (for i in 1 2 3 4 5; do run_tree "$BASE" "git status" "$T35/../t33r/real-snap.sh" >/dev/null; done)
time (for i in 1 2 3 4 5; do run_tree "$BASE" "git commit -m 'feat: x'" "" >/dev/null; done)
