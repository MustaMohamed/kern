#!/bin/bash
# t35atk.sh: modifier attacks, base 3c66863 vs head 54ffc16, plus head on the unmodified command.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; BASE=$T33/${ATK_BASE:-b35}; HEAD=$T33/h35c
setup_env >/dev/null
mkdir -p "$R/.claude"; printf 'deploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/wt/creds.txt"; git -C "$W/wt" add creds.txt
echo '{}' >"$HOME/.claude/settings.json"
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"; echo x >"$SD/test-session.state"
export CWD="$W/wt"
one() { # TREE AGENT CMD -> decision
  local p
  if [ -n "$2" ]; then
    p=$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","agent_id":"a1","agent_type":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$CWD" "$2" "$(json_str "$3")")
  else p=$(payload_of "$3"); fi
  dec "$(env KERN_SHELL_SNAPSHOT=/nonexistent KERN_GUARDS= /bin/bash "$1/hooks/pre-tool-use" <<<"$p" 2>&1)"
}
MODS=("noglob" "nocorrect" "coproc" "repeat 1" "repeat \$N" "repeat -1+2" "repeat 1 repeat 1" "repeat '1'" "repeat 0" "sudo noglob" "noglob sudo" "env X=1 noglob" "command noglob" "noglob command")
CMDS=("git push --force origin main" "git push origin main" "eval 'git push --force origin main'" "sh -c 'git push --force origin main'"
  "bash <<EOF@NL@git push --force origin main@NL@EOF" "gh pr create --title t --body b" "gh pr merge 1" "git commit -m 'feat: add creds'"
  "cat @SD@/test-session.state" "echo x > @SD@/test-session.state" "sed -i '' s/a/b/ @HC@/settings.json"
  "psql -h prod-db.internal -c 'DELETE FROM x'" "npm publish" "git -C @R@ clean -fdx" "rm -rf build" "ls" "zsh -c 'echo hi'"
  "cd @R@ && git clean -fdx" "git push origin production")
for mode in $1; do
  autopilot "$mode"
  for agent in $2; do
    [ "$agent" = main ] && agent=""
    for c in "${CMDS[@]}"; do
      c=${c//@NL@/$'\n'}; c=${c//@SD@/$SD}; c=${c//@HC@/$HOME/.claude}; c=${c//@R@/$R}
      hu=$(one "$HEAD" "$agent" "$c")
      for m in "${MODS[@]}"; do
        mc="$m $c"
        b=$(one "$BASE" "$agent" "$mc"); h=$(one "$HEAD" "$agent" "$mc")
        rb=$(rank "$b"); rh=$(rank "$h"); ru=$(rank "$hu")
        tag=same; [ "$rh" -gt "$rb" ] && tag=tighter
        if [ "$rh" -lt "$rb" ]; then if [ "$h" = "$hu" ]; then tag=looser-eq; else tag=LOOSER-NE; fi; fi
        [ "$rh" -lt "$ru" ] && tag="$tag/below-unmod"
        printf '%s|%s|%s|base=%s|head=%s|unmod=%s|%s\n' "$tag" "$mode" "${agent:-main}" "${b:-none}" "${h:-none}" "${hu:-none}" "${mc//$'\n'/⏎}"
      done
    done
  done
done
