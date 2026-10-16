. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35/h.sh
setup_env
for cwd in "$R" "$W/wt"; do export CWD=$cwd
for m in off on; do autopilot $m
while IFS= read -r c; do
  c=${c//@NL@/$'\n'}; c=${c//@HC@/$HOME/.claude}; c=${c//@SD@/$SD}
  o=$(run_tree "$BASE" "$c" "${SNAP-}")
  printf '%s %-3s %-5s | %s\n     %s\n' "${cwd##*/}" $m "$(dec "$o")" "${c//$'\n'/⏎}" "$(why "$o")"
done <<'C'
noglob eval 'git push --force origin main'
nocorrect eval 'git push --force origin main'
repeat 1 eval 'git push --force origin main'
coproc eval 'git push --force origin main'
noglob sh <<EOF@NL@git push --force origin main@NL@EOF
(cd .); git commit -m x
cd @HC@ && cd "$(git rev-parse --show-toplevel || echo .)" && sed -i '' s/a/b/ settings.json
C
done; done
