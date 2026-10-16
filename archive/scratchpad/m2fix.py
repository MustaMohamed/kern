p='tests/hooks/aliases.bats'; s=open(p).read()
a='''  sleep 1
  printf "alias -- x='git push --force'\\n" >"$f"
  touch -t 203101010000 "$f"
  # The edit kept the size, the modification time and the inode: only the change time tells it apart.
  printf "alias -- x='git push -f -v-v-v'\\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"'''
b='''  sleep 1
  # This edit keeps the size, the modification time and the inode: only the change time tells it apart.
  printf "alias -- x='git push --force'\\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"'''
assert s.count(a)==1; open(p,'w').write(s.replace(a,b))
