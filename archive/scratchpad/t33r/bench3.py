import json, os, random, subprocess, sys, time, statistics
# bench3.py ROUNDS CWD T33: interleaved rounds over 90a9fb9 configs, warm and cold cache.
rounds = int(sys.argv[1]); cwd = sys.argv[2]; t33 = sys.argv[3]
real = t33 + "/real-snap.sh"
cache = os.environ["CLAUDE_PLUGIN_DATA"] + "/sessions/aliases.cache"
cfg = [
  ("noalias  git status", None, "git status", False),
  ("warm     git status", real, "git status", False),
  ("cold     git status", real, "git status", True),
  ("noalias  git status (literal of gst)", None, "git status", False),
  ("warm     gst", real, "gst", False),
  ("cold     gst", real, "gst", True),
  ("noalias  git push origin feat", None, "git push origin feat", False),
  ("warm     gp origin feat", real, "gp origin feat", False),
]
ts = {c[0]: [] for c in cfg}; dec = {}
def run(snap, cmd):
    p = json.dumps({"session_id": "test-session", "cwd": cwd, "hook_event_name": "PreToolUse",
                    "tool_name": "Bash", "tool_input": {"command": cmd}}).encode()
    env = dict(os.environ); env["KERN_GUARDS"] = ""; env["KERN_SHELL_SNAPSHOT"] = snap or "/nonexistent"
    t = time.perf_counter()
    out = subprocess.run(["/bin/bash", t33 + "/head3/hooks/pre-tool-use"], input=p, env=env, capture_output=True).stdout
    return (time.perf_counter() - t) * 1000, out
run(real, "git status")  # build the cache once
for r in range(rounds):
    order = list(cfg); random.shuffle(order)
    for name, snap, cmd, cold in order:
        if cold:
            try: os.remove(cache)
            except FileNotFoundError: pass
        elif snap:
            if not os.path.exists(cache): run(real, "true")  # rewarm, untimed
        ms, out = run(snap, cmd)
        ts[name].append(ms)
        dec[name] = json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "none"
for name, *_ in cfg:
    v = ts[name]; q = statistics.quantiles(v, n=4)
    print("%-38s median %7.1f ms  p25 %7.1f  p75 %7.1f  n=%d  %s" % (name, statistics.median(v), q[0], q[2], len(v), dec[name]))
