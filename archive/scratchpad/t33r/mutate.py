import sys
# mutate.py TREE NAME: applies one removal mutation to TREE in place.
t, name = sys.argv[1], sys.argv[2]
def sub(path, a, b):
    p = t + "/" + path; s = open(p).read()
    assert s.count(a) == 1, (name, path, s.count(a)); open(p, "w").write(s.replace(a, b))
G = "hooks/lib/gitctx.sh"; A = "hooks/lib/aliases.sh"
if name == "union":
    sub(G, """    printf '%s\\n' "$seg"
    # A record whose head word""", """    # A record whose head word""")
    sub(G, """      git_words "$ALIAS_EXP"
      _GW_NOALIAS=
    fi
""", """      git_words "$ALIAS_EXP"
      _GW_NOALIAS=
      continue
    fi
    printf '%s\\n' "$seg"
""")
elif name == "hex":
    sub(A, 'HX[c] = sprintf("%02x", i) }', 'HX[c] = (c ~ /[A-Za-z0-9]/) ? sprintf("%02x", i) : "5f" }')
    sub(A, """    printf -v c '%02x' "'$c"
""", """    case "$c" in [A-Za-z0-9]) printf -v c '%02x' "'$c" ;; *) c=5f ;; esac
""")
elif name == "reset":
    sub(A, """  for h in ${!_KA_@}; do unset "$h"; done
""", "")
elif name == "nextword":
    sub(A, """  while [ "$n" -lt 8 ]; do""", """  while false; do""")
elif name == "bound9":
    sub(A, """  while [ "$n" -lt 8 ]; do""", """  while [ "$n" -lt 9 ]; do""")
elif name == "aliastext":
    sub("hooks/pre-tool-use", """  [ -n "${KERN_ALIASES-}" ] && KERN_ALIAS_TEXT=$(alias_text "$(ti_get command 2>/dev/null)")
""", "")
elif name.startswith("pf-"):
    g = name[3:]
    files = {"g02": "hooks/guards/g02-pr.sh", "g03": "hooks/guards/g03-review.sh", "g04": "hooks/guards/g04-untrusted.sh",
             "g14": "hooks/guards/g14-tracker.sh"}
    if g in files:
        sub(files[g], 'case "$cmd ${KERN_ALIAS_TEXT-}" in', 'case "$cmd" in')
    elif g == "g13":
        sub("hooks/guards/g13-protected.sh", '_g13_flat "$cmd ${KERN_ALIAS_TEXT-}"', '_g13_flat "$cmd"')
    elif g == "g15":
        sub("hooks/guards/g15-deploy.sh", '_g15_named "$cmd ${KERN_ALIAS_TEXT-}"', '_g15_named "$cmd"')
else:
    raise SystemExit("unknown " + name)
