# sync.py RELPATH...: replace the old file text (k2b) with the new one (k2) in the M2a plan; each old text must occur exactly once.
import sys
S='/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad'
PLAN='/Users/musta/Code/projects/kern/docs/plans/2026-10-14-kern-m2a-plan.md'
s=open(PLAN).read()
for rel in sys.argv[1:]:
    old=open(f'{S}/k2b/{rel}').read().rstrip('\n'); new=open(f'{S}/k2/{rel}').read().rstrip('\n')
    c=s.count(old)
    if c!=1: print(f'{rel}: old text found {c} times'); sys.exit(1)
    s=s.replace(old,new); print(f'{rel}: synced')
open(PLAN,'w').write(s)
