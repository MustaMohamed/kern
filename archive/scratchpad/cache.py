p='hooks/lib/aliases.sh'; s=open(p).read()
start=s.index('# aliases_load: sets one variable _KA_<hex of name>')
end=s.index('\n}\n', start)+3
new='''# _ALIASES_CACHE_V: the format of the alias cache. Bump it when _ALIASES_AWK's output or the cache
# layout changes meaning; the cache header also holds the awk program's length.
_ALIASES_CACHE_V=1

# _alias_key FILE: prints FILE's size and modification time in seconds, from BSD or GNU stat; exit 1
# when neither reads it.
_alias_key() {
  local k
  k=$(stat -f '%z %m' "$1" 2>/dev/null) || k=$(stat -c '%s %Y' "$1" 2>/dev/null) || return 1
  case "$k" in '' | *[!0123456789\\ ]* | ' '* | *' ' | *' '*' '*) return 1 ;; esac
  case "$k" in *' '*) printf '%s\\n' "$k" ;; *) return 1 ;; esac
}

# _alias_table: reads `<hex of name><TAB>expansion` lines on stdin into _KA_<hex>, and sets
# KERN_ALIASES=1 for each it keeps. The lines are data: a line whose name is not hex digits is skipped,
# nothing in a line is evaluated, and reading stops after 4 MB.
_alias_table() {
  local h v t=0
  while IFS=$'\\t' read -r h v; do
    t=$((t + ${#h} + ${#v} + 2))
    [ "$t" -le 4194304 ] || break
    case "$h" in '' | *[!0123456789abcdef]*) continue ;; esac
    [ -n "$v" ] || continue
    printf -v "_KA_$h" '%s' "$v"
    KERN_ALIASES=1
  done
  return 0
}

# aliases_load: sets one variable _KA_<hex of name> per alias whose expansion holds a git or gh word,
# holding its expansion, and KERN_ALIASES=1 when there is at least one. Names are hex-encoded because
# alias names hold characters such as ! and - that a variable name cannot; two hex digits per byte keep
# distinct names apart. The snapshot is read as text by awk, at most its first 4 MB; nothing from it is
# evaluated. A missing, unreadable or unparseable snapshot sets nothing, which changes nothing, and so
# does any failure here: it never stops the hook.
# The parsed table is cached in aliases.cache under the state dir (state.sh), whose first line names the
# cache format, the snapshot's path, size and modification time; a cache whose first line differs is
# rebuilt. The cache is read as data by _alias_table, like the parse it replaces, and a forged one can
# only add expansions, as a forged snapshot can. A cache that cannot be read or written leaves the parse
# as the only source; a symlinked cache or state dir is never used.
aliases_load() {
  local snap out h key dir="" cache="" line="" tmp
  KERN_ALIASES=""
  # The table holds only what this snapshot defines, never a _KA_ variable from the environment.
  for h in ${!_KA_@}; do unset "$h"; done
  snap=$(alias_snapshot) || return 0
  if declare -F state_dir >/dev/null && key=$(_alias_key "$snap") && dir=$(state_dir); then
    cache="$dir/aliases.cache"
    line="kern aliases $_ALIASES_CACHE_V ${#_ALIASES_AWK}"$'\\t'"$snap"$'\\t'"$key"
    if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] &&
      { IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then
      return 0
    fi
  fi
  out=$(set -o pipefail; head -c 4194304 2>/dev/null <"$snap" | LC_ALL=C awk -v sq="'" "$_ALIASES_AWK" 2>/dev/null) || return 0
  _alias_table <<<"$out"
  # A new file in the state dir, then a rename over the cache, so a planted symlink is never written through.
  if [ -n "$cache" ] && (umask 077 && mkdir -p "$dir") 2>/dev/null && [ ! -L "$dir" ] &&
    tmp=$(mktemp "$dir/.aliases.cache.XXXXXX" 2>/dev/null); then
    { printf '%s\\n' "$line" "$out" >"$tmp" && mv -f "$tmp" "$cache"; } 2>/dev/null || rm -f "$tmp" 2>/dev/null
  fi
  return 0
}
'''
s=s[:start]+new+s[end:]
open(p,'w').write(s)
p='hooks/pre-tool-use'; s=open(p).read()
a='need aliases.sh alias_snapshot aliases_load alias_text _alias_var alias_expand'
assert s.count(a)==1; open(p,'w').write(s.replace(a,'need aliases.sh alias_snapshot _alias_key _alias_table aliases_load alias_text _alias_var alias_expand'))
