import sys
p='hooks/lib/aliases.sh'; s=open(p).read(); m=sys.argv[1]
R={
 'm1': ('''    if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] && size=$(_alias_key "$cache") &&''', '''    if [ -f "$cache" ] && size=$(_alias_key "$cache") &&'''),
 'm2': ('''  k=$(stat -f '%z %m %c %i' "$1" 2>/dev/null) || k=$(stat -c '%s %Y %Z %i' "$1" 2>/dev/null) || return 1''', '''  k=$(stat -f '%z %m 0 0' "$1" 2>/dev/null) || k=$(stat -c '%s %Y 0 0' "$1" 2>/dev/null) || return 1'''),
 'm3': ('''      [ "${size%% *}" -le $((4194304 + ${#line} + 1)) ] &&\n''', ''),
}
a,b=R[m]; assert s.count(a)==1, m; open(p,'w').write(s.replace(a,b))
