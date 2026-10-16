K=/Users/musta/Code/projects/kern
. "$K/hooks/lib/settings.sh"; . "$K/hooks/lib/gitctx.sh"
while IFS= read -r c; do cmd_mod "$c"; printf '%s  %s\n' "$?" "$c"; done <<'C'
cd /tmp
noglob cd /tmp
nocorrect cd /tmp
coproc cd /tmp
repeat 1 cd /tmp
repeat 0 cd /tmp
repeat 00 cd /tmp
repeat -1 cd /tmp
repeat -1+2 cd /tmp
repeat $N cd /tmp
repeat '1' cd /tmp
'coproc' cd /tmp
co''proc cd /tmp
'repeat' 1 cd /tmp
'nocorrect' cd /tmp
no''glob cd /tmp
\noglob cd /tmp
noglob repeat 1 cd /tmp
noglob coproc cd /tmp
nocorrect repeat 1 cd /tmp
repeat 1 nocorrect cd /tmp
nocorrect noglob cd /tmp
coproc noglob cd /tmp
repeat 1 coproc cd /tmp
cd /tmp 2> noglob
X=' noglob' cd /tmp
cd repeat
2> noglob cd /tmp
! coproc cd /tmp
C
