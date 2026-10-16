#!/opt/homebrew/bin/bash
# cost.sh HOOKDIR SNAPSHOT|- CMD [N]: median wall time in ms of N runs of HOOKDIR/hooks/pre-tool-use on a Bash payload.
K=/Users/musta/Code/projects/kern
hd=$1 snap=$2 cmd=$3 n=${4:-30}
T=$(mktemp -d "${TMPDIR:-/tmp}/cost.XXXXXX")
export HOME="$T/home" CLAUDE_PLUGIN_DATA="$T/data" CLAUDE_PLUGIN_ROOT="$K"
mkdir -p "$HOME/.claude" "$CLAUDE_PLUGIN_DATA"
unset CLAUDE_CODE_ENTRYPOINT KERN_SHELL_SNAPSHOT
[ "$snap" = - ] || export KERN_SHELL_SNAPSHOT="$snap"
R="$T/repo"
git init -q -b main "$R"; git -C "$R" config user.name t; git -C "$R" config user.email t@e; git -C "$R" config commit.gpgsign false
echo r > "$R/README.md"; git -C "$R" add README.md; git -C "$R" commit -qm init
git init -q --bare -b main "$R.origin"; git -C "$R" remote add origin "$R.origin"; git -C "$R" push -q origin main; git -C "$R" remote set-head origin main
git -C "$R" worktree add -q -b feat "$T/wt" >/dev/null 2>&1
. "$K/hooks/lib/json.sh"
p=$(printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"}}' "$T/wt" "$(printf '%s' "$cmd" | json_escape)")
out=$(/bin/bash "$hd/hooks/pre-tool-use" <<<"$p")
ts=()
for ((i = 0; i < n; i++)); do
  s=$EPOCHREALTIME
  /bin/bash "$hd/hooks/pre-tool-use" <<<"$p" >/dev/null
  e=$EPOCHREALTIME
  ts+=("$(awk -v s="$s" -v e="$e" 'BEGIN { printf "%.1f", (e - s) * 1000 }')")
done
med=$(printf '%s\n' "${ts[@]}" | sort -n | awk '{a[NR]=$1} END {print (NR % 2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}')
printf '%s | %s | %-32s | median %s ms | decision %s\n' "$(basename "$hd")" "$( [ "$snap" = - ] && echo none || basename "$snap")" "$cmd" "$med" "$(printf '%s' "$out" | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p')"
rm -rf "$T"
