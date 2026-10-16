import sys
t, name = sys.argv[1], sys.argv[2]
A = t + "/hooks/lib/aliases.sh"
s = open(A).read()
def sub(a, b):
    global s
    assert s.count(a) == 1, (name, s.count(a)); s = s.replace(a, b)
if name == "keycheck":
    sub('IFS= read -r h && [ "$h" = "$line" ] && _alias_table;', 'IFS= read -r h && _alias_table;')
elif name == "source":
    sub('IFS= read -r h && [ "$h" = "$line" ] && _alias_table;', 'IFS= read -r h && [ "$h" = "$line" ] && . /dev/stdin && KERN_ALIASES=1;')
elif name == "eval":
    sub("""    case "$h" in '' | *[!0123456789abcdef]*) continue ;; esac
    [ -n "$v" ] || continue
    printf -v "_KA_$h" '%s' "$v\"""", """    [ -n "$v" ] || continue
    eval "_KA_$h=$v\"""")
elif name == "rename":
    sub("""{ printf '%s\\n' "$line" "$out" >"$tmp" && mv -f "$tmp" "$cache"; }""", """{ printf '%s\\n' "$line" "$out" >"$cache" && rm -f "$tmp"; }""")
elif name == "symread":
    sub('if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] &&', 'if [ -f "$cache" ] &&')
elif name == "symwrite":
    sub('(umask 077 && mkdir -p "$dir") 2>/dev/null && [ ! -L "$dir" ] &&', '(umask 077 && mkdir -p "$dir") 2>/dev/null &&')
else:
    raise SystemExit("unknown")
open(A, "w").write(s)
