. /Users/musta/Code/projects/kern/hooks/lib/settings.sh; . /Users/musta/Code/projects/kern/hooks/lib/state.sh; . /Users/musta/Code/projects/kern/hooks/lib/aliases.sh
export KERN_SHELL_SNAPSHOT=$1 CLAUDE_PLUGIN_DATA=$(mktemp -d)
t() { local s e; s=$(perl -MTime::HiRes=time -e 'printf "%.1f", time*1000'); for i in 1 2 3 4 5; do "$@"; done; e=$(perl -MTime::HiRes=time -e 'printf "%.1f", time*1000'); perl -e "printf '%.1f', ($e - $s) / 5"; }
rm -f "$CLAUDE_PLUGIN_DATA/sessions/aliases.cache"; aliases_load
printf '%s: cache hit %s ms; ' "$(basename "$1")" "$(t aliases_load)"
miss() { rm -f "$CLAUDE_PLUGIN_DATA/sessions/aliases.cache"; aliases_load; }
printf 'cache miss %s ms\n' "$(t miss)"
rm -rf "$CLAUDE_PLUGIN_DATA"
