"""analyze.py A B FILE...: compare tree A to tree B per (snap, cwd, mode, idx). For each looser row,
say whether B's vote equals B's vote on the same command without its leading zsh modifiers."""
import sys, collections

MODS = ["noglob", "nocorrect", "coproc", "repeat 1", "repeat $N", "repeat -1+2", "repeat 1 repeat 1",
        "repeat '1'", "repeat 0", "sudo noglob", "noglob sudo", "env X=1 noglob", "command noglob",
        "noglob command", "NOGLOB"]
RANK = {"deny": 3, "ask": 2, "none": 1, "allow": 0}

a, b = sys.argv[1], sys.argv[2]
rows = {}
bycmd = {}
for fn in sys.argv[3:]:
    for line in open(fn, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 8:
            continue
        tree, snap, cwd, mode, idx, dec, why, cmd = f[:8]
        k = (snap, cwd, mode, int(idx))
        rows.setdefault(k, {})[tree] = (dec, why, cmd)
        bycmd[(tree, snap, cwd, mode, cmd)] = dec


def unmod(cmd):
    agent = ""
    if cmd.endswith(" [kern:investigator]"):
        agent, cmd = " [kern:investigator]", cmd[: -len(" [kern:investigator]")]
    for m in sorted(MODS, key=len, reverse=True):
        if cmd.startswith(m + " "):
            return cmd[len(m) + 1:] + agent
    return None


count = collections.Counter()
classes = collections.defaultdict(list)
for k, t in sorted(rows.items()):
    if a not in t or b not in t:
        count["unmatched"] += 1
        continue
    da, db = t[a][0], t[b][0]
    cmd = t[b][2]
    if da not in RANK or db not in RANK:
        count["ERROR"] += 1
        classes[("ERROR", cmd)].append(k)
        continue
    if RANK[db] > RANK[da]:
        tag = "tighter"
    elif RANK[db] < RANK[da]:
        u = unmod(cmd)
        ud = bycmd.get((b, k[0], k[1], k[2], u)) if u else None
        tag = "looser-eq-unmod" if ud == db else "LOOSER"
    else:
        tag = "same"
    count[tag] += 1
    if tag != "same":
        classes[(tag, cmd)].append((k, da, db, t[a][1][:150], t[b][1][:150]))

print(f"{a} -> {b}: " + ", ".join(f"{x} {count[x]}" for x in ["same", "tighter", "looser-eq-unmod", "LOOSER", "ERROR", "unmatched"]))
for (tag, cmd), lst in sorted(classes.items(), key=lambda x: (x[0][0], -len(x[1]))):
    k, da, db, ra, rb = lst[0]
    print(f"  {tag:15} x{len(lst):<3} {da:>5}->{db:<5} | {cmd}")
    if tag in ("LOOSER", "ERROR") or "-v" in sys.argv[:1]:
        print(f"       {a}: {ra}\n       {b}: {rb}")
