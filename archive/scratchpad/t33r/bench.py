import json, os, subprocess, sys, time, statistics
# usage: bench.py N TREE SNAP CWD CMD...
n = int(sys.argv[1]); tree = sys.argv[2]; snap = sys.argv[3]; cwd = sys.argv[4]
for cmd in sys.argv[5:]:
    p = json.dumps({"session_id": "test-session", "cwd": cwd, "hook_event_name": "PreToolUse",
                    "tool_name": "Bash", "tool_input": {"command": cmd}}).encode()
    env = dict(os.environ); env["KERN_GUARDS"] = ""
    if snap == "-": env.pop("KERN_SHELL_SNAPSHOT", None); env["KERN_SHELL_SNAPSHOT"] = "/nonexistent"
    else: env["KERN_SHELL_SNAPSHOT"] = snap
    ts = []; out = b""
    for i in range(n):
        t = time.perf_counter()
        out = subprocess.run(["/bin/bash", tree + "/hooks/pre-tool-use"], input=p, env=env, capture_output=True).stdout
        ts.append((time.perf_counter() - t) * 1000)
    d = json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "none"
    print("%8.1f ms  %-5s %s %s | %s" % (statistics.median(ts), d, os.path.basename(tree), os.path.basename(snap), cmd))
