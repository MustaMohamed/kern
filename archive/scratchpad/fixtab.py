p='tests/hooks/aliases.bats'; s=open(p).read()
a='"alias -- t=\'nice\t\'"'
b='"alias -- t=\'nice"$\'\\t\'"\'"'
assert s.count(a)==1, a
s=s.replace(a,b); open(p,'w').write(s)
