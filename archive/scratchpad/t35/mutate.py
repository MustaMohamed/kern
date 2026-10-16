import sys, shutil, os
src, dst, rel, old, new = sys.argv[1:6]
if os.path.exists(dst): shutil.rmtree(dst)
shutil.copytree(src, dst)
p = os.path.join(dst, rel)
s = open(p).read()
n = s.count(old)
if n != 1: sys.exit(f"MUTATION {dst}: old text found {n} times")
open(p, 'w').write(s.replace(old, new))
