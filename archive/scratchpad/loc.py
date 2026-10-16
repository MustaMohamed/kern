import re,sys
def load(p):
    L=open(p).read().split('\n')
    task=None; step=None; idx=[]
    for i,l in enumerate(L):
        m=re.match(r'^### Task (\d+):',l)
        if m: task=int(m.group(1)); step=None
        m=re.match(r'^- \[ \] \*\*Step (\d+)',l)
        if m: step=int(m.group(1))
        if l.startswith('## Self-review') or l.startswith('## Tasks added'): task=None
        idx.append((task,step))
    return L,idx
plans={'a':load('/Users/musta/Code/projects/kern/docs/plans/2026-10-14-kern-m2a-plan.md'),'b':load('/Users/musta/Code/projects/kern/docs/plans/2026-10-14-kern-m2b-plan.md')}
for arg in sys.argv[1:]:
    which,rx=arg.split(':',1)
    L,idx=plans[which]
    hits=[]
    for i,l in enumerate(L):
        if re.search(rx,l):
            t,s=idx[i]
            if t is None: continue
            k=f"T{t}" + (f" S{s}" if s else " (Files/Interfaces)")
            if k not in hits: hits.append(k)
    print(f"{arg} => {', '.join(hits[:8])}")
