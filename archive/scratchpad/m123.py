def rep(p,a,b):
    s=open(p).read(); assert s.count(a)==1,(p,a[:70]); open(p,'w').write(s.replace(a,b))
A='hooks/lib/aliases.sh'
rep(A,'''# _alias_key FILE: prints FILE's size and modification time in seconds, from BSD or GNU stat; exit 1
# when neither reads it.
_alias_key() {
  local k
  k=$(stat -f '%z %m' "$1" 2>/dev/null) || k=$(stat -c '%s %Y' "$1" 2>/dev/null) || return 1
  case "$k" in '' | *[!0123456789\\ ]* | ' '* | *' ' | *' '*' '*) return 1 ;; esac
  case "$k" in *' '*) printf '%s\\n' "$k" ;; *) return 1 ;; esac
}''','''# _alias_key FILE: prints FILE's size, modification time, change time (in seconds) and inode, from BSD or
# GNU stat; exit 1 when neither reads it. touch can put a modification time back, not a change time.
_alias_key() {
  local k
  k=$(stat -f '%z %m %c %i' "$1" 2>/dev/null) || k=$(stat -c '%s %Y %Z %i' "$1" 2>/dev/null) || return 1
  case "$k" in '' | *[!0123456789\\ ]* | ' '* | *' ' | *'  '*) return 1 ;; esac
  # shellcheck disable=SC2086 # digits and single spaces only: four fields
  set -- $k
  [ "$#" = 4 ] || return 1
  printf '%s\\n' "$k"
}''')
rep(A,'''# The parsed table is cached in aliases.cache under the state dir (state.sh), whose first line names the
# cache format, the snapshot's path, size and modification time; a cache whose first line differs is
# rebuilt.''','''# The parsed table is cached in aliases.cache under the state dir (state.sh), whose first line names the
# cache format, the snapshot's path, size, modification and change times and inode; a cache whose first
# line differs, or that is larger than the table can be, is rebuilt without reading its lines.''')
rep(A,'''  local snap out h key dir="" cache="" line="" tmp''','''  local snap out h key size dir="" cache="" line="" tmp''')
rep(A,'''    if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] &&
      { IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then''','''    if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] && size=$(_alias_key "$cache") &&
      [ "${size%% *}" -le $((4194304 + ${#line} + 1)) ] &&
      { IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then''')
C='docs/plans/contract.md'
rep(C,"a first line `kern aliases <_ALIASES_CACHE_V> <length of _ALIASES_AWK><TAB><snapshot path><TAB><size> <mtime>`, then the `<hex><TAB>expansion` lines. A cache whose first line differs is rebuilt;",
"a first line `kern aliases <_ALIASES_CACHE_V> <length of _ALIASES_AWK><TAB><snapshot path><TAB><size> <mtime> <ctime> <inode>`, then the `<hex><TAB>expansion` lines. A cache whose first line differs, or whose size (stat) is over 4 MB plus its first line, is rebuilt without its lines being read;")
rep(C,"- `_alias_key FILE`: prints FILE's size and modification time in seconds (BSD or GNU `stat`); exit 1 when neither reads it.",
"- `_alias_key FILE`: prints FILE's size, modification time, change time (seconds) and inode (BSD `stat -f '%z %m %c %i'` or GNU `stat -c '%s %Y %Z %i'`); exit 1 when neither reads it. A change time cannot be set back with `touch`; an edit in the same second at the same size and inode is not seen.")
rep('CHANGELOG.md',"It caches the parsed table in its state dir, keyed by the snapshot's path, size and modification time,",
"It caches the parsed table in its state dir, keyed by the snapshot's path, size, modification and change times and inode,")
