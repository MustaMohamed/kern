#!/usr/bin/env bash
# usage: replay.sh  -> sets up and prints votes
set -u
S=$(cd "$(dirname "$0")" && pwd -P)
K=/Users/musta/Code/projects/kern
export HOME=$S/home GIT_CONFIG_NOSYSTEM=1 CLAUDE_PLUGIN_DATA=$S/data CLAUDE_PLUGIN_ROOT=$K
rm -rf $S/home $S/data $S/repo $S/repo.origin; mkdir -p $HOME/.claude $CLAUDE_PLUGIN_DATA
export PATH=$S/bin:$PATH
cat > $S/bin/gh <<'GH'
#!/usr/bin/env bash
case "$*" in
  "pr list"*) [ -n "${FAKE_GH_STATES-}" ] && printf '%s\n' "$FAKE_GH_STATES" | tr ',' '\n'; exit "${FAKE_GH_RC:-0}" ;;
esac
GH
chmod +x $S/bin/gh
R=$S/repo
git init -q -b main $R; git -C $R config user.name T; git -C $R config user.email t@e.x; git -C $R config commit.gpgsign false
echo r>$R/README.md; git -C $R add .; git -C $R commit -qm init
git init -q --bare -b main $R.origin; git -C $R remote add origin $R.origin; git -C $R push -q origin main; git -C $R remote set-head origin main >/dev/null
cd $R
W=$(bash $K/scripts/wt-new plan 2>/dev/null); echo "wt=$W"
git -C $W config user.name T
MAINTMP=$(bash $K/scripts/kern-dir tmp); echo "tmp=$MAINTMP"
echo body > $MAINTMP/pr-body.md
export WT=$W MAINTMP R
vote() { # cwd cmd
  local cmd=$2 esc
  esc=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$esc" | bash $K/hooks/pre-tool-use | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p;s/.*"permissionDecisionReason":"\(.\{0,140\}\).*/   \1/p' | tr '\n' ' '
  [ -z "$(printf '%s' x)" ] ; echo
}
ap() { mkdir -p $CLAUDE_PLUGIN_DATA/sessions; printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$1" >$CLAUDE_PLUGIN_DATA/sessions/test-session.state; }
run() { echo "[$1] $2"; vote "$3" "$2"; }
for mode in off on; do
  ap $mode; echo "=== autopilot $mode"
  for st in "" OPEN MERGED; do
    export FAKE_GH_STATES=$st; unset FAKE_GH_RC
    echo "-- gh states='$st'"
    run $mode "git push -u origin kern/plan" "$W"
    run $mode "gh pr create --draft --title 'M2: fix' --base main --body-file $MAINTMP/pr-body.md" "$W"
    run $mode "gh pr create --draft --title 'M2: don'\\''t break' --base main --body-file $MAINTMP/pr-body.md" "$W"
  done
  export FAKE_GH_STATES=; export FAKE_GH_RC=1
  echo "-- gh failing"
  run $mode "gh pr create --draft --title 'M2: fix' --base main --body-file $MAINTMP/pr-body.md" "$W"
  unset FAKE_GH_RC
  run $mode "cd $W" "$R"
  run $mode "gh pr list --head kern/plan --state all --json number,state,headRefOid,url" "$W"
  run $mode "git branch -D kern/plan" "$R"
  run $mode "git worktree remove $W" "$R"
  run $mode "git worktree remove $W-check" "$R"
  run $mode "git push -u origin main" "$R"
  run $mode "git push -u origin main" "$W"
  run $mode "gh pr ready 1" "$W"
done
