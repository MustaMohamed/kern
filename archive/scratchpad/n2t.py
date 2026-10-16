p='tests/hooks/aliases.bats'; s=open(p).read()
a='''  [ "$output" = "$(printf 'gpf!\\n%.0s' 1 2 3 4 5 6 7)'gpf!'" ] || { echo "$output"; return 1; }'''
b='''  [ "$output" = $'gpf!\\ngpf!\\ngpf!\\ngpf!\\ngpf!\\ngpf!\\ngpf!\\n\\'gpf!\\'' ] || { echo "$output"; return 1; }'''
assert s.count(a)==1; open(p,'w').write(s.replace(a,b))
