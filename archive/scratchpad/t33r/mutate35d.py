import sys
t, name = sys.argv[1], sys.argv[2]
def sub(rel, a, b):
    p = t + "/" + rel; s = open(p).read()
    assert s.count(a) >= 1, (name, rel, s.count(a)); open(p, "w").write(s.replace(a, b, 1))
G = "hooks/lib/gitctx.sh"; G16 = "hooks/guards/g16-state.sh"; G20 = "hooks/guards/g20-approval.sh"
if name == "r1":
    sub(G, "if (!sw_q[k] && x ~ /^[0-9]*(<|>|&>)/)", "if (x ~ /^[0-9]*(<|>|&>)/)")
    sub(G, "if (!sw_q[k] && x ~ /^[A-Za-z_][A-Za-z0-9_]*\\+?=/)", "if (x ~ /^[A-Za-z_][A-Za-z0-9_]*\\+?=/)")
elif name == "r2":
    sub(G16, "        mixed=1\n", "        mixed=0\n")
elif name == "r3":
    sub(G20, '    [ "$_G20_BACK" = 0 ] || back=1\n', "    :\n")
elif name == "r4":
    sub(G20, '    builtin) case "${1-}" in cd | pushd | popd) _g20_cmd "$@" ;; esac ;;\n', "    builtin) ;;\n")
elif name == "r5":
    sub(G20, "_g20_seg1() {\n  local w\n", '_g20_seg1() {\n  local w\n  [ "$_G20_OVER" = 0 ] || { _G20_WHY=$_G20_OVER_WHY; return 0; }\n')
elif name == "r6":
    sub(G20, '*) if [ "$n" -lt 16 ]; then next="$next$x$nl"; n=$((n + 1)); else _G20_OVER=1; fi ;;', '*) next="$next$x$nl"; n=$((n + 1)) ;;')
elif name == "once":
    sub(G20, '[ "$first" = 0 ] || [ "$_G20_REL" = 1 ] || return 0', '[ "$first" = 0 ] || return 0')
elif name == "src":
    sub(G20, "| head -n 1024)", "| head -n 64)")
else:
    raise SystemExit("unknown")
