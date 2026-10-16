import sys
t, name = sys.argv[1], sys.argv[2]
def sub(path, a, b):
    p = t + "/" + path; s = open(p).read()
    assert s.count(a) == 1, (name, path, s.count(a)); open(p, "w").write(s.replace(a, b))
G = "hooks/lib/gitctx.sh"; A = "hooks/lib/aliases.sh"
if name == "reorder":
    sub(G, """  if [ -z "${_GW_IN-}" ] && [ -n "${KERN_ALIASES-}" ]; then
    _GW_IN=1 git_words "$1" | LC_ALL=C awk '/^\\t/ { a[++n] = substr($0, 2); next } { print } END { for (i = 1; i <= n; i++) print a[i] }'
    return
  fi
""", "")
elif name == "tabmark":
    sub(G, """      git_words "$ALIAS_EXP" | LC_ALL=C sed $'s/^/\\t/'""", """      git_words "$ALIAS_EXP\"""")
elif name == "past8":
    sub(A, """    if [ "$n" -ge 8 ]; then
      # shellcheck disable=SC2016 # a literal $, for G00
      pre="$pre"'$KERN_ALIAS_PAST_8 '
      break
    fi
""", "")
elif name == "i2":
    sub(A, """        [ "$skip" = 0 ] || return 1
        case "$w" in *=*) ;; *) return 1 ;; esac""", """        return 1
        case "$w" in *=*) ;; *) return 1 ;; esac""")
else:
    raise SystemExit("unknown")
