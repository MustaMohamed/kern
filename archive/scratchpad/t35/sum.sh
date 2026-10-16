T=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35
for r in "1 103 reviewer-103" "104 133 fix5-30" "134 224 task35-91" "225 292 ordinary-68"; do set -- $r
cat $T/res2/*.tsv | awk -F'\t' -v lo=$1 -v hi=$2 -v nm=$3 '
 function rk(d){return d=="deny"?3:d=="ask"?2:d=="none"?1:d=="allow"?0:9}
 $5>=lo && $5<=hi { k=$2 FS $3 FS $4 FS $5; d[$1,k]=$6; K[k]=1 }
 END { for (k in K) for (p=1;p<=3;p++) { a = p==3?"base":p==1?"base":"p3c"; b = p==1?"p3c":"fin"; x=rk(d[a,k]); y=rk(d[b,k]); t = y>x?"T":y<x?"L":"S"; c[p,t]++ }
   printf "%-13s parts2+3: same %d tighter %d looser %d | part1: same %d tighter %d looser %d | all: same %d tighter %d looser %d\n", nm, c[1,"S"],c[1,"T"],c[1,"L"], c[2,"S"],c[2,"T"],c[2,"L"], c[3,"S"],c[3,"T"],c[3,"L"] }'
done
