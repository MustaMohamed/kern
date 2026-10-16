S=$1; . $S/walk.sh $S 2>&1
KERN=/Users/musta/Code/projects/kern
echo "== A: two complete tasks, disjoint (a.txt | b.txt)"
setup A; echo t1 >> $W/a.txt; s1=$(task 1 $T0); echo t2 >> $W/b.txt; s2=$(task 2 $s1); PROVEN=$(bash $KERN/scripts/wt-snap $W)
echo " status:"; git -C $W status --porcelain | sed 's/^/   /'
echo " task1 paths: $(files_pkg 1|tr '\n' ' ')"; commit "task one" $(files_pkg 1)
echo " task2 paths: $(files_pkg 2|tr '\n' ' ')"; commit "task two" $(files_pkg 2); final

echo "== B: two complete tasks share shared.txt"
setup B; echo t1 >> $W/a.txt; echo t1 >> $W/shared.txt; s1=$(task 1 $T0); echo t2 >> $W/b.txt; echo t2 >> $W/shared.txt; s2=$(task 2 $s1); PROVEN=$(bash $KERN/scripts/wt-snap $W)
echo " t1: $(files_pkg 1|tr '\n' ' ') t2: $(files_pkg 2|tr '\n' ' ')"
echo " overlap=shared.txt -> one commit naming each:"; commit "tasks one and two" $(files_pkg 1) $(files_pkg 2 | grep -vx -f <(files_pkg 1)); final

echo "== C: parked started task 3 whose .files shares shared.txt; complete task 1 (a.txt, shared.txt), complete task 2 (b.txt)"
setup C; echo t1 >> $W/a.txt; echo t1 >> $W/shared.txt; s1=$(task 1 $T0); echo t2 >> $W/b.txt; s2=$(task 2 $s1)
echo "Task 3: start tree=$s2 at=z" >> $L/ledger.md; printf 'shared.txt\nsrc/\n' > $L/briefs/task-3.files; echo partial3 >> $W/shared.txt; PROVEN=$(bash $KERN/scripts/wt-snap $W)
echo " t1 shares shared.txt with started task 3 -> not committed by path (ask/park, default uncommitted)"
echo " task2 (disjoint) commits:"; commit "task two" $(files_pkg 2)
echo " status after:"; git -C $W status --porcelain | sed 's/^/   /'; final
echo " (rule gap check) task 3 started but .files missing the path it actually dirtied:"; 

echo "== D: rename old.txt -> new.txt in package"
setup D; mv $W/old.txt $W/new.txt; s1=$(task 1 $T0); PROVEN=$(bash $KERN/scripts/wt-snap $W)
grep -A3 '^## Files changed' $L/reviews/task-1-*.diff | sed 's/^/   /' | cat -A | sed -n 1,4p
echo " paths from name-status fields: $(files_pkg 1|tr '\n' ' ')"; commit "rename" $(files_pkg 1); final

echo "== E: missing package -> name-only fallback (rename task)"
setup E; mv $W/old.txt $W/new.txt; s1=$(task 1 $T0); PROVEN=$(bash $KERN/scripts/wt-snap $W); rm $L/reviews/task-1-*.diff
echo " package: $(files_pkg 1)  fallback paths: $(files_fallback 1|tr '\n' ' ')"; commit "rename via fallback" $(files_fallback 1); final
echo "== E2: missing package, plain modify + delete"
setup E2; echo m >> $W/a.txt; rm $W/b.txt; s1=$(task 1 $T0); PROVEN=$(bash $KERN/scripts/wt-snap $W); rm $L/reviews/task-1-*.diff
echo " fallback paths: $(files_fallback 1|tr '\n' ' ')"; commit "modify+delete" $(files_fallback 1); final

echo "== F: task 1 already committed, task 2 pending"
setup F; echo t1 >> $W/a.txt; s1=$(task 1 $T0); git -C $W add a.txt; git -C $W commit -qm "CDS-2: one"; echo t2 >> $W/b.txt; s2=$(task 2 $s1); PROVEN=$(bash $KERN/scripts/wt-snap $W)
echo " status: $(git -C $W status --porcelain | tr '\n' ' ')"
echo " task1 paths: $(files_pkg 1|tr '\n' ' ') -> clean in status => already committed (not failure)"
echo " task2:"; commit "task two" $(files_pkg 2); final
echo " F2: task1 already committed, then later task2 touches a.txt too (uncommitted)"
setup F2; echo t1 >> $W/a.txt; s1=$(task 1 $T0); git -C $W add a.txt; git -C $W commit -qm "CDS-2: one"; echo t2 >> $W/a.txt; echo t2 >> $W/b.txt; s2=$(task 2 $s1)
echo " status: $(git -C $W status --porcelain | tr '\n' ' ') ; t1 paths $(files_pkg 1) dirty (a.txt) but committed -> misread as uncommitted & overlapping with t2"
