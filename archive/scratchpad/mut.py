import sys
p='hooks/lib/aliases.sh'; s=open(p).read(); m=sys.argv[1]
if m=='i1':
    a='''    if [ "$n" -ge 8 ]; then
      # shellcheck disable=SC2016 # a literal $, for G00
      pre="$pre"'$KERN_ALIAS_PAST_8 '
      break
    fi
'''
    b='''    [ "$n" -lt 8 ] || break
'''
elif m=='i2':
    a='''        [ "$skip" = 0 ] || return 1
        case "$w" in *=*) ;; *) return 1 ;; esac'''
    b='''        return 1'''
elif m=='tab':
    a='''nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1; ts = v ~ / $/'''
    b='''nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1; ts = v ~ /[ \\t]$/'''
assert s.count(a)==1, m; open(p,'w').write(s.replace(a,b))
