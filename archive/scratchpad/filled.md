GOAL add parser
SCOPE may write src/a.txt; worktree /w base origin/main
CONTEXT see src
ACCEPTANCE a changes
VERIFY bash /Users/musta/Code/projects/kern/scripts/wt-check /w origin/main
  then true
TIMEBOX 10m
FORBIDDEN commit
REPORT status
STANDING work in worktree
