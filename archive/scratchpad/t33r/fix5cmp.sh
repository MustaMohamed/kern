T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env
mkdir -p "$R/.claude"
printf 'deploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"; echo x > "$SD/test-session.state.bak"
run1() { # TREE AGENT CMD
  local p
  if [ -n "$2" ]; then
    p=$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","agent_id":"a1","agent_type":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$CWD" "$2" "$(json_str "$3")")
  else p=$(payload_of "$3"); fi
  env KERN_SHELL_SNAPSHOT="$T33/real-snap.sh" KERN_GUARDS= /bin/bash "$1/hooks/pre-tool-use" <<<"$p" 2>&1
}
for cw in main wt; do
  case $cw in main) export CWD="$R" ;; wt) export CWD="$W/wt" ;; esac
  for m in off on; do
    autopilot $m
    while IFS='|' read -r agent c; do
      c=${c//@NL@/$'\n'}; c=${c//@SD@/$SD}
      h=$(run1 "$HEAD" "$agent" "$c"); f=$(run1 "$T33/fix5" "$agent" "$c")
      rh=$(rank "$(dec "$h")"); rf=$(rank "$(dec "$f")")
      t=same; [ "$rf" -lt "$rh" ] && t=LOOSER; [ "$rf" -gt "$rh" ] && t=tighter
      printf '%-7s %s %-3s head=%-5s fix=%-5s | %s%s\n' "$t" "$cw" "$m" "$(dec "$h")" "$(dec "$f")" "${agent:+[$agent] }" "${c//$'\n'/⏎}"
      [ "$t" = same ] || printf '        head: %s\n        fix:  %s\n' "$(why "$h")" "$(why "$f")"
    done <<'CORPUS'
|nocorrect git push --force origin main
|noglob git push --force origin main
|repeat 2 git push --force origin main
|coproc git push --force origin main
|nocorrect git push -u origin feat
|noglob git status
|noglob gh pr create --title t --body b
|nocorrect npm publish
|noglob psql -h prod-db.internal -c 'DELETE FROM x'
|noglob cat @SD@/test-session.state
|noglob echo x > @SD@/test-session.state
|nocorrect sudo git push --force origin main
|_ gpf! origin main
|noglob eval 'git push --force origin main'
|noglob sh -c 'git push --force origin main'
|noglob bash <<EOF@NL@git push --force origin main@NL@EOF
|noglob git commit -m "feat: x"
|noglob gh pr merge 1
|repeat 3 echo hi
|noglob ls -la
|nocorrect rm -rf build
|coproc cat
|repeat
|noglob
|nocorrect
kern:investigator|noglob git log
kern:investigator|nocorrect git log --stat
kern:investigator|repeat 2 git status
kern:investigator|noglob git push origin feat
kern:investigator|noglob rm -rf x
CORPUS
  done
done
