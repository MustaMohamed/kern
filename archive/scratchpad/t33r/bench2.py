import json, os, random, subprocess, sys, time, statistics
# bench2.py ROUNDS CWD T33: interleaved rounds over fixed configs; prints medians.
rounds = int(sys.argv[1]); cwd = sys.argv[2]; t33 = sys.argv[3]
real = t33 + "/real-snap.sh"
cfg = [
  ("noalias  git status", "head2", None, "git status"),
  ("aliases  git status", "head2", real, "git status"),
  ("noalias  git status (literal of gst)", "head2", None, "git status"),
  ("aliases  gst", "head2", real, "gst"),
  ("noalias  git push origin feat", "head2", None, "git push origin feat"),
  ("aliases  gp origin feat", "head2", real, "gp origin feat"),
  ("bb74e68 aliases git status", "head", real, "git status"),
  ("bb74e68 aliases gp origin feat", "head", real, "gp origin feat"),
]
ts = {c[0]: [] for c in cfg}; dec = {}
for r in range(rounds):
    order = list(cfg); random.shuffle(order)
    for name, tree, snap, cmd in order:
        p = json.dumps({"session_id": "test-session", "cwd": cwd, "hook_event_name": "PreToolUse",
                        "tool_name": "Bash", "tool_input": {"command": cmd}}).encode()
        env = dict(os.environ); env["KERN_GUARDS"] = ""
        env["KERN_SHELL_SNAPSHOT"] = snap or "/nonexistent"
        t = time.perf_counter()
        out = subprocess.run(["/bin/bash", t33 + "/" + tree + "/hooks/pre-tool-use"], input=p, env=env, capture_output=True).stdout
        ts[name].append((time.perf_counter() - t) * 1000)
        dec[name] = json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "none"
for name, *_ in cfg:
    v = ts[name]
    print("%-40s median %7.1f ms  p25 %7.1f  p75 %7.1f  n=%d  %s" % (name, statistics.median(v), statistics.quantiles(v, n=4)[0], statistics.quantiles(v, n=4)[2], len(v), dec[name]))
