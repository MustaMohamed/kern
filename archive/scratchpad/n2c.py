p='docs/plans/contract.md'; s=open(p).read()
a="which splits words at blanks outside quotes, `$( )`, `${ }` and backticks."
b="which splits words at blanks outside quotes, `$( )`, `${ }` and backticks, each `$( )` and `${ }` keeping its own quote state."
assert s.count(a)==1; open(p,'w').write(s.replace(a,b))
