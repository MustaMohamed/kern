. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35/h.sh
FIN=$T35/fin
setup_env
for m in off on; do autopilot $m
  while IFS='|' read -r a b; do
    a=${a//@SD@/$SD}; a=${a//@HC@/$HOME/.claude}; b=${b//@SD@/$SD}; b=${b//@HC@/$HOME/.claude}
    da=$(dec "$(run_tree "$FIN" "$a" "")"); db=$(dec "$(run_tree "$FIN" "$b" "")")
    printf '%-3s %-5s %-5s %s  ==  %s\n' $m "${da:-none}" "${db:-none}" "${a##*/}" "${b##*/}"
  done <<'C'
noglob cat @SD@/test-session.state|cat @SD@/test-session.state
NOGLOB cat @SD@/test-session.state|cat @SD@/test-session.state
noglob cat @HC@/settings.json|cat @HC@/settings.json
noglob ls @HC@|ls @HC@
noglob zsh -c 'echo hi'|zsh -c 'echo hi'
noglob bash -c 'git status'|bash -c 'git status'
C
done
