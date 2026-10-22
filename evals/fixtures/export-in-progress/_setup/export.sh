#!/usr/bin/env bash
# Setup for the export-in-progress fixture layer. workspace() runs it in the project root, with this
# folder as $SETUP_FILES. It builds the state a delegate-mode execute-plan run of .kern/plans/export.md
# leaves when the implementer has just returned Status: DONE for Task 3 and nothing has checked it yet:
# - the plan worktree .claude/worktrees/export on branch kern/export, made off a fresh origin/main as
#   wt-new makes it, so the case needs origin: true;
# - Tasks 1 and 2 done there and recorded by snapshot trees, uncommitted, as `commits: ask` leaves them;
# - Task 3's change on top (task-3/), whose new test fails although its report says DONE;
# - the ledger .kern/ledgers/export/ledger.md, each line in the format its script writes, with this
#   workspace's paths and tree ids.
set -euo pipefail
files=${SETUP_FILES:?run by workspace(), which sets SETUP_FILES}
root=$(pwd -P)
g() { git -c user.email=dev@example.com -c user.name=dev -c commit.gpgsign=false "$@"; }

g -C "$root" fetch --quiet origin main
mkdir -p "$root/.claude/worktrees"
printf '/.claude/worktrees/\n' >> "$root/.git/info/exclude"
g -C "$root" worktree add --quiet --no-track -b kern/export "$root/.claude/worktrees/export" refs/remotes/origin/main
wt=$(cd "$root/.claude/worktrees/export" && pwd -P)
printf 'setup: none (worktree.setup unset)\n' > "$(git -C "$wt" rev-parse --path-format=absolute --git-dir)/kern-setup-done"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# snap: the tree of the worktree's whole working state, as scripts/wt-snap prints it.
snap() {
  rm -f "$tmp/index"
  GIT_INDEX_FILE="$tmp/index" git -C "$wt" read-tree HEAD &&
    GIT_INDEX_FILE="$tmp/index" git -C "$wt" add -A &&
    GIT_INDEX_FILE="$tmp/index" git -C "$wt" write-tree
}
base=$(snap)
cp -R "$files/task-1/." "$wt/"
t1=$(snap)
cp -R "$files/task-2/." "$wt/"
t2=$(snap)
cp -R "$files/task-3/." "$wt/"

# The header as ledger-open writes it: the Plan: line, the plan's blob hash, then the Main: line, the
# main checkout, its branch, its HEAD and a hash of its status.
main=$(git -C "$root" worktree list --porcelain | sed -n 's/^worktree //p' | head -n 1)
st=$(git --no-optional-locks -C "$main" status --porcelain)
hash=$({ [ -z "$st" ] || printf '%s\n' "$st"; } | git hash-object --stdin)
branch=$(git -C "$main" symbolic-ref -q --short HEAD)
head=$(git -C "$main" rev-parse -q --verify HEAD)
plan="$(cd "$root/.kern/plans" && pwd -P)/export.md"
planhash=$(git hash-object --no-filters -- "$plan")

# at SECONDS: a UTC time as task-start prints it. GNU date takes -d @S, BSD date -r S.
if date -u -d @0 +%s > /dev/null 2>&1; then
  at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
else
  at() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
fi
now=$(date +%s)

dir="$root/.kern/ledgers/export"
mkdir -p "$dir/briefs" "$dir/reports" "$dir/reviews" "$dir/logs"
cat > "$dir/ledger.md" << EOF
# kern ledger: $plan
Plan: $planhash
Main: $main branch=$branch head=$head status=$hash
Preflight: Task 1 x Task 2: test/export.test.js: run in order, Task 2 is blocked by Task 1
Preflight: Task 1 x Task 3: test/export.test.js: run in order, Task 3 is blocked by Task 2
Preflight: Task 2 x Task 3: test/export.test.js: run in order, Task 3 is blocked by Task 2
Worktree: $wt branch=kern/export base-tree=$base
Task 1: start tree=$base at=$(at $((now - 3 * 3600)))
Task 1: review round=1 tree=$t1 spec=compliant quality=approved
Task 1: complete tree=$t1 test=npm test exit=0 review=approved probe=skipped (probe inconclusive: new module) last=# duration_ms 58.1
Task 2: start tree=$t1 at=$(at $((now - 2 * 3600)))
Task 2: review round=1 tree=$t2 spec=compliant quality=approved
Task 2: complete tree=$t2 test=npm test exit=0 review=approved probe=ok last=# duration_ms 61.4
Task 3: start tree=$t2 at=$(at $((now - 3600)))
EOF
