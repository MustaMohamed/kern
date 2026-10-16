set -u
KERN=/Users/musta/Code/projects/kern; S=$1; export HOME=$S/home; mkdir -p $HOME
GIT="git -c user.name=T -c user.email=t@e.x -c commit.gpgsign=false"
setup() { # name
  B=$S/w/$1; rm -rf $B; mkdir -p $B; R=$B/repo; git init -q -b main $R; cd $R
  git config user.name T; git config user.email t@e.x; git config commit.gpgsign false
  for f in a.txt b.txt shared.txt old.txt; do printf 'x\n%s\n' $f > $f; done; git add .; git commit -qm init
  git switch -q -c CDS-1/feat; W=$B/wt; git worktree add -q -b CDS-2/plan $W
  mkdir -p $R/.kern; echo '/.kern/' >> $R/.git/info/exclude
  L=$R/.kern/ledgers/plan1; mkdir -p $L/reviews $L/briefs
  echo "Worktree: $W branch=CDS-2/plan base-tree=x" > $L/ledger.md
  SNAP=$(bash $KERN/scripts/wt-snap $W); T0=$SNAP
}
task() { # N tree-before : closes task with current wt state
  n=$1; before=$2; after=$(bash $KERN/scripts/wt-snap $W)
  echo "Task $n: start tree=$before at=z" >> $L/ledger.md
  (cd $W && bash $KERN/scripts/wt-diff $W $before $after --out $L/reviews/task-$n-${after:0:7}.diff >/dev/null)
  echo "Task $n: complete tree=$after test=x exit=0 review=approved probe=ok last=x" >> $L/ledger.md
  echo $after
}
files_pkg() { n=$1; t=$(grep "^Task $n: complete" $L/ledger.md | sed 's/.*tree=\([0-9a-f]*\).*/\1/'); f=$L/reviews/task-$n-${t:0:7}.diff
  [ -f $f ] || { echo MISSING; return; }
  awk '/^## Files changed/{on=1;next} /^$/{on=0} on{for(i=2;i<=NF;i++)print $i}' $f; }
files_fallback() { n=$1; s=$(grep "^Task $n: start" $L/ledger.md | sed 's/.*tree=\([0-9a-f]*\).*/\1/'); c=$(grep "^Task $n: complete" $L/ledger.md | sed 's/.*tree=\([0-9a-f]*\).*/\1/'); git -C $W diff --name-only $s $c; }
commit() { # msg paths...
  m=$1; shift; echo "  git -C wt add -- $*"; git -C $W add -- "$@" ; printf 'CDS-2: %s\n\nwhy\n' "$m" > $R/.kern/msg; git -C $W commit -q -F $R/.kern/msg && echo "  commit ok: $(git -C $W log -1 --format='%h %s')  staged-after-status:" && git -C $W status --porcelain | sed 's/^/    /'; }
final() { echo "  HEAD^{tree}=$(git -C $W rev-parse 'HEAD^{tree}')  proven(step4 snap)=$PROVEN  $( [ "$(git -C $W rev-parse 'HEAD^{tree}')" = "$PROVEN" ] && echo EQUAL || echo MISMATCH)"; }
