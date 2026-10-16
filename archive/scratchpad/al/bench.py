import subprocess,sys,time,os,statistics
home,data,snap,hook,pay,label=sys.argv[1:7]
env=dict(os.environ); env['HOME']=home; env['CLAUDE_PLUGIN_DATA']=data
env.pop('KERN_SHELL_SNAPSHOT',None)
if snap!='-': env['KERN_SHELL_SNAPSHOT']=snap
ts=[]
for i in range(30):
    t=time.perf_counter(); r=subprocess.run(['/bin/bash',hook],input=pay.encode(),env=env,capture_output=True); ts.append((time.perf_counter()-t)*1000)
print(f"{label}: median {statistics.median(ts):.1f} ms, min {min(ts):.1f}; out={r.stdout.decode()[:90]}")
