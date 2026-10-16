def rep(p,a,b):
    s=open(p).read(); assert s.count(a)==1,(p,a[:70]); open(p,'w').write(s.replace(a,b))
rep('hooks/lib/aliases.sh','''# rule does, and so on, at most 8 times; a 9th word that is still such an alias becomes the command name
# $KERN_ALIAS_PAST_8, which G00 reads as built at run time, so autopilot denies it. As zsh does, the''',
'''# rule does, and so on, at most 8 times; a 9th word that is still such an alias starts a record of its
# own whose command name is $KERN_ALIAS_PAST_8, which G00 reads as built at run time, so autopilot denies
# it whatever word the expansions before it start with (nocorrect, watch). As zsh does, the''')
rep('hooks/lib/aliases.sh','''      # shellcheck disable=SC2016 # a literal $, for G00
      pre="$pre"'$KERN_ALIAS_PAST_8 \'''','''      # shellcheck disable=SC2016 # a literal $, for G00
      pre="$pre"'; $KERN_ALIAS_PAST_8 \'''')
rep('docs/plans/contract.md','''8 times; a 9th word that is still such an alias becomes the command name `$KERN_ALIAS_PAST_8`, which G00 reads as built at run time''',
'''8 times; a 9th word that is still such an alias starts a record of its own (after `; `) whose command name is `$KERN_ALIAS_PAST_8`, which G00 reads as built at run time whatever the expansions before it start with''')
