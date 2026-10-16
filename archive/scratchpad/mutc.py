import sys
p='hooks/lib/aliases.sh'; s=open(p).read(); m=sys.argv[1]
R={
 'nohdr': ('{ IFS= read -r h && [ "$h" = "$line" ] && _alias_table; }', '{ IFS= read -r h && _alias_table; }'),
 'source': ('      { IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then', '      { ( . "$cache" ) >/dev/null 2>&1; IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then'),
 'direct': ('''    { printf '%s\\n' "$line" "$out" >"$tmp" && mv -f "$tmp" "$cache"; } 2>/dev/null || rm -f "$tmp" 2>/dev/null''', '''    rm -f "$tmp"; { printf '%s\\n' "$line" "$out" >"$cache"; } 2>/dev/null'''),
 'nosize': ("""  case "$k" in *' '*) printf '%s\\n' "$k" ;; *) return 1 ;; esac""", """  case "$k" in *' '*) printf '%s\\n' "${k#* }" ;; *) return 1 ;; esac"""),
}
a,b=R[m]; assert s.count(a)==1, m; open(p,'w').write(s.replace(a,b))
