#!/usr/bin/env python3
"""Extract one task from a plan into a brief file, respecting fence lengths.

Usage: brief.py PLAN N OUTFILE
A fence opened with k backticks (or tildes) closes only on a line of at least k of the same
character and nothing else, so a ### Task heading inside a nested fence is ignored.
"""
import re
import sys

plan, n, out = sys.argv[1], sys.argv[2], sys.argv[3]
fence = None
intask = False
lines = []
heading = re.compile(r'^#+[ \t]+Task[ \t]+(\d+)\b')
for line in open(plan, encoding='utf-8'):
    stripped = line.rstrip('\n')
    if fence is None:
        m = re.match(r'^(`{3,}|~{3,})', stripped)
        if m:
            fence = m.group(1)
        else:
            h = heading.match(stripped)
            if h:
                intask = h.group(1) == n
            elif re.match(r'^## ', stripped):
                intask = False
    else:
        if re.fullmatch(re.escape(fence[0]) + '{' + str(len(fence)) + r',}\s*', stripped):
            fence = None
    if intask:
        lines.append(line)
if not lines:
    sys.exit(f'task {n} not found in {plan}')
open(out, 'w', encoding='utf-8').write(''.join(lines))
print(out)
