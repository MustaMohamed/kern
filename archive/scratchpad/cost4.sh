#!/opt/homebrew/bin/bash
# cost4.sh SNAPSHOT N "ALIAS|LITERAL"...: medians of N interleaved rounds of four runs each:
# lit = the literal, no snapshot (no aliases); nc = the alias, no cache (dc9865d); c = the alias,
# cache warm; lits = the literal with the snapshot and cache.
K=/Users/musta/Code/projects/kern; SP=$(cd "$(dirname "$0")" && pwd)
snap=$1 n=$2; shift 2
T=$(mktemp -d "$SP/c4.XXXXXX")
export HOME="$T/home" CLAUDE_PLUGIN_DATA="$T/data" CLAUDE_PLUGIN_ROOT="$K"
mkdir -p "$HOME/.claude" "$CLAUDE_PLUGIN_DATA"; unset CLAUDE_CODE_ENTRYPOINT KERN_SHELL_SNAPSHOT
R="$T/repo"; git init -q -b main "$R"; git -C "$R" config user.name t; git -C "$R" config user.email t@e; git -C "$R" config commit.gpgsign false
echo r > "$R/README.md"; git -C "$R" add README.md; git -C "$R" commit -qm init
git init -q --bare -b main "$R.origin"; git -C "$R" remote add origin "$R.origin"; git -C "$R" push -q origin main; git -C "$R" remote set-head origin main
git -C "$R" worktree add -q -b feat "$T/wt" >/dev/null 2>&1
. "$K/hooks/lib/json.sh"
pl() { printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"}}' "$T/wt" "$(printf '%s' "$1" | json_escape)"; }
ms() { awk -v s="$1" -v e="$2" 'BEGIN{printf "%.1f",(e-s)*1000}'; }
med() { sort -n | awk '{a[NR]=$1} END {print (NR % 2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}'; }
echo "load at start: $(uptime | sed 's/.*load averages*: //')"
for pair in "$@"; do
  al=${pair%%|*} li=${pair#*|}; pa=$(pl "$al"); pli=$(pl "$li")
  KERN_SHELL_SNAPSHOT=$snap /bin/bash "$K/hooks/pre-tool-use" <<<"$pa" >/dev/null
  a=(); b=(); c=(); d=()
  for ((i = 0; i < n; i++)); do
    s=$EPOCHREALTIME; /bin/bash "$K/hooks/pre-tool-use" <<<"$pli" >/dev/null; e=$EPOCHREALTIME; a+=("$(ms "$s" "$e")")
    s=$EPOCHREALTIME; KERN_SHELL_SNAPSHOT=$snap /bin/bash "$SP/prevC/hooks/pre-tool-use" <<<"$pa" >/dev/null; e=$EPOCHREALTIME; b+=("$(ms "$s" "$e")")
    s=$EPOCHREALTIME; KERN_SHELL_SNAPSHOT=$snap /bin/bash "$K/hooks/pre-tool-use" <<<"$pa" >/dev/null; e=$EPOCHREALTIME; c+=("$(ms "$s" "$e")")
    s=$EPOCHREALTIME; KERN_SHELL_SNAPSHOT=$snap /bin/bash "$K/hooks/pre-tool-use" <<<"$pli" >/dev/null; e=$EPOCHREALTIME; d+=("$(ms "$s" "$e")")
  done
  ml=$(printf '%s\n' "${a[@]}" | med); mn=$(printf '%s\n' "${b[@]}" | med); mc=$(printf '%s\n' "${c[@]}" | med); md=$(printf '%s\n' "${d[@]}" | med)
  printf '%-16s vs %-22s literal/no-aliases %6s | alias no-cache %6s (%+.1f) | alias cache %6s (%+.1f) | literal with aliases %6s (%+.1f)\n' \
    "$al" "$li" "$ml" "$mn" "$(awk -v x="$mn" -v y="$ml" 'BEGIN{print x-y}')" "$mc" "$(awk -v x="$mc" -v y="$ml" 'BEGIN{print x-y}')" "$md" "$(awk -v x="$md" -v y="$ml" 'BEGIN{print x-y}')"
done
echo "load at end: $(uptime | sed 's/.*load averages*: //')"
rm -rf "$T"
