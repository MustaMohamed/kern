S=$(cd "$(dirname "$0")" && pwd -P); K=/Users/musta/Code/projects/kern
export HOME=$S/home GIT_CONFIG_NOSYSTEM=1 CLAUDE_PLUGIN_DATA=$S/data CLAUDE_PLUGIN_ROOT=$K; export PATH=$S/bin:$PATH
rm -rf $S/home $S/data $S/r2 $S/r2.origin; mkdir -p $HOME/.claude $CLAUDE_PLUGIN_DATA/sessions
R=$S/r2; git init -q -b main $R; git -C $R config user.name Me; git -C $R config user.email me@x.io; git -C $R config commit.gpgsign false
echo r>$R/README.md; git -C $R add .; git -C $R commit -qm init
git init -q --bare -b main $R.origin; git -C $R remote add origin $R.origin; git -C $R push -q origin main; git -C $R remote set-head origin main >/dev/null
cd $R; W=$(bash $K/scripts/wt-new plan 2>/dev/null); cd $W; echo f>f.txt; git add f.txt; git commit -qm feat; git push -q -u origin kern/plan
v(){ esc=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g'); printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$esc" | bash $K/hooks/pre-tool-use | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p'; }
ap(){ printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$1" >$CLAUDE_PLUGIN_DATA/sessions/test-session.state; }
authors(){ echo "  authors: $(git log --format=%ae main..HEAD origin/kern/plan 2>&1 | sort | uniq -c | tr '\n' ' ') | verify: $(git rev-parse --verify --quiet origin/kern/plan | cut -c1-7)"; }
moveBase(){ git -C $R commit -q --allow-empty -m basemove; git -C $R push -q origin main; git fetch -q origin main; }
echo "== A: own commits, published"; moveBase; authors
echo "  baseref=origin/main:"; git log --format=%ae origin/main..HEAD origin/kern/plan | sort -u
git rebase -q origin/main; echo "rebased"
ap off; echo "plain push: $(v $W 'git push -u origin kern/plan') ; real: $(git push -u origin kern/plan 2>&1 | grep -c rejected) rejected"
echo "lease: noap=$(v $W 'git push --force-with-lease origin kern/plan')"; ap on; echo "lease: autopilot=$(v $W 'git push --force-with-lease origin kern/plan')"; ap off
git push -q --force-with-lease origin kern/plan && echo "lease push worked"
echo "== B: another author on origin/branch"
git clone -q $R.origin $S/other 2>/dev/null; (cd $S/other && git checkout -q kern/plan && git -c user.name=O -c user.email=other@x.io commit -q --allow-empty -m theirs && git push -q origin kern/plan); git fetch -q origin kern/plan
moveBase; authors; git rebase -q origin/main; echo "lease(after rebase anyway): $(v $W 'git push --force-with-lease origin kern/plan')"
echo "== C: merge commit in branch authored by me (merged base in)"
git reset -q --hard origin/kern/plan; git -c user.name=Me -c user.email=other@x.io log -1 --format=%ae
echo "== D: no origin/branch"; git branch -q -f lone HEAD; git update-ref -d refs/remotes/origin/kern/plan; authors
