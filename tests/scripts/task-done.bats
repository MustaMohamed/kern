#!/usr/bin/env bats
# tests/scripts/task-done.bats: task-review records verdicts; task-done closes only a reviewed, unchanged tree.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf 'exit 0\n' > check.sh
  git add check.sh && git commit --quiet -m check && git push --quiet origin main
  WT=$(bash "$KERN_ROOT/scripts/wt-new" task-x 2> /dev/null)
  L="$TMP/ledger"
  mkdir -p "$L"
  printf '# kern ledger: plan.md\n' > "$L/ledger.md"
  T0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  # The task: a guard in check.sh and a test that needs it.
  printf '[ "$1" -ge 0 ]\n' > "$WT/check.sh"
  mkdir -p "$WT/test"
  printf 'sh check.sh -1 && exit 1\necho guard holds\n' > "$WT/test/check_test.sh"
  T1=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  PKG=$(bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T1" --out "$L/reviews/task-1.diff" | head -n 1)
}

review() { bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$1" "${2:-1}" "${3:-compliant}" "${4:-approved}" > /dev/null; }

@test "task-review appends the verdict line and deferred minors" {
  run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$T1" 1 compliant approved --minor "name the helper check_guard"
  [ "$status" -eq 0 ]
  [ "$(tail -n 2 "$L/ledger.md" | head -n 1)" = "Task 1: review round=1 tree=$T1 spec=compliant quality=approved" ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: minor (deferred): name the helper check_guard" ]
}

@test "task-review refuses a bad verdict, a fourth round and a short tree id" {
  for args in "$T1 1 ok approved" "$T1 4 compliant approved" "$T1 1 compliant fine" "abc 1 compliant approved"; do
    run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 $args
    [ "$status" -eq 2 ] || { echo "accepted: $args"; false; }
  done
  [ "$(grep -c 'review' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a task with no review and writes nothing" {
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"has no review line"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a review of an older tree, and a review with issues" {
  review "$T0"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  review "$T1" 1 issues needs-fixes
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"did not approve tree"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a worktree edited after its review" {
  review "$T1"
  printf 'late\n' > "$WT/late.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"changed after the review"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "an approved, unchanged tree with a passing command is recorded with its last output line" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=sh test/check_test.sh exit=0 review=approved probe=skipped (test only) last=guard holds" ]
}

@test "a failing command is not recorded and keeps its exit code" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- bash -c 'echo boom; exit 4'
  [ "$status" -eq 4 ]
  [[ "$output" == *boom* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
  grep -q boom "$L/logs/task-1.log"
}

@test "--probe records ok when the test fails with the change reversed" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$L/ledger.md")" == *" probe=ok last=guard holds" ]] || false
}

@test "--probe refuses a task whose test passes without the change" {
  printf 'echo always\n' > "$WT/test/check_test.sh"
  T2=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T2" --out "$L/reviews/task-1b.diff" > /dev/null
  review "$T2"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T2" --probe "$L/reviews/task-1b.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"does not prove Task 1"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done needs --probe PATCH or --no-probe REASON, and writes nothing without one" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--no-probe needs a reason"* ]] || false
  ! grep -q "^Task 1: complete" "$L/ledger.md"
}

@test "task-done quotes arguments with spaces in the ledger line" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- bash -c 'exit 0'
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$L/ledger.md")" == "Task 1: complete tree=$T1 test=bash -c 'exit 0' exit=0 review=approved probe=skipped (test only) last="* ]] || false
}

@test "task-done refuses an empty --probe patch, an unsnappable worktree and an unreadable ledger" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--probe needs a patch file"* ]] || false
  mkdir "$TMP/notgit"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$TMP/notgit" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"cannot snapshot"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$TMP/missing.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  ! grep -q "^Task 1: complete" "$L/ledger.md"
}

@test "task-done refuses a malformed last review line" {
  printf 'Task 1: review round=1 tree=%s spec=compliant quality=approved extra\n' "$T1" >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"did not approve tree"* ]] || false
}
