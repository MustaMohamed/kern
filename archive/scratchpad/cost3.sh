#!/opt/homebrew/bin/bash
# cost3.sh SNAPSHOT N CMD...: per CMD, median ms of N interleaved rounds of base (no snapshot), headB and kern (snapshot).
K=/Users/musta/Code/projects/kern; SP=$(cd "$(dirname "$0")" && pwd)
snap=$1 n=$2; shift 2
T=$(mktemp -d "$SP/c3.XXXXXX")
export HOME="$T/home" CLAUDE_PLUGIN_DATA="$T/data" CLAUDE_PLUGIN_ROOT="$K"
mkdir -p "$HOME/.claude" "$CLAUDE_PLUGIN_DATA"; unset CLAUDE_CODE_ENTRYPOINT KERN_SHELL_SNAPSHOT
R="$T/repo"; git init -q -b main "$R"; git -C "$R" config user.name t; git -C "$R" config user.email t@e; git -C "$R" config commit.gpgsign false
echo r > "$R/README.md"; git -C "$R" add README.md; git -C "$R" commit -qm init
git init -q --bare -b main "$R.origin"; git -C "$R" remote add origin "$R.origin"; git -C "$R" push -q origin main; git -C "$R" remote set-head origin main
git -C "$R" worktree add -q -b feat "$T/wt" >/dev/null 2>&1
. "$K/hooks/lib/json.sh"
med() { sort -n | awk '{a[NR]=$1} END {print (NR % 2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}'; }
for cmd in "$@"; do
  p=$(printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"}}' "$T/wt" "$(printf '%s' "$cmd" | json_escape)")
  b=(); h=(); k=()
  for ((i = 0; i < n; i++)); do
    s=$EPOCHREALTIME; env -u KERN_SHELL_SNAPSHOT /bin/bash "$SP/base/hooks/pre-tool-use" <<<"$p" >/dev/null; e=$EPOCHREALTIME; b+=("$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.1f",(e-s)*1000}')")
    s=$EPOCHREALTIME; KERN_SHELL_SNAPSHOT=$snap /bin/bash "$SP/headB/hooks/pre-tool-use" <<<"$p" >/dev/null; e=$EPOCHREALTIME; h+=("$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.1f",(e-s)*1000}')")
    s=$EPOCHREALTIME; KERN_SHELL_SNAPSHOT=$snap /bin/bash "$K/hooks/pre-tool-use" <<<"$p" >/dev/null; e=$EPOCHREALTIME; k+=("$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.1f",(e-s)*1000}')")
  done
  printf '%-36s base %6s | prev %6s | new %6s\n' "$cmd" "$(printf '%s\n' "${b[@]}" | med)" "$(printf '%s\n' "${h[@]}" | med)" "$(printf '%s\n' "${k[@]}" | med)"
done
rm -rf "$T"
