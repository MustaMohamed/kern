#!/usr/bin/env bats
# tests/scripts/no-commit-review.bats: one task through ledger-open, review and task-done --probe, with no
# commit anywhere and the main checkout unchanged.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf 'exit 0\n' > check.sh
  git add check.sh && git commit --quiet -m check && git push --quiet origin main
  printf '%s\n' '---' 'status: approved' 'spec: none' 'approved: 2026-10-14, "yes, delegate"' 'execution: delegate' 'commits: ask' '---' > "$TMP/plan.md"
}

@test "a task is opened, changed, packaged, reviewed and closed without a commit" {
  main_branch=$(git rev-parse --abbrev-ref HEAD)
  main_status=$(git status --porcelain | git hash-object --stdin)
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/plan.md" 2> /dev/null)
  wt=$(bash "$KERN_ROOT/scripts/wt-new" plan-x 2> /dev/null)
  head_before=$(git -C "$wt" rev-parse HEAD)
  before=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  bash "$KERN_ROOT/scripts/task-start" "$dir/ledger.md" 1 "$before" > /dev/null
  printf '[ "$1" -ge 0 ]\n' > "$wt/check.sh"
  mkdir -p "$wt/test"
  printf 'sh check.sh -1 && exit 1\necho guarded\n' > "$wt/test/check_test.sh"
  after=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  printf 'check.sh\ntest/\n' > "$dir/briefs/task-1.files"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$wt" "$before" "$after" --out "$dir/reviews/task-1.diff" --allow-file "$dir/briefs/task-1.files"
  [ "$status" -eq 0 ]
  grep -q '^+\[ "\$1" -ge 0 \]$' "$dir/reviews/task-1.diff"
  bash "$KERN_ROOT/scripts/task-review" "$dir/ledger.md" 1 "$after" 1 compliant approved > /dev/null
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$dir/ledger.md" 1 "$wt" "$after" --probe "$dir/reviews/task-1.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  grep -q "^Task 1: complete tree=$after test=sh test/check_test.sh exit=0 review=approved probe=ok last=guarded$" "$dir/ledger.md"
  [ "$(git -C "$wt" rev-parse HEAD)" = "$head_before" ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "$main_branch" ]
  [ "$(git status --porcelain | git hash-object --stdin)" = "$main_status" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "main: unchanged" ]
}
