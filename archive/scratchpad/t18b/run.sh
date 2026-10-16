K=/Users/musta/Code/projects/kern/skills/diagnose/scripts
FP() { /bin/bash $K/find-polluter.sh "$@"; }
LR() { /bin/bash $K/loop-rate.sh "$@"; }
cd $1; export TMPDIR=$1/tmp; mkdir -p tmp t
r() { echo "\$ $*"; "$@"; echo "rc=$?"; rm -f polluted; }
printf 'true\n' > t/a.sh; printf 'exit 126\n' > t/b.sh; printf 'true\n' > t/c.sh
echo "## 126 on 2nd (sh wrapper: sh -c)"; r FP polluted 't/*.sh' -- sh -c 'case "$1" in *b.sh) exit 126;; esac' x
printf 'exit 127\n' > t/b.sh; r FP polluted 't/*.sh' -- sh -c 'case "$1" in *b.sh) exit 127;; esac' x
echo "## all exit 1, no pollution"; r FP polluted 't/*.sh' -- sh -c 'exit 1' x
echo "## mixed pass/fail + real polluter"; r FP polluted 't/*.sh' -- sh -c 'case "$1" in *a.sh) exit 1;; *b.sh) touch polluted; exit 1;; esac' x
echo "## all fail, one creates"; r FP polluted 't/*.sh' -- sh -c 'case "$1" in *b.sh) touch polluted;; esac; exit 1' x
echo "## mixed no polluter"; r FP polluted 't/*.sh' -- sh -c 'case "$1" in *a.sh) exit 1;; esac' x
echo "## single file all fail"; rm t/b.sh t/c.sh; r FP polluted 't/*.sh' -- sh -c 'exit 1' x
echo "## single file pass"; r FP polluted 't/*.sh' -- true
echo "## polluter + pre-existing: still 2"; touch polluted; r FP polluted 't/*.sh' -- true
echo "## LR 127 on run 3 of 5"; rm -f c; r LR 5 -- sh -c 'n=$(cat c 2>/dev/null||echo 0); n=$((n+1)); echo $n>c; [ $n -eq 3 ] && exit 127; exit 0'
rm -f c; echo "## LR 126 run1"; r LR 3 -- sh -c 'exit 126'
echo "## LR mixed"; rm -f c; r LR 5 -- sh -c 'n=$(cat c 2>/dev/null||echo 0); n=$((n+1)); echo $n>c; [ $((n%2)) -eq 1 ]'
echo "## LR 3 steady, 4 true, 1"; r LR 3 -- true; r LR 4 -- true; r LR 1 -- false
echo "## tmp leftovers:"; ls tmp | wc -l; ls -A . 
echo "## HITL closed"; cp $K/hitl-loop.template.sh h.sh; /bin/bash h.sh </dev/null; echo rc=$?
