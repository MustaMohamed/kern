#!/bin/bash
# cmp.sh A B FILE...: compares tree A to tree B on every (snap, cwd, mode, idx); prints counts and each change.
a=$1; b=$2; shift 2
cat "$@" | awk -F'\t' -v A="$a" -v B="$b" '
  function rk(d) { return d == "deny" ? 3 : d == "ask" ? 2 : d == "none" ? 1 : d == "allow" ? 0 : 9 }
  { k = $2 "\t" $3 "\t" $4 "\t" $5 }
  $1 == A { da[k] = $6; ra[k] = $7; cm[k] = $8 }
  $1 == B { db[k] = $6; rb[k] = $7; cm[k] = $8 }
  END {
    for (k in da) {
      if (!(k in db)) { miss++; continue }
      n++
      x = rk(da[k]); y = rk(db[k])
      if (x == 9 || y == 9) t = "ERROR"; else if (y > x) t = "tighter"; else if (y < x) t = "LOOSER"; else t = "same"
      c[t]++
      if (t != "same") { split(k, p, "\t"); printf "%-7s %-7s %-4s %-3s #%-3s %-5s -> %-5s | %s\n    %s: %s\n    %s: %s\n", t, p[1], p[2], p[3], p[4], da[k], db[k], cm[k], A, substr(ra[k],1,200), B, substr(rb[k],1,200) }
    }
    printf "TOTAL %d compared (%d unmatched): same %d, tighter %d, LOOSER %d, ERROR %d\n", n, miss, c["same"], c["tighter"], c["LOOSER"], c["ERROR"]
  }'
