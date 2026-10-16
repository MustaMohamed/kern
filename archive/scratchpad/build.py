#!/usr/bin/env python3
"""Assemble a plan from template parts. A line `@@FILE <path>@@` becomes the file's content (path under the
scratch dir), with a trailing newline stripped; `@@OLD a b@@` becomes lines a..b of the old M2 plan."""
import sys, os, re
S = os.path.dirname(os.path.abspath(__file__))
OLD = '/Users/musta/Code/projects/kern/docs/plans/2026-10-12-kern-m2-plan.md'
old = open(OLD).read().split('\n')
def expand(text):
    out = []
    for line in text.split('\n'):
        m = re.fullmatch(r'@@FILE (\S+)@@', line)
        if m:
            c = open(os.path.join(S, m.group(1))).read()
            out.append(c[:-1] if c.endswith('\n') else c)
            continue
        m = re.fullmatch(r'@@OLD (\d+) (\d+)@@', line)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            out.append('\n'.join(old[a-1:b]))
            continue
        out.append(line)
    return '\n'.join(out)
parts_dir, dest = sys.argv[1], sys.argv[2]
parts = sorted(f for f in os.listdir(parts_dir) if f.endswith('.md'))
doc = '\n'.join(expand(open(os.path.join(parts_dir, p)).read().rstrip('\n')) for p in parts) + '\n'
assert not re.search(r'^@@(FILE|OLD) ', doc, re.M), 'unexpanded marker'
open(dest, 'w').write(doc)
print(dest, len(doc.split('\n')), 'lines')
