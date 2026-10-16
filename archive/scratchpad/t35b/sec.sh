B=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b
A=$1; Z=$2
for r in "1 103 reviewer-103" "104 133 fix5-30" "134 224 task35-91" "225 292 ordinary-68" "293 359 round1-67" "360 684 modifiers-325" "685 775 n1-p1-91" "776 822 followup-47"; do set -- $r
cat $B/${RES:-res1}/*.tsv | awk -F'\t' -v lo=$1 -v hi=$2 -v nm=$3 -v A=$A -v Z=$Z '
 function rk(d){return d=="deny"?3:d=="ask"?2:d=="none"?1:d=="allow"?0:9}
 $5>=lo && $5<=hi { k=$2 FS $3 FS $4 FS $5; d[$1,k]=$6; K[k]=1 }
 END { for (k in K) { x=rk(d[A,k]); y=rk(d[Z,k]); t = (x==9||y==9)?"E":y>x?"T":y<x?"L":"S"; c[t]++ }
   printf "%-14s %s->%s: same %d tighter %d looser %d error %d\n", nm, A, Z, c["S"], c["T"], c["L"], c["E"] }'
done
