K=/Users/musta/Code/projects/kern; export KERN_ROOT=$K CWD=$S
for lib in json settings state decide gitctx; do . $K/hooks/lib/$lib.sh; done
. $K/hooks/guards/g18-readonly-agent.sh
for c in "wc -c app.log" "rg -n 'ERROR|WARN' app.log" "sed -n 1200,1260p app.log" "sort -rn counts.txt" "git log -S foo" "awk '{print}' f" "zcat f.gz" "sqlite3 db .dump" "sed -i s/a/b/ f" "rg --pre cat x f" "git log -S <symbol>" "tee out" "rm -rf x" "echo hi > f"; do g18_allowed "$c" && echo "ALLOW: $c" || echo "DENY:  $c"; done
