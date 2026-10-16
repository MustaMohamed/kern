import sys
t, name = sys.argv[1], sys.argv[2]
def sub(rel, a, b):
    p = t + "/" + rel; s = open(p).read()
    assert s.count(a) == 1, (name, rel, s.count(a)); open(p, "w").write(s.replace(a, b))
G = "hooks/lib/gitctx.sh"
if name == "kw":
    sub(G, "|[{]|noglob|nocorrect|coproc)$/)", "|[{])$/)")
elif name == "repeat":
    sub(G, '    if (x == "repeat") { cw_wrap = ""; cw_cnt = 1; return }\n', "")
elif name == "prefilter":
    sub(G, "        */noglob | */nocorrect | */coproc | */repeat | \\\n", "")
elif name == "g6cont":
    sub("hooks/guards/g06-secrets.sh", """reads a repository or index kern does not see"
    fi""", """reads a repository or index kern does not see"
      continue
    fi""")
elif name == "g16dk":
    sub("hooks/guards/g16-state.sh", 'if [ "$dk" = 1 ]; then\n          # A relative', 'if true; then\n          # A relative')
elif name == "cmdmodoff":
    sub(G, """      *[[:space:]]repeat[[:space:]]*) return 0 ;;
  esac
  return 1""", """      *[[:space:]]repeat[[:space:]]*) return 1 ;;
  esac
  return 1""")
else:
    raise SystemExit("unknown")
