#!/bin/bash
# evade.sh: prints, for each case, the decision of the BASE hook and of the working-tree hook.
SP=$(cd "$(dirname "$0")" && pwd)
K=/Users/musta/Code/projects/kern
T=$(mktemp -d "$SP/ev.XXXXXX")
export HOME="$T/home" CLAUDE_PLUGIN_DATA="$T/data" CLAUDE_PLUGIN_ROOT="$K"
mkdir -p "$HOME/.claude/shell-snapshots" "$CLAUDE_PLUGIN_DATA/sessions"
unset CLAUDE_CODE_ENTRYPOINT; export KERN_SHELL_SNAPSHOT=/Users/musta/.claude/shell-snapshots/snapshot-zsh-1792072549515-0umb42.sh
R="$T/repo"
git init -q -b main "$R"; git -C "$R" config user.name t; git -C "$R" config user.email t@e; git -C "$R" config commit.gpgsign false
echo r > "$R/README.md"; git -C "$R" add README.md; git -C "$R" commit -qm init
git init -q --bare -b main "$R.origin"; git -C "$R" remote add origin "$R.origin"; git -C "$R" push -q origin main; git -C "$R" remote set-head origin main
git -C "$R" worktree add -q -b feat "$T/wt" >/dev/null 2>&1
cat > "$HOME/.claude/shell-snapshots/snapshot-zsh-1-a.sh" <<'SNAP'
alias -- gpf!='git push --force'
alias -- gp='git push'
alias -- _='sudo '
alias -- sgpf='sudo git push --force'
alias -- egpf='env X=1 git push --force'
alias -- ngpf='noglob git push --force'
alias -- cgpf='command git push --force'
alias -- prc='gh pr create'
alias -- prm='gh pr merge --admin'
alias -- chain1='echo C1; gpf!'
alias -- rel='gh release create'
alias -- wfr='gh workflow run'
alias -- ghrel='gh release create'
SNAP
CWD="$R"
. "$K/hooks/lib/json.sh"; json() { printf '"%s"' "$(printf "%s" "$1" | json_escape)"; }
dec() { sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p' | head -1; }
run() { # run HOOK CMD
  local p out
  p=$(printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":%s}}' "$CWD" "$(json "$2")")
  out=$(bash "$1/hooks/pre-tool-use" <<<"$p" 2>&1)
  d=$(printf '%s' "$out" | dec); [ -n "$d" ] || { [ -n "$out" ] && d="error:$out" || d=none; }
  printf '%s' "$d"
}
row() { printf '%-55s | %-6s | %-6s\n' "$(printf '%s' "$1" | tr '\n' '~')" "$(run "$SP/base" "$1")" "$(run "$K" "$1")"; }
mode=${1:-interactive}
if [ "$mode" = autopilot ]; then printf 'voice: normal\nsurface: auto\nautopilot: on\nsince: 2026-10-12T00:00:00Z\n' > "$CLAUDE_PLUGIN_DATA/sessions/s.state"; fi
if [ -n "${DEPLOY-}" ]; then mkdir -p "$R/.claude"; printf 'deploy.envs: production\n' > "$R/.claude/kern.local.yml"; fi
shift || true
while IFS= read -r c; do [ -n "$c" ] && row "$(printf '%b' "$c")"; done
rm -rf "$T" "$R.origin"
