import sys
t, name = sys.argv[1], sys.argv[2]
def sub(rel, a, b):
    p = t + "/" + rel; s = open(p).read()
    assert s.count(a) == 1, (name, rel, s.count(a)); open(p, "w").write(s.replace(a, b))
G = "hooks/lib/gitctx.sh"; G16 = "hooks/guards/g16-state.sh"
if name == "alt":
    sub("hooks/guards/g01-git.sh", '    [ -z "${_G01_ALT-}" ] || _g01_push "$_G01_ALT" 0 "$@"\n', "")
elif name == "seen":
    sub(G16, '[ "$seg_s" = 0 ] && [ "$sd_seen" = 0 ] || in_sd=1', '[ "$seg_s" = 0 ] || in_sd=1')
elif name == "popd":
    sub(G16, """      popd)
        dk=0
        [ "$sd_seen" = 0 ] || in_sd=1
        [ "$cc_seen" = 0 ] || _G16_INCC=1
        ;;
""", "")
elif name == "cdir":
    sub(G16, "            */.claude) _G16_INCC=1 ;;\n", "")
elif name == "quoted":
    sub(G, 'if (x == "coproc" || cw_q || cw_rw) cw_mod = 3', 'if (x == "coproc" || cw_rw) cw_mod = 3')
elif name == "rep0":
    sub(G, "      if (x ~ /^-?[0-9]+$/ && x + 0 <= 0) cw_mod = 3\n      else if", "      if")
else:
    raise SystemExit("unknown")
