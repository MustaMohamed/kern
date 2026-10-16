# Runs each case line through g18_allowed (sourced from the repo) and prints ALLOW or DENY.
K=/Users/musta/Code/projects/kern
export KERN_ROOT="$K" CWD="${CWD:-$PWD}"
for lib in json settings state decide gitctx; do . "$K/hooks/lib/$lib.sh"; done
. "$K/hooks/guards/g18-readonly-agent.sh"
while IFS= read -r c; do
  [ -n "$c" ] || continue
  if g18_allowed "$c"; then r=ALLOW; else r=DENY; fi
  printf '%-6s %s\n' "$r" "$c"
done < "$1"
