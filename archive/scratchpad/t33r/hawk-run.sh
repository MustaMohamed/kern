#!/bin/bash
# hawk-run.sh AWK DIR: runs the head awk on each case with a 10 s cap; prints case, rc, time, output.
A=$1; D=$2
for f in "$D"/c*.txt; do
  s=$(date +%s)
  out=$(perl -e "alarm 10; exec @ARGV" "$A" -v sq="'" -f "$D/../head-awk.awk" < "$f" 2>&1); rc=$?
  e=$(( $(date +%s) - s ))
  printf '%s rc=%s t=%ss out=%s\n' "$(basename "$f")" "$rc" "$e" "$(printf '%s' "$out" | head -c 160 | tr '\n' '|')"
done
