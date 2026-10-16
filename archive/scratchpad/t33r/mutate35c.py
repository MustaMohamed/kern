import sys
t, name = sys.argv[1], sys.argv[2]
def sub(rel, a, b):
    p = t + "/" + rel; s = open(p).read()
    assert s.count(a) == 1, (name, rel, s.count(a)); open(p, "w").write(s.replace(a, b))
G = "hooks/lib/gitctx.sh"; G16 = "hooks/guards/g16-state.sh"; G20 = "hooks/guards/g20-approval.sh"
if name == "plain":
    sub(G, 'cmd_plain() {\n', 'cmd_plain() {\n  return 0\n')
elif name == "union":
    sub(G16, '[ "$sd_f" = 0 ] && [ "$sd_seen" = 0 ] || in_sd=1\n          [ "$cc_f" = 0 ] && [ "$cc_seen" = 0 ] || _G16_INCC=1',
        'in_sd=$sd_f\n          _G16_INCC=$cc_f')
elif name == "set":
    sub(G20, '      [ "$_G20_STAY" = 1 ] || break\n', '      break\n')
elif name == "cap":
    sub(G20, 'if [ "$n" -gt 16 ]; then', 'if false; then')
else:
    raise SystemExit("unknown")
