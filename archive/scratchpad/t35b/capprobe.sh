. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
setup_env >/dev/null 2>&1
printf -- '---\nstatus: approved\napproved: 2026-10-14, "yes"\n---\n' >"$R/src.md"
c15=""; for i in $(seq 1 15); do c15="${c15}nice cd /tmp/k$i; "; done; c16="${c15}nice cd /tmp/k16; "
while IFS= read -r c; do
  c=${c//@15@/$c15}; c=${c//@16@/$c16}; c=${c//@R@/$R}
  a=$(dec "$(run_tree "$T35/p3c" "$c" "")"); b=$(dec "$(run_tree "$T35/r3" "$c" "")")
  printf '0653941=%-5s 5fd783b=%-5s | %s\n' "${a:-none}" "${b:-none}" "$(printf '%s' "$c" | sed 's|nice cd /tmp/k[0-9]*; |·|g')"
done <<'C'
@15@echo x >> notes.md
@15@cp src.md dst.md
@16@echo x >> notes.md
@16@cp @R@/src.md dst.md
@16@echo x > out.txt && ls notes.md
@16@echo x >> @R@/notes.md
@16@ls notes.md
@16@echo x > @R@/out.txt && ls notes.md
@16@cd @R@ && echo x >> notes.md
if cd a; then ls; fi; if cd b; then ls; fi; if cd c; then ls; fi; if cd d; then ls; fi; if cd e; then ls; fi; ls notes.md
C
