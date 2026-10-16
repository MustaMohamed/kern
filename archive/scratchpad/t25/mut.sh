cd "$(dirname "$0")/kc2" || exit 1
T="tests/skills/finish-branch.test.mjs tests/skills/prove-it.test.mjs"
mut(){ cp "$1" "$1.bak"; node ../rep.mjs "$1" "$2" "$3" || { echo "$4 => NOT APPLIED"; mv "$1.bak" "$1"; return; }
  r=$(node --test $T 2>&1 | grep -E '^# fail'); echo "$4 => $r"; mv "$1.bak" "$1"; }
K=skills/finish-branch
echo "baseline: $(node --test $T 2>&1 | grep -E '^# fail')"
mut $K/SKILL.md "propose a split; stop on yes, go on on no" "propose a split; go on on yes, stop on no" "size swap"
mut $K/SKILL.md "behind above 0 is stale" "behind above 5 is stale" "stale thr"
mut $K/SKILL.md "Option 1 ends with the short SHA." "" "opt1 sha"
mut $K/references/push-and-pr.md "An open PR at an older head: push, report its URL, and open no new PR." "An open PR at an older head: report its URL, and open no new PR." "older head no push"
mut $K/references/branch-ops.md "If not, run" "If so, run" "tree cmp"
mut $K/SKILL.md "\`ready\`: go on." "\`ready\`: stop." "ready"
mut $K/references/branch-ops.md "prints only \`git config user.email\`" "prints any email" "author check loosened"
mut $K/references/branch-ops.md "\`git rev-parse --verify --quiet origin/<branch>\` prints a SHA" "\`git rev-parse --verify --quiet origin/<branch>\` prints nothing" "published inverted"
mut $K/references/push-and-pr.md "Autopilot never rebases, so never lease-pushes." "" "autopilot lease sentence"
mut $K/references/push-and-pr.md "G1 asks when every commit past the base is the user's, else denies." "G1 allows it." "lease vote"
mut $K/references/discard.md "for the user to type with the \`!\` prefix" "and run them" "discard force by agent"
mut $K/references/branch-ops.md "run plain \`git worktree remove <path>\`, under autopilot too, then wt-new again" "run \`git worktree remove --force <path>\`" "stale force"
mut $K/references/branch-ops.md "<slug>-check-<sha7>" "<slug>-check" "slug no sha"
mut skills/prove-it/SKILL.md "unless this run is already inside commit or finish-branch" "" "gate loop"
mut $K/SKILL.md "no teardown runs but the stale-check removal" "no teardown runs" "autopilot stale removal"
mut $K/SKILL.md "ls -t <dir>/*/ledger.md" "ls -t <dir>" "ls -t"
mut $K/SKILL.md "Bash(bash \${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)" "Bash(git rev-list *)" "frontmatter rev-list"
mut $K/references/push-and-pr.md "A plain push rejected right after this run's rebase is that rebase: it rewrote published commits, so use the lease push." "" "rejected explanation"
mut $K/references/branch-ops.md "else G1 denies that push, so go on stale" "else rebase anyway" "others commits rebase"
mut $K/references/branch-ops.md "A PR counts only" "A PR counts only" "control"
echo END
